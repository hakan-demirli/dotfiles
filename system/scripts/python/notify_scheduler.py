#!/usr/bin/env python3
import json
import os
import signal
import time
from datetime import date, datetime

# Define XDG directories
XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
XDG_DATA_HOME = os.getenv("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))

# Define paths
CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "notify-scheduler")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")
STATE_DIR = os.path.join(XDG_DATA_HOME, "notify-scheduler")
STATE_FILE = os.path.join(STATE_DIR, "state.json")

# Ensure directories exist
os.makedirs(CONFIG_DIR, exist_ok=True)
os.makedirs(STATE_DIR, exist_ok=True)

# Load configuration
if not os.path.exists(CONFIG_FILE):
    print(
        f"Config file not found at {CONFIG_FILE}. Please create one with the appropriate schedule."
    )
    exit(1)

with open(CONFIG_FILE, "r") as f:
    config = json.load(f)

# Load or initialize state
if os.path.exists(STATE_FILE):
    with open(STATE_FILE, "r") as f:
        state = json.load(f)
else:
    state = {}


def save_state():
    """Save the current state to a file."""
    with open(STATE_FILE, "w") as f:
        json.dump(state, f)


def should_notify(task_name, task_time):
    """Determine if a notification should be sent."""
    today = str(date.today())
    task_key = f"{task_name}:{today}:{task_time}"
    if state.get(task_key):
        return False
    state[task_key] = True
    save_state()
    return True


def send_notification(title, message):
    """Send a notification using notify-send."""
    os.system(f'notify-send "{title}" "{message}" -t 0 -u critical')


def shutdown_handler(signum, frame):
    """Handle shutdown signals."""
    print("Shutting down...")
    exit(0)


# Register shutdown handlers for various signals
for sig in [
    signal.SIGINT,
    signal.SIGTERM,
    signal.SIGHUP,
    signal.SIGQUIT,
    signal.SIGABRT,
    signal.SIGUSR1,
    signal.SIGUSR2,
]:
    signal.signal(sig, shutdown_handler)

if __name__ == "__main__":
    now = datetime.now().strftime("%H:%M")
    for task_name, task_details in config.items():
        times = task_details.get("time", [])
        content = task_details.get("content", "")
        for task_time in times:
            if should_notify(task_name, task_time):
                send_notification("Reminder", content)

    while True:
        now = datetime.now().strftime("%H:%M")
        for task_name, task_details in config.items():
            times = task_details.get("time", [])
            content = task_details.get("content", "")
            for task_time in times:
                if now == task_time and should_notify(task_name, task_time):
                    send_notification("Reminder", content)
        time.sleep(60)
