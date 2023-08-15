import signal
import gi
import subprocess
import pathlib

gi.require_version("Gtk", "3.0")
gi.require_version("AppIndicator3", "0.1")

from gi.repository import Gtk, AppIndicator3, Gio


class AppIndicatorExample:
    def __init__(self):
        self.app = "my-gtk-applet"
        self.indicator = AppIndicator3.Indicator.new(
            id=self.app,
            # Use a cogwheel icon name, you can replace this with your desired icon
            icon_name="preferences-system-symbolic",  # Icon name for cogwheel
            category=AppIndicator3.IndicatorCategory.APPLICATION_STATUS,
        )
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.menu = Gtk.Menu()
        self.create_menu()
        self.menu.show_all()
        self.indicator.set_menu(self.menu)
        self.indicator.set_label("⚙️", self.app)

    def create_menu(self):
        script_dir = pathlib.Path(__file__).parent.absolute()
        self.add_menu_item(
            "🎵 youtubeSync",
            lambda _: subprocess.run(["python", f"{script_dir}/youtubeSync.py"]),
        )
        self.add_menu_item(
            "🗓️ updateOverlay",
            lambda _: subprocess.run(["python", f"{script_dir}/updateOverlay.py"]),
        )
        self.add_menu_item(
            "📝 editTasks",
            lambda _: subprocess.run(["python", f"{script_dir}/editTasks.py"]),
        )
        self.add_menu_item(
            "--",
            lambda _: subprocess.run(["echo", f"dummy"]),
        )
        self.add_menu_item(
            "🗣️ clipboardTTS",
            lambda _: subprocess.run(["python", f"{script_dir}/clipboardTTS.py"]),
        )
        self.add_menu_item("Quit", self.quit)

    def add_menu_item(self, label, callback):
        item = Gtk.MenuItem(label=label)
        item.connect("activate", callback)
        self.menu.append(item)

    def quit(self):
        Gtk.main_quit()


def main():
    Gtk.init(None)
    indicator = AppIndicatorExample()
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    Gtk.main()


if __name__ == "__main__":
    main()
