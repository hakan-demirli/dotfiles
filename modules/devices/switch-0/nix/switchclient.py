from __future__ import annotations

import hashlib
import json
import re
import socket
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request

DEFAULT_TIMEOUT = 15
FIRMWARE_KEY = "sysVer"
LIST_PREVIEW = 64
MAC_SEARCH_INTERVAL = 2
MAC_SEARCH_TIMEOUT = 30

COMMAND_TIMEOUT = {
    "stp_global": 120,
    "get_storm_ctrl_info": 30,
    "get_port_rate": 30,
}

PORT_TYPE = {0: "GE", 1: "2.5GE", 2: "2.5SFP", 3: "SFP+", 4: "10GE", 5: "SFP"}
SPEED = {0: "10M", 1: "100M", 2: "1G", 3: "2.5G", 4: "10G", 5: "5G"}
MANAGEMENT_PLATFORM = {
    0: "auto",
    1: "gdms",
    2: "l3-manager",
    3: "l2-manager",
    4: "l2-router",
    5: "l3-router",
}

SENSITIVE_KEY = re.compile(
    r"mac|serial|devsn|devpn|(^|_)(sn|pn)($|_)|addr|gateway|dns|passw"
    r"|community|secret|token|location|contact|descr|hostname|oui|ssid|user|part",
    re.IGNORECASE,
)
SAFE_STRING = re.compile(
    r"^(?:-?\d+(?:\.\d+)?|2\.5GE\d+|SFP\+\d+|LAG\d+|[A-Za-z][A-Za-z0-9_-]{0,15})$"
)


class DeviceError(RuntimeError):
    pass


def hex_to_pids(value: object) -> list[int]:
    if value in (None, ""):
        return []
    try:
        bits = int(str(value), 16)
    except ValueError:
        return []
    return [pid for pid in range(1, 64) if bits >> pid & 1]


def pids_to_hex(pids: list[int]) -> str:
    bits = 0
    for pid in pids:
        bits |= 1 << pid
    return format(bits, "x")


def port_name(entry: dict) -> str:
    return f"{PORT_TYPE.get(entry.get('type'), '?')}{entry.get('pid')}"


class Session:
    def __init__(self, base: str) -> None:
        self.base = base.rstrip("/")
        self.token = ""

    def _request(
        self,
        method: str,
        cmd: str,
        params: dict | None,
        body: dict | None,
        timeout: int,
    ) -> dict:
        path = "/set.cgi" if method == "POST" else "/get.cgi"
        query = {"cmd": cmd}
        if params:
            query.update(params)
        url = f"{self.base}{path}?{urllib.parse.urlencode(query)}"

        data = json.dumps(body).encode() if body is not None else None
        request = urllib.request.Request(url, data=data, method=method)
        if self.token:
            request.add_header("Authorization", self.token)
        if data is not None:
            request.add_header("Content-Type", "application/json")

        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                raw = response.read()
        except (urllib.error.URLError, OSError) as error:
            raise DeviceError(f"{cmd} transport failure: {error}") from error

        try:
            envelope = json.loads(raw)
        except json.JSONDecodeError as error:
            raise DeviceError(f"{cmd} returned non-JSON") from error

        code = envelope.get("code")
        if code != 200:
            message = envelope.get("msg", "unknown")
            raise DeviceError(f"{cmd} rejected with code {code}: {message}")

        payload = envelope.get("data")
        return payload if isinstance(payload, dict) else {"value": payload}

    def get(self, cmd: str, params: dict | None = None) -> dict:
        return self._request(
            "GET", cmd, params, None, COMMAND_TIMEOUT.get(cmd, DEFAULT_TIMEOUT)
        )

    def post(self, cmd: str, body: dict | None = None) -> dict:
        return self._request(
            "POST", cmd, None, body or {}, COMMAND_TIMEOUT.get(cmd, DEFAULT_TIMEOUT)
        )


