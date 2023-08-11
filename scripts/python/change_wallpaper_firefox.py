#!/usr/bin/env python3
import hashlib
import pathlib
import datetime
import shutil
import mylib
import os
import argparse


def chromeFolderPath() -> str:
    return f"{mylib.findFirefoxProfileFolder()}/chrome/"


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
    parser = argparse.ArgumentParser(description="Change wallpaper based on the day.")
    parser.add_argument(
        "--wp-folder",
        default="./",
        help="Folder path containing wallpaper images. Default: './'",
    )
    parser.add_argument(
        "--types",
        nargs="+",
        default=[".jpg", ".png", ".jpeg"],
        help="List of wallpaper image file extensions. Default: ['.jpg', '.png', '.jpeg']",
    )
    args = parser.parse_args()

    wallpapers = mylib.getFilesByType(args.wp_folder, args.types)
    if len(wallpapers) <= 0:
        print(f"No wallpapers found in '{args.wp_folder}'. Exiting.")
        exit(1)

    idx = mylib.timeToIndex(len(wallpapers))
    removeAllFiles(chromeFolderPath(), args.types)  # del old wp

    new_wallpaper_str = wallpapers[idx]
    new_wallpaper_path = pathlib.Path(new_wallpaper_str)
    shutil.copy2(new_wallpaper_str, chromeFolderPath())
    new_wallpaper_name = (
        chromeFolderPath() + "my_wallpaper" + str(new_wallpaper_path.suffix)
    )

    shutil.move(
        chromeFolderPath() + str(new_wallpaper_path.stem + new_wallpaper_path.suffix),
        new_wallpaper_name,
    )
    css_file = chromeFolderPath() + "userContent.css"
    changeStringInPlace(".jpg", str(new_wallpaper_path.suffix), css_file)
    changeStringInPlace(".jpeg", str(new_wallpaper_path.suffix), css_file)
    changeStringInPlace(".png", str(new_wallpaper_path.suffix), css_file)


if __name__ == "__main__":
    main()
