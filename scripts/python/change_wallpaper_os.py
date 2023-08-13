#!/usr/bin/env python3
import argparse
import mylib


def main():
    wp_folder = mylib.WALLPAPERS_PC_DIR
    types = [".jpg", ".png", ".jpeg"]

    wallpapers = mylib.getFilesByType(wp_folder, types)

    if len(wallpapers) <= 0:
        print(f"No wallpapers found in '{wp_folder}'. Exiting.")
        exit(1)
    idx = mylib.timeToIndex(len(wallpapers))
    mylib.changeWallpaper(wallpapers[idx])


if __name__ == "__main__":
    main()
