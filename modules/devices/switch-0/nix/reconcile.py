#!/usr/bin/env python3

from __future__ import annotations

import argparse
import getpass
import json
import os
import pathlib
import subprocess
import sys
import time

import baseline
from rules import TIER_MANAGEMENT, TIER_SAFE, Rule, build_rules, find_uplink
from switchclient import (
    FIRMWARE_KEY,
    DeviceError,
    Session,
    Tunnel,
    authenticate,
    mac_lookup,
)

TOOL = "switch-0-config"
RETARGET_INTERVAL = 2
RETARGET_TIMEOUT = 40


def log(message: str) -> None:
    print(f"[{TOOL}] {message}", file=sys.stderr)


def read_secret(path: pathlib.Path, key: str, sops_bin: str) -> str | None:
    if not path.is_file():
        return None
    config = path.parent / ".sops.yaml"
    command = [sops_bin]
    if config.is_file():
        command += ["--config", str(config)]
    command += ["--decrypt", "--extract", f'["{key}"]', str(path)]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        return None
    return result.stdout.strip() or None


def read_password(secrets: pathlib.Path, sops_bin: str) -> str:
    stored = read_secret(secrets, "adminPassword", sops_bin)
    if stored:
        return stored
    return getpass.getpass("switch-0 admin password: ")


def discover_uplink(
    session: Session, secrets: pathlib.Path, sops_bin: str
) -> int | None:
    uplink_mac = read_secret(secrets, "uplinkMac", sops_bin)
    if not uplink_mac:
        log("no uplinkMac in secrets; the uplink cannot be discovered")
        return None
    result = mac_lookup(session, uplink_mac)
    if not result.get("isOK"):
        log("uplink mac lookup did not complete")
        return None
    pid = find_uplink(result)
    if pid is None:
        log("uplink mac did not resolve to exactly one switch port")
    return pid


def evaluate(session: Session, rules: list[Rule]) -> list[tuple[Rule, object, object]]:
    differences = []
    for rule in rules:
        actual = rule.actual(session)
        wanted = rule.wanted()
        if actual != wanted:
            differences.append((rule, actual, wanted))
    return differences


def report(differences: list[tuple[Rule, object, object]]) -> None:
    if not differences:
        log("no drift: device matches the declared state")
        return
    width = max(len(rule.subject) for rule, _, _ in differences)
    log(f"{len(differences)} difference(s):")
    for rule, actual, wanted in differences:
        tier = "mgmt" if rule.tier == TIER_MANAGEMENT else "safe"
        print(
            f"  [{tier}] {rule.subject.ljust(width)}  actual={actual}  desired={wanted}"
        )


def report_baseline(warnings: list[str]) -> None:
    if not warnings:
        log("no undeclared baseline drift")
        return
    log(f"{len(warnings)} undeclared baseline warning(s):")
    for warning in warnings:
        print(f"  [baseline] {warning}")


def reattach(candidates: list[str], args: argparse.Namespace, password: str) -> Session:
    deadline = time.monotonic() + RETARGET_TIMEOUT
    while time.monotonic() < deadline:
        time.sleep(RETARGET_INTERVAL)
        for address in candidates:
            session = Session(f"http://{address}:{args.port}")
            try:
                session.get("get_product_name")
                authenticate(session, args.user, password)
            except DeviceError:
                continue
            log(f"reattached at {address}")
            return session
    raise SystemExit(
        f"{TOOL}: device unreachable at {' or '.join(candidates)} after the address change. "
        "Configuration was NOT saved, so a power cycle restores the previous address."
    )


def apply_changes(
    session: Session,
    differences: list[tuple[Rule, object, object]],
    args: argparse.Namespace,
    password: str,
) -> tuple[list[Rule], Session]:
    applied: list[Rule] = []
    ordered = sorted(differences, key=lambda item: item[0].tier)
    applicable = [
        rule
        for rule, _actual, _wanted in ordered
        if rule.tier == TIER_SAFE or args.allow_mgmt_change
    ]
    blocked = [
        f"{rule.subject}: {reason}"
        for rule in applicable
        if (reason := rule.blocked_reason()) is not None
    ]
    if blocked:
        raise SystemExit(f"{TOOL}: refusing to apply: {'; '.join(blocked)}")

    for rule, _actual, wanted in ordered:
        if rule.tier == TIER_MANAGEMENT and not args.allow_mgmt_change:
            log(
                f"skipping management-plane change: {rule.subject} (needs --allow-mgmt-change)"
            )
            continue
        retarget = getattr(rule, "retarget", None)
        if retarget and args.via:
            log(f"skipping {rule.subject}: an address change cannot run through --via")
            continue
        log(f"applying {rule.subject} -> {wanted}")
        rule.apply(session)
        applied.append(rule)
        if retarget:
            session = reattach([retarget, args.address], args, password)
    return applied, session


