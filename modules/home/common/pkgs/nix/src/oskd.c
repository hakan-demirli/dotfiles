#define _GNU_SOURCE
#include <errno.h>
#include <linux/input-event-codes.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>

#include "virtual-keyboard-unstable-v1-client-protocol.h"

#define LINE_CAPACITY 128
#define CHUNK_CAPACITY 512

enum command_kind {
  COMMAND_INVALID,
  COMMAND_KEY,
  COMMAND_RELEASE_ALL,
};

struct command {
  enum command_kind kind;
  uint32_t code;
  bool press;
};

struct line_reader {
  char data[LINE_CAPACITY];
  size_t length;
  bool overflow;
};

struct oskd {
  struct wl_display *display;
  struct wl_registry *registry;
  struct wl_seat *seat;
  struct zwp_virtual_keyboard_manager_v1 *manager;
  struct zwp_virtual_keyboard_v1 *keyboard;
  struct xkb_context *context;
  struct xkb_keymap *keymap;
  struct xkb_state *state;
  bool pressed[KEY_CNT];
};

static void fail(const char *message) {
  fprintf(stderr, "oskd: %s\n", message);
  exit(EXIT_FAILURE);
}

static void handle_global(void *data, struct wl_registry *registry, uint32_t name,
                          const char *interface, uint32_t version) {
  struct oskd *oskd = data;

  if (strcmp(interface, wl_seat_interface.name) == 0) {
    oskd->seat = wl_registry_bind(registry, name, &wl_seat_interface, version < 7 ? version : 7);
  } else if (strcmp(interface, zwp_virtual_keyboard_manager_v1_interface.name) == 0) {
    oskd->manager =
        wl_registry_bind(registry, name, &zwp_virtual_keyboard_manager_v1_interface, 1);
  }
}

