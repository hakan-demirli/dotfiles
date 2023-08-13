import os
import time
import mylib
import subprocess
import pathlib


def main():
    script_dir = pathlib.Path(__file__).parent.absolute()
    try:
        last_mod_time = os.path.getmtime(mylib.OVERLAY_FILE)
    except:
        last_mod_time = 0
    while True:
        if mylib.checkFileModification(mylib.OVERLAY_FILE, last_mod_time):
            subprocess.run(["python", f"{script_dir}/overlayImages.py"])
            mylib.changeWallpaper(mylib.OVERLAYED_FILE)
            last_mod_time = os.path.getmtime(mylib.OVERLAY_FILE)
        time.sleep(120)


if __name__ == "__main__":
    main()
