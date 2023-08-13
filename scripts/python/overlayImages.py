import os
import subprocess
import tempfile
import mylib
import pathlib


def main():
    overlay_file = mylib.OVERLAY_FILE
    wp_folder = mylib.WALLPAPERS_PC_DIR
    types = [".jpg", ".png", ".jpeg"]

    wallpapers = mylib.getFilesByType(wp_folder, types)

    if len(wallpapers) <= 0:
        print(f"No wallpapers found in '{wp_folder}'. Exiting.")
        exit(1)
    idx = mylib.timeToIndex(len(wallpapers))
    monitor_width, monitor_height = mylib.getMonitorResolution()
    if monitor_width and monitor_height:
        try:
            with tempfile.TemporaryDirectory() as temp_dir:
                resized_image = os.path.join(
                    temp_dir, f"{mylib.getRandomFileName()}.png"
                )
                mylib.resizeImage(
                    wallpapers[idx], resized_image, monitor_width, monitor_height
                )
                mylib.overlayImages(resized_image, overlay_file, mylib.OVERLAYED_FILE)

        except FileNotFoundError:
            print("Input image files not found.")
        except subprocess.CalledProcessError as e:
            print("Image processing error:", e)
    else:
        print("Unable to get monitor resolution. Exiting.")


if __name__ == "__main__":
    main()
