/*
https://github.com/qmk/qmk_firmware/blob/d9737349769a8bd2198733a81c1c74bd7db82c3a/quantum/keycode.h#L354
Key | Key Code | Name in graphical environment
F20 | 198 | XF86AudioMicMute
F21 | 199 | XF86TouchpadToggle
F22 | 200 | XF86TouchpadOn
F23 | 201 | XF86TouchpadOff
??  | ??  | XF86ScreenSaver
*/

#include QMK_KEYBOARD_H

// ctrl alt del
// #define KC_CAD LALT(LCTL(KC_DEL))
// shift alt
// #define KC_SA LSFT(LALT(KC_TRNS))
// windows/super key
// LGUI(kc)

// shorten alias
// F codes are assigned in hyprland.conf
#define KC_MMUTE KC_F20
#define BUP KC_F13
#define BDOWN KC_F14
#define BOFF KC_F15
#define MMUTE KC_F16
#define MUTE KC_F17
#define VDOWN KC_KB_VOLUME_DOWN
#define VUP KC_KB_VOLUME_UP

// // Left-hand home row mods
// #define GUI_A LGUI_T(KC_A)
// #define ALT_S LALT_T(KC_S)
// #define SFT_D LSFT_T(KC_D)
// #define CTL_F LCTL_T(KC_F)

// // Right-hand home row mods
// #define CTL_J RCTL_T(KC_J)
// #define SFT_K RSFT_T(KC_K)
// #define ALT_L LALT_T(KC_L)
// #define GUI_SCLN RGUI_T(KC_SCLN)

// // Left-hand home row mods
#define GUI_A LT(QWERTY_RIGHT, KC_A)
#define ALT_S LT(QWERTY_RIGHT, KC_S)
#define SFT_D LT(QWERTY_RIGHT, KC_D)
#define CTL_F LT(QWERTY_RIGHT, KC_F)

// Right-hand home row mods
#define CTL_J LT(QWERTY_LEFT, KC_J)
#define SFT_K LT(QWERTY_LEFT, KC_K)
#define ALT_L LT(QWERTY_LEFT, KC_L)
#define GUI_SCLN LT(QWERTY_LEFT, KC_SCLN)

