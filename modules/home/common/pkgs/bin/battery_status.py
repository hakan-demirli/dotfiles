#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import os
import re
import sqlite3
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import tomllib

DEFAULT_POWER_SUPPLY = Path("/sys/class/power_supply")
DEFAULT_INTERVAL = 60
DEFAULT_RECENT_HOURS = 12
DEFAULT_RETENTION_DAYS = 365
CONFIG_PATH = Path(".config/hibat/config.toml")
DATABASE_PATH = Path(".cache/hibat/hibat.db")

SCHEMA = """
CREATE TABLE IF NOT EXISTS battery_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp INTEGER NOT NULL,
    battery TEXT NOT NULL,
    capacity INTEGER,
    status TEXT,
    voltage_now INTEGER,
    current_now INTEGER,
    power_now INTEGER,
    energy_now INTEGER,
    energy_full INTEGER,
    energy_full_design INTEGER,
    cycle_count INTEGER,
    temperature INTEGER
);
CREATE INDEX IF NOT EXISTS idx_battery_log_timestamp
    ON battery_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_battery_log_battery
    ON battery_log(battery);
CREATE INDEX IF NOT EXISTS idx_battery_log_battery_timestamp
    ON battery_log(battery, timestamp);
"""

INSERT_SAMPLE = """
INSERT INTO battery_log (
    timestamp, battery, capacity, status, voltage_now,
    current_now, power_now, energy_now, energy_full,
    energy_full_design, cycle_count, temperature
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
"""

RANGE_PATTERN = re.compile(r"^([1-9][0-9]*)([hdwmy])$")
RANGE_SECONDS = {
    "h": 3600,
    "d": 86400,
    "w": 7 * 86400,
    "m": 30 * 86400,
    "y": 365 * 86400,
}


@dataclass(frozen=True)
class Settings:
    interval: int = DEFAULT_INTERVAL
    recent_hours: int = DEFAULT_RECENT_HOURS
    power_supply: Path = DEFAULT_POWER_SUPPLY
    retention_days: int = DEFAULT_RETENTION_DAYS


@dataclass(frozen=True)
class Sample:
    timestamp: int
    battery: str
    capacity: int | None
    status: str
    voltage_now: int | None
    current_now: int | None
    power_now: int | None
    energy_now: int | None
    energy_full: int | None
    energy_full_design: int | None
    cycle_count: int | None
    temperature: int | None

    def scaled(self, name: str) -> float | None:
        value = getattr(self, name)
        return value / 1_000_000.0 if value is not None else None

    @property
    def health(self) -> float | None:
        if self.energy_full is None or not self.energy_full_design:
            return None
        return self.energy_full * 100.0 / self.energy_full_design


@dataclass(frozen=True)
class History:
    rows: list[dict[str, float | None]]
    summary: dict[str, tuple[float | None, ...]]
    count: int
    first: int | None
    last: int | None


def home_path(relative: Path) -> Path:
    return Path(os.environ.get("HOME", ".")) / relative


def positive_int(value: object, default: int) -> int:
    if isinstance(value, int) and not isinstance(value, bool) and value > 0:
        return value
    return default


def load_settings() -> Settings:
    path = home_path(CONFIG_PATH)
    try:
        with path.open("rb") as config_file:
            data = tomllib.load(config_file)
    except FileNotFoundError:
        return Settings()
    except (OSError, tomllib.TOMLDecodeError) as error:
        print(
            f"battery-status: cannot read {path}: {error}; using defaults",
            file=sys.stderr,
        )
        return Settings()

    ui = data.get("ui") if isinstance(data.get("ui"), dict) else {}
    collector = data.get("collector") if isinstance(data.get("collector"), dict) else {}
    raw_path = collector.get("battery_path", str(DEFAULT_POWER_SUPPLY))
    power_supply = (
        Path(raw_path).expanduser()
        if isinstance(raw_path, str) and raw_path
        else DEFAULT_POWER_SUPPLY
    )
    return Settings(
        interval=positive_int(data.get("polling_interval_secs"), DEFAULT_INTERVAL),
        recent_hours=positive_int(ui.get("recent_hours"), DEFAULT_RECENT_HOURS),
        power_supply=power_supply,
        retention_days=positive_int(
            collector.get("retention_days"), DEFAULT_RETENTION_DAYS
        ),
    )


def read_text(path: Path) -> str | None:
    try:
        return path.read_text(encoding="utf-8").strip()
    except (OSError, UnicodeError):
        return None


