#!/usr/bin/env python3

import argparse
import logging
import os
import socket
import time
import requests
from datetime import datetime, timezone
from time import sleep
from statistics import mean

from aw_client import ActivityWatchClient
from aw_core.log import setup_logging
from aw_core.models import Event
import tomllib  # Python 3.11+ for reading TOML files

# Default settings
default_settings = {
    "poll_time": 60,  # seconds
    "hosts": "google.com,cloudflare.com",
    "port": 80,
}

default_testing_settings = {
    "poll_time": 5,  # seconds
    "hosts": "localhost",
    "port": 8080,
}

# Paths for configuration files
XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "activitywatch", "aw-watcher-netstatus")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.toml")

# Logger setup
logger = logging.getLogger(__name__)


def load_or_create_config():
    """Load configuration from a file, or create a new file with default settings."""
    os.makedirs(CONFIG_DIR, exist_ok=True)

    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "rb") as f:
                config = tomllib.load(f)
            logger.info("Config loaded from file.")
        except Exception as e:
            logger.error(f"Failed to load config file: {e}")
            config = {}
    else:
        config = {}
        try:
            with open(CONFIG_FILE, "w") as f:
                # Manually write default settings to the file
                f.write("# Configuration for aw-watcher-netstatus\n")
                f.write("[default]\n")
                for key, value in default_settings.items():
                    f.write(f"{key} = {repr(value)}\n")
                f.write("\n[testing]\n")
                for key, value in default_testing_settings.items():
                    f.write(f"{key} = {repr(value)}\n")
            logger.info(f"Config file created at {CONFIG_FILE} with default settings.")
        except Exception as e:
            logger.error(f"Failed to create config file: {e}")

    # Merge defaults with loaded config
    final_config = {"default": default_settings, "testing": default_testing_settings}
    if config:
        final_config.update(config)
    return final_config


# Settings class
class Settings:
    def __init__(self, config_section):
        self.poll_time = config_section.get("poll_time", default_settings["poll_time"])
        self.hosts = config_section.get("hosts", default_settings["hosts"]).split(",")
        self.port = config_section.get("port", default_settings["port"])

        assert self.poll_time > 0, "Polling time must be greater than 0."
        assert self.hosts, "Configuration is missing valid `hosts`."
        assert self.port, "Configuration is missing a valid `port`."


# NetworkWatcher class
class NetworkWatcher:
    def __init__(self, config, testing=False):
        section = "testing" if testing else "default"
        self.settings = Settings(config[section])
        self.client = ActivityWatchClient("aw-watcher-netstatus", testing=testing)
        self.bucketname = f"{self.client.client_name}_{self.client.client_hostname}"

    def run(self):
        logger.info("aw-watcher-netstatus started")

        eventtype = "networkstatus"
        self.client.create_bucket(self.bucketname, eventtype, queued=True)

        with self.client:
            self.heartbeat_loop()

    def heartbeat_loop(self):
        while True:
            try:
                metrics = self.collect_metrics()
                logger.debug(f"Metrics: {metrics}")
                self.log_metrics(metrics)
                sleep(self.settings.poll_time)
            except KeyboardInterrupt:
                logger.info("aw-watcher-netstatus stopped by keyboard interrupt")
                break

    def log_metrics(self, metrics):
        data = {
            "status": metrics["status"],
            "latency": metrics["latency"],
            "packet_loss": metrics["packet_loss"],
            "public_ip": metrics["public_ip"],
            "dns_resolution_time": metrics["dns_resolution_time"],
        }
        e = Event(timestamp=datetime.now(timezone.utc), data=data)
        pulsetime = self.settings.poll_time + 30
        self.client.heartbeat(self.bucketname, e, pulsetime=pulsetime, queued=True)

    def collect_metrics(self):
        metrics = {
            "status": "offline",
            "latency": None,
            "packet_loss": None,
            "public_ip": None,
            "dns_resolution_time": None,
        }

        try:
            # Test connectivity and measure latency
            latencies = []
            for host in self.settings.hosts:
                start_time = time.time()
                try:
                    with socket.create_connection(
                        (host, self.settings.port), timeout=5
                    ):
                        latencies.append(time.time() - start_time)
                except socket.error:
                    pass

            if latencies:
                metrics["status"] = "online"
                metrics["latency"] = round(
                    mean(latencies) * 1000, 2
                )  # Average latency in ms

            # Estimate packet loss
            total_hosts = len(self.settings.hosts)
            successful_pings = len(latencies)
            metrics["packet_loss"] = round(
                (1 - successful_pings / total_hosts) * 100, 2
            )

            # Fetch public IP address
            try:
                response = requests.get("https://api.ipify.org", timeout=5)
                metrics["public_ip"] = response.text.strip()
            except requests.RequestException:
                metrics["public_ip"] = "N/A"

            # DNS resolution time
            try:
                start_time = time.time()
                socket.gethostbyname(self.settings.hosts[0])
                metrics["dns_resolution_time"] = round(
                    (time.time() - start_time) * 1000, 2
                )  # DNS resolution time in ms
            except socket.error:
                metrics["dns_resolution_time"] = None

        except Exception as e:
            logger.warning(f"Error collecting metrics: {e}")

        return metrics


# Main function
def main() -> None:
    parser = argparse.ArgumentParser(description="Monitor network availability.")
    parser.add_argument(
        "-v",
        "--verbose",
        dest="verbose",
        action="store_true",
        help="Run with verbose logging.",
    )
    parser.add_argument(
        "--testing", action="store_true", help="Run against test server."
    )
    args = parser.parse_args()

    setup_logging(
        "aw-watcher-netstatus",
        testing=args.testing,
        verbose=args.verbose,
        log_stderr=True,
        log_file=True,
    )

    config = load_or_create_config()
    watcher = NetworkWatcher(config=config, testing=args.testing)
    watcher.run()


if __name__ == "__main__":
    main()