static void handle_global_remove(void *data, struct wl_registry *registry, uint32_t name) {
  (void)data;
  (void)registry;
  (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = handle_global,
    .global_remove = handle_global_remove,
};

static bool prepare_keymap(struct oskd *oskd) {
  oskd->context = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
  if (oskd->context == NULL) {
    return false;
  }

  oskd->keymap = xkb_keymap_new_from_names(oskd->context, NULL, XKB_KEYMAP_COMPILE_NO_FLAGS);
  if (oskd->keymap == NULL) {
    return false;
  }

  oskd->state = xkb_state_new(oskd->keymap);
  return oskd->state != NULL;
}

static bool upload_keymap(struct oskd *oskd) {
  char *text = xkb_keymap_get_as_string(oskd->keymap, XKB_KEYMAP_FORMAT_TEXT_V1);
  if (text == NULL) {
    return false;
  }

  size_t size = strlen(text) + 1;
  int descriptor = memfd_create("oskd-keymap", MFD_CLOEXEC);
  if (descriptor < 0) {
    free(text);
    return false;
  }

  bool written = write(descriptor, text, size) == (ssize_t)size;
  free(text);
  if (!written) {
    close(descriptor);
    return false;
  }

  zwp_virtual_keyboard_v1_keymap(oskd->keyboard, WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1, descriptor,
                                 (uint32_t)size);
  wl_display_roundtrip(oskd->display);
  close(descriptor);
  return true;
}

static uint32_t now_milliseconds(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (uint32_t)((uint64_t)now.tv_sec * 1000 + (uint64_t)now.tv_nsec / 1000000);
}

static void send_modifiers(struct oskd *oskd) {
  zwp_virtual_keyboard_v1_modifiers(
      oskd->keyboard, xkb_state_serialize_mods(oskd->state, XKB_STATE_MODS_DEPRESSED),
      xkb_state_serialize_mods(oskd->state, XKB_STATE_MODS_LATCHED),
      xkb_state_serialize_mods(oskd->state, XKB_STATE_MODS_LOCKED),
      xkb_state_serialize_layout(oskd->state, XKB_STATE_LAYOUT_EFFECTIVE));
}

static void send_key(struct oskd *oskd, uint32_t code, bool press) {
  if (oskd->pressed[code] == press) {
    return;
  }

  oskd->pressed[code] = press;
  zwp_virtual_keyboard_v1_key(
      oskd->keyboard, now_milliseconds(), code,
      press ? WL_KEYBOARD_KEY_STATE_PRESSED : WL_KEYBOARD_KEY_STATE_RELEASED);

  if (xkb_state_update_key(oskd->state, code + 8, press ? XKB_KEY_DOWN : XKB_KEY_UP) != 0) {
    send_modifiers(oskd);
  }
}

static void release_all(struct oskd *oskd) {
  for (uint32_t code = 0; code < (uint32_t)KEY_CNT; code++) {
    send_key(oskd, code, false);
  }
}

static struct command parse_command(const char *line) {
  const struct command invalid = {.kind = COMMAND_INVALID};

  if (strcmp(line, "r") == 0) {
    return (struct command){.kind = COMMAND_RELEASE_ALL};
  }

  if (line[0] != 'k' || line[1] != ' ') {
    return invalid;
  }

  char *rest = NULL;
  errno = 0;
  unsigned long code = strtoul(line + 2, &rest, 10);
  if (errno != 0 || rest == line + 2 || code >= (unsigned long)KEY_CNT || *rest != ' ') {
    return invalid;
  }

  rest++;
  if ((rest[0] != '0' && rest[0] != '1') || rest[1] != '\0') {
    return invalid;
  }

  return (struct command){.kind = COMMAND_KEY, .code = (uint32_t)code, .press = rest[0] == '1'};
}

static void run_command(struct oskd *oskd, struct command command) {
  switch (command.kind) {
  case COMMAND_KEY:
    send_key(oskd, command.code, command.press);
    return;
  case COMMAND_RELEASE_ALL:
    release_all(oskd);
    return;
  case COMMAND_INVALID:
    fprintf(stderr, "oskd: ignored a malformed command\n");
    return;
  }
}

static bool read_commands(struct oskd *oskd, struct line_reader *reader) {
  char chunk[CHUNK_CAPACITY];
  ssize_t received = read(STDIN_FILENO, chunk, sizeof(chunk));
  if (received < 0) {
    return errno == EINTR || errno == EAGAIN;
  }
  if (received == 0) {
    return false;
  }

  for (ssize_t index = 0; index < received; index++) {
    if (chunk[index] != '\n') {
      if (reader->length + 1 < sizeof(reader->data)) {
        reader->data[reader->length++] = chunk[index];
      } else {
        reader->overflow = true;
      }
      continue;
    }

    reader->data[reader->length] = '\0';
    if (reader->overflow) {
      fprintf(stderr, "oskd: ignored an oversized command\n");
    } else {
      run_command(oskd, parse_command(reader->data));
    }
    reader->length = 0;
    reader->overflow = false;
  }

  return true;
}

int main(void) {
  struct oskd oskd = {0};

  oskd.display = wl_display_connect(NULL);
  if (oskd.display == NULL) {
    fail("cannot connect to the wayland display");
  }

  oskd.registry = wl_display_get_registry(oskd.display);
  wl_registry_add_listener(oskd.registry, &registry_listener, &oskd);
  wl_display_roundtrip(oskd.display);

  if (oskd.manager == NULL) {
    fail("the compositor does not implement zwp_virtual_keyboard_manager_v1");
  }
  if (oskd.seat == NULL) {
    fail("the compositor exposes no wl_seat");
  }

  if (!prepare_keymap(&oskd)) {
    fail("cannot compile the keymap");
  }

  oskd.keyboard =
      zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(oskd.manager, oskd.seat);
  if (!upload_keymap(&oskd)) {
    fail("cannot upload the keymap");
  }

  struct pollfd descriptors[] = {
      {.fd = wl_display_get_fd(oskd.display), .events = POLLIN},
      {.fd = STDIN_FILENO, .events = POLLIN},
  };
  struct line_reader reader = {0};

  while (true) {
    if (wl_display_flush(oskd.display) < 0 && errno != EAGAIN) {
      break;
    }
    if (poll(descriptors, 2, -1) < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    if (descriptors[0].revents & (POLLERR | POLLHUP)) {
      break;
    }
    if ((descriptors[0].revents & POLLIN) && wl_display_dispatch(oskd.display) < 0) {
      break;
    }
    if ((descriptors[1].revents & (POLLIN | POLLHUP)) && !read_commands(&oskd, &reader)) {
      break;
    }
  }

  release_all(&oskd);
  wl_display_roundtrip(oskd.display);

  zwp_virtual_keyboard_v1_destroy(oskd.keyboard);
  xkb_state_unref(oskd.state);
  xkb_keymap_unref(oskd.keymap);
  xkb_context_unref(oskd.context);
  zwp_virtual_keyboard_manager_v1_destroy(oskd.manager);
  wl_seat_destroy(oskd.seat);
  wl_registry_destroy(oskd.registry);
  wl_display_disconnect(oskd.display);
  return EXIT_SUCCESS;
}
