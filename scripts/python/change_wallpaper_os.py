#!/usr/bin/env python3
import argparse
import mylib


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
    mylib.changeWallpaper(wallpapers[idx])


if __name__ == "__main__":
    main()
