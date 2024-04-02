#!/usr/bin/env python3

import os
import subprocess

import gi

gi.require_version("GUdev", "1.0")

from gi.repository import GLib, GUdev  # noqa: E402


def sed(regex: str, path: str):
    subprocess.run(["sed", "-i", regex, path])


def check_initial_power_status(client):
    devices = client.query_by_subsystem("power_supply")
    for device in devices:
        if device.get_property("POWER_SUPPLY_ONLINE") == "1":
            ac_event_handler(client, "change", device, None)


def ac_event_handler(client, action, device, user_data):
    CONFIG_FILE_PATH = "~/.config/hypr/monitors.conf"  # ABS_PATH: fix pls
    CONFIG_FILE_PATH = os.path.expanduser(CONFIG_FILE_PATH)
    MAX_REFRESH_RATE = 144
    MIN_REFRESH_RATE = 60
    TO_MAX_REGEX = f"/eDP-1/s/@{MIN_REFRESH_RATE}/@{MAX_REFRESH_RATE}/g"
    TO_MIN_REGEX = f"/eDP-1/s/@{MAX_REFRESH_RATE}/@{MIN_REFRESH_RATE}/g"

    if action == "change":
        if device.get_property("SUBSYSTEM") == "power_supply":
            online = device.get_property("POWER_SUPPLY_ONLINE")
            if online == "1":
                with open(CONFIG_FILE_PATH, "r") as file:
                    file_contents = file.read()
                if f"@{MAX_REFRESH_RATE}" not in file_contents:
                    sed(TO_MAX_REGEX, CONFIG_FILE_PATH)
            elif online == "0":
                sed(TO_MIN_REGEX, CONFIG_FILE_PATH)
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
    client.connect("uevent", ac_event_handler, None)

    # Check the initial power status
    check_initial_power_status(client)

    # Create a GLib MainLoop to listen for events
    loop = GLib.MainLoop()
    loop.run()


if __name__ == "__main__":
    """
    Monitors power supply events and automatically changes monitor refresh rate.
    Only Hyprland Window Manager is supported.
    """
    main()
