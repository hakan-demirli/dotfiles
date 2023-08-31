import gi
import subprocess
import os
import signal
import pathlib

gi.require_version("Gtk", "3.0")
gi.require_version("AppIndicator3", "0.1")

from gi.repository import Gtk, AppIndicator3, Gio, GLib


class IndicatorApp:
    def __init__(self):
        self.app = "my-indicator"
        self.menu = Gtk.Menu()

        script_dir = pathlib.Path(__file__).parent.absolute()
        self.menu_items = {}

        item_callback = lambda _: self.toggle_process(
            "🗣️ clipboardTTS", f"python {script_dir}/clipboardTTS.py"
        )
        self.add_menu_item("🗣️ clipboardTTS", item_callback)

        item_callback = lambda _: self.toggle_process(
            "🗓️ updateOverlay", f"python {script_dir}/updateOverlay.py"
        )
        self.add_menu_item("🗓️ updateOverlay", item_callback)

        item_callback = lambda _: self.toggle_process(
            "🎵 youtubeSync", f"python {script_dir}/youtubeSync.py"
        )
        self.add_menu_item("🎵 youtubeSync", item_callback)

        self.add_menu_item("--", lambda _: print("---"))

        self.add_menu_item("Quit", self.quit)

        self.menu.show_all()
        self.indicator = AppIndicator3.Indicator.new(
            id=self.app,
            icon_name="preferences-system-symbolic",
            category=AppIndicator3.IndicatorCategory.APPLICATION_STATUS,
        )
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.menu)

    def add_menu_item(self, label, callback):
        item = Gtk.MenuItem(label=label)
        item.connect("activate", callback)
        self.menu_items[label] = {"status": False, "item": item, "process": None}
        self.menu.append(item)

    def toggle_process(self, label, command):
        process_info = self.menu_items[label]
        if process_info["process"]:
            os.killpg(os.getpgid(process_info["process"].pid), signal.SIGTERM)
            process_info["process"] = None
            process_info["item"].set_label(label)
            return
        else:
            process_info["process"] = subprocess.Popen(
                command.split(" "), preexec_fn=os.setsid
            )
            process_info["item"].set_label(label + "⌛")
            return
        process_info["item"].set_label(label)
        return

    def quit(self, _):
        for label in self.menu_items:
            menu_item = self.menu_items[label]
            status = menu_item["status"]
            process = menu_item["process"]
            if status:
                os.killpg(os.getpgid(process.pid), signal.SIGTERM)

        Gtk.main_quit()


if __name__ == "__main__":
    app = IndicatorApp()
    Gtk.main()
