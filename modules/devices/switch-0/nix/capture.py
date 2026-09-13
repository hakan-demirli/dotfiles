#!/usr/bin/env python3

from __future__ import annotations

import argparse
import getpass
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time

from switchclient import (
    FIRMWARE_KEY,
    DeviceError,
    Session,
    Tunnel,
    authenticate,
    mac_lookup,
    paginate,
    redact,
)

TOOL = "switch-0-capture"

SIMPLE_CONFIG = [
    "get_ip",
    "get_admin_vlan",
    "manager_prop",
    "get_vlan_state",
    "get_8021q_pvid",
    "get_port_vlan",
    "get_lag_list",
    "stp_global",
    "get_mirror_info",
    "get_dhcp_snoop_state",
    "get_dhcp_snoop_list",
    "snmp_global",
    "snmp_trap_event",
    "snmp_notify_edit",
    "get_lldp_config",
    "get_lldp_portconfig",
    "get_qos_info",
    "pri_to_queue_info",
    "dscp_to_pri_info",
    "qos_scheduler_info",
    "get_jumbo_cfg",
    "get_snooping_info",
    "get_loop_info",
    "get_voice_vlan_info",
    "get_voice_vlan_oui",
    "get_voice_vlan_ports",
    "get_sysinfo",
]

PAGINATED_CONFIG = [
    ("get_port", "pid"),
    ("get_8021q_vlan", "id"),
    ("stp_port", "id"),
    ("get_storm_ctrl_info", "id"),
    ("get_port_rate", "id"),
]

OBSERVED = [
    "get_port_basic",
    "get_router_port",
    "get_fan_info",
    "get_lldp_nei_info",
]


def log(message: str) -> None:
    print(f"[{TOOL}] {message}", file=sys.stderr)


def read_password(sops_secrets: str | None, sops_bin: str) -> str:
    if sops_secrets:
        path = pathlib.Path(sops_secrets)
        if not path.is_file():
            raise SystemExit(f"{TOOL}: secrets file is missing: {path}")
        config = path.parent / ".sops.yaml"
        command = [sops_bin]
        if config.is_file():
            command += ["--config", str(config)]
        command += ["--decrypt", "--extract", '["adminPassword"]', str(path)]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            raise SystemExit(
                f"{TOOL}: could not decrypt {path}: {result.stderr.strip()}"
            )
        return result.stdout.strip()
    return getpass.getpass("switch-0 admin password: ")


