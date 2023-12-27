from traymenu import TrayMenu, quitsystray
import mylib
import pathlib
import sys
import subprocess

import psutil


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
        script_dir = pathlib.Path(__file__).parent.absolute()
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
