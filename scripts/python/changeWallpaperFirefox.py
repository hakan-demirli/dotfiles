#!/usr/bin/env python3
import hashlib
import pathlib
import datetime
import shutil
import mylib
import os
import argparse


def changeStringInPlace(old_string: str, new_string: str, file: str) -> None:
    with open(file) as f:
        s = f.read()
        if old_string not in s:
            print(f'"{old_string}" not found')
            return

    with open(file, "w") as f:
        s = s.replace(old_string, new_string)
        f.write(s)


def removeAllFiles(dir: str, extensions: list) -> None:
    for ext in extensions:
        for index, path in enumerate(pathlib.Path(dir).glob(ext)):
            os.remove(path)


def main():
    wp_folder = mylib.WALLPAPERS_PC_DIR
    types = [".jpg", ".png", ".jpeg"]
    chrome_folder_path = mylib.chromeFolderPath()
    css_file = chrome_folder_path + "userContent.css"

    wallpapers = mylib.getFilesByType(wp_folder, types)
    if len(wallpapers) <= 0:
        print(f"No wallpapers found in '{wp_folder}'. Exiting.")
        exit(1)

    idx = mylib.timeToIndex(len(wallpapers))
    removeAllFiles(mylib.chromeFolderPath(), types)  # del old wp

    new_wallpaper_str = wallpapers[idx]
    new_wallpaper_path = pathlib.Path(new_wallpaper_str)
    shutil.copy2(new_wallpaper_str, chrome_folder_path)
    new_wallpaper_name = (
        chrome_folder_path + "my_wallpaper" + str(new_wallpaper_path.suffix)
    )

    shutil.move(
        chrome_folder_path + str(new_wallpaper_path.stem + new_wallpaper_path.suffix),
        new_wallpaper_name,
    )
    for type in types:
        changeStringInPlace(type, str(new_wallpaper_path.suffix), css_file)


if __name__ == "__main__":
    main()
