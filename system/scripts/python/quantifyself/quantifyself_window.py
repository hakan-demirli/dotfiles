#!/usr/bin/env python3
import json
import logging
import os
import subprocess
from datetime import datetime, timezone
from time import sleep

import requests

XDG_DATA_HOME = os.getenv("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
XDG_CACHE_HOME = os.getenv("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
LOG_FILE = os.path.join(XDG_CACHE_HOME, "quantifyself", "window.log")

QUANTIFYSELF_CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "quantifyself")
QUANTIFYSELF_CONFIG_FILE = os.path.join(QUANTIFYSELF_CONFIG_DIR, "config.json")

CONFIG_DIR = os.path.join(QUANTIFYSELF_CONFIG_DIR, "window")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.json")

default_settings = {
    "poll_time": 5,
    "database_path": os.path.join(XDG_DATA_HOME, "quantifyself/window/window.duckdb"),
    "filter": [
        {
            "class": "Tor Browser",
            "title": "*",
        },
        {
            "class": "firefox",
            "title": ".*Private Browsing.*",
        },
        {
            "class": "Opera",
            "title": "*",
        },
    ],
}

# Logger setup
logger = logging.getLogger(__name__)


def load_or_create_config():
    os.makedirs(CONFIG_DIR, exist_ok=True)

    def load_config_file(path):
        if os.path.exists(path):
            try:
                with open(path, "r") as f:
                    logger.info(f"Config file loaded from {f}.")
                    return json.load(f)
            except Exception as e:
                logger.error(f"Failed to load config file {path}: {e}")
        raise FileNotFoundError(f"No configuration files found at {path}")

    if not os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "w") as f:
                json.dump(default_settings, f, indent=4)
            logger.info(f"Config file created at {CONFIG_FILE} with default settings.")
        except Exception as e:
            logger.error(f"Failed to create config file: {e}")

    if not os.path.exists(QUANTIFYSELF_CONFIG_FILE):
        raise FileNotFoundError("No configuration files found.")

    window_config = load_config_file(CONFIG_FILE)
    root_config = load_config_file(QUANTIFYSELF_CONFIG_FILE)

    return {**root_config, **window_config}


class WindowWatcher:
    def __init__(self, config: dict):
        self.port = int(config.get("port", None))
        self.host = str(config.get("host", None))
        self.poll_time = int(config.get("poll_time", None))
        self.filter = list(config.get("filter", None))
        self.database_path = config.get("database_path", None)

        if self.host is None:
            raise TypeError("host is None")
        if self.port is None:
            raise TypeError("port is None")
        if self.poll_time is None:
            raise TypeError("poll_time is None")
        if self.database_path is None:
            raise TypeError("database_path is None")
        if self.filter is None:
            raise TypeError("filter is None")
        self.setup_database()

    def run(self):
        logger.info("window_watcher started")
        self.heartbeat_loop()

    def heartbeat_loop(self):
        while True:
            try:
                window_info = self.get_window_info()
                logger.debug(f"Window Info: {window_info}")
                self.log_event(window_info)
                sleep(self.poll_time)
            except KeyboardInterrupt:
                logger.info("window_watcher stopped by keyboard interrupt")
                break

    def log_event(self, data: list):
        try:
            for client in data:
                timestamp = datetime.now(timezone.utc).isoformat()
                query = """
                    INSERT INTO window_metrics (
                        timestamp, client_class, client_title
                    ) VALUES (?, ?, ?)
                """
                params = [
                    timestamp,
                    client["client_class"],
                    client["client_title"],
                ]
                response = requests.post(
                    f"http://{self.host}:{self.port}/execute",
                    json={
                        "db_file": self.database_path,
                        "query": query,
                        "params": params,
                    },
                )

                if response.status_code == 200:
                    logger.info("Metrics logged successfully.")
                else:
                    logger.error(
                        f"Failed to log metrics: {response.status_code} {response.text}"
                    )

        except Exception as e:
            logger.error(f"Error making API call: {e}")

    def get_window_info(self) -> list:
        try:
            result = subprocess.run(
                ["hyprctl", "clients", "-j"], capture_output=True, text=True, check=True
            )
            clients = json.loads(result.stdout)
            window_info = []

            for client in clients:
                client_class = client.get("class", "unknown")
                client_title = client.get("title", "unknown")

                # Check if the client matches any filter
                filtered = any(
                    (f["class"] == "*" or f["class"] == client_class)
                    and (f["title"] == "*" or f["title"] == client_title)
                    for f in self.filter
                )

                if filtered:
                    window_info.append(
                        {"client_class": "filtered", "client_title": "filtered"}
                    )
                else:
                    window_info.append(
                        {"client_class": client_class, "client_title": client_title}
                    )

            return window_info
        except subprocess.CalledProcessError as e:
            logger.error(f"Error running hyprctl: {e}")
        except json.JSONDecodeError as e:
            logger.error(f"Error decoding JSON: {e}")
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
        return []

    def setup_database(self):
        try:
            commands = [
                """
                CREATE TABLE IF NOT EXISTS window_metrics (
                    timestamp TIMESTAMP PRIMARY KEY,
                    client_class TEXT,
                    client_title TEXT
                )
                """,
            ]

            for query in commands:
                response = requests.post(
                    f"http://{self.host}:{self.port}/execute",
                    json={
                        "db_file": self.database_path,
                        "query": query,
                    },
                )
                if response.status_code != 200:
                    logger.error(
                        f"Failed to execute setup query: {query}. Error: {response.text}"
                    )
                    raise Exception(response.text)
            logger.info("Database setup completed via API.")
        except Exception as e:
            logger.error(f"Error setting up database: {e}")


def main() -> None:
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
        handlers=[
            logging.FileHandler(LOG_FILE),
            logging.StreamHandler(),
        ],
    )

    config = load_or_create_config()

    watcher = WindowWatcher(config)

    try:
        watcher.run()
    except Exception as e:
        logger.error(f"Unhandled exception: {e}")


if __name__ == "__main__":
    main()