def load_baseline(source: pathlib.Path, sops_bin: str, sops_config: str | None) -> dict:
    config = pathlib.Path(sops_config) if sops_config else source.parent / ".sops.yaml"
    command = [sops_bin]
    if config.is_file():
        command += ["--config", str(config)]
    command += ["--decrypt", "--output-type", "json", str(source)]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(f"{TOOL}: could not decrypt {source}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def write_baseline(
    payload: dict,
    output: pathlib.Path,
    sops_bin: str,
    sops_config: str | None,
) -> None:
    config = pathlib.Path(sops_config) if sops_config else output.parent / ".sops.yaml"
    if not config.is_file():
        raise SystemExit(
            f"{TOOL}: no sops creation rules at {config}; pass --sops-config"
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    handle, staged = tempfile.mkstemp(prefix="switch-0-baseline.", suffix=".json")
    try:
        os.fchmod(handle, 0o600)
        with os.fdopen(handle, "w") as stream:
            json.dump(payload, stream, indent=2, sort_keys=True)
        result = subprocess.run(
            [
                sops_bin,
                "--config",
                str(config),
                "--encrypt",
                "--input-type",
                "json",
                "--output-type",
                "yaml",
                "--filename-override",
                str(output),
                staged,
            ],
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            raise SystemExit(f"{TOOL}: sops encryption failed: {result.stderr.strip()}")
        output.write_text(result.stdout)
        output.chmod(0o600)
    finally:
        os.unlink(staged)


def walk(session: Session, args: argparse.Namespace, model: str | None) -> dict:
    sysinfo = session.get("get_sysinfo")
    firmware = sysinfo.get(FIRMWARE_KEY)
    if firmware is None:
        present = ", ".join(sorted(sysinfo)) or "none"
        raise SystemExit(
            f"{TOOL}: get_sysinfo has no {FIRMWARE_KEY}; keys present: {present}"
        )
    log(f"firmware {firmware}")
    if args.expect_firmware and firmware != args.expect_firmware:
        message = f"expected firmware {args.expect_firmware}, device reports {firmware}"
        if not args.accept_firmware:
            raise SystemExit(
                f"{TOOL}: {message}; rerun with --accept-firmware to override"
            )
        log(f"WARNING: {message}")

    config: dict = {}
    observed: dict = {}
    unavailable: dict = {}

    for cmd in SIMPLE_CONFIG:
        log(f"read {cmd}")
        try:
            config[cmd] = session.get(cmd)
        except DeviceError as error:
            log(f"unavailable {cmd}: {error}")
            unavailable[cmd] = str(error)
    for cmd, next_key in PAGINATED_CONFIG:
        log(f"read {cmd} (paginated on {next_key})")
        try:
            config[cmd] = paginate(session, cmd, next_key)
        except DeviceError as error:
            log(f"unavailable {cmd}: {error}")
            unavailable[cmd] = str(error)

    for cmd in OBSERVED:
        log(f"observe {cmd}")
        try:
            observed[cmd] = session.get(cmd)
        except DeviceError as error:
            log(f"unavailable {cmd}: {error}")
            unavailable[cmd] = str(error)

    if args.identify:
        lookups: dict = {}
        for mac in args.identify:
            log(f"locate {mac}")
            try:
                lookups[mac] = mac_lookup(session, mac)
            except DeviceError as error:
                log(f"unavailable mac_search {mac}: {error}")
                unavailable[f"mac_search:{mac}"] = str(error)
        observed["mac_lookups"] = lookups

    if unavailable:
        names = ", ".join(sorted(unavailable))
        log(f"{len(unavailable)} command(s) unavailable on this model: {names}")

    return {
        "model": model,
        "firmware": firmware,
        "capturedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "config": config,
        "observed": observed,
        "unavailable": unavailable,
    }


def collect(session: Session, args: argparse.Namespace) -> dict:
    identity = session.get("get_product_name")
    model = identity.get("productName")
    if args.expect_model and model != args.expect_model:
        raise SystemExit(
            f"{TOOL}: expected model {args.expect_model}, device reports {model}"
        )
    log(f"model {model}")

    authenticate(session, args.user, read_password(args.sops_secrets, args.sops_bin))
    log("authenticated")

    try:
        return walk(session, args, model)
    finally:
        try:
            session.post("logout", {"token": session.token})
        except DeviceError:
            log("logout failed; the session will expire on its own")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog=TOOL)
    parser.add_argument("--address", default=os.environ.get("SWITCH_0_ADDRESS"))
    parser.add_argument(
        "--port", type=int, default=int(os.environ.get("SWITCH_0_PORT", "80"))
    )
    parser.add_argument("--user", default=os.environ.get("SWITCH_0_USERNAME", "admin"))
    parser.add_argument("--via", default=None)
    parser.add_argument("--output", default="secrets/switch-0/baseline.yaml")
    parser.add_argument("--sops-secrets", default=None)
    parser.add_argument("--sops-bin", default=os.environ.get("SWITCH_0_SOPS", "sops"))
    parser.add_argument("--sops-config", default=None)
    parser.add_argument("--identify", action="append", default=[], metavar="MAC")
    parser.add_argument("--from-baseline", default=None, metavar="PATH")
    parser.add_argument("--expect-model", default=os.environ.get("SWITCH_0_MODEL"))
    parser.add_argument(
        "--expect-firmware", default=os.environ.get("SWITCH_0_FIRMWARE")
    )
    parser.add_argument("--accept-firmware", action="store_true")
    parser.add_argument("--shape-only", action="store_true")
    args = parser.parse_args()
    if not args.address and not args.from_baseline:
        parser.error("--address is required (or set SWITCH_0_ADDRESS)")
    return args


def main() -> None:
    args = parse_args()

    if args.from_baseline:
        source = pathlib.Path(args.from_baseline).resolve()
        log(f"re-rendering shape from {source}")
        shape = redact(load_baseline(source, args.sops_bin, args.sops_config))
        json.dump(shape, sys.stdout, indent=2)
        sys.stdout.write("\n")
        return

    try:
        if args.via:
            with Tunnel(args.via, args.address, args.port, log) as base:
                baseline = collect(Session(base), args)
        else:
            base = f"http://{args.address}:{args.port}"
            log(f"target {base}")
            baseline = collect(Session(base), args)
    except DeviceError as error:
        raise SystemExit(f"{TOOL}: {error}") from error

    json.dump(redact(baseline), sys.stdout, indent=2)
    sys.stdout.write("\n")
    sys.stdout.flush()

    if args.shape_only:
        log("shape-only run; no baseline written")
        return

    if not args.output.startswith("/") and not pathlib.Path("flake.nix").is_file():
        raise SystemExit(
            f"{TOOL}: run from the repository root, or pass an absolute --output"
        )
    output = pathlib.Path(args.output).resolve()
    write_baseline(baseline, output, args.sops_bin, args.sops_config)
    log(f"encrypted baseline written to {output}")


if __name__ == "__main__":
    main()
