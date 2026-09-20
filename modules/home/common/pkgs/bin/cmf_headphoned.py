#!/usr/bin/env python3

import argparse
import asyncio
import contextlib
import enum
import json
import os
import re
import signal
import socket
import struct
import sys
from collections.abc import AsyncIterator, Callable, Iterator
from dataclasses import dataclass, replace
from pathlib import Path

from dbus_fast import BusType, DBusError, Variant
from dbus_fast.aio import MessageBus, ProxyInterface, ProxyObject
from dbus_fast.constants import PropertyAccess
from dbus_fast.service import ServiceInterface, dbus_property, method

PROGRAM = "cmf-headphoned"

TOTA_UUID = "aeac4a03-dff5-498f-843a-34487cf133eb"

BLUEZ_SERVICE = "org.bluez"
BLUEZ_ROOT = "/org/bluez"
OBJECT_ROOT = "/"
DBUS_SERVICE = "org.freedesktop.DBus"
DBUS_PATH = "/org/freedesktop/DBus"
DEVICE_INTERFACE = "org.bluez.Device1"
PROFILE_INTERFACE = "org.bluez.Profile1"
PROFILE_MANAGER_INTERFACE = "org.bluez.ProfileManager1"
BATTERY_PROVIDER_INTERFACE = "org.bluez.BatteryProvider1"
BATTERY_PROVIDER_MANAGER_INTERFACE = "org.bluez.BatteryProviderManager1"
OBJECT_MANAGER_INTERFACE = "org.freedesktop.DBus.ObjectManager"
PROPERTIES_INTERFACE = "org.freedesktop.DBus.Properties"

PROFILE_PATH = "/org/cmf/headphoned/profile"
PROVIDER_ROOT = "/org/cmf/headphoned/battery"
PROVIDER_PATH = f"{PROVIDER_ROOT}/headphone"

DEVICE_NODE_PREFIX = "dev_"
CONNECTED_PROPERTY = "Connected"
UUIDS_PROPERTY = "UUIDs"
DEVICE_TRIGGERS = frozenset({CONNECTED_PROPERTY, "ServicesResolved", UUIDS_PROPERTY})
ADDRESS_PATTERN = re.compile(r"[0-9A-F]{2}(?::[0-9A-F]{2}){5}")

SIGNATURE_OBJECT_PATH = "o"
SIGNATURE_BYTE = "y"
SIGNATURE_STRING = "s"
SIGNATURE_UNIX_FD = "h"
SIGNATURE_OPTIONS = "a{sv}"

SYNC = 0x55
FLAG_CRC = 0x60
TARGET = 0x01
SEQUENCE = 0x01
HEADER_LEN = 8
CRC_LEN = 2
READ_SIZE = 4096
RESPONSE_MASK = 0x7FFF

PERCENTAGE_MASK = 0x7F
FULL_PERCENTAGE = 100
BATTERY_LEVEL_OFFSET = 2

ANC_RECORD_LEN = 3
ANC_FIELD_MODE = 0x01
ANC_FIELD_LEVEL = 0x02
ANC_ATTEMPTS = 2
ANC_RETRY_DELAY = 0.5
ANC_CONFIRM_TIMEOUT = 5.0

LDAC_RESTART_TIMEOUT = 30.0

VENDOR_ATTEMPTS = 3
VENDOR_RETRY_DELAY = 2.0


def log(message: str) -> None:
    print(f"{PROGRAM}: {message}", file=sys.stderr, flush=True)


class Command(enum.IntEnum):
    GET_BATTERY = 0xC007
    GET_ANC = 0xC01E
    GET_LDAC = 0xC029
    SET_ANC = 0xF00F
    SET_LDAC = 0xF01C
    EVENT_BATTERY = 0xE001
    EVENT_ANC = 0xE003

    @property
    def reply(self) -> int:
        return self.value & RESPONSE_MASK


