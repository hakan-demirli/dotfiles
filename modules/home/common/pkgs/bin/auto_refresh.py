#!/usr/bin/env python3

import argparse
import fcntl
import json
import logging
import os
import re
import signal
import subprocess
import sys
import threading
import time
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any

LOG = logging.getLogger("auto_refresh")

RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
POWER_SUPPLY_ROOT = Path(
    os.environ.get("AUTO_REFRESH_POWER_SUPPLY_ROOT", "/sys/class/power_supply")
)
MONITOR_UPDATE_LOCK = RUNTIME_DIR / "hypr-monitor-update.lock"

MODE_RE = re.compile(r"^(\d+)x(\d+)@([\d.]+)Hz$")
RATE_TOLERANCE = 0.1
STOP = threading.Event()


class AutoRefreshError(RuntimeError):
    pass


@dataclass(frozen=True)
class Mode:
    width: int
    height: int
    rate: float
    value: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="auto_refresh",
        description="Switch the built-in Hyprland display refresh rate with AC power.",
    )
    parser.add_argument(
        "--monitor",
        help="Monitor connector to manage (defaults to the first eDP-* output).",
    )
    parser.add_argument(
        "--min-rate",
        type=float,
        help="Refresh rate to use on battery (defaults to the lowest native mode).",
    )
    parser.add_argument(
        "--max-rate",
        type=float,
        help="Refresh rate to use on AC (defaults to the highest native mode).",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=2.0,
        help="Seconds between reconciliations (default: 2).",
    )
    parser.add_argument(
        "--once",
        action="store_true",
        help="Reconcile once and exit.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show the desired change without applying it.",
    )
    return parser.parse_args()


def read_text(path: Path) -> str | None:
    try:
        return path.read_text().strip()
    except OSError:
        return None


def external_power_online() -> bool:
    states = []
    try:
        supplies = sorted(POWER_SUPPLY_ROOT.iterdir())
    except OSError as e:
        raise AutoRefreshError(f"cannot read {POWER_SUPPLY_ROOT}: {e}") from e

    for supply in supplies:
        supply_type = read_text(supply / "type")
        if not supply_type or supply_type.casefold() == "battery":
            continue

        online = read_text(supply / "online")
        if online in {"0", "1"}:
            states.append(online == "1")

    if not states:
        raise AutoRefreshError("no external power supply with an online state found")

    return any(states)


