#!/usr/bin/env python3

import gi

import os
import subprocess

gi.require_version("GUdev", "1.0")

from gi.repository import GLib, GUdev


def ac_event_handler(client, action, device, user_data):
    property_keys = device.get_property_keys()

    # Print all properties and their values
    for key in property_keys:
        value = device.get_property(key)
        print(f"{key}: {value}")
    if action == "change":
        if device.get_property("SUBSYSTEM") == "power_supply":
            online = device.get_property("POWER_SUPPLY_ONLINE")
            file_path = "~/.config/hypr/monitors.conf"
            file_path = os.path.expanduser(file_path)
            if online == "1":
                print("AC Adapter Plugged In")
                with open(file_path, "r") as file:
                    file_contents = file.read()
                if "@144" not in file_contents:
                    subprocess.run(["sed", "-i", "/eDP-1/s/@60/@144/g", file_path])
            elif online == "0":
                print("AC Adapter Unplugged")
                subprocess.run(["sed", "-i", "/eDP-1/s/@144/@60/g", file_path])
        if device.get_property("POWER_SUPPLY_CAPACITY_LEVEL") == "critical":
            subprocess.run(
                [
                    "notify-send",
                    "--urgency=critical",
                    "Battery critical!",
                ]
            )


# Create a GUdev client to monitor power supply events
client = GUdev.Client(subsystems=["power_supply"])
client.connect("uevent", ac_event_handler, None)

# Create a GLib MainLoop to listen for events
loop = GLib.MainLoop()
loop.run()
