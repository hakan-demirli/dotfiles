from __future__ import annotations

from switchclient import (
    MANAGEMENT_PLATFORM,
    Session,
    hex_to_pids,
    paginate,
    pids_to_hex,
    port_name,
)

TIER_SAFE = 1
TIER_MANAGEMENT = 2
UNSET_ADDRESS = "0.0.0.0"

PLATFORM_VALUE = {name: value for value, name in MANAGEMENT_PLATFORM.items()}


class Rule:
    tier = TIER_SAFE

    def __init__(self, subject: str) -> None:
        self.subject = subject

    def actual(self, session: Session) -> object:
        raise NotImplementedError

    def wanted(self) -> object:
        raise NotImplementedError

    def apply(self, session: Session) -> None:
        raise NotImplementedError

    def blocked_reason(self) -> str | None:
        return None


class FieldRule(Rule):
    def __init__(
        self,
        subject: str,
        read: str,
        write: str,
        decode,
        want: object,
        encode,
        tier: int = TIER_SAFE,
    ) -> None:
        super().__init__(subject)
        self.read = read
        self.write = write
        self.decode = decode
        self.want = want
        self.encode = encode
        self.tier = tier

    def actual(self, session: Session) -> object:
        return self.decode(session.get(self.read))

    def wanted(self) -> object:
        return self.want

    def apply(self, session: Session) -> None:
        session.post(self.write, self.encode(session.get(self.read), self.want))


class TrustedPortRule(Rule):
    def __init__(self, uplink_pid: int | None, ports: dict) -> None:
        super().__init__("dhcp snooping trusted port")
        self.uplink_pid = uplink_pid
        self.ports = ports

    def _trusted(self, session: Session) -> list[int]:
        entries = session.get("get_dhcp_snoop_list").get("list") or []
        return sorted(
            entry.get("portId") for entry in entries if entry.get("mode") == 1
        )

    def actual(self, session: Session) -> object:
        return [self.ports.get(pid, pid) for pid in self._trusted(session)]

    def wanted(self) -> object:
        if self.uplink_pid is None:
            return "uplink (undiscoverable)"
        return [self.ports.get(self.uplink_pid, self.uplink_pid)]

    def apply(self, session: Session) -> None:
        stale = [pid for pid in self._trusted(session) if pid != self.uplink_pid]
        session.post(
            "set_dhcp_snoop_list",
            _snoop_payload(pids_to_hex([self.uplink_pid]), 1),
        )
        if stale:
            session.post(
                "set_dhcp_snoop_list",
                _snoop_payload(pids_to_hex(stale), 0),
            )

    def blocked_reason(self) -> str | None:
        if self.uplink_pid is None:
            return "the uplink did not resolve to exactly one port"
        return None


def _snoop_payload(port_map: str, mode: int) -> dict:
    return {
        "portMap": port_map,
        "mode": mode,
        "op82": 0,
        "op82Mode": 0,
        "cIdMode": 0,
        "cId": "",
        "rIdMode": 0,
        "rId": "",
    }


class ManagementAddressRule(Rule):
    tier = TIER_MANAGEMENT

    def __init__(self, management: dict) -> None:
        super().__init__("management address block")
        self.management = management
        self.retarget = management["address"]

    def actual(self, session: Session) -> object:
        payload = session.get("get_ip")
        return {
            "mode": "dhcp" if payload.get("dhcpStatus") else "static",
            "address": payload.get("ipAddr"),
            "netmask": payload.get("netMask"),
            "gateway": payload.get("gateway"),
            "dns": [payload.get("dnsServer1"), payload.get("dnsServer2")],
        }

    def wanted(self) -> object:
        return {
            "mode": "static",
            "address": self.management["address"],
            "netmask": self.management["netmask"],
            "gateway": self.management["gateway"] or UNSET_ADDRESS,
            "dns": self._dns(),
        }

    def _dns(self) -> list[str]:
        configured = self.management["dns"]
        if not configured:
            return [UNSET_ADDRESS, UNSET_ADDRESS]
        return [*list(configured), UNSET_ADDRESS, UNSET_ADDRESS][:2]

    def apply(self, session: Session) -> None:
        current = session.get("get_ip")
        session.post(
            "set_ip",
            {
                **current,
                "dhcpStatus": 0,
                "ipAddr": self.management["address"],
                "netMask": self.management["netmask"],
                "gateway": self.management["gateway"] or UNSET_ADDRESS,
                "dnsEn": 0,
                "dnsServer1": self._dns()[0],
                "dnsServer2": self._dns()[1],
            },
        )


class MirrorRule(Rule):
    def __init__(self, wanted_sessions: list) -> None:
        super().__init__("mirror sessions")
        self.want = wanted_sessions

    def _active(self, session: Session) -> list:
        return [
            entry
            for entry in session.get("get_mirror_info").get("list") or []
            if entry.get("obPort")
        ]

    def actual(self, session: Session) -> object:
        return len(self._active(session))

    def wanted(self) -> object:
        return len(self.want)

    def apply(self, session: Session) -> None:
        for entry in self._active(session):
            session.post("reset_mirror_list", {"session": entry.get("id")})


