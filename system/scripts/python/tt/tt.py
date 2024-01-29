#!/usr/bin/env python3
import argparse
import copy
import os
import sys
import termios
import tty
from typing import Final, Tuple

from terminal_runner import TerminalRunner

TASK_LIST_COMMAND: Final = ["task", "list"]
TASK_SUMMARY_COMMAND: Final = ["task", "summary"]
TASK_INFO_COMMAND: Final = ["task", "info"]
TASK_LIST_DONE_COMMAND: Final = ["task", "done"]
TASK_LIST_MODIFY_COMMAND: Final = ["task", "modify"]
TASK_LIST_START_COMMAND: Final = ["task", "start"]
TASK_LIST_STOP_COMMAND: Final = ["task", "stop"]
TASK_LIST_ADD_COMMAND: Final = ["task", "add"]
GREEN: Final = "42;30"


class State:
    def __init__(
        self,
        keymap,
        window_state="summary",
        list_state="normal",
        summary_state="normal",
    ):
        self.keymap = keymap
        self.window_state = window_state
        self.list_state = list_state
        self.summary_state = summary_state
        self.current_list = ""
        self.list_index = 1
        self.summary_index = 1
        self.list_insert_state = ""
        self.input_string = ""

    def get_task_list_command(self):
        if self.current_list == "(none)":
            return TASK_LIST_COMMAND + ["-PROJECT"]
        elif self.current_list == "":
            return TASK_LIST_COMMAND
        else:
            return TASK_LIST_COMMAND + [f"project:{self.current_list}"]

    def get_task_add_command(self):
        if self.current_list == "(none)":
            return TASK_LIST_ADD_COMMAND
        elif self.current_list == "":
            return TASK_LIST_ADD_COMMAND
        else:
            return TASK_LIST_ADD_COMMAND + [f"project:{self.current_list}"]


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
    def get_up(lines, idx) -> int:
        return len(lines) - 1 if idx == 1 else idx - 1

    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    idx = get_up(clines, state.summary_index)
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


def task_summary_find(key: str, state: State) -> State:
    state.summary_state = "find"
    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    TerminalRunner().render_screen(
        TerminalRunner().highlight_line(state.summary_index, clines, GREEN)
    )
    return state


def task_summary_rename(key: str, state: State) -> State:
    state.summary_state = "rename"
    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    clines.append(f": {state.input_string}")
    TerminalRunner().render_screen(
        TerminalRunner().highlight_line(state.summary_index, clines, GREEN)
    )

    return state


def task_summary_to_list(key: str, state: State) -> State:
    def index_to_list(idx):
        lines = TerminalRunner().get_colorless_lines(TASK_SUMMARY_COMMAND)
        if lines[idx + 1][0] == " ":
            saved_word = lines[idx + 1].split()[0]
            while lines[idx][0] == " ":
                idx -= 1
            parent = lines[idx].split()[0]
            return parent + "." + saved_word
        else:
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
    state.list_insert_state = "add"
    clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
    clines.append(f": {state.input_string}")
    TerminalRunner().render_screen(
        TerminalRunner().highlight_line(state.list_index, clines, GREEN)
    )

    return state


def task_list_modify(key: str, state: State) -> State:
    state.list_state = "insert"
    state.list_insert_state = "modify"
    clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
    clines.append(f": {state.input_string}")
    TerminalRunner().render_screen(
        TerminalRunner().highlight_line(state.list_index, clines, GREEN)
    )

    return state


def task_list_to_summary(key: str, state: State) -> State:
    state.window_state = "summary"
    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    TerminalRunner().render_screen(
        TerminalRunner().highlight_line(state.summary_index, clines, GREEN)
    )
    return state


def task_summary_find_key(key: str, state: State) -> State:
    def get_below(lines, idx) -> int:
        return 1 if idx == len(lines) - 1 else idx + 1

    def index_to_list(idx):
        lines = TerminalRunner().get_colorless_lines(TASK_SUMMARY_COMMAND)
        if lines[idx + 1][0] == " ":
            saved_word = lines[idx + 1].split()[0]
            while lines[idx][0] == " ":
                idx -= 1
            parent = lines[idx].split()[0]
            return parent + "." + saved_word
        else:
            return lines[idx + 1].split()[0]

    lines = TerminalRunner().get_colorless_lines(TASK_SUMMARY_COMMAND)

    for idx, line in enumerate(lines):
        if not idx:
            continue
        saved_word = lines[idx].split()[0]
        if saved_word[0] == key:
            state.summary_index = idx - 1
            break
    clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
    TerminalRunner().render_screen(
        TerminalRunner().highlight_line(state.summary_index, clines, GREEN)
    )
    state.summary_state = "normal"
    return state


