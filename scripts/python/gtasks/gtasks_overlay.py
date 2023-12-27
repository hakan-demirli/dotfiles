#!/usr/bin/env python3

from PIL import Image, ImageDraw, ImageFont, ImageOps
import subprocess
import pathlib
import sys
import tempfile
import os

"""
Gtasks to png transparent overlay image.
"""


def main():
    script_dir = pathlib.Path(os.path.realpath(__file__)).parent.absolute()
    font_file = script_dir / "anonymous.ttf"
    overlay_file = tempfile.gettempdir() + "/tasks_overlay.png"
    width, height = 700, 800
    background_color = (0, 0, 0, 0)
    text_position = (40, 40)
    font_size = 13
    text_color = (155, 205, 205)

    image = Image.new("RGBA", (width, height), background_color)
    draw = ImageDraw.Draw(image)

    font = ImageFont.truetype(str(font_file), size=font_size)

    try:
        command = f"{sys.executable} {script_dir}/main.py view"
        tasks = subprocess.check_output(command, shell=True, text=True)
        draw.text(text_position, tasks, fill=text_color, font=font)
        image.save(overlay_file)
        return
    except subprocess.CalledProcessError as e:
        print(f"Command failed with exit code {e.returncode}")
        print("Deleting token and trying again")
        command = f"{sys.executable} {script_dir}/main.py delete_token"
        subprocess.run(command, shell=True, text=True)
        command = f"{sys.executable} {script_dir}/main.py auth"
        subprocess.run(command, shell=True, text=True)
        command = f"{sys.executable} {script_dir}/main.py view"
        tasks = subprocess.check_output(command, shell=True, text=True)
        draw.text(text_position, tasks, fill=text_color, font=font)
        # image = ImageOps.expand(image, border=5, fill="black")
        image.save(overlay_file)
        return


if __name__ == "__main__":
    main()
