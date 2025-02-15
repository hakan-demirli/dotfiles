#!/usr/bin/env python3

from prometheus_client import start_http_server, Gauge
import os
import socket
import time
import requests
from statistics import mean

# Define metrics
status_metric = Gauge("network_status", "Network status (1=online, 0=offline)")
latency_metric = Gauge("network_latency_ms", "Average network latency in milliseconds")
packet_loss_metric = Gauge("network_packet_loss", "Packet loss percentage")
public_ip_metric = Gauge("network_public_ip", "Public IP address (dummy value)")
dns_resolution_metric = Gauge(
    "dns_resolution_time_ms", "DNS resolution time in milliseconds"
)


class NetworkMetricsExporter:
    def __init__(self, hosts, port):
        self.hosts = hosts
        self.port = port

    def collect_metrics(self):
        metrics = {
            "status": 0,
            "latency": None,
            "packet_loss": None,
            "public_ip": None,
            "dns_resolution_time": None,
        }

        try:
            # Test connectivity and measure latency
            latencies = []
            for host in self.hosts:
                start_time = time.time()
                try:
                    with socket.create_connection((host, self.port), timeout=5):
                        latencies.append(time.time() - start_time)
                except socket.error:
                    pass

            if latencies:
                metrics["status"] = 1
                metrics["latency"] = round(mean(latencies) * 1000, 2)  # ms

            # Estimate packet loss
            total_hosts = len(self.hosts)
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
                socket.gethostbyname(self.hosts[0])
                metrics["dns_resolution_time"] = round(
                    (time.time() - start_time) * 1000, 2
                )
            except socket.error:
                metrics["dns_resolution_time"] = None

        except Exception as e:
            print(f"Error collecting metrics: {e}")

        return metrics

    def update_metrics(self):
        metrics = self.collect_metrics()

        status_metric.set(metrics["status"])
        latency_metric.set(metrics["latency"] or 0)
        packet_loss_metric.set(metrics["packet_loss"] or 0)
        public_ip_metric.set(hash(metrics["public_ip"] or "0"))
        dns_resolution_metric.set(metrics["dns_resolution_time"] or 0)


def main():
    try:
        exporter_addr = os.environ["EXPORTER_ADDR"]
        exporter_port = int(os.environ["EXPORTER_NETWORK_PORT"])
    except KeyError as e:
        raise EnvironmentError(f"Missing required environment variable: {e}")

    hosts = ["google.com", "cloudflare.com"]
    port = 80

    exporter = NetworkMetricsExporter(hosts=hosts, port=port)

    # Start the HTTP server
    start_http_server(addr=exporter_addr, port=exporter_port)

    print(f"Exporter running at {exporter_addr}:{exporter_port}")

    while True:
        exporter.update_metrics()
        time.sleep(60)


if __name__ == "__main__":
    main()