def task_summary_input(key: str, state: State) -> State:
    def index_to_list(idx):
        lines = TerminalRunner().get_colorless_lines(TASK_SUMMARY_COMMAND)
        if lines[idx + 1][0] == " ":
            saved_word = lines[idx + 1].split()[0]
            while lines[idx][0] == " ":
                idx -= 1
            parent = lines[idx].split()[0]
            return parent + "." + saved_word
        else:
            return lines[idx + 1].split()[0]

    if key == "esc":
        state.summary_state = "normal"
        state.input_string = ""
        clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
        TerminalRunner().render_screen(
            TerminalRunner().highlight_line(state.summary_index, clines, GREEN)
        )
        return state
    else:
        if key == "space":
            state.input_string += " "
        elif key == "backspace":
            state.input_string = state.input_string[:-1]
        elif key == "return":
            state.summary_state = "normal"
            # Create a copy of the original list
            modify_cmd = TASK_LIST_MODIFY_COMMAND[:]
            project = index_to_list(state.summary_index)
            parent_project = (
                project.rpartition(".")[0] + "." if project.rpartition(".")[0] else ""
            )
            modify_cmd.insert(1, f"project:{project}")
            modify_cmd.append(f"project:{parent_project}{state.input_string}")
            _ = TerminalRunner().run(modify_cmd)
        else:
            state.input_string += key

        clines = TerminalRunner().get_colored_lines(TASK_SUMMARY_COMMAND)
        clines.append(f": {state.input_string}")
        TerminalRunner().render_screen(
            TerminalRunner().highlight_line(state.summary_index, clines, GREEN)
        )
        if key == "return":
            state.input_string = ""
        return state


def task_list_insert(key: str, state: State) -> State:
    def index_to_id(idx: int) -> int:
        lines = TerminalRunner().get_colorless_lines(state.get_task_list_command())
        return int(lines[idx + 1].split()[0])

    if key == "esc":
        state.list_state = "normal"
        state.input_string = ""
        clines = TerminalRunner().get_colored_lines(state.get_task_list_command())
        TerminalRunner().render_screen(
            TerminalRunner().highlight_line(state.list_index, clines, GREEN)
        )
        return state
    else:
        if key == "space":
            state.input_string += " "
        elif key == "backspace":
            state.input_string = state.input_string[:-1]
        elif key == "return":
            state.list_state = "normal"
            if state.list_insert_state == "add":
                _ = TerminalRunner().run(
                    state.get_task_add_command() + [state.input_string]
                )
            elif state.list_insert_state == "modify":
                _ = TerminalRunner().run(
                    TASK_LIST_MODIFY_COMMAND
                    + [str(index_to_id(state.list_index))]
                    + [state.input_string]
                )
            else:
                raise ValueError
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
    _ = TerminalRunner().run(cmd)
    return task_list_move_top(key, state)


def quit(key: str, state: State) -> State:
    print("\033[J", end="")  # clear to the end
    print("\033[?25h", end="")  # Show the cursor
    exit()
    return state


def default(key: str, state: State) -> State:
    return state


def handle_key(key: str, state: State) -> State:
    if state.window_state == "list":
        try:
            return state.keymap[state.window_state][state.list_state][key](key, state)
        except Exception:
            try:
                return state.keymap[state.window_state][state.list_state]["default"](
                    key, state
                )
            except Exception:
                return state.keymap[state.window_state][state.list_state](key, state)
    elif state.window_state == "summary":
        try:
            return state.keymap[state.window_state][state.summary_state][key](
                key, state
            )
        except Exception:
            try:
                return state.keymap[state.window_state][state.summary_state]["default"](
                    "default", state
                )
            except Exception:
                return state.keymap[state.window_state][state.summary_state](key, state)
    else:
        raise ValueError


if __name__ == "__main__":
    keymap = {
        "list": {
            "normal": {
                "g": task_list_move_top,
                "G": task_list_move_end,
                "j": task_list_move_down,
                "k": task_list_move_up,
                "s": task_list_toggle_active,
                "d": task_list_done,
                "m": task_list_modify,
                "a": task_list_add,
                "h": task_list_to_summary,
                "q": quit,
                "default": default,
            },
            "insert": task_list_insert,
        },
        "summary": {
            "normal": {
                "l": task_summary_to_list,
                "k": task_summary_move_up,
                "j": task_summary_move_down,
                "r": task_summary_rename,
                "g": task_summary_move_top,
                "G": task_summary_move_end,
                "f": task_summary_find,
                "q": quit,
                "default": default,
            },
            "rename": task_summary_input,
            "find": task_summary_find_key,
        },
    }

    # Create the parser
    parser = argparse.ArgumentParser(description="Taskwarrior default TUI.")

    parser.add_argument(
        "--window_state", default="summary", help="Specify window state."
    )
    parser.add_argument("--list_state", default="normal", help="Specify list state.")
    parser.add_argument(
        "--summary_state", default="normal", help="Specify summary state."
    )

    args = parser.parse_args()

    state = State(
        keymap=keymap,
        window_state=args.window_state,
        list_state=args.list_state,
        summary_state=args.summary_state,
    )

    if args.window_state == "list":  # render first screen
        task_list_move_top("g", state)
    else:
        task_summary_move_top("g", state)

    while True:
        b, key = getkey()
        state_copy = copy.deepcopy(state)
        state = handle_key(key, state_copy)
