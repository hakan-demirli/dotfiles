#!/usr/bin/env python3
import json
import logging
import os
import signal
import sys
import threading

import duckdb
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__)

# Define paths for configuration
XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
QUANTIFYSELF_CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "quantifyself")
QUANTIFYSELF_CONFIG_FILE = os.path.join(QUANTIFYSELF_CONFIG_DIR, "config.json")

XDG_CACHE_HOME = os.getenv("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
LOG_FILE = os.path.join(XDG_CACHE_HOME, "quantifyself", "server.log")

# Default settings
default_settings = {
    "port": 8080,
    "host": "127.0.0.1",
}

# Logger setup
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(),  # Retain console logging
    ],
)

logger = logging.getLogger(__name__)

# Database connections dictionary and a lock for thread safety
db_connections = {}
db_lock = threading.Lock()


def load_or_create_config():
    """Load configuration from a file, or create a new file with default settings."""
    os.makedirs(QUANTIFYSELF_CONFIG_DIR, exist_ok=True)

    if os.path.exists(QUANTIFYSELF_CONFIG_FILE):
        try:
            with open(QUANTIFYSELF_CONFIG_FILE, "r") as f:
                config = json.load(f)
            logger.info("Config loaded from file.")
        except Exception as e:
            logger.error(f"Failed to load config file: {e}")
            config = {}
    else:
        config = default_settings
        try:
            with open(QUANTIFYSELF_CONFIG_FILE, "w") as f:
                json.dump(default_settings, f, indent=4)
            logger.info(
                f"Config file created at {QUANTIFYSELF_CONFIG_FILE} with default settings."
            )
        except Exception as e:
            logger.error(f"Failed to create config file: {e}")

    # Merge defaults with loaded config
    return {**default_settings, **config}


def get_connection(db_file):
    """Get or create a DuckDB connection for the specified database file."""
    with db_lock:
        if db_file not in db_connections:
            # Ensure intermediate directories are created
            db_dir = os.path.dirname(db_file)
            if db_dir:  # Avoid issues if db_file is in the current directory
                os.makedirs(db_dir, exist_ok=True)

            logger.info(f"Opening new connection for database file: {db_file}")
            db_connections[db_file] = duckdb.connect(db_file, read_only=False)
        return db_connections[db_file]


@app.route("/execute", methods=["POST"])
def execute_query():
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No input provided"}), 400

        db_file = data.get("db_file")
        if not db_file:
            return jsonify({"error": "Database file is missing"}), 400

        query = data.get("query")
        params = data.get("params", [])

        if not query:
            return jsonify({"error": "Query is missing"}), 400

        conn = get_connection(db_file)

        # Serialize all queries on this connection
        with db_lock:
            if params:
                result = conn.execute(query, params).fetchall()
            else:
                result = conn.execute(query).fetchall()

        return jsonify({"status": "success", "result": result})
    except Exception as e:
        logger.error(f"Error executing query: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/")
def serve_index():
    """Serve the index.html file."""
    return send_from_directory(app.static_folder or "static", "index.html")


def shutdown_handler(signum, frame):
    """Handles graceful shutdown on receiving termination signals."""
    logger.info(f"Signal {signum} received. Gracefully shutting down.")
    try:
        with db_lock:
            for db_file, conn in db_connections.items():
                try:
                    logger.info(f"Executing database CHECKPOINT for {db_file}...")
                    conn.execute("CHECKPOINT;")
                    logger.info(f"Database CHECKPOINT completed for {db_file}.")
                    conn.close()
                    logger.info(f"Database connection closed for {db_file}.")
                except Exception as e:
                    logger.error(f"Error during shutdown for {db_file}: {e}")
    finally:
        sys.exit(0)


if __name__ == "__main__":
    # Register shutdown handlers for various signals
    for sig in [
        signal.SIGINT,
        signal.SIGTERM,
        signal.SIGHUP,
        signal.SIGQUIT,
        signal.SIGABRT,
        signal.SIGUSR1,
        signal.SIGUSR2,
        signal.SIGPIPE,
    ]:
        signal.signal(sig, shutdown_handler)

    config = load_or_create_config()
    port = int(config.get("port", default_settings["port"]))
    host = str(config.get("host", default_settings["host"]))

    app.run(host=host, port=port)
