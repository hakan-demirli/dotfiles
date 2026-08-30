#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import pathlib
import sys

KEY_MGMT = {
    "psk": "wpa-psk",
    "sae": "sae",
    "eap-ttls": "wpa-eap",
    "eap-peap": "wpa-eap",
}


def render(network_id: str, network: dict) -> str:
    auth = network.get("auth")
    if auth not in KEY_MGMT and auth != "open":
        raise SystemExit(
            f"wifi-profiles: network {network_id} has unsupported auth {auth!r}"
        )

    ssid = network.get("ssid")
    if not ssid:
        raise SystemExit(f"wifi-profiles: network {network_id} is missing its ssid")

    lines = [
        "[connection]",
        f"id={ssid}",
        f"uuid={network_id}",
        "type=wifi",
    ]
    priority = network.get("priority")
    if priority is not None:
        lines.append(f"autoconnect-priority={priority}")

    lines += ["", "[wifi]", "mode=infrastructure", f"ssid={ssid}"]

    if auth != "open":
        lines += ["", "[wifi-security]", f"key-mgmt={KEY_MGMT[auth]}"]
        if auth != "sae":
            lines.append("auth-alg=open")
        if auth in ("psk", "sae"):
            psk = network.get("psk")
            if not psk:
                raise SystemExit(
                    f"wifi-profiles: network {network_id} is missing its psk"
                )
            lines.append(f"psk={psk}")
        else:
            identity = network.get("identity")
            password = network.get("password")
            if not identity or not password:
                raise SystemExit(
                    f"wifi-profiles: network {network_id} is missing its identity or password"
                )
            lines += [
                "",
                "[802-1x]",
                f"eap={auth.removeprefix('eap-')};",
                f"identity={identity}",
                f"password={password}",
                f"phase2-auth={network.get('inner_auth', 'mschapv2').lower()}",
            ]

    lines += [
        "",
        "[ipv4]",
        "method=auto",
        "",
        "[ipv6]",
        "addr-gen-mode=default",
        "method=auto",
        "",
        "[proxy]",
        "",
    ]
    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--networks", type=pathlib.Path, required=True)
    p.add_argument("--out-dir", type=pathlib.Path, required=True)
    args = p.parse_args()

    networks = json.loads(args.networks.read_text()).get("networks", {})
    if not networks:
        raise SystemExit("wifi-profiles: the secrets document declares no networks")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    for network_id, network in networks.items():
        target = args.out_dir / f"{network_id}.nmconnection"
        target.write_text(render(network_id, network))
        target.chmod(0o600)

    print("\n".join(sorted(networks)), file=sys.stderr)
    print(f"wifi-profiles: rendered {len(networks)} profiles", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
