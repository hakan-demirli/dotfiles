#!/usr/bin/env python3
import re
import subprocess


def get_active_source_status():
    # Get active source status using pactl
    pactl_output = subprocess.check_output(["pactl", "list", "sources"]).decode("utf-8")
    active_port = re.search(r"Active Port: (\S+)", pactl_output).group(1)

    if "headset-mic" in active_port:
        return "headset-mic"
    elif "hands-free-mic" in active_port:
        return "hands-free-mic"
    elif "phone-mic" in active_port or "portable-mic" in active_port:
        return "phone-mic"
    elif "car-mic" in active_port:
        return "car-mic"
    elif "internal-mic" in active_port:
        return "internal-mic"
    else:
        return "default"


def get_volume_progress():
    # Get volume progress using pactl
    pactl_output = subprocess.check_output(
        ["pactl", "get-source-volume", "@DEFAULT_SOURCE@"]
    ).decode("utf-8")
    volume_str = pactl_output.split("front-left: ")[1].split(" ")[0]
    volume = int(volume_str) / 65536  # Convert volume to a float between 0 and 1
    return volume


def get_mute_status():
    pactl_output = subprocess.check_output(
        ["pactl", "get-source-mute", "@DEFAULT_SOURCE@"]
    ).decode("utf-8")
    if "yes" in pactl_output:
        return "muted"
    else:
        return None


def main():
    status = get_mute_status()
    if not status:
        status = get_active_source_status()
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
            "mic",
            "--progress",
            str(progress),
        ]
    )


if __name__ == "__main__":
    main()
