#!/usr/bin/env python3
import subprocess
import re


def get_active_sink_status():
    # Get active sink status using pactl
    pactl_output = subprocess.check_output(["pactl", "list", "sinks"]).decode("utf-8")
    active_port = re.search(r"Active Port: (\S+)", pactl_output).group(1)

    if "headphones" in active_port:
        return "headphone"
    elif "hands-free" in active_port:
        return "hands-free"
    elif "phone" in active_port or "portable" in active_port:
        return "phone"
    elif "car" in active_port:
        return "car"
    else:
        return "default"


def get_volume_progress():
    # Get volume progress using pactl
    pactl_output = subprocess.check_output(
        ["pactl", "get-sink-volume", "@DEFAULT_SINK@"]
    ).decode("utf-8")
    volume_str = pactl_output.split("front-left: ")[1].split(" ")[0]
    volume = int(volume_str) / 65536  # Convert volume to a float between 0 and 1
    return volume


def get_mute_status():
    pactl_output = subprocess.check_output(
        ["pactl", "get-sink-mute", "@DEFAULT_SINK@"]
    ).decode("utf-8")
    if "yes" in pactl_output:
        return "muted"
    else:
        return None


def main():
    status = get_mute_status()
    if not status:
        status = get_active_sink_status()
        progress = get_volume_progress()
    else:
        progress = 0.0

    # Call gtk_indicator_client with status and progress
    subprocess.run(
        [
            "gtk_indicator_client",
            "--status",
            status,
            "--name",
            "volume",
            "--progress",
            str(progress),
        ]
    )


if __name__ == "__main__":
    main()
