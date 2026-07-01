#!/usr/bin/env python3

from __future__ import annotations

import argparse
import pathlib
import re
import sys

import tomllib

NETIFD_IFACE = "wwan"
ALLOWED_RADIOS = {"radio0", "radio1"}
MARKER = "# === GENERATED STA wifi-iface BLOCKS (from secrets/wifi.toml) ==="


def slug(s: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "_", s).strip("_").lower()
    return s or "net"


def quote(s) -> str:
    s = str(s)
    return "'" + s.replace("'", "'\\''") + "'"


def emit_wireless(net: dict, radio: str, section: str) -> list[str] | None:
    auth = net.get("auth", "psk").lower()
    ssid = net["ssid"]
    out: list[str] = []
    out.append(f"config wifi-iface {quote(section)}")
    out.append(f"\toption device {quote(radio)}")
    out.append("\toption mode 'sta'")
    out.append(f"\toption network {quote(NETIFD_IFACE)}")
    out.append(f"\toption ssid {quote(ssid)}")
    if net.get("hidden"):
        out.append("\toption scan_ssid '1'")
    if "ieee80211w" in net:
        out.append(f"\toption ieee80211w {quote(net['ieee80211w'])}")

    if auth == "psk":
        psk = net.get("psk") or ""
        if not psk:
            print(
                f"wifi-to-uci: psk network '{ssid}' has empty psk. Skipping",
                file=sys.stderr,
            )
            return None
        out.append("\toption encryption 'psk2'")
        out.append(f"\toption key {quote(psk)}")
    elif auth in ("eap-ttls", "eap-peap", "wpa-eap", "eap"):
        eap_type = (
            "ttls"
            if auth == "eap-ttls"
            else ("peap" if auth == "eap-peap" else net.get("eap_type", "ttls"))
        )
        identity = net.get("identity") or ""
        password = net.get("password") or ""
        if not identity or not password:
            print(
                f"wifi-to-uci: eap network '{ssid}' missing identity/password. Skipping",
                file=sys.stderr,
            )
            return None
        out.append("\toption encryption 'wpa2'")
        out.append(f"\toption eap_type {quote(eap_type)}")
        out.append(f"\toption auth {quote(net.get('inner_auth', 'MSCHAPV2'))}")
        out.append(f"\toption identity {quote(identity)}")
        out.append(f"\toption password {quote(password)}")
        if net.get("anonymous_identity"):
            out.append(
                f"\toption anonymous_identity {quote(net['anonymous_identity'])}"
            )
        out.append(f"\toption ca_cert {quote(net.get('ca_cert', ''))}")
    elif auth == "open":
        out.append("\toption encryption 'none'")
    else:
        print(
            f"wifi-to-uci: unknown auth '{auth}' for '{ssid}'. Skipping",
            file=sys.stderr,
        )
        return None

    out.append("\toption disabled '1'")
    return out


def emit_uplink(net: dict, radio: str) -> list[str]:
    ssid = net["ssid"]
    return [
        "config uplink",
        f"\toption device {quote(radio)}",
        f"\toption ssid {quote(ssid)}",
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


def render(wifi_toml_path: pathlib.Path) -> tuple[str, str]:
    with wifi_toml_path.open("rb") as f:
        cfg = tomllib.load(f)

    networks = cfg.get("networks", [])
    if not networks:
        raise SystemExit("wifi-to-uci: no [[networks]] entries in wifi.toml")

    wireless_lines: list[str] = []
    trm_uplinks: list[str] = []

    sorted_nets = sorted(
        [n for n in networks if "ssid" in n],
        key=lambda n: -int(n.get("priority", 50)),
    )

    for net in sorted_nets:
        requested = net.get("radio", "radio0")
        radios = [requested] if requested != "any" else ["radio0", "radio1"]
        for r in radios:
            if r not in ALLOWED_RADIOS:
                print(
                    f"wifi-to-uci: invalid radio '{r}' for '{net['ssid']}'. Skipping",
                    file=sys.stderr,
                )
                continue
            section = f"sta_{slug(net['ssid'])}_{r[-1]}"
            w = emit_wireless(net, r, section)
            if not w:
                continue
            wireless_lines.extend(w)
            wireless_lines.append("")
            trm_uplinks.extend(emit_uplink(net, r))
            trm_uplinks.append("")

    wireless = MARKER + "\n" + "\n".join(wireless_lines).rstrip() + "\n"
    travelmate = (
        "\n".join(TRAVELMATE_GLOBAL) + "\n" + "\n".join(trm_uplinks).rstrip() + "\n"
    )
    return wireless, travelmate


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("wifi_toml", type=pathlib.Path)
    p.add_argument("--wireless-out", type=pathlib.Path, required=True)
    p.add_argument("--travelmate-out", type=pathlib.Path, required=True)
    args = p.parse_args()

    wireless, travelmate = render(args.wifi_toml)
    args.wireless_out.write_text(wireless)
    args.travelmate_out.write_text(travelmate)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
