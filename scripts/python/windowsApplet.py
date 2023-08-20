from dep.traymenu import TrayMenu, quitsystray
import mylib
import os
import signal
import pathlib
import sys
import subprocess


class IndicatorApp:
    def __init__(self):
        script_dir = pathlib.Path(__file__).parent.absolute()
        self.menu_items = {}
        self.tray_functions = []

        self.add_menu_item(
            "🎵 youtubeSync",
            lambda: self.toggle_script("🎵 youtubeSync", f"{script_dir}/youtubeSync.py"),
        )

        self.add_menu_item(
            "🗓️ updateOverlay",
            lambda: self.toggle_script(
                "🗓️ updateOverlay", f"{script_dir}/updateOverlay.py"
            ),
        )

        self.add_menu_item(
            "📝 editTasks",
            lambda: self.toggle_script("📝 editTasks", f"{script_dir}/editTasks.py"),
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
            process_info["process"].terminate()
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