enum layers {
    QWERTY,
    QWERTY_LEFT,
    QWERTY_RIGHT,
    NUM_LEFT,
    NUM_RIGHT,
    SYM_LEFT,
    SYM_RIGHT,
    FUN_LEFT,
    FUN_RIGHT
};

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    // clang-format off
    [QWERTY] = LAYOUT(
        // Left
           KC_TAB,        KC_Q,       KC_W,       KC_E,        KC_R,          KC_T,         XXXXXXX,
           KC_ESC,        GUI_A,      ALT_S,      SFT_D,       CTL_F,         KC_G,         LT(NUM_RIGHT, KC_SPC),
           XXXXXXX,       KC_Z,       KC_X,       KC_C,        KC_V,          KC_B,         MO(SYM_RIGHT),
        // Right
           XXXXXXX,       KC_Y,       KC_U,       KC_I,        KC_O,          KC_P,         KC_BSPC,
           MO(NUM_LEFT),  KC_H,       CTL_J,      SFT_K,       ALT_L,         GUI_SCLN,     KC_ENT,
           MO(SYM_LEFT),  KC_N,       KC_M,       KC_COMM,     KC_DOT,        KC_SLSH,      XXXXXXX
        ),
    [QWERTY_LEFT] = LAYOUT(
        // Left
           KC_TAB,        KC_Q,       KC_W,       KC_E,        KC_R,          KC_T,         XXXXXXX,
           KC_ESC,        KC_A,       KC_S,       KC_D,        KC_F,          KC_G,         LT(NUM_RIGHT, KC_SPC),
           XXXXXXX,       KC_Z,       KC_X,       KC_C,        KC_V,          KC_B,         MO(SYM_RIGHT),
        // Right
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,    XXXXXXX,        XXXXXXX,      XXXXXXX,
           MO(NUM_LEFT),  XXXXXXX,    KC_LCTL,    KC_LSFT,    KC_LALT,        KC_LGUI,      XXXXXXX,
           MO(SYM_LEFT),  XXXXXXX,    XXXXXXX,    XXXXXXX,    XXXXXXX,        XXXXXXX,      XXXXXXX
        ),
    [QWERTY_RIGHT] = LAYOUT(
        // Left
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           XXXXXXX,       KC_LGUI,    KC_LALT,    KC_LSFT,     KC_LCTL,       XXXXXXX,      LT(NUM_RIGHT, KC_SPC),
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      MO(SYM_RIGHT),
        // Right
           XXXXXXX,       KC_Y,       KC_U,       KC_I,        KC_O,          KC_P,         KC_BSPC,
           MO(NUM_LEFT),  KC_H,       KC_J,       KC_K,        KC_L,          KC_SCLN,      KC_ENT,
           MO(SYM_LEFT),  KC_N,       KC_M,       KC_COMM,     KC_DOT,        KC_SLSH,      XXXXXXX
        ),
    [NUM_LEFT] = LAYOUT(
        // Left
           QK_BOOT,       XXXXXXX,    KC_7,       KC_8,        KC_9,          KC_0,         XXXXXXX,
           XXXXXXX,       XXXXXXX,    KC_4,       KC_5,        KC_6,          XXXXXXX,      LT(FUN_RIGHT, KC_SPC),
           XXXXXXX,       XXXXXXX,    KC_1,       KC_2,        KC_3,          XXXXXXX,      XXXXXXX,
        // Right
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      KC_BSPC,
           _______,       XXXXXXX,    KC_LCTL,    KC_LSFT,     KC_LALT,       KC_LGUI,      XXXXXXX,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX
        ),
    [NUM_RIGHT] = LAYOUT(
        // Left
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           XXXXXXX,       KC_LGUI,    KC_LALT,    KC_LSFT,     KC_LCTL,       XXXXXXX,      _______,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
        // Right
           XXXXXXX,       MUTE,       VDOWN,      VUP,         XXXXXXX,       KC_PASTE,     KC_DEL,
           MO(FUN_RIGHT), KC_LEFT,    KC_DOWN,    KC_UP,       KC_RIGHT,      KC_PSCR,      XXXXXXX,
           XXXXXXX,       MMUTE,      BDOWN,      BUP,         BOFF,          XXXXXXX,      XXXXXXX
        ),
    [SYM_LEFT] = LAYOUT(
        // Left
           XXXXXXX,       XXXXXXX,    KC_AMPR,    KC_ASTR,     KC_CIRC,       KC_AT,        XXXXXXX,
           XXXXXXX,       KC_EXCLAIM, KC_KP_MINUS,KC_KP_PLUS,  KC_KP_EQUAL,   KC_HASH,      XXXXXXX,
           XXXXXXX,       KC_BSLS,    KC_TILD,    KC_GRAVE,    KC_PERC,       KC_PIPE,      MO(FUN_LEFT),
        // Right
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           XXXXXXX,       XXXXXXX,    KC_LCTL,    KC_LSFT,     KC_LALT,       KC_LGUI,      XXXXXXX,
           _______,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX
        ),
    [SYM_RIGHT] = LAYOUT(
        // Left
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           XXXXXXX,       KC_LGUI,    KC_LALT,    KC_LSFT,     KC_LCTL,       XXXXXXX,      XXXXXXX,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      _______,
        // Right
           XXXXXXX,       KC_QUOT,    KC_LCBR,    KC_RCBR,     KC_DOLLAR,     XXXXXXX,      KC_UNDS,
           XXXXXXX,       XXXXXXX,    KC_LPRN,    KC_RPRN,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           MO(FUN_LEFT),  KC_DQUO,    KC_LBRC,    KC_RBRC,     XXXXXXX,       XXXXXXX,      XXXXXXX
        ),
    [FUN_LEFT] = LAYOUT(
        // Left
           XXXXXXX,       XXXXXXX,    KC_F7,       KC_F8,        KC_F9,       KC_F10,       XXXXXXX,
           XXXXXXX,       XXXXXXX,    KC_F4,       KC_F5,        KC_F6,       KC_F11,       _______,
           XXXXXXX,       XXXXXXX,    KC_F1,       KC_F2,        KC_F3,       KC_F12,       XXXXXXX,
        // Right
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           _______,       XXXXXXX,    KC_LCTL,    KC_LSFT,     KC_LALT,       KC_LGUI,      XXXXXXX,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX
        ),
    [FUN_RIGHT] = LAYOUT(
        // Left
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           XXXXXXX,       KC_LGUI,    XXXXXXX,    KC_MS_BTN2,  KC_MS_BTN1,    XXXXXXX,      _______,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    KC_MS_WH_UP, KC_MS_WH_DOWN, XXXXXXX,      XXXXXXX,
        // Right
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX,
           _______,       KC_MS_LEFT, KC_MS_DOWN, KC_MS_UP,    KC_MS_RIGHT,   XXXXXXX,      XXXXXXX,
           XXXXXXX,       XXXXXXX,    XXXXXXX,    XXXXXXX,     XXXXXXX,       XXXXXXX,      XXXXXXX
        ),
    // clang-format on
};

#define HOLD_MOD(MOD_KEY)                      \
    if (record->tap.count == 0) {              \
        if (record->event.pressed) {           \
            register_mods(MOD_BIT(MOD_KEY));   \
        } else {                               \
            unregister_mods(MOD_BIT(MOD_KEY)); \
        }                                      \
    }                                          \
    return true;

bool process_record_user(uint16_t keycode, keyrecord_t* record)
{
    // Switch to the LAYER 'layer with MOD applied' on hold, KC_KEY on tap.
    switch (keycode) {
    case GUI_A:
        HOLD_MOD(KC_LGUI)
    case ALT_S:
        HOLD_MOD(KC_LALT)
    case SFT_D:
        HOLD_MOD(KC_LSFT)
    case CTL_F:
        HOLD_MOD(KC_LCTL)
    case GUI_SCLN:
        HOLD_MOD(KC_RGUI)
    case ALT_L:
        HOLD_MOD(KC_RALT)
    case SFT_K:
        HOLD_MOD(KC_RSFT)
    case CTL_J:
        HOLD_MOD(KC_RCTL)
    }
    return true; // Continue default handling.
}
