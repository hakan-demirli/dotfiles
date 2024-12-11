#!/usr/bin/env python3

import logging
import os
import socket
import time
from datetime import datetime, timezone
from statistics import mean
from time import sleep

import psutil
import requests
import tomllib  # Python 3.11+ for reading TOML files

XDG_DATA_HOME = os.getenv("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))

XDG_CACHE_HOME = os.getenv("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
LOG_FILE = os.path.join(XDG_CACHE_HOME, "quantifyself", "netstatus.log")

QUANTIFYSELF_CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "quantifyself")
QUANTIFYSELF_CONFIG_FILE = os.path.join(QUANTIFYSELF_CONFIG_DIR, "config.toml")

CONFIG_DIR = os.path.join(QUANTIFYSELF_CONFIG_DIR, "netstatus")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.toml")

default_settings = {
    "poll_time": 1,  # seconds
    "poll_host": "cloudflare.com",
    "database_path": os.path.join(
        XDG_DATA_HOME, "quantifyself", "netstatus", "netstatus.duckdb"
    ),
}
# Logger setup
logger = logging.getLogger(__name__)


def load_or_create_config():
    """Load configuration from files, or create new files with default settings."""
    os.makedirs(CONFIG_DIR, exist_ok=True)

    # Helper to load a config file
    def load_config_file(path):
        if os.path.exists(path):
            try:
                with open(path, "rb") as f:
                    logger.info(f"Config file loaded from {f} .")
                    return tomllib.load(f)

            except Exception as e:
                logger.error(f"Failed to load config file {path}: {e}")
        raise FileNotFoundError(f"No configuration files found at {path}")

    if not os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "w") as f:
                f.write("# Configuration for network_watcher\n")
                for key, value in default_settings.items():
                    f.write(f"{key} = {repr(value)}\n")
            logger.info(f"Config file created at {CONFIG_FILE} with default settings.")
        except Exception as e:
            logger.error(f"Failed to create config file: {e}")

    # If root config file does not exist throw error
    if not os.path.exists(QUANTIFYSELF_CONFIG_FILE):
        raise FileNotFoundError("No configuration files found..")

    # Load configurations from both files
    netstatus_config = load_config_file(CONFIG_FILE)
    root_config = load_config_file(QUANTIFYSELF_CONFIG_FILE)

    # Merge configs: prioritize netstatus_config > root_config
    merged_config = {**root_config, **netstatus_config}

    return merged_config


def get_connection_info():
    """Get connection type (WiFi/Ethernet) and network name."""
    connection_type = 0  # Default to Ethernet
    network_name = "Unknown"

    addrs = psutil.net_if_addrs()
    for interface, addr_info in addrs.items():
        for addr in addr_info:
            if addr.family == socket.AF_INET:
                if "Wi-Fi" in interface or "wlan" in interface.lower():
                    connection_type = 1
                network_name = interface
                break
    return connection_type, network_name


