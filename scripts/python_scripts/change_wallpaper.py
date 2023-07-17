#!/usr/bin/env python3
from pathlib import Path
from datetime import datetime
from subprocess import run, check_output
from os import getenv

"""
Change wallpaper every day on Gnome.

How to get a different wallpaper each day?
    Days since epoch always increase by one each day.
    Get total number of files and divide days since epoch by it.
    We got the index of the todays wallpaper.

"""

# Run the command and capture the output
IMAGES_PATH = getenv("MY_IMAGE_DIR")
WALLPAPER_PATH = Path(f"{IMAGES_PATH}/art/wallpapers_pc")
COMMAND = "echo $XDG_CURRENT_DESKTOP"


def chooseWallpaper():
    days_since_epoch = int(int(datetime.now().strftime("%s")) / 86400)
    paths = []

    for index, path in enumerate(WALLPAPER_PATH.glob("*")):
        paths.append(path)

    idx = days_since_epoch % len(paths)
    return paths[idx]


if __name__ == "__main__":
    output = check_output(COMMAND, shell=True).decode("utf-8")
    wp = chooseWallpaper()

    if "gnome" in output.lower():
        # picture-uri-dark -> picture-uri for light theme
        info = run(
            [
                "gsettings",
                "set",
                "org.gnome.desktop.background",
                "picture-uri-dark",
                str("file://" + str(wp)),
            ]
        )

    if ("sway" in output.lower()) or ("hyprland" in output.lower()):
        info = run(
            [
                "swww",
                "img",
                f"{wp}",
                "-t",
                "any",
                "--transition-fps",
                "144",
                "--transition-step",
                "90",
            ]
        )
