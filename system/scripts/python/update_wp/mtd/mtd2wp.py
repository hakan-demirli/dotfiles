import os
import pathlib
import tempfile

from PIL import Image


# TODO
def main():
    script_dir = pathlib.Path(os.path.realpath(__file__)).parent.absolute()
    mylib.runInVenv(f"{script_dir}/mtd2overlay.py")
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
