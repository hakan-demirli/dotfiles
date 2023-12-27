import os
import pathlib
import shutil
import subprocess
import tempfile

from PIL import Image

script_dir = pathlib.Path(os.path.realpath(__file__)).parent.absolute()
config_dir = os.path.expanduser("~/.config/mylib/")
font_file = script_dir / "anonymous.ttf"

ics_url_file = config_dir + "ics.json"
calendar_overlay_file = tempfile.gettempdir() + "/calendar_overlay.png"
ics_file = tempfile.gettempdir() + "/calendar_events.ics"


def main():
    subprocess.run("ics_overlay")
    subprocess.run("gtasks_overlay")
    subprocess.run("mtd_overlay")
    subprocess.run("add_ics_overlay")
    subprocess.run("add_gtasks_overlay")
    shutil.copy(mylib.OVERLAYED_FILE, mylib.OVERLAYED_BACKUP_FILE)
    mylib.runInVenv(f"{script_dir}/overlayMtd.py")
    mylib.changeWallpaper(mylib.OVERLAYED_FILE)

    image = Image.open(mylib.OVERLAYED_FILE)
    width, height = image.size
    crop_box = (137, 26, width, height)
    cropped_image = image.crop(crop_box)
    tmp_image = tempfile.gettempdir() + "/" + mylib.getRandomFileName(".png")
    cropped_image.save(tmp_image)
    image.close()

    mylib.setFirefoxWallpaper(tmp_image)


if __name__ == "__main__":
    main()
