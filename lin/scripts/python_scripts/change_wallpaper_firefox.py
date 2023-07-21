#!/usr/bin/env python3
from hashlib import new
from pathlib import Path
from datetime import datetime
from shutil import copy2, move
from os import remove, path

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


def find_firefox_profile_folder():
    # Search for profiles.ini in both locations
    locations = [
        path.expanduser("~/.mozilla/firefox/profiles.ini"),
        path.expanduser("~/snap/firefox/common/.mozilla/firefox/profiles.ini"),
    ]
    for location in locations:
        if path.exists(location):
            with open(location, "r") as file:
                for line in file:
                    key = "Default="
                    if line.startswith(key):
                        folder_name = line.strip().replace(key, "").strip()
                        return path.join(path.dirname(location), folder_name)

    return None


WALLPAPER_PATH = Path("/mnt/second/images/art/wallpapers_pc")
USER_CHROME_PATH = Path(f"{find_firefox_profile_folder()}/chrome")


def daysSinceEpoch():
    return int(int(datetime.now().strftime("%s")) / 86400)


def wallpaperPaths():
    paths = []
    for index, path in enumerate(WALLPAPER_PATH.glob("*")):
        paths.append(path)
    return paths


def inplaceStringChange(old_string, new_string):
    with open((USER_CHROME_PATH / "userContent.css")) as f:
        s = f.read()
        if old_string not in s:
            print(f'"{old_string}" not found')
            return

    with open((USER_CHROME_PATH / "userContent.css"), "w") as f:
        s = s.replace(old_string, new_string)
        f.write(s)


paths = wallpaperPaths()
idx = daysSinceEpoch() % len(paths)

for ext in ["*.jpg", "*.png", "*.jpeg"]:
    for index, path in enumerate(USER_CHROME_PATH.glob(ext)):
        remove(path)

copy2(str(paths[idx]), USER_CHROME_PATH)

new_name = USER_CHROME_PATH / ("my_wallpaper" + str(paths[idx].suffix))
move(USER_CHROME_PATH / str(paths[idx].stem + paths[idx].suffix), new_name)

inplaceStringChange(".jpg", str(paths[idx].suffix))
inplaceStringChange(".jpeg", str(paths[idx].suffix))
inplaceStringChange(".png", str(paths[idx].suffix))
