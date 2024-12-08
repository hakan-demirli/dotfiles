#!/usr/bin/env python3

import json
import os
import subprocess
import time
from prometheus_client import Gauge, start_http_server

# Define Prometheus gauge that uses client_class, title, and focus_history_id as labels
client_info_metric = Gauge(
    "hyprctl_client_info",
    "Information about Hyprctl clients",
    ["client_class", "title", "focus_history_id"],
)


def update_clients():
    while True:
        try:
            result = subprocess.run(
                ["hyprctl", "clients", "-j"], capture_output=True, text=True, check=True
            )
            clients = json.loads(result.stdout)

            # Clear existing metrics
            client_info_metric.clear()

            # Parse and update metrics
            for client in clients:
                client_class = client.get("class", "unknown")
                client_title = client.get("title", "unknown")
                focus_history_id = client.get("focusHistoryID", "unknown")

                # Set a value of '1' for each client found
                client_info_metric.labels(
                    client_class=client_class,
                    title=client_title,
                    focus_history_id=str(focus_history_id),
                ).set(1)

        except subprocess.CalledProcessError as e:
            print(f"Error running hyprctl: {e}")
        except json.JSONDecodeError as e:
            print(f"Error decoding JSON: {e}")
        except Exception as e:
            print(f"Unexpected error: {e}")

        time.sleep(1)


if __name__ == "__main__":
    try:
        exporter_addr = os.environ["EXPORTER_ADDR"]
        exporter_port = int(os.environ["EXPORTER_WINDOW_PORT"])
    except KeyError as e:
        raise EnvironmentError(f"Missing required environment variable: {e}")

    start_http_server(port=exporter_port, addr=exporter_addr)
    update_clients()