# NetworkWatcher class
class NetworkWatcher:
    def __init__(self, config: dict):
        self.port = int(config.get("port", None))
        self.host = str(config.get("host", None))
        self.poll_time = int(config.get("poll_time", None))
        self.poll_host = config.get("poll_host", None)
        self.database_path = config.get("database_path", None)

        if self.host is None:
            raise TypeError("host is None")
        if self.port is None:
            raise TypeError("port is None")
        if self.poll_host is None:
            raise TypeError("hosts is None")
        if self.poll_time is None:
            raise TypeError("poll_time is None")
        if self.database_path is None:
            raise TypeError("database_path is None")
        self.setup_database()

    def run(self):
        logger.info("network_watcher started")
        self.heartbeat_loop()

    def heartbeat_loop(self):
        logger.info("Entering heartbeat loop...")
        while True:
            try:
                metrics = self.collect_metrics()
                logger.debug(f"Metrics: {metrics}")
                self.log_event(metrics)
                sleep(self.poll_time)
            except KeyboardInterrupt:
                logger.info("network_watcher stopped by keyboard interrupt")
                break

    def log_event(self, data: dict):
        """Logs network metrics and disk metrics by calling the Flask API."""
        try:
            timestamp = datetime.now(timezone.utc).isoformat()
            response = requests.post(
                f"http://{self.host}:{self.port}/execute",
                json={
                    "db_file": self.database_path,
                    "query": """
                        INSERT INTO network_metrics (timestamp, status, latency, packet_loss, public_ip, dns_resolution_time, connection_type, network_name)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    "params": [
                        timestamp,
                        data.get("status"),
                        data.get("latency"),
                        data.get("packet_loss"),
                        data.get("public_ip"),
                        data.get("dns_resolution_time"),
                        data.get("connection_type"),
                        data.get("network_name"),
                    ],
                },
            )

            # Check the response status
            if response.status_code == 200:
                logger.info("Metrics logged successfully.")
            else:
                logger.error(
                    f"Failed to log metrics: {response.status_code} {response.text}"
                )
        except Exception as e:
            logger.error(f"Error making API call: {e}")

    def collect_metrics(self):
        logger.debug("Collecting Metrics")
        metrics = {
            "status": False,
            "latency": None,
            "packet_loss": None,
            "public_ip": None,
            "dns_resolution_time": None,
            "connection_type": None,
            "network_name": None,
        }

        try:
            # Test connectivity and measure latency
            latencies = []
            start_time = time.time()
            try:
                # WARNING: 80 hard coded port?
                with socket.create_connection((self.poll_host, 80), timeout=5):
                    latencies.append(time.time() - start_time)
            except socket.error:
                pass

            if latencies:
                metrics["status"] = True
                metrics["latency"] = round(
                    mean(latencies) * 1000, 2
                )  # Average latency in ms

            # Estimate packet loss
            successful_pings = len(latencies)
            metrics["packet_loss"] = round((1 - successful_pings) * 100, 2)

            # Fetch public IP address
            try:
                response = requests.get("https://api.ipify.org", timeout=5)
                metrics["public_ip"] = response.text.strip()
            except requests.RequestException:
                metrics["public_ip"] = "N/A"

            # DNS resolution time
            try:
                start_time = time.time()
                socket.gethostbyname(self.poll_host)
                metrics["dns_resolution_time"] = round(
                    (time.time() - start_time) * 1000, 2
                )  # DNS resolution time in ms
            except socket.error:
                metrics["dns_resolution_time"] = None

            # Connection type and network name
            try:
                metrics["connection_type"], metrics["network_name"] = (
                    get_connection_info()
                )
                logger.debug(
                    f"Connection Info: Type={metrics['connection_type']}, Name={metrics['network_name']}"
                )
            except Exception as e:
                logger.warning(f"Error retrieving connection info: {e}")

        except Exception as e:
            logger.warning(f"Error collecting metrics: {e}")

        # logger.info(f"Metrics before returning: {metrics}")
        return metrics

    def setup_database(self):
        """Set up the DuckDB database and create the metrics tables via the API."""
        try:
            commands = [
                """
                    CREATE TABLE IF NOT EXISTS network_metrics (
                        timestamp TIMESTAMP,
                        status BOOLEAN,
                        latency FLOAT,
                        packet_loss FLOAT,
                        public_ip VARCHAR(45),
                        dns_resolution_time FLOAT,
                        connection_type BOOLEAN,
                        network_name VARCHAR
                    )
                    """,
                """
                    PRAGMA enable_checkpoint_on_shutdown
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
            logging.StreamHandler(),  # Retain console logging
        ],
    )

    config = load_or_create_config()

    watcher = NetworkWatcher(config)

    try:
        watcher.run()
    except Exception as e:
        logger.error(f"Unhandled exception: {e}")


if __name__ == "__main__":
    main()
