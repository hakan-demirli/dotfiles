import mylib
from PIL import Image, ImageDraw, ImageFont
from xdg import xdg_cache_home
import os
import subprocess

"""
Download credentials.json

Dependencies:
    pip install gtasks-md
    pandoc-2.19.2-windows-x86_64.msi

Modify the package after installation.
Editor.py:
    self.editor = "code"
"""


def main():
    wp_folder = mylib.WALLPAPERS_PC_DIR
    font_file = mylib.ANON_FONT_FILE
    overlay_file = mylib.TASKS_OVERLAY_FILE
    types = [".jpg", ".png", ".jpeg"]
    width, height = 400, 800
    background_color = (0, 0, 0, 222)
    text_position = (40, 40)
    font_size = 14
    text_color = (255, 255, 255)

    cache_dir = f"{xdg_cache_home()}/gtasks-md/default"

    wallpapers = mylib.getFilesByType(wp_folder, types)

    if len(wallpapers) <= 0:
        print(f"No wallpapers found in '{wp_folder}'. Exiting.")
        exit(1)

    image = Image.new("RGBA", (width, height), background_color)
    draw = ImageDraw.Draw(image)

    command = "gtasks-md view"
    font = ImageFont.truetype(font_file, size=font_size)
    output = subprocess.check_output(command, shell=True, text=True)
    lines = output.split("\n")
    lines = lines[6:]
    tasks = "\n".join(lines)
    tasks = tasks.replace("\n\n", "\n")
    draw.text(text_position, tasks, fill=text_color, font=font)
    image.save(overlay_file)


if __name__ == "__main__":
    main()
