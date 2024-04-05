#!/usr/bin/env python3

import logging
import os
import subprocess
import time

import gi

gi.require_version("GUdev", "1.0")

from gi.repository import GLib, GUdev  # noqa: E402

LOG_FILE_PATH = os.path.expanduser("~/.cache/auto_refresh/log.txt")  # ABS_PATH: fix pls
CONFIG_FILE_PATH = os.path.expanduser("~/.config/hypr/monitors.conf")
AC_STATUS_FILE_PATH = os.path.expanduser("/sys/class/power_supply/ACAD/online")
MAX_REFRESH_RATE = 144
MIN_REFRESH_RATE = 60
TO_MAX_REGEX = f"/eDP-1/s/@{MIN_REFRESH_RATE}/@{MAX_REFRESH_RATE}/g"
TO_MIN_REGEX = f"/eDP-1/s/@{MAX_REFRESH_RATE}/@{MIN_REFRESH_RATE}/g"

os.makedirs(os.path.dirname(LOG_FILE_PATH), exist_ok=True)
logging.basicConfig(filename=(LOG_FILE_PATH), level=logging.INFO)


# Replace all print statements with logging.info
def sed(regex: str, path: str):
    command = ["sed", "-i", regex, path]
    try:
        subprocess.run(command)
    except Exception as e:
        print(f"[sed] command {command} failed: {e}")


def set_min_refresh_rate():
    file_contents = ""
    with open(CONFIG_FILE_PATH, "r") as file:
        file_contents = file.read()
    if f"@{MAX_REFRESH_RATE}" in file_contents:
        sed(TO_MIN_REGEX, CONFIG_FILE_PATH)
    else:
        logging.info("Refresh rate is not max or already at min.")


def set_max_refresh_rate():
    file_contents = ""
    with open(CONFIG_FILE_PATH, "r") as file:
        file_contents = file.read()
    if f"@{MIN_REFRESH_RATE}" in file_contents:
        sed(TO_MAX_REGEX, CONFIG_FILE_PATH)
    else:
        logging.info("Refresh rate is not min or already at max.")


def check_initial_power_status():
    """
    Initially, AC status is None for a couple of seconds.
    Retry until it is valid.
    """
    while True:
        with open(AC_STATUS_FILE_PATH, "r") as file:
            online = file.read()
            logging.info(f"[Initial check] power status is {online}")
            if 0 == int(online):
                set_min_refresh_rate()
                break
            elif 1 == int(online):
                set_max_refresh_rate()
                break
            else:
                logging.error(f"[Initial check] online status status is: {online}")
        time.sleep(1)


def ac_event_handler(client, action, device, user_data):
    if action == "change":
        if device.get_property("SUBSYSTEM") == "power_supply":
            online = device.get_property("POWER_SUPPLY_ONLINE")
            logging.info(f"[AC event] online status is: {online}")

            if online == "1":
                set_max_refresh_rate()
            elif online == "0":
                set_min_refresh_rate()
            else:
                logging.error(f"[AC event] {online} is not valid.")

        if device.get_property("POWER_SUPPLY_CAPACITY_LEVEL") == "critical":
            subprocess.run(
                [
                    "notify-send",
                    "--urgency=critical",
                    "Battery critical!",
                ]
            )


def main():
    # Create a GUdev client to monitor power supply events
    client = GUdev.Client(subsystems=["power_supply"])

    check_initial_power_status()

    # Create a GLib MainLoop to listen for events
    client.connect("uevent", ac_event_handler, None)
    loop = GLib.MainLoop()
    loop.run()


if __name__ == "__main__":
    """
    Monitors power supply events and automatically changes monitor refresh rate.
    Only Hyprland Window Manager is supported.
    """
    main()
