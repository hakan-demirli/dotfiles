import mylib
from PIL import Image, ImageDraw, ImageFont

"""
Dependencies:
    pip install gtasks-md
    pandoc-2.19.2-windows-x86_64.msi

Modify the package after installation.
Editor.py:
    self.editor = "nvim"
"""


def main():
    overlay_file = mylib.TASKS_OVERLAY_FILE
    overlayed_file = mylib.OVERLAYED_FILE

    # Calculate the position for overlay (top right corner)
    x_offset = 200
    y_offset = 0
    mylib.overlayImages(
        overlayed_file, overlay_file, overlayed_file, x_offset, y_offset
    )


if __name__ == "__main__":
    main()
