import mylib
from PIL import Image, ImageDraw, ImageFont


def main():
    overlay_file = mylib.MTD_OVERLAY_FILE
    overlayed_file = mylib.OVERLAYED_FILE

    # Calculate the position for overlay (top right corner)
    x_offset = mylib.SCREEN_WIDTH - 700
    y_offset = (mylib.SCREEN_HEIGHT // 2) + 75
    mylib.overlayImages(
        overlayed_file, overlay_file, overlayed_file, x_offset, y_offset
    )


if __name__ == "__main__":
    main()
