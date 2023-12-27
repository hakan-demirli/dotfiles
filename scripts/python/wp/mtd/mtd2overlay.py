import mylib
from PIL import Image, ImageDraw, ImageFont, ImageOps
import pathlib
import sys
import os


def main():
    script_dir = pathlib.Path(__file__).parent.absolute()
    font_file = mylib.ANON_FONT_FILE
    overlay_file = mylib.MTD_OVERLAY_FILE
    width, height = 700, 800
    background_color = (0, 0, 0, 0)
    text_position = (400, 40)
    font_size = 13
    text_color = (255, 205, 205)
    font = ImageFont.truetype(font_file, size=font_size)

    image = Image.new("RGBA", (width, height), background_color)
    draw = ImageDraw.Draw(image)

    config_dir = os.path.expanduser("~/.config/mtd")
    mtdr_file = os.path.join(config_dir, "mtd.md")

    with open(mtdr_file, "r") as mtdr:
        mtd_contents = mtdr.readlines()
        mtd_contents = [line for line in mtd_contents if line.strip() != ""]

    tasks = "\n".join(mtd_contents)
    draw.text(text_position, tasks, fill=text_color, font=font)
    image.save(overlay_file)
    return


if __name__ == "__main__":
    main()
