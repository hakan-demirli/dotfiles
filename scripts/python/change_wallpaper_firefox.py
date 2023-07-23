#!/usr/bin/env python3
from hashlib import new
from pathlib import Path
from datetime import datetime
from shutil import copy2, move

"""
Change wallpaper every day on Firefox.

How to get a different wallpaper each day?
    Days since epoch always increase by one each day.
    Get total number of files and divide days since epoch by it.
    We got the index of the todays wallpaper.

How to change firefox wallpaper?
    Copy wallpaper to the chrome directory
    Change the name of the file to match userChrome.css
    Change the extension inside the userChrome.css to match the file
"""

import os


def findFirefoxProfileFolder():
    # Search for profiles.ini in both locations
    locations = []
    locations.append(os.path.expanduser("~/.mozilla/firefox/profiles.ini"))
    locations.append(
        os.path.expanduser("~/snap/firefox/common/.mozilla/firefox/profiles.ini")
    )
    locations.append(
        os.path.expanduser("~/AppData/Roaming/Mozilla/Firefox/profiles.ini")
    )

    for location in locations:
        if os.path.exists(location):
            with open(location, "r") as file:
                for line in file:
                    key = "Default="
                    if line.startswith(key):
                        folder_name = line.strip().replace(key, "").strip()
                        return os.path.join(os.path.dirname(location), folder_name)

    return None


def wallpaperPath():
    if os.name == "nt":
        return Path("D:/images/art/wallpapers_pc")
    else:
        return Path("/mnt/second/images/art/wallpapers_pc")


def chromeFolderPath():
    return Path(f"{findFirefoxProfileFolder()}/chrome")


def daysSinceEpoch():
    return (datetime.now() - datetime(1970, 1, 1)).days


def wallpaperPaths():
    paths = []
    for index, path in enumerate(wallpaperPath().glob("*")):
        paths.append(path)
    return paths


def inplaceStringChange(old_string, new_string):
    with open((chromeFolderPath() / "userContent.css")) as f:
        s = f.read()
        if old_string not in s:
            print(f'"{old_string}" not found')
            return

    with open((chromeFolderPath() / "userContent.css"), "w") as f:
        s = s.replace(old_string, new_string)
        f.write(s)


if __name__ == "__main__":
    paths = wallpaperPaths()
    idx = daysSinceEpoch() % len(paths)

    for ext in ["*.jpg", "*.png", "*.jpeg"]:
        for index, path in enumerate(chromeFolderPath().glob(ext)):
            os.remove(path)

    copy2(str(paths[idx]), chromeFolderPath())

    new_name = chromeFolderPath() / ("my_wallpaper" + str(paths[idx].suffix))
    move(chromeFolderPath() / str(paths[idx].stem + paths[idx].suffix), new_name)

    inplaceStringChange(".jpg", str(paths[idx].suffix))
    inplaceStringChange(".jpeg", str(paths[idx].suffix))
    inplaceStringChange(".png", str(paths[idx].suffix))