def run(session: Session, args: argparse.Namespace, desired: dict) -> int:
    identity = session.get("get_product_name")
    log(f"model {identity.get('productName')}")

    secrets = pathlib.Path(args.secrets)
    password = read_password(secrets, args.sops_bin)
    authenticate(session, args.user, password)
    log("authenticated")

    try:
        firmware = session.get("get_sysinfo").get(FIRMWARE_KEY)
        log(f"firmware {firmware}")
        if args.expect_firmware and firmware != args.expect_firmware:
            message = (
                f"expected firmware {args.expect_firmware}, device reports {firmware}"
            )
            if not args.accept_firmware:
                raise SystemExit(
                    f"{TOOL}: {message}; rerun with --accept-firmware to override"
                )
            log(f"WARNING: {message}")

        uplink = discover_uplink(session, secrets, args.sops_bin)
        rules = build_rules(session, desired, uplink)
        differences = evaluate(session, rules)
        report(differences)
        try:
            baseline_warnings = baseline.inspect(
                session, pathlib.Path(args.baseline), args.sops_bin
            )
        except (RuntimeError, json.JSONDecodeError) as error:
            raise SystemExit(f"{TOOL}: {error}") from error
        report_baseline(baseline_warnings)

        if args.check:
            return 1 if differences else 0
        if not differences:
            return 0

        pending = [
            item
            for item in differences
            if item[0].tier == TIER_SAFE or args.allow_mgmt_change
        ]
        if not pending:
            log("nothing to apply; all outstanding changes are management-plane")
            return 1

        applied, session = apply_changes(session, differences, args, password)
        if not applied:
            return 1

        log(f"verifying {len(applied)} applied change(s)")
        remaining = evaluate(session, applied)
        if remaining:
            report(remaining)
            raise SystemExit(
                f"{TOOL}: verification failed; configuration was NOT saved. "
                "Runtime state is dirty but the saved configuration is intact: "
                "power-cycle the switch to revert."
            )

        log("verification passed; committing with save_configure")
        session.post("save_configure")
        log("committed")

        residual = evaluate(session, rules)
        report(residual)
        return 1 if residual else 0
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
    parser.add_argument("--desired", default=os.environ.get("SWITCH_0_DESIRED"))
    parser.add_argument("--secrets", default="secrets/switch-0/deploy.yaml")
    parser.add_argument("--baseline", default="secrets/switch-0/baseline.yaml")
    parser.add_argument("--sops-bin", default=os.environ.get("SWITCH_0_SOPS", "sops"))
    parser.add_argument(
        "--expect-firmware", default=os.environ.get("SWITCH_0_FIRMWARE")
    )
    parser.add_argument("--accept-firmware", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--allow-mgmt-change", action="store_true")
    args = parser.parse_args()
    if not args.address:
        parser.error("--address is required (or set SWITCH_0_ADDRESS)")
    if not args.desired:
        parser.error("--desired is required (or set SWITCH_0_DESIRED)")
    if args.allow_mgmt_change and args.check:
        parser.error("--allow-mgmt-change has no meaning with --check")
    return args


def main() -> None:
    args = parse_args()
    desired = json.loads(pathlib.Path(args.desired).read_text())

    try:
        if args.via:
            with Tunnel(args.via, args.address, args.port, log) as base:
                code = run(Session(base), args, desired)
        else:
            base = f"http://{args.address}:{args.port}"
            log(f"target {base}")
            code = run(Session(base), args, desired)
    except DeviceError as error:
        raise SystemExit(f"{TOOL}: {error}") from error

    raise SystemExit(code)


if __name__ == "__main__":
    main()