def read_int(path: Path) -> int | None:
    value = read_text(path)
    if value is None:
        return None
    try:
        return int(value)
    except ValueError:
        return None


def discover_batteries(base: Path) -> list[str]:
    try:
        supplies = list(base.iterdir())
    except OSError:
        return []
    return sorted(
        supply.name
        for supply in supplies
        if read_text(supply / "type") == "Battery"
        and not supply.name.startswith("hid-")
    )


def read_sample(base: Path, battery: str, timestamp: int | None = None) -> Sample:
    path = base / battery
    return Sample(
        timestamp=int(time.time()) if timestamp is None else timestamp,
        battery=battery,
        capacity=read_int(path / "capacity"),
        status=read_text(path / "status") or "Unknown",
        voltage_now=read_int(path / "voltage_now"),
        current_now=read_int(path / "current_now"),
        power_now=read_int(path / "power_now"),
        energy_now=read_int(path / "energy_now"),
        energy_full=read_int(path / "energy_full"),
        energy_full_design=read_int(path / "energy_full_design"),
        cycle_count=read_int(path / "cycle_count"),
        temperature=read_int(path / "temp"),
    )


def battery_name(base: Path, battery: str) -> str:
    path = base / battery
    parts = (read_text(path / "manufacturer"), read_text(path / "model_name"))
    return " ".join(part for part in parts if part) or battery


def ac_online(base: Path) -> bool | None:
    try:
        supplies = list(base.iterdir())
    except OSError:
        return None
    states = []
    for supply in supplies:
        if read_text(supply / "type") == "Battery":
            continue
        online = read_int(supply / "online")
        if online is not None:
            states.append(online != 0)
    return any(states) if states else None


