#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
from datetime import datetime, timedelta
from enum import Enum

TIMER_FILE = "/tmp/waybar_timer.json"
DEFAULT_MINUTE = 40
FONT_SIZE = 14
ZENITY = "zenity"


class TimerState(Enum):
    READY = "ready"
    COUNTING = "counting"
    STOPPED = "stopped"
    TIMEOUT = "timeout"


class Timer:
    def __init__(self, state_file: str) -> None:
        self.state_file: str = state_file
        self.state: TimerState = TimerState.READY
        self.end_time: datetime = datetime.min
        self.stopped_time: datetime = datetime.min
        if not os.path.exists(state_file):
            self.clear()
        self.load_state()

    def load_state(self) -> None:
        try:
            with open(self.state_file, "r") as f:
                state = json.load(f)
                self.state = TimerState(state["state"])
                self.end_time = datetime.fromisoformat(state["end_time"])
                self.stopped_time = datetime.fromisoformat(state["stopped_time"])
        except (FileNotFoundError, json.JSONDecodeError):
            self.state = TimerState.READY
            self.end_time = datetime.min
            self.stopped_time = datetime.min

    def save_state(self) -> None:
        state = {
            "state": self.state.value,
            "end_time": self.end_time.isoformat(),
            "stopped_time": self.stopped_time.isoformat(),
        }
        with open(self.state_file, "w") as f:
            json.dump(state, f)

    def set(self, minutes: int) -> None:
        self.state = TimerState.COUNTING
        self.end_time = datetime.now() + timedelta(minutes=minutes)
        self.stopped_time = datetime.min
        self.save_state()

    def read(self) -> timedelta:
        if self.state == TimerState.COUNTING:
            remaining = self.end_time - datetime.now()
            if remaining.total_seconds() <= 0:
                self.state = TimerState.TIMEOUT
                self.save_state()
                return timedelta(0)
            return remaining
        elif self.state == TimerState.STOPPED:
            return self.end_time - self.stopped_time
        return timedelta(0)

    def print_time(self) -> dict:
        if self.state == TimerState.READY:
            return {
                "text": f"<span font='{FONT_SIZE}' rise='-2000'>󰔛</span>",
                "tooltip": "Timer is not active",
            }
        elif self.state == TimerState.TIMEOUT:
            return {"text": f"<span font='{FONT_SIZE}' rise='-2000'>󰔛</span>"}
        elif self.state == TimerState.COUNTING or self.state == TimerState.STOPPED:
            remaining_time = self.read()
            minutes, seconds = divmod(int(remaining_time.total_seconds()), 60)
            return {
                "text": f"<span font='{FONT_SIZE}' rise='-2000'>󰔟</span> {minutes}:{str(seconds).zfill(2)} ",
                "class": "active",
            }
        else:
            return {
                "text": f"<span font='{FONT_SIZE}' rise='-2000'>󰔛</span>",
                "tooltip": "Timer is not active",
            }

    def toggle(self) -> None:
        if self.state == TimerState.COUNTING:
            self.state = TimerState.STOPPED
            self.stopped_time = datetime.now()
        elif self.state == TimerState.STOPPED:
            self.state = TimerState.COUNTING
            self.end_time = datetime.now() + (self.end_time - self.stopped_time)
        else:
            return
        self.save_state()

    def clear(self) -> None:
        self.state = TimerState.READY
        self.end_time = datetime.min
        self.stopped_time = datetime.min
        self.save_state()


def run_cmd(cmd: str) -> str:
    return subprocess.check_output(cmd, shell=True).decode().strip()


def main():
    parser = argparse.ArgumentParser(description="CLI Timer")
    parser.add_argument("-r", "--read", action="store_true", help="Read remaining time")
    parser.add_argument("-s", "--set", type=int, help="Set the timer")
    parser.add_argument(
        "-m",
        "--minute",
        nargs="?",
        const=None,
        default=False,
        help="Set the timer using a popup or provided value",
    )
    parser.add_argument(
        "-t", "--toggle", action="store_true", help="Start/Stop the timer"
    )
    parser.add_argument("-c", "--clear", action="store_true", help="Reset the timer")
    args = parser.parse_args()

    timer = Timer(TIMER_FILE)

    if args.read:
        print(json.dumps(timer.print_time()))
    elif args.set is not None:
        timer.set(args.set)
    elif args.minute is not False:
        # minute is not set via cli. Ask the user via gui
        if args.minute is None:
            try:
                timer_target = run_cmd(
                    f'{ZENITY} --scale --title "Set timer" --text "In x minutes:" --min-value=0 --max-value=600 --step=1 --value={DEFAULT_MINUTE}'
                )
            except Exception:
                # print("{}")
                return 0
            if timer_target:
                timer.set(int(timer_target))
        else:
            if isinstance(args.minute, int):
                timer.set(int(args.minute))
    elif args.toggle:
        timer.toggle()
    elif args.clear:
        timer.clear()


if __name__ == "__main__":
    main()