class Anc(enum.Enum):
    HIGH = (0x01, "high")
    MID = (0x02, "mid")
    LOW = (0x03, "low")
    ADAPTIVE = (0x04, "adaptive")
    OFF = (0x05, "off")
    TRANSPARENCY = (0x07, "transparency")

    def __init__(self, code: int, label: str) -> None:
        self.code = code
        self.label = label

    @property
    def cancelling(self) -> bool:
        return self not in (Anc.OFF, Anc.TRANSPARENCY)


ANC_BY_CODE = {mode.code: mode for mode in Anc}
ANC_BY_LABEL = {mode.label: mode for mode in Anc}


@dataclass(frozen=True, slots=True)
class Frame:
    command: int
    payload: bytes


@dataclass(frozen=True, slots=True)
class State:
    connected: bool = False
    restarting: bool = False
    address: str | None = None
    battery: int | None = None
    anc: Anc | None = None
    level: Anc | None = None
    ldac: bool | None = None

    def encode(self) -> bytes:
        report = {
            "connected": self.connected,
            "restarting": self.restarting,
            "address": self.address,
            "battery": self.battery,
            "anc": self.anc.label if self.anc else None,
            "level": self.level.label if self.level else None,
            "ldac": self.ldac,
        }
        return json.dumps(report).encode() + b"\n"


@dataclass(frozen=True, slots=True)
class Watch:
    device: ProxyInterface
    properties: ProxyInterface
    handler: Callable[[str, dict[str, Variant], list[str]], None]


def decode_address(device_path: str) -> str | None:
    node = device_path.rsplit("/", 1)[-1]
    if not node.startswith(DEVICE_NODE_PREFIX):
        return None
    address = node[len(DEVICE_NODE_PREFIX) :].replace("_", ":").upper()
    return address if ADDRESS_PATTERN.fullmatch(address) else None


def is_connected(properties: dict[str, Variant]) -> bool:
    entry = properties.get(CONNECTED_PROPERTY)
    return entry is not None and entry.value is True


def offers_vendor_channel(properties: dict[str, Variant]) -> bool:
    entry = properties.get(UUIDS_PROPERTY)
    return entry is not None and TOTA_UUID in {uuid.casefold() for uuid in entry.value}


