#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <sys/wait.h>

static int fzf_search_history(int count, int key) {
  char *saved_line = rl_line_buffer ? strdup(rl_line_buffer) : strdup("");

  HIST_ENTRY **hist_list = history_list();
  if (!hist_list) {
    free(saved_line);
    return 0;
  }

  int hist_count = 0;
  while (hist_list[hist_count]) {
    hist_count++;
  }

  int pipe_in[2], pipe_out[2];
  if (pipe(pipe_in) == -1 || pipe(pipe_out) == -1) {
    return 0;
  }

  pid_t pid = fork();
  if (pid == 0) {
    close(pipe_in[1]);
    close(pipe_out[0]);
    dup2(pipe_in[0], STDIN_FILENO);
    dup2(pipe_out[1], STDOUT_FILENO);

    char *query = rl_line_buffer ? rl_line_buffer : "";
    execlp("fzf", "fzf", "--height=40%", "--tiebreak=index", "--query", query,
           "--no-multi", NULL);
    exit(1);
  }

  close(pipe_in[0]);
  close(pipe_out[1]);

  for (int i = hist_count - 1; i >= 0; i--) {
    if (hist_list[i] && hist_list[i]->line) {
      write(pipe_in[1], hist_list[i]->line, strlen(hist_list[i]->line));
      write(pipe_in[1], "\n", 1);
    }
  }
  close(pipe_in[1]);

  char result[4096] = {0};
  ssize_t n = read(pipe_out[0], result, sizeof(result) - 1);
  if (n < 0) n = 0;
  result[n] = '\0';
  close(pipe_out[0]);

  int status;
  waitpid(pid, &status, 0);

  if (n > 0 && WIFEXITED(status) && WEXITSTATUS(status) == 0) {
    if (result[n - 1] == '\n') {
      result[n - 1] = '\0';
    }

    rl_replace_line(result, 0);
    rl_point = rl_end;
  }

  rl_forced_update_display();

  return 0;
}

static int fzf_complete(int count, int key) {
  rl_complete(count, key);
  return 0;
}

__attribute__((constructor)) static void init_fzf_bindings(void) {
  rl_bind_keyseq("\\C-r", fzf_search_history);
}
