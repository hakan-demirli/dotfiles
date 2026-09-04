#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

NETIFD_IFACE = "wwan"
RADIO_EXPANSION = {
    "radio0": ["radio0"],
    "radio1": ["radio1"],
    "any": ["radio0", "radio1"],
}
MARKER = "# === GENERATED STA wifi-iface BLOCKS (from secrets/wifi/networks.yaml) ==="


def slug(s: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    return s or "net"


def quote(s: object) -> str:
    return "'" + str(s).replace("'", "'\\''") + "'"


def resolve(networks: dict) -> list[dict]:
    resolved: list[dict] = []
    for network_id, network in networks.items():
        radio = network.get("uplink_radio")
        if radio is None:
            continue

        if radio not in RADIO_EXPANSION:
            raise SystemExit(
                f"wifi-to-uci: uplink {network_id} has invalid radio {radio!r}"
            )

        auth = network.get("auth")
        if auth in ("psk", "sae"):
            if not network.get("psk"):
                raise SystemExit(f"wifi-to-uci: uplink {network_id} is missing its psk")
        elif auth in ("eap-ttls", "eap-peap"):
            if not network.get("identity") or not network.get("password"):
                raise SystemExit(
                    f"wifi-to-uci: uplink {network_id} is missing its identity or password"
                )
        elif auth != "open":
            raise SystemExit(
                f"wifi-to-uci: uplink {network_id} has unsupported auth {auth!r}"
            )

        if not network.get("ssid"):
            raise SystemExit(f"wifi-to-uci: uplink {network_id} is missing its ssid")

        autostart = network.get("uplink_autostart", False)
        if not isinstance(autostart, bool):
            raise SystemExit(
                f"wifi-to-uci: uplink {network_id} has non-boolean uplink_autostart"
            )
        radios = RADIO_EXPANSION[radio]
        if autostart and len(radios) != 1:
            raise SystemExit(
                f"wifi-to-uci: autostart uplink {network_id} must select one radio"
            )

        resolved.append(
            {
                "id": network_id,
                "ssid": network["ssid"],
                "auth": auth,
                "network": network,
                "radios": radios,
                "priority": int(network.get("uplink_priority", 50)),
                "autostart": autostart,
            }
        )

    resolved.sort(key=lambda entry: (-entry["priority"], entry["ssid"]))
    autostart = [entry for entry in resolved if entry["autostart"]]
    if len(autostart) != 1:
        raise SystemExit(
            f"wifi-to-uci: expected exactly one autostart uplink, found {len(autostart)}"
        )
    return resolved


def emit_wireless(entry: dict, radio: str, section: str) -> list[str]:
    network = entry["network"]
    auth = entry["auth"]
    out = [
        f"config wifi-iface {quote(section)}",
        f"\toption device {quote(radio)}",
        "\toption mode 'sta'",
        f"\toption network {quote(NETIFD_IFACE)}",
        f"\toption ssid {quote(entry['ssid'])}",
    ]

    if auth == "psk":
        out.append("\toption encryption 'psk2'")
        out.append(f"\toption key {quote(network['psk'])}")
    elif auth == "sae":
        out.append("\toption encryption 'sae'")
        out.append(f"\toption key {quote(network['psk'])}")
        out.append("\toption ieee80211w '2'")
    elif auth in ("eap-ttls", "eap-peap"):
        out.append("\toption encryption 'wpa2'")
        out.append(f"\toption eap_type {quote(auth.removeprefix('eap-'))}")
        out.append(
            f"\toption auth {quote(network.get('inner_auth', 'MSCHAPV2').upper())}"
        )
        out.append(f"\toption identity {quote(network['identity'])}")
        out.append(f"\toption password {quote(network['password'])}")
        out.append("\toption ca_cert ''")
    elif auth == "open":
        out.append("\toption encryption 'none'")

    out.append(f"\toption disabled {quote(0 if entry['autostart'] else 1)}")
    return out


def emit_uplink(entry: dict, radio: str) -> list[str]:
    return [
        "config uplink",
        f"\toption device {quote(radio)}",
        f"\toption ssid {quote(entry['ssid'])}",
        "\toption bssid ''",
        "\toption enabled '1'",
    ]


TRAVELMATE_GLOBAL = [
    "config travelmate 'global'",
    "\toption trm_enabled '1'",
    f"\toption trm_iface {quote(NETIFD_IFACE)}",
    "\toption trm_captive '1'",
    "\toption trm_proactive '0'",
    "\toption trm_autoadd '0'",
    "\toption trm_maxretry '5'",
    "\toption trm_maxwait '30'",
    "\toption trm_minquality '35'",
    "\toption trm_listexpiry '0'",
    "\toption trm_radio ''",
    "\toption trm_debug '0'",
    "",
]


def render(networks: dict) -> tuple[str, str]:
    entries = resolve(networks)
    if not entries:
        raise SystemExit("wifi-to-uci: no network declares an uplink_radio")

    wireless_lines: list[str] = []
    trm_uplinks: list[str] = []

    for entry in entries:
        for radio in entry["radios"]:
            section = f"sta_{slug(entry['ssid'])}_{radio[-1]}"
            wireless_lines.extend(emit_wireless(entry, radio, section))
            wireless_lines.append("")
            trm_uplinks.extend(emit_uplink(entry, radio))
            trm_uplinks.append("")

    wireless = MARKER + "\n" + "\n".join(wireless_lines).rstrip() + "\n"
    travelmate = (
        "\n".join(TRAVELMATE_GLOBAL) + "\n" + "\n".join(trm_uplinks).rstrip() + "\n"
    )
    return wireless, travelmate


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--networks", type=pathlib.Path, required=True)
    p.add_argument("--wireless-out", type=pathlib.Path, required=True)
    p.add_argument("--travelmate-out", type=pathlib.Path, required=True)
    args = p.parse_args()

    networks = json.loads(args.networks.read_text()).get("networks", {})

    wireless, travelmate = render(networks)
    args.wireless_out.write_text(wireless)
    args.travelmate_out.write_text(travelmate)
    print(f"wifi-to-uci: rendered {len(resolve(networks))} uplinks", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
