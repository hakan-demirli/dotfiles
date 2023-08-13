import signal
import gi
import subprocess

gi.require_version("Gtk", "3.0")
gi.require_version("AppIndicator3", "0.1")

from gi.repository import Gtk, AppIndicator3, Gio


class AppIndicatorExample:
    def __init__(self):
        self.app = "my-app-indicator"
        self.indicator = AppIndicator3.Indicator.new(
            id=self.app,
            icon_name="system-shutdown-symbolic",
            category=AppIndicator3.IndicatorCategory.APPLICATION_STATUS,
        )
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.create_menu())
        self.indicator.set_label("⏻", self.app)  # Set power symbol here

    def create_menu(self):
        menu = Gtk.Menu()

        self.add_menu_item(
            menu,
            "Sleep",
            self.confirm_action,
            "Sleep",
            "Are you sure you want to sleep?",
        )
        self.add_menu_item(
            menu,
            "Reboot",
            self.confirm_action,
            "Reboot",
            "Are you sure you want to reboot?",
        )
        self.add_menu_item(
            menu,
            "Shutdown",
            self.confirm_action,
            "Shutdown",
            "Are you sure you want to shut down?",
        )
        # self.add_menu_item(menu, "Quit", self.quit)

        menu.show_all()
        return menu

    def add_menu_item(self, menu, label, callback, *args):
        item = Gtk.MenuItem(label=label)
        item.connect("activate", callback, *args)
        menu.append(item)

    def confirm_action(self, source, action_name, confirmation_text):
        dialog = Gtk.MessageDialog(
            parent=None,
            flags=0,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.YES_NO,
            text=f"Confirm {action_name}",
        )
        dialog.format_secondary_text(confirmation_text)

        settings = Gtk.Settings.get_default()
        settings.props.gtk_application_prefer_dark_theme = True

        response = dialog.run()
        dialog.destroy()

        if response == Gtk.ResponseType.YES:
            if action_name == "Sleep":
                self.sleep()
            elif action_name == "Shutdown":
                self.shutdown()
            elif action_name == "Reboot":
                self.reboot()

    def sleep(self):
        subprocess.run(["systemctl", "suspend"])

    def reboot(self):
        subprocess.run(["systemctl", "reboot"])

    def shutdown(self):
        subprocess.run(["systemctl", "poweroff"])

    def quit(self, source):
        Gtk.main_quit()


def main():
    Gtk.init(None)
    indicator = AppIndicatorExample()
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    Gtk.main()


if __name__ == "__main__":
    main()
