import os

from PIL import Image, ImageDraw, ImageFont


def main():
    font_file = os.path.expanduser("~/.local/share/fonts/anonymous.ttf")
    overlay_file = "/tmp/mtd_overlay.png"
    width, height = 700, 800
    background_color = (0, 0, 0, 0)
    text_position = (400, 40)
    font_size = 12
    text_color = (255, 205, 205)
    font = ImageFont.truetype(font_file, size=font_size)

    image = Image.new("RGBA", (width, height), background_color)
    draw = ImageDraw.Draw(image)

    config_dir = os.path.expanduser("~/.config/mtd")
    mtdr_file = os.path.join(config_dir, "mtd.md")

    if not os.path.exists(config_dir):
        os.makedirs(config_dir)

    if not os.path.isfile(mtdr_file):
        open(mtdr_file, "a").close()

    with open(mtdr_file, "r") as mtdr:
        mtd_contents = mtdr.readlines()
        mtd_contents = [line for line in mtd_contents if line.strip() != ""]

    tasks = "\n".join(mtd_contents)
    draw.text(text_position, tasks, fill=text_color, font=font)
    image.save(overlay_file)
    return


if __name__ == "__main__":
    main()
