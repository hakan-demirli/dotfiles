#!/usr/bin/env python3
import fcntl
import hashlib
import ipaddress
import json
import os
import re
import select
import shutil
import subprocess
import sys
import termios
import tty
import unicodedata
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Window:
    id: int
    label: str


def ssh_host(command):
    if not command:
        return None

    name = os.path.basename(command[0])
    if name == "ssh":
        args = command[1:]
    elif len(command) > 2 and command[1:3] == ["+kitten", "ssh"]:
        args = command[3:]
    elif len(command) > 1 and command[1] == "ssh":
        args = command[2:]
    else:
        return None

    options_with_values = {
        "-b",
        "-c",
        "-D",
        "-E",
        "-e",
        "-F",
        "-I",
        "-i",
        "-J",
        "-L",
        "-l",
        "-m",
        "-O",
        "-o",
        "-p",
        "-Q",
        "-R",
        "-S",
        "-W",
        "-w",
    }
    skip_next = False
    for arg in args:
        if skip_next:
            skip_next = False
        elif arg in options_with_values:
            skip_next = True
        elif arg.startswith("-") or not re.fullmatch(r"(?:[\w.-]+@)?[\w.:-]+", arg):
            continue
        else:
            host = arg.rsplit("@", 1)[-1]
            try:
                ipaddress.ip_address(host)
            except ValueError:
                host = host.split(".", 1)[0]
            return host
    return None


def label_for(window):
    processes = window.get("foreground_processes") or []
    for process in processes:
        host = ssh_host(process.get("cmdline") or [])
        if host:
            return host

    shells = {"bash", "sh", "zsh", "fish", "ssh", "kitten"}
    for process in processes:
        command = process.get("cmdline") or []
        if command:
            name = os.path.basename(command[0])
            if name not in shells and name != "tmux":
                return name

    cwd = window.get("cwd") or ""
    return os.path.basename(cwd.rstrip("/")) or "/"


def state_path():
    instance = f"{os.environ.get('KITTY_LISTEN_ON', '')}:{os.environ.get('KITTY_PID') or os.getppid()}"
    directory = os.environ.get("XDG_RUNTIME_DIR") or os.environ.get("XDG_CACHE_HOME")
    if not directory:
        directory = Path.home() / ".cache"
    name = hashlib.sha256(instance.encode()).hexdigest() + ".csv"
    return Path(directory) / "kitty-window-selector" / name


def migrate_label(label, fallback):
    if label.startswith("󰍹 ") or (label.startswith("/") and "/.ssh/" in label):
        return fallback
    if "@" in label and "." in label.rsplit("@", 1)[-1]:
        return label.rsplit("@", 1)[-1].split(".", 1)[0]
    return label


def apply_state(windows, path):
    legacy = not path.is_file() and path.with_suffix(".tsv").is_file()
    source = path.with_suffix(".tsv") if legacy else path
    if not source.is_file():
        return windows

    by_id = {window.id: window for window in windows}
    ordered = []
    for line in source.read_text().splitlines():
        if legacy:
            label, separator, window_id = line.rpartition("\t")
        else:
            window_id, separator, label = line.partition(",")
        if not separator or not window_id.isdecimal():
            continue
        window = by_id.pop(int(window_id), None)
        if window is not None:
            if legacy:
                label = migrate_label(label, window.label)
            ordered.append(Window(window.id, label.strip() or window.label))
    ordered.extend(by_id.values())
    return ordered


def save_state(windows, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    with temporary.open("w") as file:
        for window in windows:
            label = window.label.replace("\t", " ").replace("\n", " ")
            file.write(f"{window.id},{label}\n")
    temporary.replace(path)


def list_windows(path):
    tree = json.loads(subprocess.check_output(["kitty", "@", "ls"], text=True))
    self_id = int(os.environ["KITTY_WINDOW_ID"])
    windows = []
    previous_id = None

    for os_window in tree:
        for tab in os_window["tabs"]:
            tab_windows = tab["windows"]
            if any(window["id"] == self_id for window in tab_windows):
                previous_id = next(
                    (
                        id
                        for id in tab.get("active_window_history", [])
                        if id != self_id
                    ),
                    None,
                )
                if previous_id is None:
                    previous_id = next(
                        (
                            window["id"]
                            for window in reversed(tab_windows)
                            if window["id"] != self_id
                        ),
                        None,
                    )

            for window in tab_windows:
                if window["id"] != self_id:
                    windows.append(Window(window["id"], label_for(window)))

    counts = {}
    for window in windows:
        counts[window.label] = counts.get(window.label, 0) + 1
    windows = [
        Window(
            window.id,
            f"{window.label} ({window.id})"
            if counts[window.label] > 1
            else window.label,
        )
        for window in windows
    ]
    windows = apply_state(windows, path)
    selected = next(
        (i for i, window in enumerate(windows) if window.id == previous_id), 0
    )
    return windows, selected


def preview_for(window):
    result = subprocess.run(
        ["kitty", "@", "get-text", "--ansi", "--match", f"id:{window.id}"],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout if result.returncode == 0 else result.stderr


ANSI_CONTROL = re.compile(
    r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)|.)", re.DOTALL
)
BAR_BACKGROUND = "\x1b[48;2;18;56;63m"
BAR_FOREGROUND = "\x1b[38;2;214;241;235m"
BAR_SELECTED = "\x1b[48;2;255;135;98m\x1b[38;2;18;46;51m\x1b[1m"
BAR_SEPARATOR = "\x1b[48;2;45;114;122m"


def cell_width(char):
    if unicodedata.combining(char) or unicodedata.category(char) == "Cf":
        return 0
    return 2 if unicodedata.east_asian_width(char) in "WF" else 1


