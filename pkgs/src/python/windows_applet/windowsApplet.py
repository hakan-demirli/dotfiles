import os
import subprocess
import sys
from pathlib import Path

import mylib
import psutil
from traymenu import TrayMenu, quitsystray


def kill_process_and_children(pid: int, sig: int = 15):
    try:
        proc = psutil.Process(pid)
    except psutil.NoSuchProcess as e:
        print(e)
        return

    for child_process in proc.children(recursive=True):
        child_process.send_signal(sig)

    proc.send_signal(sig)


class IndicatorApp:
    def __init__(self):
        script_dir = Path(os.path.realpath(__file__)).parent.absolute()
        self.menu_items = {}
        self.tray_functions = []

        self.add_menu_item(
            "🎵 youtubeSync",
            lambda: mylib.runInVenv(f"{script_dir}/youtubeSync.py"),
        )

        self.add_menu_item(
            "🗓️ updateOverlay",
            lambda: mylib.runInVenv(f"{script_dir}/updateOverlay.py"),
        )

        self.tray_functions.append(("--"))

        self.add_menu_item(
            "🗣️ clipboardTTS",
            lambda: self.toggle_script(
                "🗣️ clipboardTTS", f"{script_dir}/clipboardTTS.py"
            ),
        )

        self.tray_functions.append(("Quit", lambda: quitsystray()))
        self.tm = TrayMenu(icon=mylib.APPLET_ICON_FILE, functions=self.tray_functions)

    def add_menu_item(self, label, callback):
        self.menu_items[label] = {"label": label, "process": None}
        self.tray_functions.append((label, callback))

    def toggle_script(self, label, script_path):
        process_info = self.menu_items[label]
        if process_info["process"]:
            kill_process_and_children(process_info["process"].pid)
            process_info["process"] = None
            return
        else:
            process_info["process"] = subprocess.Popen([sys.executable, script_path])
            return
        return

    def run(self):
        self.tm.letsgo()


if __name__ == "__main__":
    app = IndicatorApp()
    app.run()
