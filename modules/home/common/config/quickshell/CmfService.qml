pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    enum Noise {
        Unknown,
        Off,
        Transparency,
        Low,
        Mid,
        High,
        Adaptive
    }

    readonly property string socketPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/cmf-headphoned.sock`

    property bool present: false
    property bool restarting: false
    property string address: ""
    property int battery: -1
    property int noise: CmfService.Noise.Unknown
    property int level: CmfService.Noise.High
    property bool ldac: false

    readonly property bool available: present && !restarting
    readonly property bool cancelling: noise === CmfService.Noise.Low || noise === CmfService.Noise.Mid || noise === CmfService.Noise.High || noise === CmfService.Noise.Adaptive

    readonly property string status: {
        if (restarting)
            return "Restarting...";
        if (!present)
            return "Not connected";
        return battery >= 0 ? `${battery}% - ${noiseName(noise)}` : noiseName(noise);
    }

    function noiseName(value) {
        switch (value) {
        case CmfService.Noise.Off:
            return "Noise control off";
        case CmfService.Noise.Transparency:
            return "Transparency";
        case CmfService.Noise.Low:
            return "Low cancelling";
        case CmfService.Noise.Mid:
            return "Mid cancelling";
        case CmfService.Noise.High:
            return "High cancelling";
        case CmfService.Noise.Adaptive:
            return "Adaptive cancelling";
        default:
            return "Unknown";
        }
    }

    function noiseFromLabel(label) {
        switch (label) {
        case "off":
            return CmfService.Noise.Off;
        case "transparency":
            return CmfService.Noise.Transparency;
        case "low":
            return CmfService.Noise.Low;
        case "mid":
            return CmfService.Noise.Mid;
        case "high":
            return CmfService.Noise.High;
        case "adaptive":
            return CmfService.Noise.Adaptive;
        default:
            return CmfService.Noise.Unknown;
        }
    }

    function noiseLabel(value) {
        switch (value) {
        case CmfService.Noise.Off:
            return "off";
        case CmfService.Noise.Transparency:
            return "transparency";
        case CmfService.Noise.Low:
            return "low";
        case CmfService.Noise.Mid:
            return "mid";
        case CmfService.Noise.High:
            return "high";
        case CmfService.Noise.Adaptive:
            return "adaptive";
        default:
            return "";
        }
    }

    function clear() {
        root.present = false;
        root.restarting = false;
        root.address = "";
        root.battery = -1;
        root.noise = CmfService.Noise.Unknown;
        root.ldac = false;
    }

    function resume() {
        root.setNoise(root.level);
    }

    function apply(line) {
        const text = line.trim();
        if (text.length === 0)
            return;
        let report = null;
        try {
            report = JSON.parse(text);
        } catch (error) {
            return;
        }
        root.present = report.connected === true;
        root.restarting = report.restarting === true;
        root.address = typeof report.address === "string" ? report.address.toUpperCase() : "";
        root.battery = typeof report.battery === "number" ? report.battery : -1;
        root.noise = root.noiseFromLabel(report.anc);
        const level = root.noiseFromLabel(report.level);
        if (level !== CmfService.Noise.Unknown)
            root.level = level;
        root.ldac = report.ldac === true;
    }

    function request(payload) {
        if (!socket.connected)
            return;
        socket.write(`${JSON.stringify(payload)}\n`);
        socket.flush();
    }

    function setNoise(value) {
        const label = root.noiseLabel(value);
        if (label.length === 0)
            return;
        root.request({
            anc: label
        });
    }

    function setLdac(enabled) {
        root.request({
            ldac: enabled
        });
    }

    Socket {
        id: socket

        path: root.socketPath
        connected: true

        parser: SplitParser {
            onRead: line => root.apply(line)
        }

        onConnectionStateChanged: {
            if (!socket.connected)
                root.clear();
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: !socket.connected
        onTriggered: socket.connected = true
    }
}
