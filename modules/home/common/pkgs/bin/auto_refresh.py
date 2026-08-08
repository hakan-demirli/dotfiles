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
POLICIES = ("auto", "48", "120")
MANUAL_RATES = {"48": 48.0, "120": 120.0}
STOP = threading.Event()


class AutoRefreshError(RuntimeError):
    pass


@dataclass(frozen=True)
class Mode:
    width: int
    height: int
    rate: float
    value: str


@dataclass(frozen=True)
class RefreshStatus:
    policy: str
    monitor: str
    current_rate: float
    target_rate: float | None
    available_rates: tuple[float, ...]
    external_power: bool | None
    power_error: str | None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="auto_refresh",
        description="Manage the built-in Hyprland display refresh-rate policy.",
    )
    parser.add_argument(
        "command",
        nargs="?",
        default="daemon",
        choices=("daemon", *POLICIES, "status", "waybar"),
        help="Run the daemon, select a policy, or print status (default: daemon).",
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
        help="Reconcile the current policy once and exit instead of running the daemon.",
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


def instance_path(suffix: str) -> Path:
    signature = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "default")
    safe_signature = re.sub(r"[^A-Za-z0-9_.-]", "_", signature)
    return RUNTIME_DIR / f"auto_refresh-{safe_signature}.{suffix}"


def policy_path() -> Path:
    return instance_path("policy")


def read_policy() -> str:
    policy = read_text(policy_path())
    return policy if policy in POLICIES else "auto"


def write_policy(policy: str) -> None:
    path = policy_path()
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_text(f"{policy}\n")
        os.replace(temporary, path)
    except OSError as e:
        raise AutoRefreshError(f"cannot write refresh policy to {path}: {e}") from e
    finally:
        temporary.unlink(missing_ok=True)


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


def desired_policy_mode(
    available: list[Mode],
    policy: str,
    args: argparse.Namespace,
    *,
    external_power: bool | None,
) -> Mode:
    if policy in MANUAL_RATES:
        return desired_mode(available, MANUAL_RATES[policy], highest=True)
    if external_power is None:
        raise AutoRefreshError("cannot resolve the auto policy without power status")
    return desired_mode(
        available,
        args.max_rate if external_power else args.min_rate,
        highest=external_power,
    )


def format_rate(rate: float) -> str:
    rounded = round(rate)
    return str(rounded) if abs(rate - rounded) <= RATE_TOLERANCE else f"{rate:g}"


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


def reconcile(
    args: argparse.Namespace,
    *,
    requested_policy: str | None = None,
    persist: bool = False,
    announce: bool = False,
) -> None:
    with monitor_update_lock():
        policy = requested_policy or read_policy()
        monitor = select_monitor(args.monitor)
        available = native_modes(monitor)
        online = external_power_online() if policy == "auto" else None
        mode = desired_policy_mode(
            available,
            policy,
            args,
            external_power=online,
        )

        if persist:
            write_policy(policy)

        name = str(monitor["name"])
        current_rate = float(monitor.get("refreshRate", 0))
        lua = monitor_lua(monitor, mode)
        reason = (
            f"auto ({'AC' if online else 'battery'})"
            if policy == "auto"
            else f"fixed {format_rate(mode.rate)}Hz"
        )

        if abs(current_rate - mode.rate) <= RATE_TOLERANCE:
            if announce or args.dry_run:
                LOG.info("%s: %s already at %gHz", reason, name, current_rate)
            return

        if args.dry_run:
            LOG.info(
                "%s: would switch %s from %gHz to %gHz",
                reason,
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
                    "%s: queued %gHz for DPMS-off monitor %s",
                    reason,
                    mode.rate,
                    name,
                )
            return

        verify_rate(name, mode.rate)
        LOG.info(
            "%s: switched %s from %gHz to %gHz",
            reason,
            name,
            current_rate,
            mode.rate,
        )


def refresh_status(args: argparse.Namespace) -> RefreshStatus:
    with monitor_update_lock():
        policy = read_policy()
        monitor = select_monitor(args.monitor)
        available = native_modes(monitor)

        power_error = None
        try:
            online = external_power_online()
        except AutoRefreshError as e:
            online = None
            power_error = str(e)

        target = None
        if policy != "auto" or online is not None:
            target = desired_policy_mode(
                available,
                policy,
                args,
                external_power=online,
            ).rate

        return RefreshStatus(
            policy=policy,
            monitor=str(monitor["name"]),
            current_rate=float(monitor.get("refreshRate", 0)),
            target_rate=target,
            available_rates=tuple(sorted({mode.rate for mode in available})),
            external_power=online,
            power_error=power_error,
        )


def print_status(args: argparse.Namespace) -> None:
    status = refresh_status(args)
    policy = "Auto" if status.policy == "auto" else f"Fixed {status.policy} Hz"
    power = (
        "AC"
        if status.external_power is True
        else "battery"
        if status.external_power is False
        else "unknown"
    )
    target = (
        f"{format_rate(status.target_rate)} Hz"
        if status.target_rate is not None
        else "unknown"
    )
    rates = ", ".join(format_rate(rate) for rate in status.available_rates)

    print(f"Policy          : {policy}")
    print(f"Monitor         : {status.monitor}")
    print(f"Power           : {power}")
    print(f"Current         : {format_rate(status.current_rate)} Hz")
    print(f"Target          : {target}")
    print(f"Native rates    : {rates} Hz")
    if status.power_error:
        print(f"Power detection : {status.power_error}")


def print_waybar(args: argparse.Namespace) -> None:
    try:
        status = refresh_status(args)
    except AutoRefreshError as e:
        print(json.dumps({"text": "", "class": "hidden", "tooltip": str(e)}))
        return

    controls_supported = all(
        any(abs(rate - requested) <= RATE_TOLERANCE for rate in status.available_rates)
        for requested in MANUAL_RATES.values()
    )
    if not controls_supported:
        print(json.dumps({"text": "", "class": "hidden"}))
        return

    current = format_rate(status.current_rate)
    text = f"󰍹\n{current}Hz"
    if status.policy == "auto":
        css_class = "auto" if status.target_rate is not None else "error"
        policy = "Auto"
    else:
        css_class = f"manual-{status.policy}"
        policy = f"Fixed {status.policy} Hz"

    power = (
        "AC"
        if status.external_power is True
        else "battery"
        if status.external_power is False
        else "unknown"
    )
    target = (
        format_rate(status.target_rate) if status.target_rate is not None else "unknown"
    )
    tooltip = (
        f"Refresh policy: {policy}\n"
        f"Current: {current} Hz\n"
        f"Target: {target} Hz\n"
        f"Power: {power}"
    )
    if status.power_error:
        tooltip += f"\n{status.power_error}"

    print(json.dumps({"text": text, "class": css_class, "tooltip": tooltip}))


def acquire_daemon_lock() -> Any | None:
    path = instance_path("lock")
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

    if args.command == "waybar":
        print_waybar(args)
        return 0

    if args.command == "status":
        try:
            print_status(args)
        except AutoRefreshError as e:
            LOG.error("%s", e)
            return 1
        return 0

    if args.command in POLICIES:
        try:
            reconcile(
                args,
                requested_policy=args.command,
                persist=not args.dry_run,
                announce=True,
            )
        except AutoRefreshError as e:
            LOG.error("%s", e)
            return 1
        return 0

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
