import mylib
from PIL import Image, ImageDraw, ImageFont
import subprocess
import pathlib
import sys

"""
Download credentials.json

Dependencies:
    pip install gtasks-md
    pandoc-2.19.2-windows-x86_64.msi

Modify the package after installation.
Editor.py:
    self.editor = "code"
cli.py:
    str.lower -> str
"""


def main():
    script_dir = pathlib.Path(__file__).parent.absolute()
    font_file = mylib.ANON_FONT_FILE
    overlay_file = mylib.TASKS_OVERLAY_FILE
    width, height = 400, 800
    background_color = (0, 0, 0, 222)
    text_position = (40, 40)
    font_size = 14
    text_color = (255, 255, 255)

    image = Image.new("RGBA", (width, height), background_color)
    draw = ImageDraw.Draw(image)

    command = f"{sys.executable} {script_dir}/gtasks/main.py view"
    font = ImageFont.truetype(font_file, size=font_size)
    tasks = subprocess.check_output(command, shell=True, text=True)

    draw.text(text_position, tasks, fill=text_color, font=font)
    image.save(overlay_file)


if __name__ == "__main__":
    main()