def crc16_modbus(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if crc & 1 else crc >> 1
    return crc


def build_frame(command: Command, payload: bytes = b"") -> bytes:
    body = (
        bytes([SYNC, FLAG_CRC, TARGET])
        + struct.pack("<HH", command.value, len(payload))
        + bytes([SEQUENCE])
        + payload
    )
    return body + struct.pack("<H", crc16_modbus(body))


def decode_battery(payload: bytes) -> int | None:
    if len(payload) <= BATTERY_LEVEL_OFFSET:
        return None
    percentage = payload[BATTERY_LEVEL_OFFSET] & PERCENTAGE_MASK
    return percentage if percentage <= FULL_PERCENTAGE else None


def decode_anc_records(payload: bytes) -> dict[int, int]:
    return {
        payload[offset]: payload[offset + 1]
        for offset in range(0, len(payload) - 1, ANC_RECORD_LEN)
    }


def decode_anc(payload: bytes) -> Anc | None:
    records = decode_anc_records(payload)
    if ANC_FIELD_MODE not in records:
        return None
    return ANC_BY_CODE.get(records[ANC_FIELD_MODE])


def decode_anc_level(payload: bytes) -> Anc | None:
    records = decode_anc_records(payload)
    if ANC_FIELD_LEVEL not in records:
        return None
    level = ANC_BY_CODE.get(records[ANC_FIELD_LEVEL])
    return level if level is not None and level.cancelling else None


def decode_ldac(payload: bytes) -> bool | None:
    return bool(payload[-1]) if payload else None


class FrameReader:
    def __init__(self) -> None:
        self._buffer = bytearray()

    def feed(self, chunk: bytes) -> Iterator[Frame]:
        self._buffer += chunk
        while True:
            frame, consumed = self._take()
            if not consumed:
                return
            del self._buffer[:consumed]
            if frame is not None:
                yield frame

    def _take(self) -> tuple[Frame | None, int]:
        buffer = self._buffer
        if not buffer:
            return None, 0
        if buffer[0] != SYNC:
            offset = buffer.find(SYNC, 1)
            return None, len(buffer) if offset < 0 else offset
        if len(buffer) < HEADER_LEN:
            return None, 0
        command, length = struct.unpack_from("<HH", buffer, 3)
        trailer = CRC_LEN if buffer[1] & FLAG_CRC else 0
        end = HEADER_LEN + length + trailer
        if len(buffer) < end:
            return None, 0
        if trailer:
            carried = struct.unpack_from("<H", buffer, end - CRC_LEN)[0]
            if carried != crc16_modbus(buffer[: end - CRC_LEN]):
                return None, 1
        payload = bytes(buffer[HEADER_LEN : HEADER_LEN + length])
        return Frame(command, payload), end


class Link:
    def __init__(self, descriptor: int) -> None:
        self._socket = socket.socket(
            socket.AF_BLUETOOTH,
            socket.SOCK_STREAM,
            socket.BTPROTO_RFCOMM,
            fileno=descriptor,
        )
        self._socket.setblocking(False)
        self._reader = FrameReader()
        self._loop = asyncio.get_running_loop()

    async def send(self, command: Command, payload: bytes = b"") -> None:
        await self._loop.sock_sendall(self._socket, build_frame(command, payload))

    async def frames(self) -> AsyncIterator[Frame]:
        while True:
            chunk = await self._loop.sock_recv(self._socket, READ_SIZE)
            if not chunk:
                return
            for frame in self._reader.feed(chunk):
                yield frame

    def close(self) -> None:
        self._socket.close()


class BatteryProvider(ServiceInterface):
    def __init__(self, device_path: str, percentage: int) -> None:
        super().__init__(BATTERY_PROVIDER_INTERFACE)
        self._device_path = device_path
        self._percentage = percentage

    @dbus_property(access=PropertyAccess.READ)
    def Device(self) -> SIGNATURE_OBJECT_PATH:
        return self._device_path

    @dbus_property(access=PropertyAccess.READ)
    def Percentage(self) -> SIGNATURE_BYTE:
        return self._percentage

    @dbus_property(access=PropertyAccess.READ)
    def Source(self) -> SIGNATURE_STRING:
        return PROGRAM

    def update(self, percentage: int) -> None:
        if percentage == self._percentage:
            return
        self._percentage = percentage
        self.emit_properties_changed({"Percentage": percentage})


class Profile(ServiceInterface):
    def __init__(self, daemon: "Daemon") -> None:
        super().__init__(PROFILE_INTERFACE)
        self._daemon = daemon

    @method()
    async def NewConnection(
        self,
        device: SIGNATURE_OBJECT_PATH,
        fd: SIGNATURE_UNIX_FD,
        options: SIGNATURE_OPTIONS,
    ):
        await self._daemon.attach(device, fd)

    @method()
    async def RequestDisconnection(self, device: SIGNATURE_OBJECT_PATH):
        await self._daemon.detach(device)

    @method()
    async def Release(self):
        await self._daemon.detach(None)


class Daemon:
    def __init__(self, bus: MessageBus, socket_path: Path) -> None:
        self._bus = bus
        self._socket_path = socket_path
        self._state = State()
        self._device_path: str | None = None
        self._link: Link | None = None
        self._provider: BatteryProvider | None = None
        self._provider_adapter: str | None = None
        self._objects: ProxyInterface | None = None
        self._watches: dict[str, Watch] = {}
        self._connecting: set[str] = set()
        self._server: asyncio.Server | None = None
        self._link_task: asyncio.Task | None = None
        self._restart_task: asyncio.Task | None = None
        self._tasks: set[asyncio.Task] = set()
        self._clients: set[asyncio.StreamWriter] = set()
        self._condition = asyncio.Condition()
        self._control = asyncio.Lock()

    @classmethod
    async def connect(cls, socket_path: Path) -> "Daemon":
        bus = MessageBus(bus_type=BusType.SYSTEM, negotiate_unix_fd=True)
        return cls(await bus.connect(), socket_path)

    def _spawn(self, coroutine) -> asyncio.Task:
        task = asyncio.create_task(coroutine)
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)
        return task

    async def _proxy(self, path: str, service: str = BLUEZ_SERVICE) -> ProxyObject:
        introspection = await self._bus.introspect(service, path)
        return self._bus.get_proxy_object(service, path, introspection)

    async def _interface(
        self, path: str, name: str, service: str = BLUEZ_SERVICE
    ) -> ProxyInterface:
        proxy = await self._proxy(path, service)
        return proxy.get_interface(name)

    async def start(self) -> None:
        await self._listen()
        self._bus.export(PROFILE_PATH, Profile(self))
        dbus = await self._interface(DBUS_PATH, DBUS_SERVICE, service=DBUS_SERVICE)
        dbus.on_name_owner_changed(self._on_name_owner_changed)
        if await dbus.call_name_has_owner(BLUEZ_SERVICE):
            await self._bind()
        else:
            log("waiting for bluetoothd")

    async def _listen(self) -> None:
        self._socket_path.parent.mkdir(parents=True, exist_ok=True)
        if self._socket_path.exists():
            if await self._answered():
                raise SystemExit(
                    f"{PROGRAM}: another instance is serving {self._socket_path}"
                )
            self._socket_path.unlink()
        self._server = await asyncio.start_unix_server(
            self._serve_client, path=self._socket_path
        )
        log(f"listening on {self._socket_path}")

    async def _answered(self) -> bool:
        try:
            _, writer = await asyncio.open_unix_connection(self._socket_path)
        except OSError:
            return False
        writer.close()
        with contextlib.suppress(OSError, ConnectionError):
            await writer.wait_closed()
        return True

    async def stop(self) -> None:
        await self.detach(None)
        if self._server is not None:
            self._server.close()
            for writer in tuple(self._clients):
                writer.close()
            with contextlib.suppress(OSError):
                await self._server.wait_closed()
            self._socket_path.unlink(missing_ok=True)
        self._bus.disconnect()

    async def _bind(self) -> None:
        await self._register_profile()
        await self._observe()

    async def _observe(self) -> None:
        if self._objects is None:
            self._objects = await self._interface(OBJECT_ROOT, OBJECT_MANAGER_INTERFACE)
            self._objects.on_interfaces_added(self._track)
            self._objects.on_interfaces_removed(self._on_interfaces_removed)
        objects = await self._objects.call_get_managed_objects()
        for path in tuple(self._watches):
            if path not in objects:
                self._untrack(path)
        for path, interfaces in objects.items():
            await self._track(path, interfaces)

    async def _track(
        self, path: str, interfaces: dict[str, dict[str, Variant]]
    ) -> None:
        if DEVICE_INTERFACE not in interfaces:
            return
        with contextlib.suppress(DBusError):
            if path not in self._watches:
                proxy = await self._proxy(path)
                properties = proxy.get_interface(PROPERTIES_INTERFACE)
                handler = self._watcher(path)
                properties.on_properties_changed(handler)
                self._watches[path] = Watch(
                    proxy.get_interface(DEVICE_INTERFACE), properties, handler
                )
            await self._ensure(path)

    def _untrack(self, path: str) -> None:
        watch = self._watches.pop(path, None)
        if watch is not None:
            watch.properties.off_properties_changed(watch.handler)

    def _watcher(
        self, path: str
    ) -> Callable[[str, dict[str, Variant], list[str]], None]:
        def changed(
            interface: str, values: dict[str, Variant], invalidated: list[str]
        ) -> None:
            if interface == DEVICE_INTERFACE and not DEVICE_TRIGGERS.isdisjoint(values):
                self._spawn(self._ensure(path))

        return changed

    def _on_interfaces_removed(self, path: str, interfaces: list[str]) -> None:
        if DEVICE_INTERFACE in interfaces:
            self._untrack(path)

    async def _ensure(self, path: str) -> None:
        watch = self._watches.get(path)
        if watch is None or self._link is not None or path in self._connecting:
            return
        with contextlib.suppress(DBusError):
            properties = await watch.properties.call_get_all(DEVICE_INTERFACE)
            if is_connected(properties) and offers_vendor_channel(properties):
                await self._open(path, watch)

    async def _open(self, path: str, watch: Watch) -> None:
        self._connecting.add(path)
        try:
            for attempt in range(VENDOR_ATTEMPTS):
                if attempt:
                    await asyncio.sleep(VENDOR_RETRY_DELAY)
                if self._link is not None:
                    return
                properties = await watch.properties.call_get_all(DEVICE_INTERFACE)
                if not is_connected(properties):
                    return
                try:
                    await watch.device.call_connect_profile(TOTA_UUID)
                    return
                except DBusError as error:
                    log(f"vendor channel refused by {path}: {error.text}")
        finally:
            self._connecting.discard(path)

    async def _register_profile(self) -> None:
        manager = await self._interface(BLUEZ_ROOT, PROFILE_MANAGER_INTERFACE)
        await manager.call_register_profile(
            PROFILE_PATH,
            TOTA_UUID,
            {
                "Name": Variant("s", PROGRAM),
                "Role": Variant("s", "client"),
                "AutoConnect": Variant("b", True),
                "RequireAuthentication": Variant("b", False),
                "RequireAuthorization": Variant("b", False),
            },
        )
        log(f"registered profile for {TOTA_UUID}")

    def _on_name_owner_changed(self, name: str, old: str, new: str) -> None:
        if name == BLUEZ_SERVICE and new:
            self._spawn(self._rebind())

    async def _rebind(self) -> None:
        log("bluetoothd appeared, registering")
        self._provider_adapter = None
        await self._release()
        await self._bind()

    async def attach(self, device_path: str, descriptor: int) -> None:
        await self.detach(None)
        self._device_path = device_path
        link = Link(descriptor)
        self._link = link
        self._link_task = self._spawn(self._serve_link(link))
        self._cancel_restart()
        await self._publish(
            replace(
                self._state,
                connected=True,
                restarting=False,
                address=decode_address(device_path),
            )
        )
        log(f"attached to {device_path}")

    async def detach(self, device_path: str | None) -> None:
        if self._link is None:
            return
        if device_path is not None and device_path != self._device_path:
            return
        task = self._link_task
        self._link_task = None
        if task is not None:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task
        await self._release()

    async def _serve_link(self, link: Link) -> None:
        try:
            for command in (Command.GET_BATTERY, Command.GET_ANC, Command.GET_LDAC):
                await link.send(command)
            async for frame in link.frames():
                await self._apply(frame)
        except OSError as error:
            log(f"vendor channel failed: {error}")
        finally:
            link.close()
        await self._release()

    async def _release(self) -> None:
        if self._link is None:
            return
        if self._provider is not None:
            self._bus.unexport(PROVIDER_PATH, self._provider)
            self._provider = None
        self._link = None
        self._link_task = None
        self._device_path = None
        await self._publish(State(restarting=self._state.restarting))
        log("detached")

    async def _apply(self, frame: Frame) -> None:
        state = self._state
        if frame.command in (Command.GET_BATTERY.reply, Command.EVENT_BATTERY):
            battery = decode_battery(frame.payload)
            state = state if battery is None else replace(state, battery=battery)
        elif frame.command in (Command.GET_ANC.reply, Command.EVENT_ANC):
            anc = decode_anc(frame.payload)
            level = decode_anc_level(frame.payload)
            state = state if anc is None else replace(state, anc=anc)
            state = state if level is None else replace(state, level=level)
        elif frame.command == Command.GET_LDAC.reply:
            ldac = decode_ldac(frame.payload)
            state = state if ldac is None else replace(state, ldac=ldac)
        else:
            return
        await self._publish(state)

    async def _publish(self, state: State) -> None:
        if state == self._state:
            return
        self._state = state
        await self._sync_battery()
        self._broadcast()
        async with self._condition:
            self._condition.notify_all()

    async def _sync_battery(self) -> None:
        percentage = self._state.battery
        device_path = self._device_path
        if percentage is None or device_path is None:
            return
        if self._provider is not None:
            self._provider.update(percentage)
            return
        provider = BatteryProvider(device_path, percentage)
        self._bus.export(PROVIDER_PATH, provider)
        if self._provider_adapter is None:
            adapter_path = device_path.rsplit("/", 1)[0]
            manager = await self._interface(
                adapter_path, BATTERY_PROVIDER_MANAGER_INTERFACE
            )
            await manager.call_register_battery_provider(PROVIDER_ROOT)
            self._provider_adapter = adapter_path
            log(f"registered battery provider on {adapter_path}")
        self._provider = provider

    def _broadcast(self) -> None:
        line = self._state.encode()
        for writer in tuple(self._clients):
            try:
                writer.write(line)
            except (OSError, ConnectionError):
                self._clients.discard(writer)

    async def _settled(self, predicate: Callable[[], bool], timeout: float) -> bool:
        if predicate():
            return True

        async def wait() -> None:
            async with self._condition:
                await self._condition.wait_for(predicate)

        try:
            await asyncio.wait_for(wait(), timeout)
        except TimeoutError:
            return False
        return True

    async def set_anc(self, mode: Anc) -> None:
        link = self._link
        if link is None:
            return
        async with self._control:
            for attempt in range(ANC_ATTEMPTS):
                if attempt:
                    await asyncio.sleep(ANC_RETRY_DELAY)
                await link.send(
                    Command.SET_ANC, bytes([ANC_FIELD_MODE, mode.code, 0x00])
                )
                if await self._settled(
                    lambda: self._state.anc is mode, ANC_CONFIRM_TIMEOUT
                ):
                    return
            log(f"device did not confirm noise mode {mode.label}")

    async def set_ldac(self, enabled: bool) -> None:
        link = self._link
        if link is None:
            return
        async with self._control:
            await link.send(Command.SET_LDAC, bytes([int(enabled)]))
            await self._publish(replace(self._state, ldac=enabled, restarting=True))
            self._cancel_restart()
            self._restart_task = self._spawn(self._expire_restart())

    def _cancel_restart(self) -> None:
        task = self._restart_task
        self._restart_task = None
        if task is not None:
            task.cancel()

    async def _expire_restart(self) -> None:
        await asyncio.sleep(LDAC_RESTART_TIMEOUT)
        self._restart_task = None
        await self._publish(replace(self._state, restarting=False))

    async def _serve_client(
        self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
    ) -> None:
        self._clients.add(writer)
        try:
            writer.write(self._state.encode())
            await writer.drain()
            async for line in reader:
                await self._request(line)
        except (OSError, ConnectionError):
            pass
        finally:
            self._clients.discard(writer)
            writer.close()
            with contextlib.suppress(OSError, ConnectionError):
                await writer.wait_closed()

    async def _request(self, line: bytes) -> None:
        try:
            request = json.loads(line)
        except ValueError:
            log("ignored a malformed request")
            return
        if not isinstance(request, dict):
            log("ignored a request that was not an object")
            return
        if "anc" in request:
            mode = ANC_BY_LABEL.get(str(request["anc"]))
            if mode is None:
                log(f"ignored unknown noise mode {request['anc']!r}")
            else:
                await self.set_anc(mode)
        if "ldac" in request:
            await self.set_ldac(bool(request["ldac"]))


def default_socket_path() -> Path:
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        raise SystemExit(f"{PROGRAM}: XDG_RUNTIME_DIR is unset; pass --socket")
    return Path(runtime) / f"{PROGRAM}.sock"


def parse_arguments(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog=PROGRAM)
    parser.add_argument(
        "--socket",
        type=Path,
        default=None,
        help="control socket to serve (default: $XDG_RUNTIME_DIR/cmf-headphoned.sock)",
    )
    return parser.parse_args(argv)


async def run(socket_path: Path) -> None:
    daemon = await Daemon.connect(socket_path)
    try:
        await daemon.start()
        loop = asyncio.get_running_loop()
        stopped = loop.create_future()

        def on_signal() -> None:
            if not stopped.done():
                stopped.set_result(None)

        for number in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(number, on_signal)
        await stopped
    finally:
        await daemon.stop()


def main(argv: list[str] | None = None) -> int:
    arguments = parse_arguments(argv)
    socket_path = arguments.socket or default_socket_path()
    try:
        asyncio.run(run(socket_path))
    except DBusError as error:
        log(error.text)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