def open_database(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(path, timeout=5)
    connection.execute("PRAGMA busy_timeout = 5000")
    connection.executescript(SCHEMA)
    return connection


def open_database_readonly(path: Path) -> sqlite3.Connection | None:
    if not path.is_file():
        return None
    connection = sqlite3.connect(
        f"{path.resolve().as_uri()}?mode=ro", uri=True, timeout=5
    )
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA busy_timeout = 5000")
    return connection


def insert_sample(connection: sqlite3.Connection, sample: Sample) -> None:
    connection.execute(
        INSERT_SAMPLE,
        (
            sample.timestamp,
            sample.battery,
            sample.capacity,
            sample.status,
            sample.voltage_now,
            sample.current_now,
            sample.power_now,
            sample.energy_now,
            sample.energy_full,
            sample.energy_full_design,
            sample.cycle_count,
            sample.temperature,
        ),
    )


def stored_batteries(connection: sqlite3.Connection | None) -> list[str]:
    if connection is None:
        return []
    rows = connection.execute(
        "SELECT DISTINCT battery FROM battery_log ORDER BY battery"
    ).fetchall()
    return [str(row[0]) for row in rows]


def database_stats(connection: sqlite3.Connection | None) -> tuple[int, int | None]:
    if connection is None:
        return (0, None)
    count, oldest = connection.execute(
        "SELECT COUNT(*), MIN(timestamp) FROM battery_log"
    ).fetchone()
    return (int(count), int(oldest) if oldest is not None else None)


def resolve_range(value: str, now: int) -> tuple[int, int, str]:
    if value == "all":
        return (0, now, "all history")
    if value == "yesterday":
        local_now = datetime.fromtimestamp(now).astimezone()
        today = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
        yesterday = today - timedelta(days=1)
        return (int(yesterday.timestamp()), int(today.timestamp()), "yesterday")

    match = RANGE_PATTERN.fullmatch(value)
    if not match:
        raise ValueError(
            "range must be 'yesterday', 'all', or a duration such as 12h, 7d, 3m, or 1y"
        )
    seconds = int(match.group(1)) * RANGE_SECONDS[match.group(2)]
    return (now - seconds, now, f"last {value}")


def query_history(
    connection: sqlite3.Connection | None,
    battery: str,
    start: int,
    end: int,
    points: int,
) -> History:
    if connection is None:
        return History([], {}, 0, None, None)
    count, first, last = connection.execute(
        """
        SELECT COUNT(*), MIN(timestamp), MAX(timestamp)
        FROM battery_log
        WHERE battery = ? AND timestamp >= ? AND timestamp <= ?
        """,
        (battery, start, end),
    ).fetchone()
    if not count:
        return History([], {}, 0, None, None)

    interval = max(1, math.ceil((int(last) - int(first) + 1) / points))
    rows = connection.execute(
        """
        SELECT
            CAST(AVG(timestamp) AS INTEGER) AS timestamp,
            AVG(capacity) AS capacity,
            AVG(power_now) / 1000000.0 AS power,
            AVG(voltage_now) / 1000000.0 AS voltage,
            AVG(energy_now) / 1000000.0 AS energy,
            AVG(
                CASE WHEN energy_full_design > 0
                THEN energy_full * 100.0 / energy_full_design END
            ) AS health
        FROM battery_log
        WHERE battery = ? AND timestamp >= ? AND timestamp <= ?
        GROUP BY CAST((timestamp - ?) / ? AS INTEGER)
        ORDER BY timestamp
        """,
        (battery, start, end, int(first), interval),
    ).fetchall()
    values = [
        {
            key: float(row[key]) if row[key] is not None else None
            for key in (
                "timestamp",
                "capacity",
                "power",
                "voltage",
                "energy",
                "health",
            )
        }
        for row in rows
    ]
    aggregate = connection.execute(
        """
        SELECT
            MIN(capacity) AS capacity_min,
            AVG(capacity) AS capacity_avg,
            MAX(capacity) AS capacity_max,
            MIN(power_now) / 1000000.0 AS power_min,
            AVG(power_now) / 1000000.0 AS power_avg,
            MAX(power_now) / 1000000.0 AS power_max,
            MIN(voltage_now) / 1000000.0 AS voltage_min,
            AVG(voltage_now) / 1000000.0 AS voltage_avg,
            MAX(voltage_now) / 1000000.0 AS voltage_max,
            MIN(energy_now) / 1000000.0 AS energy_min,
            AVG(energy_now) / 1000000.0 AS energy_avg,
            MAX(energy_now) / 1000000.0 AS energy_max,
            MIN(energy_full * 100.0 / NULLIF(energy_full_design, 0)) AS health_min,
            AVG(energy_full * 100.0 / NULLIF(energy_full_design, 0)) AS health_avg,
            MAX(energy_full * 100.0 / NULLIF(energy_full_design, 0)) AS health_max
        FROM battery_log
        WHERE battery = ? AND timestamp >= ? AND timestamp <= ?
        """,
        (battery, start, end),
    ).fetchone()
    endpoints = connection.execute(
        """
        WITH bounds AS (
            SELECT MIN(timestamp) AS first_timestamp, MAX(timestamp) AS last_timestamp
            FROM battery_log
            WHERE battery = ? AND timestamp >= ? AND timestamp <= ?
        )
        SELECT
            capacity,
            power_now / 1000000.0 AS power,
            voltage_now / 1000000.0 AS voltage,
            energy_now / 1000000.0 AS energy,
            energy_full * 100.0 / NULLIF(energy_full_design, 0) AS health
        FROM battery_log, bounds
        WHERE battery = ?
          AND timestamp IN (bounds.first_timestamp, bounds.last_timestamp)
        ORDER BY timestamp
        """,
        (battery, start, end, battery),
    ).fetchall()
    first_values, last_values = endpoints[0], endpoints[-1]
    summary = {}
    for key in ("capacity", "power", "voltage", "energy", "health"):
        summary[key] = tuple(
            float(value) if value is not None else None
            for value in (
                first_values[key],
                aggregate[f"{key}_min"],
                aggregate[f"{key}_avg"],
                aggregate[f"{key}_max"],
                last_values[key],
            )
        )
    return History(values, summary, int(count), int(first), int(last))


def format_time(timestamp: int | None) -> str:
    if timestamp is None:
        return "unknown"
    return datetime.fromtimestamp(timestamp).astimezone().strftime("%Y-%m-%d %H:%M")


def format_size(size: int) -> str:
    if size < 1024:
        return f"{size} B"
    if size < 1024 * 1024:
        return f"{size / 1024:.1f} KiB"
    return f"{size / (1024 * 1024):.1f} MiB"


def ansi(text: str, code: str, enabled: bool) -> str:
    return f"\033[{code}m{text}\033[0m" if enabled else text


def field(label: str, value: str) -> None:
    print(f"  {label:<12} {value}")


def estimate(sample: Sample) -> str | None:
    power = sample.scaled("power_now")
    now = sample.scaled("energy_now")
    full = sample.scaled("energy_full")
    if power is None or power <= 0.05 or now is None:
        return None
    hours = None
    suffix = ""
    if sample.status == "Discharging":
        hours, suffix = now / power, " remaining"
    elif sample.status == "Charging" and full is not None:
        hours, suffix = max(0.0, full - now) / power, " to full"
    if hours is None:
        return None
    minutes = round(hours * 60)
    return f"about {minutes // 60}h {minutes % 60:02d}m{suffix}"


def print_current(
    sample: Sample | None, base: Path, online: bool | None, color: bool
) -> None:
    print(ansi("Current", "1;36", color))
    if sample is None:
        print("  Battery is not currently exposed by sysfs.")
        return

    capacity = sample.capacity
    filled = 0 if capacity is None else round(max(0, min(100, capacity)) / 5)
    bar = "#" * filled + "-" * (20 - filled)
    percent = "?%" if capacity is None else f"{capacity}%"
    ac_state = (
        "AC unknown" if online is None else ("AC online" if online else "AC offline")
    )
    status_color = {
        "Charging": "1;32",
        "Discharging": "1;33",
        "Full": "1;36",
    }.get(sample.status, "1;37")

    print(f"  {sample.battery} - {battery_name(base, sample.battery)}")
    print(
        f"  [{bar}] {percent}  {ansi(sample.status, status_color, color)}  {ac_state}"
    )
    measurements = (
        ("Power", sample.scaled("power_now"), " W", 2),
        ("Voltage", sample.scaled("voltage_now"), " V", 3),
        ("Current", sample.scaled("current_now"), " A", 3),
    )
    for label, value, unit, precision in measurements:
        if value is not None:
            field(label, f"{value:.{precision}f}{unit}")

    energies = []
    for label, name in (
        ("now", "energy_now"),
        ("full", "energy_full"),
        ("design", "energy_full_design"),
    ):
        value = sample.scaled(name)
        if value is not None:
            energies.append(f"{value:.1f} Wh {label}")
    if energies:
        field("Energy", " / ".join(energies))
    if sample.health is not None:
        field("Health", f"{sample.health:.1f}%")
    if sample.cycle_count is not None:
        field("Cycles", str(sample.cycle_count))
    if sample.temperature is not None:
        field("Temperature", f"{sample.temperature / 10:.1f} C")
    if remaining := estimate(sample):
        field("Estimate", remaining)
    field("Read at", format_time(sample.timestamp))


def history_value(value: float | None, unit: str, precision: int) -> str:
    if value is None:
        return "-"
    return f"{value:.{precision}f}{unit}"


def print_history(history: History, label: str, color: bool) -> None:
    print()
    print(ansi(f"History ({label})", "1;36", color))
    if not history.count:
        print("  No samples for this period.")
        return
    print(
        f"  {history.count:,} samples, {format_time(history.first)} to {format_time(history.last)}"
    )
    metrics = (
        ("Charge", "capacity", "%", 0),
        ("Power", "power", " W", 1),
        ("Voltage", "voltage", " V", 2),
        ("Energy", "energy", " Wh", 1),
        ("Health", "health", "%", 1),
    )

    print()
    print("  Summary")
    print(
        f"  {'Metric':<9} {'First':>10} {'Minimum':>10} "
        f"{'Average':>10} {'Maximum':>10} {'Latest':>10}"
    )
    for metric_label, key, unit, precision in metrics:
        values = [
            history_value(value, unit, precision) for value in history.summary[key]
        ]
        print(
            f"  {metric_label:<9} {values[0]:>10} {values[1]:>10} "
            f"{values[2]:>10} {values[3]:>10} {values[4]:>10}"
        )

    print()
    print("  Timeline (each row is one time-bucket average)")
    print(
        f"  {'Time':<11} {'Charge':>7} {'Power':>9} "
        f"{'Voltage':>9} {'Energy':>10} {'Health':>8}"
    )
    for row in history.rows:
        timestamp = row["timestamp"]
        bucket_time = (
            datetime.fromtimestamp(int(timestamp)).astimezone().strftime("%m-%d %H:%M")
            if timestamp is not None
            else "-"
        )
        print(
            f"  {bucket_time:<11} "
            f"{history_value(row['capacity'], '%', 0):>7} "
            f"{history_value(row['power'], ' W', 1):>9} "
            f"{history_value(row['voltage'], ' V', 2):>9} "
            f"{history_value(row['energy'], ' Wh', 1):>10} "
            f"{history_value(row['health'], '%', 1):>8}"
        )


def report(args: argparse.Namespace, parser: argparse.ArgumentParser) -> int:
    settings = load_settings()
    now = int(time.time())
    try:
        start, end, range_label = resolve_range(
            args.range_name or f"{settings.recent_hours}h", now
        )
    except ValueError as error:
        parser.error(str(error))

    database = home_path(DATABASE_PATH)
    connection = None
    try:
        connection = open_database_readonly(database)
        saved = stored_batteries(connection)
    except sqlite3.Error as error:
        print(f"battery-status: cannot read {database}: {error}", file=sys.stderr)
        if connection is not None:
            connection.close()
        connection, saved = None, []

    live = discover_batteries(settings.power_supply)
    available = sorted(set(live + saved))
    battery = args.battery or (live[0] if live else (saved[0] if saved else None))
    if battery is None or battery not in available:
        print("battery-status: requested battery was not found", file=sys.stderr)
        if connection is not None:
            connection.close()
        return 1

    sample = (
        read_sample(settings.power_supply, battery, now) if battery in live else None
    )
    history = query_history(connection, battery, start, end, 12)
    total, oldest = database_stats(connection)
    color = sys.stdout.isatty() and not args.no_color and "NO_COLOR" not in os.environ

    title = "Battery status"
    print(ansi(title, "1", color))
    print("=" * 50)
    print_current(
        sample, settings.power_supply, ac_online(settings.power_supply), color
    )
    print_history(history, range_label, color)
    print()
    if connection is None:
        print(f"Database: no history database at {database}")
    else:
        print(
            f"Database: {total:,} records since {format_time(oldest)} "
            f"({format_size(database.stat().st_size)})"
        )
        connection.close()
    return 0


def positive_seconds(value: str) -> int:
    try:
        seconds = int(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be an integer") from error
    if seconds <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return seconds


def collect_once(connection: sqlite3.Connection, base: Path, verbose: bool) -> int:
    samples = [read_sample(base, battery) for battery in discover_batteries(base)]
    if not samples:
        if verbose:
            print(f"battery-status: no batteries found at {base}", file=sys.stderr)
        return 0
    with connection:
        for sample in samples:
            insert_sample(connection, sample)
            if verbose:
                capacity = "?" if sample.capacity is None else str(sample.capacity)
                power = sample.scaled("power_now") or 0.0
                print(
                    f"[{format_time(sample.timestamp)}] {sample.battery} "
                    f"capacity={capacity}% status={sample.status} power={power:.2f}W",
                    file=sys.stderr,
                )
    return len(samples)


def collect(args: argparse.Namespace) -> int:
    settings = load_settings()
    database = home_path(DATABASE_PATH)
    try:
        connection = open_database(database)
    except (OSError, sqlite3.Error) as error:
        print(f"battery-status: cannot open {database}: {error}", file=sys.stderr)
        return 1

    cutoff = int(time.time()) - settings.retention_days * 86400
    with connection:
        purged = connection.execute(
            "DELETE FROM battery_log WHERE timestamp < ?", (cutoff,)
        ).rowcount
    if args.verbose and purged:
        print(f"battery-status: purged {purged} old records", file=sys.stderr)

    if args.once:
        collect_once(connection, settings.power_supply, args.verbose)
        connection.close()
        return 0

    interval = args.interval or settings.interval
    print(f"battery-status: logging every {interval}s to {database}", file=sys.stderr)
    try:
        while True:
            started = time.monotonic()
            collect_once(connection, settings.power_supply, args.verbose)
            time.sleep(max(0.0, interval - (time.monotonic() - started)))
    except KeyboardInterrupt:
        return 0
    finally:
        connection.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Print battery status and history")
    parser.add_argument("--battery", help="battery name, for example BAT0")
    parser.add_argument(
        "--range",
        dest="range_name",
        help="history range: 12h, 7d, 3m, 1y, yesterday, or all",
    )
    parser.add_argument("--no-color", action="store_true", help="disable ANSI colors")
    subparsers = parser.add_subparsers(dest="command")
    collector = subparsers.add_parser("collect", help="collect battery history")
    collector.add_argument("--once", action="store_true", help="collect once and exit")
    collector.add_argument(
        "--interval", type=positive_seconds, help="poll interval in seconds"
    )
    collector.add_argument(
        "--verbose", action="store_true", help="print collected samples"
    )
    args = parser.parse_args()
    return collect(args) if args.command == "collect" else report(args, parser)


if __name__ == "__main__":
    raise SystemExit(main())
