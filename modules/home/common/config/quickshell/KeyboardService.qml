pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    enum Latch {
        Free,
        Once,
        Locked
    }

    property bool active: false
    property bool docked: true
    property real positionX: 0
    property real positionY: 0
    property int lockedCode: 0
    property var latches: ({})

    readonly property bool shifted: root.latchOf(42) !== KeyboardService.Latch.Free || root.latchOf(54) !== KeyboardService.Latch.Free
    readonly property bool upper: root.shifted !== (root.lockedCode !== 0)

    function open(): void {
        root.active = true;
    }

    function close(): void {
        root.releaseAll();
        root.active = false;
    }

    function toggle(): void {
        if (root.active)
            root.close();
        else
            root.open();
    }

    function place(x, y) {
        root.positionX = x;
        root.positionY = y;
    }

    function send(code, pressed) {
        if (daemon.running)
            daemon.write(`k ${code} ${pressed ? 1 : 0}\n`);
    }

    function latchOf(code) {
        const latch = root.latches[code];
        return latch === undefined ? KeyboardService.Latch.Free : latch;
    }

    function setLatch(code, latch) {
        const next = Object.assign({}, root.latches);
        if (latch === KeyboardService.Latch.Free)
            delete next[code];
        else
            next[code] = latch;
        root.latches = next;
    }

    function cycleModifier(code) {
        switch (root.latchOf(code)) {
        case KeyboardService.Latch.Free:
            root.send(code, true);
            root.setLatch(code, KeyboardService.Latch.Once);
            return;
        case KeyboardService.Latch.Once:
            root.setLatch(code, KeyboardService.Latch.Locked);
            return;
        default:
            root.send(code, false);
            root.setLatch(code, KeyboardService.Latch.Free);
        }
    }

    function consumeLatches() {
        const kept = ({});
        let consumed = false;
        for (const code in root.latches) {
            if (root.latches[code] === KeyboardService.Latch.Locked) {
                kept[code] = KeyboardService.Latch.Locked;
                continue;
            }
            root.send(Number(code), false);
            consumed = true;
        }
        if (consumed)
            root.latches = kept;
    }

    function toggleLock(code) {
        root.send(code, true);
        root.send(code, false);
        root.lockedCode = root.lockedCode === code ? 0 : code;
    }

    function press(code) {
        root.send(code, true);
    }

    function release(code) {
        root.send(code, false);
        root.consumeLatches();
    }

    function releaseAll() {
        if (root.lockedCode !== 0)
            root.toggleLock(root.lockedCode);
        if (daemon.running)
            daemon.write("r\n");
        root.latches = ({});
    }

    Process {
        id: daemon

        command: ["oskd"]
        running: root.active
        stdinEnabled: true

        onExited: {
            root.latches = ({});
            root.lockedCode = 0;
        }
    }
}
