#!/usr/bin/env python3

import signal

import eventlet

eventlet.monkey_patch()
import hashlib
import os
import threading

from flask import Flask, request, send_file, send_from_directory
from flask_socketio import SocketIO

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

HTML_DIR = ""
HTML_FILE = f"{HTML_DIR}/index.html"
last_modified_time = None
last_file_hash = None
shutdown_flag = threading.Event()

ADDITIONAL_LIB_DIR = os.path.expanduser("~/Desktop/notes/lib")
print(f"Additional lib dirs: {ADDITIONAL_LIB_DIR}")


def get_file_hash(filename):
    """Calculate a hash of the file to detect changes."""
    hasher = hashlib.md5()
    with open(filename, "rb") as afile:
        buf = afile.read()
        hasher.update(buf)
    return hasher.hexdigest()


def reload_html():
    """Read the index.html file and send the content to clients if it changed."""
    global last_modified_time, last_file_hash

    try:
        current_modified_time = os.path.getmtime(HTML_FILE)
        current_file_hash = get_file_hash(HTML_FILE)

        if (
            last_modified_time is None
            or last_file_hash is None
            or current_modified_time > last_modified_time
            or current_file_hash != last_file_hash
        ):
            print("HTML file changed, reloading...")
            with open(HTML_FILE, "r") as f:
                html_content = f.read()
            socketio.emit("html_reload", {"html": html_content})
            last_modified_time = current_modified_time
            last_file_hash = current_file_hash

    except FileNotFoundError:
        print(f"Error: {HTML_FILE} not found")
    except Exception as e:
        print(f"Error reloading HTML: {e}")


def background_file_monitor():
    """Background thread that checks if the HTML file was changed."""
    print("Starting background file monitor")
    while not shutdown_flag.is_set():
        reload_html()
        socketio.sleep(1)  # use socketio.sleep rather than time.sleep for concurrency
    print("Shutting down file monitor")


@app.route("/")
def index():
    print("Index route accessed")
    with open(HTML_FILE, "r") as f:
        html_content = f.read()
    return html_content


@app.route("/<path:filepath>")
def serve_any_file(filepath):
    print(f"Raw Requested path: {request.path.lstrip('/')}")
    print(f"Full Request URL: {request.url}")
    print(f"Request made from: {request.referrer}")

    # First, try to serve the file from HTML_DIR
    html_dir_path = os.path.join(HTML_DIR, filepath)
    if os.path.exists(html_dir_path) and os.path.isfile(html_dir_path):
        print(f"Serving file from HTML_DIR: {html_dir_path}")
        return send_from_directory(HTML_DIR, filepath)

    # Next, try to serve the file from ADDITIONAL_LIB_DIR
    additional_path = os.path.join(ADDITIONAL_LIB_DIR, filepath)
    if os.path.exists(additional_path) and os.path.isfile(additional_path):
        print(f"Serving file from ADDITIONAL_LIB_DIR: {additional_path}")
        return send_file(additional_path)

    # If not found, return a 404 error
    print(f"File not found in both HTML_DIR and ADDITIONAL_LIB_DIR: {filepath}")
    return "File not found", 404


@app.route("/update-path", methods=["POST"])
def update_path():
    global HTML_FILE, HTML_DIR, last_modified_time, last_file_hash

    # Ensure the request has a valid JSON body
    if not request.is_json:
        return {"status": "error", "message": "Request body must be JSON"}, 400

    data = request.json
    if not data or "path" not in data:
        return {"status": "error", "message": "Missing 'path' in request body"}, 400

    new_path = data["path"]
    if os.path.exists(new_path) and new_path.endswith(".html"):
        HTML_FILE = new_path
        HTML_DIR = os.path.dirname(
            new_path
        )  # Update the directory based on the new path
        last_modified_time = None
        last_file_hash = None
        print(f"Updated HTML file path to: {HTML_FILE}")
        print(f"Updated HTML directory to: {HTML_DIR}")
        return {"status": "success", "message": "HTML path and directory updated"}, 200
    else:
        return {"status": "error", "message": "Invalid file path"}, 400


@socketio.on("connect")
def handle_connect():
    print(f"Client connected: {request.sid}")
    reload_html()


@socketio.on("disconnect")
def handle_disconnect():
    print(f"Client disconnected: {request.sid}")


def shutdown_handler(sig, frame):
    """Handle shutdown signals."""
    print(f"Received signal {sig}, shutting down gracefully...")
    shutdown_flag.set()  # Signal the background thread to stop
    socketio.stop()  # Stop the Flask-SocketIO server


if __name__ == "__main__":
    # Register signal handlers for multiple signals
    for sig in [
        signal.SIGINT,
        signal.SIGTERM,
        signal.SIGHUP,
        signal.SIGQUIT,
        signal.SIGABRT,
        signal.SIGUSR1,
        signal.SIGUSR2,
    ]:
        signal.signal(sig, shutdown_handler)

    monitor_thread = threading.Thread(target=background_file_monitor)
    monitor_thread.daemon = True
    monitor_thread.start()

    socketio.run(app, debug=False, host="127.0.0.1", port=5000)
