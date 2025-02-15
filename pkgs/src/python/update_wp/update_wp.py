#!/usr/bin/env python3

import os
import pathlib
import random
import shutil
import string
import subprocess
import tempfile

from PIL import Image

from add_gtasks_overlay import main as add_gtasks_overlay
from add_ics_overlay import main as add_ics_overlay

# from add_mtd_overlay import main as add_mtd_overlay
from add_left_overlay import main as add_left_overlay
from gtasks.gtasks_overlay import main as gtasks_overlay
from ics.ics_overlay import main as ics_overlay

# from mtd.mtd_overlay import main as mtd_overlay
from left.left_overlay import main as left_overlay

script_dir = pathlib.Path(os.path.realpath(__file__)).parent.absolute()
config_dir = os.path.expanduser("~/.config/mylib/")  # ABS_PATH: fix pls
font_file = "~/.local/share/fonts/anonymous.ttf"  # ABS_PATH: fix pls

ics_url_file = config_dir + "ics.json"
calendar_overlay_file = tempfile.gettempdir() + "/calendar_overlay.png"
ics_file = tempfile.gettempdir() + "/calendar_events.ics"

overlayed_file = tempfile.gettempdir() + "/overlayed.png"
overlayed_backup_file = tempfile.gettempdir() + "/overlayed_backup.png"


def findFirefoxProfileFolder():
    # Search for profiles.ini in all locations
    locations = [
        os.path.expanduser("~/.mozilla/firefox/profiles.ini"),
        os.path.expanduser("~/snap/firefox/common/.mozilla/firefox/profiles.ini"),
        os.path.expanduser("~/AppData/Roaming/Mozilla/Firefox/profiles.ini"),
    ]
    for location in locations:
        if os.path.exists(location):
            with open(location, "r") as file:
                for line in file:
                    key = "Path="
                    if line.startswith(key):
                        folder_name = line.strip().replace(key, "").strip()
                        return os.path.join(os.path.dirname(location), folder_name)

    return None


def removeAllFiles(dir: str, extensions: list) -> None:
    print("Start removing old wallpapers:")
    for ext in extensions:
        for index, path in enumerate(pathlib.Path(dir).glob(ext)):
            print(f"Removing: {path}")
            os.remove(path)


def changeStringInPlace(old_string: str, new_string: str, file: str) -> int:
    with open(file) as f:
        s = f.read()
        if old_string not in s:
            print(f'"{old_string}" not found')
            return -1
    with open(file, "w") as f:
        s = s.replace(old_string, new_string)
        f.write(s)

    return 0


def setFirefoxWallpaper(wallpaper_path: str) -> None:
    chrome_folder_path = f"{findFirefoxProfileFolder()}/chrome/"
    new_wallpaper_name = chrome_folder_path + "wp.png"
    types = ["*.jpg", "*.png", "*.jpeg"]
    removeAllFiles(chrome_folder_path, types)  # del old wp
    new_wallpaper_path = pathlib.Path(wallpaper_path)
    shutil.copy2(wallpaper_path, chrome_folder_path)
    extension = str(new_wallpaper_path.suffix)

    if extension.lower() != ".png":
        img = Image.open(new_wallpaper_path)
        img.save(new_wallpaper_name)
    else:
        shutil.copy2(wallpaper_path, new_wallpaper_name)


def launch_onscreen_overlay(task_file_path: str) -> None:
    subprocess.run(["pkill", "activate-linux"])

    task = ""
    with open(task_file_path, "r") as f:
        lines = f.readlines()
        task = lines[0].strip()  # Strip newline characters

    os.system(f'activate-linux -t Task -m "{task}" & ')


def main():
    ics_overlay()
    gtasks_overlay()
    # mtd_overlay()
    left_overlay()
    add_ics_overlay()
    add_gtasks_overlay()
    shutil.copy(overlayed_file, overlayed_backup_file)
    add_left_overlay()
    # add_mtd_overlay()
    subprocess.run(
        [
            "swww",
            "img",
            f"{overlayed_file}",
            "-t",
            "any",
            "--transition-fps",
            "144",
            "--transition-step",
            "90",
        ]
    )
    launch_onscreen_overlay("/tmp/gtasks.txt")  # TODO: fix ABSPATH
    image = Image.open(overlayed_file)
    width, height = image.size
    crop_box = (137, 26, width, height)
    cropped_image = image.crop(crop_box)

    letters = string.ascii_lowercase
    random_file_name = "".join(random.choice(letters) for _ in range(32)) + ".png"

    tmp_image = tempfile.gettempdir() + "/" + random_file_name
    cropped_image.save(tmp_image)
    image.close()

    setFirefoxWallpaper(tmp_image)


if __name__ == "__main__":
    main()
