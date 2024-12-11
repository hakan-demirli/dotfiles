#!/usr/bin/env python3
import logging
import os
import platform
from datetime import datetime, timezone
from time import sleep

import psutil
import requests
import tomllib

XDG_DATA_HOME = os.getenv("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))

XDG_CACHE_HOME = os.getenv("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
LOG_FILE = os.path.join(XDG_CACHE_HOME, "quantifyself", "system.log")

QUANTIFYSELF_CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "quantifyself")
QUANTIFYSELF_CONFIG_FILE = os.path.join(QUANTIFYSELF_CONFIG_DIR, "config.toml")

CONFIG_DIR = os.path.join(QUANTIFYSELF_CONFIG_DIR, "system")
CONFIG_FILE = os.path.join(CONFIG_DIR, "config.toml")

default_settings = {
    "poll_time": 20,
    "database_path": os.path.join(XDG_DATA_HOME, "quantifyself/system/system.duckdb"),
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
                f.write("# Configuration for system_watcher\n")
                for key, value in default_settings.items():
                    f.write(f"{key} = {repr(value)}\n")
            logger.info(f"Config file created at {CONFIG_FILE} with default settings.")
        except Exception as e:
            logger.error(f"Failed to create config file: {e}")

    # If root config file does not exist throw error
    if not os.path.exists(QUANTIFYSELF_CONFIG_FILE):
        raise FileNotFoundError("No configuration files found.")

    # Load configurations from both files
    system_config = load_config_file(CONFIG_FILE)
    root_config = load_config_file(QUANTIFYSELF_CONFIG_FILE)

    # Merge configs: prioritize system_config > root_config
    merged_config = {**root_config, **system_config}

    return merged_config


class SystemWatcher:
    def __init__(self, config: dict):
        self.port = int(config.get("port", None))
        self.host = str(config.get("host", None))
        self.poll_time = int(config.get("poll_time", None))
        self.poll_time = int(config.get("poll_time", None))
        self.database_path = config.get("database_path", None)

        if self.host is None:
            raise TypeError("host is None")
        if self.port is None:
            raise TypeError("port is None")
        if self.poll_time is None:
            raise TypeError("poll_time is None")
        if self.database_path is None:
            raise TypeError("database_path is None")
        self.setup_database()

    def run(self):
        logger.info("system_watcher started")
        self.heartbeat_loop()

    def heartbeat_loop(self):
        while True:
            try:
                system_info = self.get_system_info()
                logger.debug(f"System Info: {system_info}")
                self.log_event(system_info)
                sleep(self.poll_time)
            except KeyboardInterrupt:
                logger.info("system_watcher stopped by keyboard interrupt")
                break

    def log_event(self, data: dict):
        """Logs system metrics and disk metrics by calling the Flask API."""
        try:
            timestamp = datetime.now(timezone.utc).isoformat()
            response = requests.post(
                f"http://{self.host}:{self.port}/execute",
                json={
                    "db_file": self.database_path,
                    "query": """
                        INSERT INTO system_metrics (
                            timestamp, cpu_usage_percent, ram_total, ram_used, ram_free,
                            ram_available, swap_total, swap_used, swap_free, battery_percent,
                            battery_time_left, battery_plugged, uptime_seconds, kernel_version,
                            process_count, top_ram_process, gpu_temperature, cpu_temperature
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    "params": [
                        timestamp,
                        data.get("cpu_usage_percent"),
                        data.get("ram_total"),
                        data.get("ram_used"),
                        data.get("ram_free"),
                        data.get("ram_available"),
                        data.get("swap_total"),
                        data.get("swap_used"),
                        data.get("swap_free"),
                        data.get("battery_percent"),
                        data.get("battery_time_left"),
                        data.get("battery_plugged"),
                        data.get("uptime_seconds"),
                        data.get("kernel_version"),
                        data.get("process_count"),
                        data.get("top_ram_process"),
                        data.get("gpu_temperature"),
                        data.get("cpu_temperature"),
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

    def get_system_info(self) -> dict:
        """Collects all the required system information."""
        info = {}

        # CPU usage
        info["cpu_usage_percent"] = psutil.cpu_percent(interval=None)

        # Memory usage
        memory = psutil.virtual_memory()
        info["ram_total"] = memory.total
        info["ram_used"] = memory.used
        info["ram_free"] = memory.free
        info["ram_available"] = memory.available

        # Swap memory usage
        swap = psutil.swap_memory()
        info["swap_total"] = swap.total
        info["swap_used"] = swap.used
        info["swap_free"] = swap.free

        # Disk usage per partition
        info["disk_usage"] = {
            part.mountpoint: {
                "total": usage.total,
                "used": usage.used,
                "free": usage.free,
            }
            for part in psutil.disk_partitions()
            if (usage := psutil.disk_usage(part.mountpoint))
        }

        # Battery status
        battery = psutil.sensors_battery()
        if battery:
            info["battery_percent"] = battery.percent
            info["battery_time_left"] = battery.secsleft
            info["battery_plugged"] = battery.power_plugged

        # Uptime
        info["uptime_seconds"] = int(psutil.boot_time())

        # Kernel version
        info["kernel_version"] = platform.release()

        # Number of processes
        info["process_count"] = len(psutil.pids())

        # Process using the most RAM
        try:
            top_process = max(
                psutil.process_iter(attrs=["pid", "name", "memory_info"]),
                key=lambda p: p.info["memory_info"].rss,
            )
            info["top_ram_process"] = {
                "pid": top_process.info["pid"],
                "name": top_process.info["name"],
                "memory_used": top_process.info["memory_info"].rss,
            }
        except Exception as e:
            logger.warning(f"Could not determine top RAM process: {e}")

        # GPU usage (requires nvidia-smi via psutil.sensors_temperatures)
        gpu_temps = psutil.sensors_temperatures().get("nvidia", [])
        if gpu_temps:
            info["gpu_temperature"] = gpu_temps[0].current

        # CPU temperatures
        cpu_temps = psutil.sensors_temperatures().get("coretemp", [])
        if cpu_temps:
            info["cpu_temperature"] = cpu_temps[0].current

        return info

    def setup_database(self):
        """Set up the DuckDB database and create the metrics tables via the API."""
        try:
            # Check if the database file exists and create tables if necessary
            commands = [
                """
                CREATE TABLE IF NOT EXISTS system_metrics (
                    timestamp TIMESTAMP PRIMARY KEY,
                    cpu_usage_percent DOUBLE,
                    ram_total BIGINT,
                    ram_used BIGINT,
                    ram_free BIGINT,
                    ram_available BIGINT,
                    swap_total BIGINT,
                    swap_used BIGINT,
                    swap_free BIGINT,
                    battery_percent DOUBLE,
                    battery_time_left BIGINT,
                    battery_plugged BOOLEAN,
                    uptime_seconds BIGINT,
                    kernel_version TEXT,
                    process_count INT,
                    top_ram_process JSON,
                    gpu_temperature DOUBLE,
                    cpu_temperature DOUBLE
                )
                """,
                """
                CREATE TABLE IF NOT EXISTS disk_metrics (
                    timestamp TIMESTAMP REFERENCES system_metrics(timestamp),
                    mountpoint TEXT,
                    total BIGINT,
                    used BIGINT,
                    free BIGINT
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
            logging.StreamHandler(),  # Retain console logging
        ],
    )

    config = load_or_create_config()

    watcher = SystemWatcher(config)

    try:
        watcher.run()
    except Exception as e:
        logger.error(f"Unhandled exception: {e}")


if __name__ == "__main__":
    main()
