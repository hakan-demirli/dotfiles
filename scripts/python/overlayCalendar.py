import subprocess
import tempfile
import mylib
from PIL import Image


def main():
    overlay_file = mylib.CALENDAR_OVERLAY_FILE
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
            with tempfile.NamedTemporaryFile(
                suffix=".png", delete=False
            ) as resized_image:
                mylib.resizeImage(
                    wallpapers[idx], resized_image, monitor_width, monitor_height
                )

                background = Image.open(resized_image)
                overlay = Image.open(overlay_file)

                # Calculate the position for overlay (top right corner)
                x_offset = background.width - overlay.width
                y_offset = 0
                mylib.overlayImages(
                    resized_image,
                    overlay_file,
                    mylib.OVERLAYED_FILE,
                    x_offset,
                    y_offset,
                )

        except FileNotFoundError:
            print("Input image files not found.")
        except subprocess.CalledProcessError as e:
            print("Image processing error:", e)
    else:
        print("Unable to get monitor resolution. Exiting.")


if __name__ == "__main__":
    main()
