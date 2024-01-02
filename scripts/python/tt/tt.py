#!/usr/bin/env python3

import os
import sys
import termios
import copy
import tty
from typing import Final, Tuple

from terminal_runner import TerminalRunner

TASK_LIST_COMMAND: Final = ["task", "list"]
TASK_SUMMARY_COMMAND: Final = ["task", "summary"]
TASK_INFO_COMMAND: Final = ["task", "info"]
TASK_LIST_DONE_COMMAND: Final = ["task", "done"]
TASK_LIST_START_COMMAND: Final = ["task", "start"]
TASK_LIST_STOP_COMMAND: Final = ["task", "stop"]
TASK_ADD_COMMAND: Final = ["task", "add"]
GREEN: Final = "42;30"


class State:
    def __init__(self, keymaps, window_state, list_state):
        self.keymaps = keymaps
        self.window_state = window_state
        self.list_state = list_state
        self.current_list = "(none)"
        self.list_index = 1
        self.summary_index = 1
        self.input_string = ""

    def get_task_list_command(self):
        if self.current_list == "(none)":
            return TASK_LIST_COMMAND + ["-PROJECT"]
        else:
            return TASK_LIST_COMMAND + [f"project:{self.current_list}"]


def getkey() -> Tuple[bytes, str]:
    """Read key press. This is a blocking function."""
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    tty.setcbreak(fd)  # https://en.wikipedia.org/wiki/Terminal_mode
    try:
        b = os.read(fd, 5)  # read up to 5 bytes

        key_mapping = {
            (127,): "backspace",
            (10,): "return",
            (32,): "space",
            (9,): "tab",
            (27,): "esc",
            (27, 91, 65): "up",
            (
                27,
                91,
                66,
            ): "down",
            (
                27,
                91,
                67,
            ): "right",
            (
                27,
                91,
                68,
            ): "left",
            (27, 91, 72): "home",
            (27, 91, 70): "end",
            (27, 91, 50, 126): "insert",
            (27, 91, 51, 126): "delete",
            (27, 91, 53, 126): "pageup",
            (27, 91, 54, 126): "pagedown",
            (27, 79, 80): "f1",
            (27, 79, 81): "f2",
            (27, 79, 82): "f3",
            (27, 79, 83): "f4",
            (27, 91, 49, 53, 126): "f5",
            (27, 91, 49, 55, 126): "f6",
            (27, 91, 49, 56, 126): "f7",
            (27, 91, 49, 57, 126): "f8",
            (27, 91, 50, 48, 126): "f9",
            (27, 91, 50, 49, 126): "f10",
            # F11 is already used to toggle fullscreen.
            (27, 91, 50, 52, 126): "f12",
        }

        keyname = key_mapping.get(tuple(b), "unknown")
        if keyname == "unknown" and len(b) == 1:
            # Check for printable ASCII characters 33-126.
            n = ord(b)
            if n >= 33 and n <= 126:
                keyname = chr(n)
        return b, keyname
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)


def task_summary_move_up(key: str, state: State) -> State:
    def get_below(lines, idx) -> int:
        return 1 if idx == len(lines) - 1 else idx + 1

    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    idx = get_below(clines, state.summary_index)
    state.summary_index = idx
    TerminalRunner().render_screen(TerminalRunner().highlight_line(idx, clines, GREEN))

    return state


def task_summary_move_down(key: str, state: State) -> State:
    def get_below(lines, idx) -> int:
        return 1 if idx == len(lines) - 1 else idx + 1

    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    idx = get_below(clines, state.summary_index)
    state.summary_index = idx
    TerminalRunner().render_screen(TerminalRunner().highlight_line(idx, clines, GREEN))

    return state


def task_summary_to_list(key: str, state: State) -> State:
    def index_to_list(idx):
        lines = TerminalRunner().get_colorless_lines(TASK_SUMMARY_COMMAND)
        return lines[idx + 1].split()[0]

    try:
        state.current_list = index_to_list(state.summary_index)
        state.window_state = "list"
        return task_list_move_top("g", state)
    except Exception:
        return state


def task_list_move_down(key: str, state: State) -> State:
    def get_below(lines, idx) -> int:
        return 1 if idx == len(lines) - 1 else idx + 1

    clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
    idx = get_below(clines, state.list_index)
    state.list_index = idx
    TerminalRunner().render_screen(TerminalRunner().highlight_line(idx, clines, GREEN))

    return state


def task_summary_move_top(key: str, state: State) -> State:
    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    idx = 1
    state.summary_index = idx
    TerminalRunner().render_screen(TerminalRunner().highlight_line(idx, clines, GREEN))

    return state


def task_summary_move_end(key: str, state: State) -> State:
    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    idx = len(clines) - 1
    state.summary_index = idx
    TerminalRunner().render_screen(TerminalRunner().highlight_line(idx, clines, GREEN))

    return state


