#!/usr/bin/env python3

import json
import logging
import os

from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS  # Import CORS

# Assumes your index.html is in the "static" folder.
app = Flask(__name__, static_folder="static")

# Enable CORS for all routes
CORS(app, resources={r"/*": {"origins": "http://127.0.0.1*"}})  # or "http://localhost*"

XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
APP_CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "quantifyself-webui")
APP_CONFIG_FILE = os.path.join(APP_CONFIG_DIR, "config.json")
WINDOW_CATEGORIES_FILE = os.path.join(APP_CONFIG_DIR, "window_categories.json")

# Default settings
default_settings = {
    "port": 8085,
    "host": "127.0.0.1",
}

# Logger setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)


def load_or_create_config():
    """Load configuration from a file, or create a new file with default settings."""
    os.makedirs(APP_CONFIG_DIR, exist_ok=True)

    if os.path.exists(APP_CONFIG_FILE):
        try:
            with open(APP_CONFIG_FILE, "r") as f:
                config = json.load(f)
            logger.info("Config loaded from file.")
        except Exception as e:
            logger.error(f"Failed to load config file: {e}")
            config = {}
    else:
        config = default_settings
        try:
            with open(APP_CONFIG_FILE, "w") as f:
                json.dump(default_settings, f, indent=4)
            logger.info(
                f"Config file created at {APP_CONFIG_FILE} with default settings."
            )
        except Exception as e:
            logger.error(f"Failed to create config file: {e}")

    return {**default_settings, **config}


@app.route("/")
def serve_index():
    """Serve the index.html file."""
    static_folder = app.static_folder or "./static"  # Default to "./static" if None
    return send_from_directory(static_folder, "index.html")


@app.route("/window_categories.json")
def serve_window_categories():
    """Serve the window_categories.json file."""
    try:
        if os.path.exists(WINDOW_CATEGORIES_FILE):
            with open(WINDOW_CATEGORIES_FILE, "r") as f:
                categories = json.load(f)
            return jsonify(categories)
        else:
            logger.error(f"File not found: {WINDOW_CATEGORIES_FILE}")
            return jsonify({"error": "window_categories.json not found"}), 404
    except Exception as e:
        logger.error(f"Error reading window_categories.json: {e}")
        return jsonify({"error": "Failed to read window_categories.json"}), 500


if __name__ == "__main__":
    # Load configuration
    config = load_or_create_config()
    port = int(config.get("port", default_settings["port"]))
    host = str(config.get("host", default_settings["host"]))

    # Start the server
    app.run(host=host, port=port)