def run_hyprctl(*args: str) -> str:
    try:
        result = subprocess.run(
            ["hyprctl", *args],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        raise AutoRefreshError(f"hyprctl {' '.join(args)} failed: {e}") from e

    output = result.stdout.strip()
    error = result.stderr.strip()
    if result.returncode != 0 or output.casefold().startswith("error"):
        detail = output or error or f"exit status {result.returncode}"
        raise AutoRefreshError(f"hyprctl {' '.join(args)} failed: {detail}")
    return output


def monitors() -> list[dict[str, Any]]:
    try:
        value = json.loads(run_hyprctl("-j", "monitors"))
    except json.JSONDecodeError as e:
        raise AutoRefreshError(f"hyprctl returned invalid monitor JSON: {e}") from e

    if not isinstance(value, list):
        raise AutoRefreshError("hyprctl monitor JSON is not a list")
    return value


def select_monitor(name: str | None) -> dict[str, Any]:
    available = monitors()
    if name:
        selected = next((item for item in available if item.get("name") == name), None)
    else:
        selected = next(
            (
                item
                for item in available
                if str(item.get("name", "")).startswith("eDP-")
            ),
            None,
        )

    if selected is None:
        target = name or "an eDP-* output"
        raise AutoRefreshError(f"could not find {target}")
    return selected


def native_modes(monitor: dict[str, Any]) -> list[Mode]:
    parsed = []
    for value in monitor.get("availableModes", []):
        match = MODE_RE.fullmatch(str(value))
        if match is None:
            continue
        width, height, rate = match.groups()
        parsed.append(
            Mode(
                width=int(width),
                height=int(height),
                rate=float(rate),
                value=f"{width}x{height}@{rate}",
            )
        )

    if not parsed:
        raise AutoRefreshError(
            f"monitor {monitor.get('name', '<unknown>')} has no parseable modes"
        )

    native_size = max(
        (mode.width * mode.height, mode.width, mode.height) for mode in parsed
    )
    return [
        mode
        for mode in parsed
        if (mode.width * mode.height, mode.width, mode.height) == native_size
    ]


def desired_mode(
    available: list[Mode], requested_rate: float | None, *, highest: bool
) -> Mode:
    if requested_rate is None:
        key = max if highest else min
        return key(available, key=lambda mode: mode.rate)

    selected = min(available, key=lambda mode: abs(mode.rate - requested_rate))
    if abs(selected.rate - requested_rate) > RATE_TOLERANCE:
        rates = ", ".join(f"{mode.rate:g}" for mode in available)
        raise AutoRefreshError(
            f"requested {requested_rate:g}Hz is unavailable; native rates: {rates}"
        )
    return selected


def monitor_lua(monitor: dict[str, Any], mode: Mode) -> str:
    name = json.dumps(str(monitor["name"]))
    mode_value = json.dumps(mode.value)
    position = json.dumps(f"{monitor.get('x', 0)}x{monitor.get('y', 0)}")
    scale = float(monitor.get("scale", 1))
    transform = int(monitor.get("transform", 0))
    return (
        f"hl.monitor({{ output = {name}, mode = {mode_value}, "
        f"position = {position}, scale = {scale:g}, transform = {transform} }})"
    )


@contextmanager
def monitor_update_lock() -> Iterator[None]:
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    with MONITOR_UPDATE_LOCK.open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def verify_rate(name: str, target: float) -> None:
    for _ in range(10):
        current = select_monitor(name)
        if abs(float(current.get("refreshRate", 0)) - target) <= RATE_TOLERANCE:
            return
        time.sleep(0.1)
    raise AutoRefreshError(f"monitor {name} did not switch to {target:g}Hz")


def reconcile(args: argparse.Namespace, *, announce: bool = False) -> None:
    online = external_power_online()
    power = "AC" if online else "battery"

    with monitor_update_lock():
        monitor = select_monitor(args.monitor)
        available = native_modes(monitor)
        mode = desired_mode(
            available,
            args.max_rate if online else args.min_rate,
            highest=online,
        )
        name = str(monitor["name"])
        current_rate = float(monitor.get("refreshRate", 0))
        lua = monitor_lua(monitor, mode)

        if abs(current_rate - mode.rate) <= RATE_TOLERANCE:
            if announce or args.dry_run:
                LOG.info("%s power: %s already at %gHz", power, name, current_rate)
            return

        if args.dry_run:
            LOG.info(
                "%s power: would switch %s from %gHz to %gHz",
                power,
                name,
                current_rate,
                mode.rate,
            )
            print(lua)
            return

        run_hyprctl("eval", lua)
        if not monitor.get("dpmsStatus", True):
            if announce:
                LOG.info(
                    "%s power: queued %gHz for DPMS-off monitor %s",
                    power,
                    mode.rate,
                    name,
                )
            return

        verify_rate(name, mode.rate)
        LOG.info(
            "%s power: switched %s from %gHz to %gHz",
            power,
            name,
            current_rate,
            mode.rate,
        )


def acquire_daemon_lock() -> Any | None:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "default")
    safe_signature = re.sub(r"[^A-Za-z0-9_.-]", "_", signature)
    path = RUNTIME_DIR / f"auto_refresh-{safe_signature}.lock"
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    lock = path.open("a+")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock.close()
        return None
    return lock


def stop(_signum: int, _frame: Any) -> None:
    STOP.set()


def daemon(args: argparse.Namespace) -> int:
    lock = acquire_daemon_lock()
    if lock is None:
        LOG.info("auto_refresh is already running for this Hyprland session")
        return 0

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    LOG.info("started with a %g second reconciliation interval", args.interval)

    first = True
    last_error = None
    last_error_at = 0.0
    while not STOP.is_set():
        started = time.monotonic()
        try:
            reconcile(args, announce=first)
            first = False
            last_error = None
        except AutoRefreshError as e:
            now = time.monotonic()
            error = str(e)
            if error != last_error or now - last_error_at >= 60:
                LOG.error("%s", error)
                last_error = error
                last_error_at = now

        elapsed = time.monotonic() - started
        STOP.wait(max(0.1, args.interval - elapsed))

    lock.close()
    LOG.info("stopped")
    return 0


def main() -> int:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )
    args = parse_args()
    if args.interval <= 0:
        LOG.error("--interval must be greater than zero")
        return 2

    if args.once or args.dry_run:
        try:
            reconcile(args, announce=True)
        except AutoRefreshError as e:
            LOG.error("%s", e)
            return 1
        return 0

    return daemon(args)


if __name__ == "__main__":
    sys.exit(main())