def preview_lines(text, width, height):
    lines = []
    line = []
    column = 0
    cursor = 0

    for match in ANSI_CONTROL.finditer(text):
        for char in text[cursor : match.start()]:
            if char == "\n":
                lines.append("".join(line))
                line = []
                column = 0
                if len(lines) >= height:
                    return lines
            elif char == "\t":
                spaces = min(4 - column % 4, max(0, width - column))
                line.append(" " * spaces)
                column += spaces
            elif char.isprintable():
                cells = cell_width(char)
                if column + cells <= width:
                    line.append(char)
                    column += cells

        control = match.group()
        if (
            control.startswith("\x1b[")
            and control.endswith("m")
            and all(char in "0123456789;:" for char in control[2:-1])
        ):
            line.append(control)
        cursor = match.end()

    for char in text[cursor:]:
        if char == "\n":
            lines.append("".join(line))
            line = []
            column = 0
            if len(lines) >= height:
                return lines
        elif char == "\t":
            spaces = min(4 - column % 4, max(0, width - column))
            line.append(" " * spaces)
            column += spaces
        elif char.isprintable():
            cells = cell_width(char)
            if column + cells <= width:
                line.append(char)
                column += cells

    if len(lines) < height:
        lines.append("".join(line))
    return lines


def draw(windows, selected, preview):
    width, height = shutil.get_terminal_size((80, 24))
    if width < 2 or height < 2:
        return

    output = ["\x1b[0m\x1b[H\x1b[2J\x1b[?7l", BAR_BACKGROUND, " " * width, "\x1b[1;1H"]
    if not windows:
        output.extend((BAR_BACKGROUND, BAR_FOREGROUND, "No Kitty windows"))
    else:
        max_label = max(6, min(24, width // min(len(windows), 4) - 5))
        segments = []
        for index, window in enumerate(windows):
            label = "".join(char for char in window.label if char.isprintable())
            if len(label) > max_label:
                label = label[: max_label - 1] + "…"
            shortcut = "uiop"[index] if index < 4 else " "
            segments.append(f" {shortcut} {label} ")

        start = 0
        while (
            start < selected
            and sum(len(segment) for segment in segments[start : selected + 1]) > width
        ):
            start += 1

        column = 0
        for index in range(start, len(segments)):
            segment = segments[index]
            if column + len(segment) > width:
                break
            output.append(
                BAR_SELECTED if index == selected else BAR_BACKGROUND + BAR_FOREGROUND
            )
            output.extend((segment, "\x1b[0m"))
            column += len(segment)
        if column + len(" e edit ") <= width:
            output.extend((BAR_BACKGROUND, "\x1b[38;2;255;135;98m", " e edit "))

    output.extend(("\x1b[2;1H", BAR_SEPARATOR, " " * width, "\x1b[0m"))
    if height > 2:
        for row, line in enumerate(preview_lines(preview, width, height - 2), start=3):
            output.extend((f"\x1b[{row};1H", line))
    output.append("\x1b[0m")
    sys.stdout.write("".join(output))
    sys.stdout.flush()


def read_key(fd):
    first = os.read(fd, 1)
    if first != b"\x1b":
        return first
    if not select.select([fd], [], [], 0.07)[0]:
        return b"escape"

    second = os.read(fd, 1)
    if second in (b"[", b"O"):
        if select.select([fd], [], [], 0.07)[0]:
            direction = os.read(fd, 1)
            if direction == b"D":
                return b"left"
            if direction == b"C":
                return b"right"
        return b"other"
    return b"alt-" + second


def edit_windows(fd, original, windows, path):
    save_state(windows, path)
    termios.tcsetattr(fd, termios.TCSADRAIN, original)
    sys.stdout.write("\x1b[0m\x1b[?7h\x1b[?25h\x1b[?1049l")
    sys.stdout.flush()
    try:
        subprocess.run(["hx", str(path)], check=False)
    finally:
        sys.stdout.write("\x1b[?1049h\x1b[?25l")
        sys.stdout.flush()
        tty.setcbreak(fd)


def choose(windows, selected, path):
    fd = sys.stdin.fileno()
    original = termios.tcgetattr(fd)
    sys.stdout.write("\x1b[?1049h\x1b[?25l")
    sys.stdout.flush()
    try:
        tty.setcbreak(fd)
        preview = preview_for(windows[selected]) if windows else ""
        while True:
            draw(windows, selected, preview)
            key = read_key(fd)
            if key in (b"\r", b"\n"):
                return windows[selected].id if windows else None
            if key in (b"escape", b"q", b""):
                return None
            if key == b"e" and windows:
                current_id = windows[selected].id
                edit_windows(fd, original, windows, path)
                windows, _ = list_windows(path)
                selected = next(
                    (i for i, window in enumerate(windows) if window.id == current_id),
                    0,
                )
                preview = preview_for(windows[selected]) if windows else ""
                continue
            if key in (b"left", b"h") and windows:
                selected = (selected - 1) % len(windows)
            elif key in (b"right", b"l") and windows:
                selected = (selected + 1) % len(windows)
            elif key.startswith(b"alt-"):
                shortcut = key[4:]
                if shortcut in (b"u", b"i", b"o", b"p"):
                    index = b"uiop".index(shortcut)
                    if index < len(windows):
                        selected = index
                elif shortcut == b"b" and len(windows) > 1:
                    selected = 1
            if windows:
                preview = preview_for(windows[selected])
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, original)
        sys.stdout.write("\x1b[0m\x1b[?7h\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()


def main():
    path = state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.with_suffix(".lock").open("a+") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return

        windows, selected = list_windows(path)
        target = choose(windows, selected, path)
        if target is not None:
            subprocess.run(
                ["kitty", "@", "focus-window", "--match", f"id:{target}"], check=True
            )


if __name__ == "__main__":
    main()
