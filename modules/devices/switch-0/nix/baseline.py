from __future__ import annotations

import copy
import json
import pathlib
import subprocess

from switchclient import DeviceError, Session, paginate, redact

PAGINATED = {
    "get_port": "pid",
    "get_8021q_vlan": "id",
    "stp_port": "id",
    "get_storm_ctrl_info": "id",
    "get_port_rate": "id",
}

DROP_ENDPOINTS = {
    "get_admin_vlan",
    "get_dhcp_snoop_state",
    "get_mirror_info",
}

DROP_FIELDS = {
    "get_ip": {
        "dhcpStatus",
        "dnsEn",
        "dnsServer1",
        "dnsServer2",
        "gateway",
        "ipAddr",
        "netMask",
    },
    "manager_prop": {"connManagementPlatform", "dhcpOptionOverwrite"},
    "snmp_global": {"snmpStatus"},
    "get_lldp_config": {"lldpStatus"},
    "stp_global": {"enable"},
    "get_snooping_info": {"igmpEn"},
    "get_loop_info": {"loopEn", "dataArray"},
    "get_sysinfo": {"gateway", "ipAddr", "netMask", "upTime"},
}

DROP_LIST_FIELDS = {
    "get_dhcp_snoop_list": {"mode"},
    "get_port": {"ANEn", "actDpx", "actFctl", "actSpd", "enable", "flowCtl", "link"},
    "get_lag_list": {"active", "inactive", "link", "state"},
    "stp_port": {
        "desgBridge",
        "desgPortId",
        "edgeOper",
        "p2pOper",
        "pathCostOper",
        "role",
        "state",
    },
}

LIST_KEYS = ("pid", "id", "portId", "vid")
MAX_WARNINGS = 100


def decrypt(path: pathlib.Path, sops_bin: str) -> dict:
    config = path.parent / ".sops.yaml"
    command = [sops_bin]
    if config.is_file():
        command += ["--config", str(config)]
    command += ["--decrypt", "--output-type", "json", str(path)]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"could not decrypt {path}: {result.stderr.strip()}")
    return json.loads(result.stdout)


def read(session: Session, commands: list[str]) -> tuple[dict, dict]:
    current = {}
    unavailable = {}
    for command in commands:
        try:
            next_key = PAGINATED.get(command)
            current[command] = (
                paginate(session, command, next_key)
                if next_key is not None
                else session.get(command)
            )
        except DeviceError as error:
            unavailable[command] = str(error)
    return current, unavailable


def normalize(config: dict) -> dict:
    normalized = copy.deepcopy(config)
    for endpoint in DROP_ENDPOINTS:
        normalized.pop(endpoint, None)
    for endpoint, fields in DROP_FIELDS.items():
        payload = normalized.get(endpoint)
        if isinstance(payload, dict):
            for field in fields:
                payload.pop(field, None)
    for endpoint, fields in DROP_LIST_FIELDS.items():
        payload = normalized.get(endpoint)
        if not isinstance(payload, dict):
            continue
        for entry in payload.get("list") or []:
            if isinstance(entry, dict):
                for field in fields:
                    entry.pop(field, None)
    return _sort_lists(normalized)


def _sort_lists(value: object) -> object:
    if isinstance(value, dict):
        return {key: _sort_lists(item) for key, item in value.items()}
    if not isinstance(value, list):
        return value
    processed = [_sort_lists(item) for item in value]
    if not processed or not all(isinstance(item, dict) for item in processed):
        return processed
    for key in LIST_KEYS:
        if all(key in item for item in processed):
            return sorted(
                processed, key=lambda item: (str(type(item[key])), str(item[key]))
            )
    return processed


def differences(
    expected: object, current: object, path: str = ""
) -> list[tuple[str, object, object]]:
    if type(expected) is not type(current):
        return [(path, expected, current)]
    if isinstance(expected, dict):
        found = []
        for key in sorted(set(expected) | set(current)):
            child = f"{path}.{key}" if path else key
            if key not in expected:
                found.append((child, "<missing>", current[key]))
            elif key not in current:
                found.append((child, expected[key], "<missing>"))
            else:
                found.extend(differences(expected[key], current[key], child))
        return found
    if isinstance(expected, list):
        found = []
        for index in range(max(len(expected), len(current))):
            child = f"{path}[{index}]"
            if index >= len(expected):
                found.append((child, "<missing>", current[index]))
            elif index >= len(current):
                found.append((child, expected[index], "<missing>"))
            else:
                found.extend(differences(expected[index], current[index], child))
        return found
    return [] if expected == current else [(path, expected, current)]


def render(value: object, path: str) -> str:
    key = path.rsplit(".", 1)[-1].split("[", 1)[0]
    return json.dumps(redact(value, key), sort_keys=True)


def inspect(session: Session, path: pathlib.Path, sops_bin: str) -> list[str]:
    if not path.is_file():
        return [f"encrypted baseline is missing: {path}"]
    baseline = decrypt(path, sops_bin)
    expected = baseline.get("config") or {}
    current, unavailable = read(session, list(expected))
    warnings = [f"{command}: {error}" for command, error in sorted(unavailable.items())]
    comparable = {
        command: payload
        for command, payload in expected.items()
        if command not in unavailable
    }
    for path_name, old, new in differences(normalize(comparable), normalize(current)):
        warnings.append(
            f"{path_name}: baseline={render(old, path_name)} current={render(new, path_name)}"
        )
        if len(warnings) >= MAX_WARNINGS:
            warnings.append("additional baseline differences omitted")
            break
    return warnings
