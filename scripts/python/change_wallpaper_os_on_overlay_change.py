import os
import time
import mylib
import subprocess


overlay = "C:\\Users\\emre\\Desktop\\overlay.png"
last_mod_time = os.path.getmtime(overlay)

while True:
    if mylib.checkFileModification(overlay, last_mod_time):
        subprocess.run(
            [
                "python",
                "./change_wallpaper_os_overlay.py",
                "--overlay-path",
                overlay,
            ]
        )
        last_mod_time = os.path.getmtime(overlay)
    time.sleep(5)