def task_list_move_top(key: str, state: State) -> State:
    clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
    idx = 1
    state.list_index = idx
    TerminalRunner().render_screen(TerminalRunner().highlight_line(idx, clines, GREEN))

    return state


def task_list_move_end(key: str, state: State) -> State:
    clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
    idx = len(clines) - 1
    state.list_index = idx
    TerminalRunner().render_screen(TerminalRunner().highlight_line(idx, clines, GREEN))

    return state


def task_list_move_up(key: str, state: State) -> State:
    def get_index_above(lines, idx) -> int:
        return len(lines) - 1 if idx == 1 else idx - 1

    clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
    idx = get_index_above(clines, state.list_index)
    state.list_index = idx
    TerminalRunner().render_screen(TerminalRunner().highlight_line(idx, clines, GREEN))

    return state


def task_list_add(key: str, state: State) -> State:
    state.list_state = "insert"
    clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
    clines.append(f": {state.input_string}")
    TerminalRunner().render_screen(
        TerminalRunner().highlight_line(state.list_index, clines, GREEN)
    )

    return state


def task_list_to_summary(key: str, state: State) -> State:
    state.window_state = "summary"
    return task_summary_move_top("g", state)


def task_list_insert(key: str, state: State) -> State:
    if key == "space":
        state.input_string += " "
    elif key == "backspace":
        state.input_string = state.input_string[:-1]
    elif key == "return":
        state.list_state = "normal"
        _ = TerminalRunner().run(TASK_ADD_COMMAND + [state.input_string])
    else:
        state.input_string += key
    clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
    clines.append(f": {state.input_string}")
    TerminalRunner().render_screen(
        TerminalRunner().highlight_line(state.list_index, clines, GREEN)
    )
    if key == "return":
        state.input_string = ""
    return state


def task_list_toggle_active(key: str, state: State) -> State:
    def index_to_id(idx: int) -> int:
        lines = TerminalRunner().get_colorless_lines(state.get_task_list_command())
        return int(lines[idx + 1].split()[0])

    cmd = ""
    cmd = TASK_INFO_COMMAND + [str(index_to_id(state.list_index))]
    status = TerminalRunner().run(cmd)

    cmd = ""
    for line in status.splitlines():
        if "Virtual tags" in line and "ACTIVE" in line:
            cmd = TASK_LIST_STOP_COMMAND + [str(index_to_id(state.list_index))]
            _ = TerminalRunner().run(cmd)
            return task_list_move_top(key, state)
    cmd = TASK_LIST_START_COMMAND + [str(index_to_id(state.list_index))]
    _ = TerminalRunner().run(cmd)
    return task_list_move_top(key, state)


def task_list_done(key: str, state: State) -> State:
    def index_to_id(idx: int) -> int:
        lines = TerminalRunner().get_colorless_lines(state.get_task_list_command())
        return int(lines[idx + 1].split()[0])

    cmd = TASK_LIST_DONE_COMMAND + [str(index_to_id(state.list_index))]
    # print(cmd)
    _ = TerminalRunner().run(cmd)
    return task_list_move_top(key, state)


def quit(key: str, state: State) -> State:
    print("\033[J", end="")  # clear to the end
    exit()
    return state


def default(key: str, state: State) -> State:
    return state


def handle_key(key: str, state: State) -> State:
    if state.window_state == "list":
        try:
            return state.keymaps[state.window_state][state.list_state][key](key, state)
        except Exception:
            try:
                return state.keymaps[state.window_state][state.list_state]["default"](
                    key, state
                )
            except Exception:
                return state.keymaps[state.window_state][state.list_state](key, state)

    else:
        try:
            return state.keymaps[state.window_state][key](key, state)
        except KeyError:
            if "default" in state.keymaps[state.window_state]:
                return state.keymaps[state.window_state]["default"]("default", state)
            exit()


if __name__ == "__main__":
    keymaps = {
        "list": {
            "normal": {
                "g": task_list_move_top,
                "G": task_list_move_end,
                "j": task_list_move_down,
                "k": task_list_move_up,
                "s": task_list_toggle_active,
                "d": task_list_done,
                "a": task_list_add,
                "h": task_list_to_summary,
                "q": quit,
                "default": default,
            },
            "insert": task_list_insert,
        },
        "summary": {
            "l": task_summary_to_list,
            "k": task_summary_move_up,
            "j": task_summary_move_down,
            "g": task_summary_move_top,
            "G": task_summary_move_end,
            "q": quit,
            "default": default,
        },
    }

    state = State(keymaps, "summary", "normal")
    while True:
        b, key = getkey()
        state_copy = copy.deepcopy(state)
        state = handle_key(key, state_copy)
