#!/usr/bin/env python3

import argparse
import logging
import os
import tomllib
from datetime import datetime, timezone
from time import sleep
import platform
import psutil

from aw_client import ActivityWatchClient
from aw_core.log import setup_logging
from aw_core.models import Event

# Default settings
default_settings = {
    "poll_time": 60,  # seconds
}

# Paths
XDG_CONFIG_HOME = os.getenv("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))
CONFIG_DIR = os.path.join(XDG_CONFIG_HOME, "activitywatch", "aw-watcher-system")
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
                # Write the default settings manually
                f.write("# Configuration for aw-watcher-system\n")
                for key, value in default_settings.items():
                    f.write(f"{key} = {value}\n")
            logger.info(f"Config file created at {CONFIG_FILE} with default settings.")
        except Exception as e:
            logger.error(f"Failed to create config file: {e}")

    # Merge defaults with loaded config
    final_config = {**default_settings, **config}
    return final_config


# SystemWatcher class
class SystemWatcher:
    def __init__(self, poll_time: int):
        self.poll_time = poll_time
        self.client = ActivityWatchClient("aw-watcher-system", testing=False)
        self.bucketname = f"{self.client.client_name}_{self.client.client_hostname}"

    def run(self):
        logger.info("aw-watcher-system started")

        eventtype = "systeminfo"
        self.client.create_bucket(self.bucketname, eventtype, queued=True)

        with self.client:
            self.heartbeat_loop()

    def heartbeat_loop(self):
        while True:
            try:
                system_info = self.get_system_info()
                logger.debug(f"System Info: {system_info}")
                self.log_event(system_info)
                sleep(self.poll_time)
            except KeyboardInterrupt:
                logger.info("aw-watcher-system stopped by keyboard interrupt")
                break

    def log_event(self, data: dict):
        e = Event(timestamp=datetime.now(timezone.utc), data=data)
        pulsetime = self.poll_time + 30
        self.client.heartbeat(self.bucketname, e, pulsetime=pulsetime, queued=True)

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


# Main function
def main() -> None:
    parser = argparse.ArgumentParser(description="Monitor system information.")
    parser.add_argument(
        "-v",
        "--verbose",
        dest="verbose",
        action="store_true",
        help="Run with verbose logging.",
    )
    args = parser.parse_args()

    setup_logging(
        "aw-watcher-system",
        testing=False,
        verbose=args.verbose,
        log_stderr=True,
        log_file=True,
    )

    config = load_or_create_config()
    poll_time = int(config.get("poll_time", default_settings["poll_time"]))

    watcher = SystemWatcher(poll_time=poll_time)
    watcher.run()


if __name__ == "__main__":
    main()
