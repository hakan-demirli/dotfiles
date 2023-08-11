import os
import subprocess
import argparse
import tempfile
import mylib
import pathlib


def main():
    parser = argparse.ArgumentParser(
        description="Change wallpaper based on the day and add an overlay."
    )
    parser.add_argument(
        "--overlay-path",
        default="./overlay.png",
        help="Path to overlay image. './overlay.png'",
    )
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
    monitor_width, monitor_height = mylib.getMonitorResolution()
    if monitor_width and monitor_height:
        try:
            with tempfile.TemporaryDirectory() as temp_dir:
                resized_image = os.path.join(
                    temp_dir, f"{mylib.getRandomFileName()}.png"
                )
                final_image = os.path.join(temp_dir, f"{mylib.getRandomFileName()}.png")
                mylib.resizeImage(
                    wallpapers[idx], resized_image, monitor_width, monitor_height
                )
                mylib.overlayImages(resized_image, args.overlay_path, final_image)

                mylib.changeWallpaper(final_image)
        except FileNotFoundError:
            print("Input image files not found.")
        except subprocess.CalledProcessError as e:
            print("Image processing error:", e)
    else:
        print("Unable to get monitor resolution. Exiting.")


if __name__ == "__main__":
    main()
