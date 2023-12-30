#!/usr/bin/env python3

import os
import signal
import subprocess

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("AppIndicator3", "0.1")

from gi.repository import AppIndicator3, Gtk


# aksdjfaskdjf
class IndicatorApp:
    def __init__(self):
        self.app = "my-indicator"
        self.menu = Gtk.Menu()
        self.menu_items = {}

        def clipboard_tts(_):
            return self.toggle_process("🗣️ clipboardTTS", "clipboard_tts")

        def youtube_sync(_):
            return self.run_process("youtube_sync")

        def update_wp(_):
            return self.run_process("update_wp")

        self.add_menu_item("🗣️ clipboardTTS", clipboard_tts)

        self.add_menu_item("🗓️ updateOverlay", update_wp)

        self.add_menu_item("🎵 youtubeSync", youtube_sync)

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

    def run_process(self, command):
        subprocess.Popen(command.split(" "), preexec_fn=os.setsid)

    def toggle_process(self, label, command):
        process_info = self.menu_items[label]
        if process_info["process"]:
            os.killpg(os.getpgid(process_info["process"].pid), signal.SIGTERM)
            process_info["process"] = None
            process_info["item"].set_label(label)
            return
        else:  # [TODO] use venv here
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
