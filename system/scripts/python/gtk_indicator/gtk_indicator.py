#!/usr/bin/env python3

import argparse
import gi
import os
import socket
import json
import logging
import signal
import sys

gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")

from gi.repository import (
    GLib,
    Gtk,
)
from gi.repository import Gtk4LayerShell as LayerShell


def get_xdg_path(env_var, default_path):
    return os.getenv(env_var, os.path.expanduser(default_path))


XDG_RUNTIME_DIR = get_xdg_path("XDG_RUNTIME_DIR", "/tmp")
XDG_CONFIG_HOME = get_xdg_path("XDG_CONFIG_HOME", "~/.config")
XDG_CACHE_HOME = get_xdg_path("XDG_CACHE_HOME", "~/.cache")


class GtkIndicator:
    def __init__(self, name):
        self.name = name
        self.socket_dir = os.path.join(XDG_RUNTIME_DIR, "gtk_indicator")
        self.socket_path = os.path.join(self.socket_dir, f"{self.name}.sock")
        self.config_path = os.path.join(
            XDG_CONFIG_HOME, "gtk_indicator", f"{self.name}_config.json"
        )
        self.height = 20
        self.width = 200
        self.transparency = 1.0
        self.quit_after = 2  # seconds
        self.hide_timeout_id = None

        self.icons = self.load_icons()

        self.progress = 0.0
        self.status = "default"

        signal.signal(signal.SIGINT, self.cleanup)
        signal.signal(signal.SIGTERM, self.cleanup)

    def load_icons(self):
        try:
            with open(self.config_path, "r") as file:
                return json.load(file)
        except FileNotFoundError:
            print(f"Configuration file {self.config_path} not found.")
            return {}
        except json.JSONDecodeError:
            print(f"Error decoding JSON from {self.config_path}.")
            return {}

    def on_activate(self, app):
        self.window = Gtk.Window(application=app)
        self.window.set_default_size(self.width, self.height)
        self.window.set_opacity(self.transparency)

        LayerShell.init_for_window(self.window)
        LayerShell.set_layer(self.window, LayerShell.Layer.TOP)
        LayerShell.set_anchor(self.window, LayerShell.Edge.TOP, True)

        self.box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        self.emoji_label = Gtk.Label()
        self.box.append(self.emoji_label)

        self.progress_bar = Gtk.ProgressBar()
        self.progress_bar.set_hexpand(True)
        self.progress_bar.set_valign(Gtk.Align.CENTER)
        self.box.append(self.progress_bar)

        self.window.set_child(self.box)
        self.window.set_visible(False)

        # Start the socket server
        GLib.idle_add(self.start_socket_server)

    def start_socket_server(self):
        os.makedirs(self.socket_dir, exist_ok=True)

        if os.path.exists(self.socket_path):
            if self.is_socket_in_use(self.socket_path):
                logging.error(f"Server with name '{self.name}' is already running.")
                print(f"Server with name '{self.name}' is already running.")
                sys.exit(1)
            else:
                os.remove(self.socket_path)

        self.server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.server.bind(self.socket_path)
        self.server.listen(1)

        GLib.io_add_watch(self.server.fileno(), GLib.IO_IN, self.handle_connection)
        return False  # Stop the idle function from being called again

    def handle_connection(self, source, condition):
        conn, _ = self.server.accept()
        data = conn.recv(1024)
        if data:
            try:
                message = json.loads(data.decode("utf-8"))
                self.progress = message.get("progress", 0.0)
                self.status = message.get("status", "default")
                self.update_gui()
            except json.JSONDecodeError:
                pass
        conn.close()
        return True

    def update_gui(self):
        icon = self.get_icon_for_status()
        self.emoji_label.set_text(icon + " ")
        self.progress_bar.set_fraction(self.progress)

        self.window.set_visible(True)

        if self.hide_timeout_id:
            GLib.source_remove(self.hide_timeout_id)
        self.hide_timeout_id = GLib.timeout_add_seconds(
            self.quit_after, self.hide_window
        )

    def get_icon_for_status(self):
        if self.status in self.icons:
            icon_or_conditions = self.icons[self.status]
            if isinstance(icon_or_conditions, str):
                return icon_or_conditions
            elif isinstance(icon_or_conditions, list):
                for condition in icon_or_conditions:
                    if all(self.evaluate_condition(cond) for cond in condition[1:]):
                        return condition[0]
        return "?"

    def evaluate_condition(self, condition):
        if condition.startswith(">="):
            return self.progress >= float(condition[2:])
        elif condition.startswith(">"):
            return self.progress > float(condition[1:])
        elif condition.startswith("<="):
            return self.progress <= float(condition[2:])
        elif condition.startswith("<"):
            return self.progress < float(condition[1:])
        elif condition.startswith("=="):
            return self.progress == float(condition[2:])
        elif condition.startswith("!="):
            return self.progress != float(condition[2:])
        return False

    def hide_window(self):
        self.window.set_visible(False)
        self.hide_timeout_id = None
        return False  # Stop the timeout from being called again

    def cleanup(self, signum=None, frame=None):
        if os.path.exists(self.socket_path):
            os.remove(self.socket_path)
        sys.exit(0)

    def is_socket_in_use(self, socket_path):
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as test_sock:
                test_sock.connect(socket_path)
            return True
        except socket.error:
            return False


def setup_logging():
    log_dir = os.path.join(XDG_CACHE_HOME, "gtk_indicator")
    os.makedirs(log_dir, exist_ok=True)
    log_file = os.path.join(log_dir, "gtk_indicator.log")
    logging.basicConfig(
        filename=log_file,
        level=logging.ERROR,
        format="%(asctime)s - %(levelname)s - %(message)s",
    )


def main():
    setup_logging()
    parser = argparse.ArgumentParser(description="GtkIndicator Server")
    parser.add_argument(
        "--name", required=True, help="Name for the GtkIndicator server instance"
    )
    args = parser.parse_args()

    if not args.name.strip():
        print("Error: The --name argument cannot be empty.")
        sys.exit(1)

    app = Gtk.Application(
        application_id=f"com.github.hakan-demirli.gtk-indicator.{args.name}"
    )
    gtk_indicator = GtkIndicator(args.name)
    app.connect("activate", gtk_indicator.on_activate)
    app.run(None)


if __name__ == "__main__":
    main()
