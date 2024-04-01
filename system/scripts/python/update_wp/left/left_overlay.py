#!/usr/bin/env python3
import os
import subprocess

from PIL import Image, ImageDraw, ImageFont


def main():
    font_file = os.path.expanduser(
        "~/.local/share/fonts/anonymous.ttf"
    )  # ABS_PATH: fix pls
    overlay_file = "/tmp/left_overlay.png"
    width, height = 650, 36
    background_color = (0, 0, 0, 0)
    text_position = (0, 0)
    font_size = 12
    text_color = (255, 205, 205)
    font = ImageFont.truetype(font_file, size=font_size)

    image = Image.new("RGBA", (width, height), background_color)
    draw = ImageDraw.Draw(image)

    script_path = os.path.expanduser("~/.config/mylib/left.py")
    left = subprocess.run(script_path, capture_output=True, text=True)
    left = left.stdout.strip()
    draw.text(text_position, left, fill=text_color, font=font)
    image.save(overlay_file)
    return


if __name__ == "__main__":
    main()