class PortUniformRule(Rule):
    FIELDS = (
        ("enable", "enable", "enabled"),
        ("autoNegotiation", "ANEn", "autonegotiation"),
        ("flowControl", "flowCtl", "flow control"),
    )

    def __init__(self, name: str, pid: int, wanted: dict) -> None:
        super().__init__(f"port {name}")
        self.name = name
        self.pid = pid
        self.want = wanted

    def _entry(self, session: Session) -> dict:
        for entry in paginate(session, "get_port", "pid")["list"]:
            if entry.get("pid") == self.pid:
                return entry
        raise RuntimeError(f"port {self.name} vanished from get_port")

    def actual(self, session: Session) -> object:
        entry = self._entry(session)
        return {label: bool(entry.get(field)) for _, field, label in self.FIELDS}

    def wanted(self) -> object:
        return {label: bool(self.want[key]) for key, _, label in self.FIELDS}

    def apply(self, session: Session) -> None:
        entry = self._entry(session)
        payload = {
            "portMap": pids_to_hex([self.pid]),
            "type": entry["type"],
            "descr": entry.get("descr") or "",
            "ANEn": entry["ANEn"],
            "enable": entry["enable"],
            "speed": entry["speed"],
            "duplex": entry["duplex"],
            "flowCtl": entry["flowCtl"],
        }
        for key, field, _ in self.FIELDS:
            payload[field] = 1 if self.want[key] else 0
        session.post("set_port", payload)


def build_rules(
    session: Session,
    desired: dict,
    uplink_pid: int | None,
) -> list[Rule]:
    hardening = desired["hardening"]
    management = desired["management"]
    ports = {
        entry["pid"]: port_name(entry)
        for entry in paginate(session, "get_port", "pid")["list"]
    }

    def toggle(subject, read, write, field, want, tier=TIER_SAFE, whole=True):
        def encode(current, wanted):
            value = 1 if wanted else 0
            return {**current, field: value} if whole else {field: value}

        return FieldRule(
            subject,
            read,
            write,
            lambda payload: bool(payload.get(field)),
            want,
            encode,
            tier,
        )

    rules: list[Rule] = [
        FieldRule(
            "management platform",
            "manager_prop",
            "manager_prop",
            lambda p: MANAGEMENT_PLATFORM.get(
                p.get("connManagementPlatform"), "unknown"
            ),
            hardening["managementPlatform"],
            lambda current, want: {
                **current,
                "connManagementPlatform": PLATFORM_VALUE[want],
            },
        ),
        toggle(
            "dhcp option 43 override",
            "manager_prop",
            "manager_prop",
            "dhcpOptionOverwrite",
            hardening["dhcpOption43Override"],
        ),
        toggle(
            "snmp enabled",
            "snmp_global",
            "snmp_global",
            "snmpStatus",
            hardening["snmp"]["enable"],
        ),
        toggle(
            "lldp enabled",
            "get_lldp_config",
            "lldp_set_config",
            "lldpStatus",
            hardening["lldp"]["enable"],
        ),
        toggle(
            "stp enabled",
            "stp_global",
            "stp_global",
            "enable",
            hardening["stp"]["enable"],
        ),
        toggle(
            "igmp snooping enabled",
            "get_snooping_info",
            "set_igmp_snooping",
            "igmpEn",
            hardening["igmpSnooping"]["enable"],
        ),
        toggle(
            "loop detection enabled",
            "get_loop_info",
            "set_port_loop",
            "loopEn",
            hardening["loopDetection"]["enable"],
            whole=False,
        ),
        MirrorRule(hardening["mirror"]["sessions"]),
    ]

    uniform = desired["ports"]["uniform"]
    overrides = desired["ports"]["overrides"]
    for pid, name in sorted(ports.items()):
        rules.append(PortUniformRule(name, pid, {**uniform, **overrides.get(name, {})}))

    if hardening["dhcpSnooping"]["enable"]:
        rules.append(TrustedPortRule(uplink_pid, ports))
        rules.append(
            toggle(
                "dhcp snooping enabled",
                "get_dhcp_snoop_state",
                "set_dhcp_snoop_state",
                "state",
                True,
            )
        )

    rules += [
        FieldRule(
            "management vlan",
            "get_admin_vlan",
            "set_admin_vlan",
            lambda p: p.get("adminVid"),
            management["vlan"],
            lambda current, want: {**current, "adminVid": want},
            TIER_MANAGEMENT,
        ),
        ManagementAddressRule(management),
    ]

    return rules


def find_uplink(lookup: dict) -> int | None:
    found = set()
    for entry in lookup.get("list") or []:
        found.update(hex_to_pids(entry.get("portMap")))
    return found.pop() if len(found) == 1 else None
