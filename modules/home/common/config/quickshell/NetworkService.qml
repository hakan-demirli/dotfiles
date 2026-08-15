pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool wifiEnabled: false
    property bool forceRescan: false
    property bool busy: actionProcess.running
    property bool scanning: scanProcess.running
    property string connectingName: ""
    property string lastError: ""
    property var networks: []
    property var activeNetwork: null

    property var rawNetworks: []
    property var savedNames: []
    property string actionKind: ""
    property string pendingPassword: ""

    function splitEscaped(line) {
        const fields = [];
        let field = "";
        let escaped = false;
        for (let index = 0; index < line.length; index++) {
            const character = line[index];
            if (escaped) {
                field += character;
                escaped = false;
            } else if (character === "\\") {
                escaped = true;
            } else if (character === ":") {
                fields.push(field);
                field = "";
            } else {
                field += character;
            }
        }
        fields.push(field);
        return fields;
    }

    function parseNetworks(text) {
        const parsed = [];
        for (const line of text.trim().split("\n")) {
            if (!line)
                continue;
            const fields = splitEscaped(line);
            if (fields.length < 4 || !fields[1])
                continue;
            const candidate = {
                active: fields[0].trim() === "*",
                name: fields[1],
                signal: Number(fields[2]) || 0,
                security: fields.slice(3).join(":"),
            };
            const existing = parsed.find(item => item.name === candidate.name);
            if (!existing) {
                parsed.push(candidate);
            } else if (candidate.active || candidate.signal > existing.signal) {
                Object.assign(existing, candidate);
            }
        }
        rawNetworks = parsed;
        rebuildNetworks();
    }

    function parseSaved(text) {
        const parsed = [];
        for (const line of text.trim().split("\n")) {
            if (!line)
                continue;
            const fields = splitEscaped(line);
            if (fields.length >= 2 && fields[1] === "802-11-wireless")
                parsed.push(fields[0]);
        }
        savedNames = parsed;
        rebuildNetworks();
    }

    function rebuildNetworks() {
        const merged = rawNetworks.map(network => ({
            active: network.active,
            known: savedNames.includes(network.name),
            name: network.name,
            secured: network.security.length > 0 && network.security !== "--",
            security: network.security,
            signal: network.signal,
        }));
        merged.sort((a, b) => {
            if (a.active !== b.active)
                return a.active ? -1 : 1;
            if (a.name === connectingName)
                return -1;
            if (b.name === connectingName)
                return 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return b.signal - a.signal;
        });
        networks = merged;
        activeNetwork = merged.find(network => network.active) || null;
    }

    function refresh(rescan) {
        if (rescan)
            forceRescan = true;
        if (!scanProcess.running)
            scanProcess.running = true;
        if (!savedProcess.running)
            savedProcess.running = true;
        if (!radioProcess.running)
            radioProcess.running = true;
    }

    function setWifi(enabled) {
        if (actionProcess.running)
            return;
        wifiEnabled = enabled;
        actionKind = "radio";
        actionProcess.exec(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
    }

    function connectNetwork(network, password) {
        if (actionProcess.running || !network)
            return;
        lastError = "";
        connectingName = network.name;
        rebuildNetworks();
        if (network.known) {
            actionKind = "connect";
            actionProcess.exec(["nmcli", "connection", "up", "id", network.name]);
        } else if (network.secured) {
            actionKind = "connect-password";
            pendingPassword = password;
            actionProcess.exec(["nmcli", "--ask", "device", "wifi", "connect", network.name]);
        } else {
            actionKind = "connect";
            actionProcess.exec(["nmcli", "device", "wifi", "connect", network.name]);
        }
    }

    function disconnectNetwork(network) {
        if (actionProcess.running || !network)
            return;
        lastError = "";
        actionKind = "disconnect";
        actionProcess.exec(["nmcli", "connection", "down", "id", network.name]);
    }

    function forgetNetwork(network) {
        if (actionProcess.running || !network)
            return;
        lastError = "";
        actionKind = "forget";
        actionProcess.exec(["nmcli", "connection", "delete", "id", network.name]);
    }

    Process {
        id: scanProcess

        command: [
            "nmcli",
            "--terse",
            "--escape",
            "yes",
            "--fields",
            "IN-USE,SSID,SIGNAL,SECURITY",
            "device",
            "wifi",
            "list",
            "--rescan",
            root.forceRescan ? "yes" : "auto",
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseNetworks(text)
        }
        onExited: root.forceRescan = false
    }

    Process {
        id: savedProcess

        command: [
            "nmcli",
            "--terse",
            "--escape",
            "yes",
            "--fields",
            "NAME,TYPE",
            "connection",
            "show",
        ]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseSaved(text)
        }
    }

    Process {
        id: radioProcess

        command: ["nmcli", "--terse", "radio", "wifi"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.wifiEnabled = text.trim() === "enabled"
        }
    }

    Process {
        id: actionProcess

        stdinEnabled: true
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: actionError
        }
        onStarted: {
            if (root.actionKind === "connect-password") {
                write(root.pendingPassword + "\n");
                root.pendingPassword = "";
            }
        }
        onExited: function(exitCode) {
            root.lastError = exitCode === 0 ? "" : actionError.text.trim();
            root.connectingName = "";
            root.actionKind = "";
            delayedRefresh.restart();
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh(false)
    }

    Timer {
        id: delayedRefresh

        interval: 600
        onTriggered: root.refresh(true)
    }
}
