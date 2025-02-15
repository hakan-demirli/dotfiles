#!/usr/bin/env python3

import socket
import json
import argparse
import os
import sys


def get_xdg_path(env_var, default_path):
    return os.getenv(env_var, os.path.expanduser(default_path))


XDG_RUNTIME_DIR = get_xdg_path("XDG_RUNTIME_DIR", "/tmp")


def send_data(progress, status, name):
    data = {"progress": progress, "status": status}
    socket_dir = os.path.join(XDG_RUNTIME_DIR, "gtk_indicator")
    socket_path = os.path.join(socket_dir, f"{name}.sock")

    # Serialize the data to a JSON formatted str
    message = json.dumps(data)

    # Create a Unix socket
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        try:
            # Connect to the server
            client.connect(socket_path)
            # Send the JSON data
            client.sendall(message.encode("utf-8"))
        except FileNotFoundError:
            print(
                f"Socket file {socket_path} not found. Make sure the server is running."
            )
        except Exception as e:
            print(f"An error occurred: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Set progress bar value.")
    parser.add_argument(
        "--progress",
        type=float,
        required=True,
        help="A float between 0 and 1 indicating how full the bar is.",
    )
    parser.add_argument(
        "--status",
        type=str,
        required=True,
        help="The status of the audio output device.",
    )
    parser.add_argument(
        "--name",
        type=str,
        required=True,
        help="Name for the GtkIndicator server instance.",
    )
    args = parser.parse_args()

    if not args.name.strip():
        print("Error: The --name argument cannot be empty.")
        sys.exit(1)

    progress = args.progress
    status = args.status
    name = args.name

    send_data(progress, status, name)