class Tunnel:
    def __init__(self, ssh_host: str, host: str, port: int, log=None) -> None:
        self.ssh_host = ssh_host
        self.host = host
        self.port = port
        self.log = log or (lambda _message: None)
        self.process: subprocess.Popen | None = None

    def __enter__(self) -> str:
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            local_port = probe.getsockname()[1]

        self.process = subprocess.Popen(
            [
                "ssh",
                "-N",
                "-o",
                "BatchMode=yes",
                "-o",
                "ExitOnForwardFailure=yes",
                "-o",
                "ConnectTimeout=10",
                "-L",
                f"127.0.0.1:{local_port}:{self.host}:{self.port}",
                self.ssh_host,
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )

        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                detail = (self.process.stderr or b"").read()
                detail = detail.decode(errors="replace").strip()
                raise DeviceError(f"ssh tunnel via {self.ssh_host} failed: {detail}")
            try:
                with socket.create_connection(("127.0.0.1", local_port), timeout=1):
                    self.log(f"tunnel established via {self.ssh_host}")
                    return f"http://127.0.0.1:{local_port}"
            except OSError:
                time.sleep(0.2)

        self.__exit__()
        raise DeviceError(f"ssh tunnel via {self.ssh_host} did not come up")

    def __exit__(self, *_: object) -> None:
        if self.process is None or self.process.poll() is not None:
            return
        self.process.terminate()
        try:
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()


def authenticate(session: Session, user: str, password: str) -> dict:
    nonce = session.get("get_nonce").get("nonce")
    if not nonce:
        raise DeviceError("device did not return a nonce")
    digest = hashlib.sha256(f"{user}:{nonce}:{password}".encode()).hexdigest()
    credentials = session.post("login", {"username": user, "password": digest})
    token = credentials.get("token")
    if not token:
        raise DeviceError("login succeeded but returned no token")
    session.token = token
    return credentials


def paginate(session: Session, cmd: str, next_key: str) -> dict:
    collected: list = []
    index = 0
    for _ in range(64):
        payload = session.get(cmd, {"index": index})
        chunk = payload.get("list") or []
        collected.extend(chunk)
        remain = payload.get("remain") or 0
        if remain <= 0 or not chunk:
            break
        following = chunk[-1].get(next_key)
        if following is None or following == index:
            break
        index = following
    return {"list": collected}


def drain_mac_result(session: Session) -> tuple[int, list]:
    collected: list = []
    index = 0
    complete = 0
    for _ in range(64):
        payload = session.get("mac_search_result", {"index": index})
        collected.extend(payload.get("list") or [])
        complete = payload.get("isOK") or 0
        count = payload.get("count") or 0
        remain = payload.get("remain") or 0
        if not (complete and count and remain > 0):
            break
        if count == index:
            break
        index = count
    return complete, collected


def mac_lookup(session: Session, mac: str) -> dict:
    session.post("mac_search", {"macAddr": mac})
    deadline = time.monotonic() + MAC_SEARCH_TIMEOUT
    while time.monotonic() < deadline:
        time.sleep(MAC_SEARCH_INTERVAL)
        complete, collected = drain_mac_result(session)
        if complete:
            return {"isOK": complete, "list": collected}
    return {"isOK": 0, "list": [], "timedOut": True}


def redact(value: object, key: str | None = None) -> object:
    if isinstance(value, dict):
        return {name: redact(item, name) for name, item in sorted(value.items())}
    if isinstance(value, list):
        preview = [redact(item, key) for item in value[:LIST_PREVIEW]]
        if len(value) > LIST_PREVIEW:
            preview.append(f"<+{len(value) - LIST_PREVIEW} more>")
        return preview
    if key is not None and SENSITIVE_KEY.search(key):
        return f"<{type(value).__name__}>"
    if isinstance(value, (bool, int, float)) or value is None:
        return value
    text = str(value)
    return text if SAFE_STRING.match(text) else f"<str:{len(text)}>"
