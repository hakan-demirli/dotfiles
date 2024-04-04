#!/usr/bin/env python3

import os
import subprocess

import gi

gi.require_version("GUdev", "1.0")

from gi.repository import GLib, GUdev  # noqa: E402

CONFIG_FILE_PATH = "~/.config/hypr/monitors.conf"  # ABS_PATH: fix pls
CONFIG_FILE_PATH = os.path.expanduser(CONFIG_FILE_PATH)
MAX_REFRESH_RATE = 144
MIN_REFRESH_RATE = 60
TO_MAX_REGEX = f"/eDP-1/s/@{MIN_REFRESH_RATE}/@{MAX_REFRESH_RATE}/g"
TO_MIN_REGEX = f"/eDP-1/s/@{MAX_REFRESH_RATE}/@{MIN_REFRESH_RATE}/g"
AC_STATUS_FILE = "/sys/class/power_supply/ACAD/online"


def sed(regex: str, path: str):
    subprocess.run(["sed", "-i", regex, path])


def set_min_refresh_rate():
    file_contents = ""
    with open(CONFIG_FILE_PATH, "r") as file:
        file_contents = file.read()
    if f"@{MIN_REFRESH_RATE}" in file_contents:
        sed(TO_MIN_REGEX, CONFIG_FILE_PATH)
    else:
        print("Refresh rate is alread at min.")


def set_max_refresh_rate():
    file_contents = ""
    with open(CONFIG_FILE_PATH, "r") as file:
        file_contents = file.read()
    if f"@{MAX_REFRESH_RATE}" in file_contents:
        sed(TO_MAX_REGEX, CONFIG_FILE_PATH)
    else:
        print("Refresh rate is alread at max.")


def check_initial_power_status():
    with open(AC_STATUS_FILE, "r") as file:
        online = file.read()
        print(f"Initial power status is {online}")
        try:
            if 0 == int(online):
                set_min_refresh_rate()
            else:
                set_max_refresh_rate()
        except Exception:
            print("Which is not an integer.")


def ac_event_handler(client, action, device, user_data):
    if action == "change":
        if device.get_property("SUBSYSTEM") == "power_supply":
            online = device.get_property("POWER_SUPPLY_ONLINE")
            print(f"Power supply status changed. online: {online}")

            if online == "1":
                set_min_refresh_rate()
            else:
                set_max_refresh_rate()

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

    # Check the initial power status
    try:
        check_initial_power_status()
    except Exception:
        print("initial check failed")

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
