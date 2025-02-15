#!/usr/bin/env python3

import os
import platform
import time

import psutil
from prometheus_client import Gauge, start_http_server

# Define Prometheus metrics
cpu_usage_gauge = Gauge("cpu_usage_percent", "CPU usage percentage")
ram_total_gauge = Gauge("ram_total_bytes", "Total RAM in bytes")
ram_used_gauge = Gauge("ram_used_bytes", "Used RAM in bytes")
ram_free_gauge = Gauge("ram_free_bytes", "Free RAM in bytes")
ram_available_gauge = Gauge("ram_available_bytes", "Available RAM in bytes")
swap_total_gauge = Gauge("swap_total_bytes", "Total swap memory in bytes")
swap_used_gauge = Gauge("swap_used_bytes", "Used swap memory in bytes")
swap_free_gauge = Gauge("swap_free_bytes", "Free swap memory in bytes")
disk_usage_gauge = Gauge(
    "disk_usage_bytes", "Disk usage in bytes", ["mountpoint", "type"]
)
battery_percent_gauge = Gauge("battery_percent", "Battery percentage")
battery_time_left_gauge = Gauge(
    "battery_time_left_seconds", "Battery time left in seconds"
)
battery_plugged_gauge = Gauge("battery_plugged", "Battery charging status")
uptime_gauge = Gauge("uptime_seconds", "System uptime in seconds")
kernel_version_gauge = Gauge("kernel_version", "Kernel version", ["version"])
process_count_gauge = Gauge("process_count", "Number of processes running")
top_ram_process_gauge = Gauge(
    "top_ram_process_memory_bytes",
    "Memory used by the top RAM-consuming process",
    ["pid", "name"],
)
cpu_temperature_gauge = Gauge("cpu_temperature_celsius", "CPU temperature in Celsius")
gpu_temperature_gauge = Gauge("gpu_temperature_celsius", "GPU temperature in Celsius")


def collect_metrics():
    while True:
        try:
            # CPU usage
            cpu_usage_gauge.set(psutil.cpu_percent(interval=None))

            # Memory usage
            memory = psutil.virtual_memory()
            ram_total_gauge.set(memory.total)
            ram_used_gauge.set(memory.used)
            ram_free_gauge.set(memory.free)
            ram_available_gauge.set(memory.available)

            # Swap memory usage
            swap = psutil.swap_memory()
            swap_total_gauge.set(swap.total)
            swap_used_gauge.set(swap.used)
            swap_free_gauge.set(swap.free)

            # Disk usage per partition
            for part in psutil.disk_partitions():
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                    disk_usage_gauge.labels(
                        mountpoint=part.mountpoint, type="total"
                    ).set(usage.total)
                    disk_usage_gauge.labels(
                        mountpoint=part.mountpoint, type="used"
                    ).set(usage.used)
                    disk_usage_gauge.labels(
                        mountpoint=part.mountpoint, type="free"
                    ).set(usage.free)
                except Exception:
                    continue

            # Battery status
            battery = psutil.sensors_battery()
            if battery:
                battery_percent_gauge.set(battery.percent)
                battery_time_left_gauge.set(battery.secsleft)
                battery_plugged_gauge.set(1 if battery.power_plugged else 0)

            # Uptime
            uptime_seconds = int(time.time() - psutil.boot_time())
            uptime_gauge.set(uptime_seconds)

            # Kernel version
            kernel_version_gauge.labels(version=platform.release()).set(1)

            # Number of processes
            process_count_gauge.set(len(psutil.pids()))

            # Process using the most RAM
            try:
                top_process = max(
                    psutil.process_iter(attrs=["pid", "name", "memory_info"]),
                    key=lambda p: p.info["memory_info"].rss,
                )
                top_ram_process_gauge.labels(
                    pid=top_process.info["pid"], name=top_process.info["name"]
                ).set(top_process.info["memory_info"].rss)
            except Exception:
                pass

            # GPU and CPU temperatures
            temperatures = psutil.sensors_temperatures()
            gpu_temps = temperatures.get("nvidia", [])
            if gpu_temps:
                gpu_temperature_gauge.set(gpu_temps[0].current)

            cpu_temps = temperatures.get("coretemp", [])
            if cpu_temps:
                cpu_temperature_gauge.set(cpu_temps[0].current)

        except Exception as e:
            print(f"Error collecting metrics: {e}")

        # Sleep before the next collection cycle
        time.sleep(10)


if __name__ == "__main__":
    try:
        exporter_addr = os.environ["EXPORTER_ADDR"]
        exporter_port = int(os.environ["EXPORTER_SYSTEM_PORT"])
    except KeyError as e:
        raise EnvironmentError(f"Missing required environment variable: {e}")

    # Start the Prometheus HTTP server
    start_http_server(port=exporter_port, addr=exporter_addr)
    print(f"Exporter running at {exporter_addr}:{exporter_port}")

    # Start collecting metrics
    collect_metrics()
