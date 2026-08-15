pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")

    property string recordingState: "idle"
    property string recordingTooltip: ""
    property string powerProfile: "unknown"
    property int fanRpm: 0
    property string refreshPolicy: "unknown"
    property int refreshRate: 0
    property bool awake: false
    property bool rotationLocked: false
    property bool tabletLocked: false
    readonly property bool actionBusy: false
    property string queuedRecordingMode: ""

    function parseJson(text) {
        try {
            return JSON.parse(text.trim());
        } catch (error) {
            return {};
        }
    }

    function run(command) {
        Quickshell.execDetached(command);
    }

    function toggleRecording(mode) {
        run(["screen-record", "toggle", mode]);
    }

    function queueRecording(mode) {
        queuedRecordingMode = mode;
    }

    function runQueuedRecording() {
        const mode = queuedRecordingMode;
        queuedRecordingMode = "";
        if (mode)
            toggleRecording(mode);
    }

    function stopRecording() {
        run(["screen-record", "stop"]);
    }

    function setPowerProfile(profile) {
        run(["hp-power", profile]);
    }

    function setRefreshPolicy(policy) {
        run(["auto_refresh", policy]);
    }

    function toggleAwake() {
        run([home + "/.local/bin/caffeinate-toggle.sh", "swaync"]);
    }

    function toggleRotationLock() {
        run([home + "/.local/bin/rotation-lock-toggle.sh", "swaync"]);
    }

    function toggleKeyboard() {
        run([home + "/.local/bin/tablet_mode_apply.sh", "osk-toggle"]);
    }

    function toggleTabletLock() {
        run([home + "/.local/bin/tablet-lock-toggle.sh", "swaync"]);
    }

    function toggleNotifications() {
        run(["swaync-client", "-t", "-sw"]);
    }

    function power(action) {
        run(["gtk_applet_power_menu", "--action", action]);
    }

    function refreshAll() {
        recordingStatus.refresh();
        powerStatus.refresh();
        refreshStatus.refresh();
        awakeStatus.refresh();
        rotationStatus.refresh();
        tabletStatus.refresh();
    }

    PollingCommand {
        id: recordingStatus

        command: ["screen-record", "json"]
        interval: 1000
        onOutput: text => {
            const status = root.parseJson(text);
            root.recordingState = status.class || "idle";
            root.recordingTooltip = status.tooltip || "";
        }
    }

    PollingCommand {
        id: powerStatus

        command: ["hp-power", "json"]
        interval: 5000
        onOutput: text => {
            const status = root.parseJson(text);
            root.powerProfile = status.class || "unknown";
            const match = String(status.tooltip || "").match(/Fan:\s*(\d+)\s*RPM/);
            root.fanRpm = match ? Number(match[1]) : 0;
        }
    }

    PollingCommand {
        id: refreshStatus

        command: ["auto_refresh", "json"]
        interval: 2000
        onOutput: text => {
            const status = root.parseJson(text);
            root.refreshPolicy = status.class || "unknown";
            const match = String(status.tooltip || "").match(/Current:\s*(\d+)\s*Hz/);
            root.refreshRate = match ? Number(match[1]) : 0;
        }
    }

    PollingCommand {
        id: awakeStatus

        command: [root.home + "/.local/bin/caffeinate-toggle.sh", "status"]
        interval: 3000
        onOutput: text => root.awake = text.trim() === "true"
    }

    PollingCommand {
        id: rotationStatus

        command: [root.home + "/.local/bin/rotation-lock-toggle.sh", "status"]
        interval: 3000
        onOutput: text => root.rotationLocked = text.trim() === "true"
    }

    PollingCommand {
        id: tabletStatus

        command: [root.home + "/.local/bin/tablet-lock-toggle.sh", "status"]
        interval: 3000
        onOutput: text => root.tabletLocked = text.trim() === "true"
    }

}
