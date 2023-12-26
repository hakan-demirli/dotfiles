import mylib
from PIL import Image, ImageDraw, ImageFont, ImageOps
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
    width, height = 700, 800
    background_color = (0, 0, 0, 0)
    text_position = (40, 40)
    font_size = 13
    text_color = (155, 205, 205)

    image = Image.new("RGBA", (width, height), background_color)
    draw = ImageDraw.Draw(image)

    font = ImageFont.truetype(font_file, size=font_size)

    try:
        command = f"{sys.executable} {script_dir}/gtasks/main.py view"
        tasks = subprocess.check_output(command, shell=True, text=True)
        draw.text(text_position, tasks, fill=text_color, font=font)
        image.save(overlay_file)
        return
    except subprocess.CalledProcessError as e:
        print(f"Command failed with exit code {e.returncode}")
        print(f"Deleting token and trying again")
        command = f"{sys.executable} {script_dir}/gtasks/main.py delete_token"
        subprocess.run(command, shell=True, text=True)
        command = f"{sys.executable} {script_dir}/gtasks/main.py auth"
        subprocess.run(command, shell=True, text=True)
        command = f"{sys.executable} {script_dir}/gtasks/main.py view"
        tasks = subprocess.check_output(command, shell=True, text=True)
        draw.text(text_position, tasks, fill=text_color, font=font)
        # image = ImageOps.expand(image, border=5, fill="black")
        image.save(overlay_file)
        return


if __name__ == "__main__":
    main()
