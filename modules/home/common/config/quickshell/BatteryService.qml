pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool available: capacityFile.loaded
    readonly property int percentage: available ? readInteger(capacityFile) : -1
    readonly property string status: statusFile.loaded ? statusFile.text().trim() : "Unavailable"
    readonly property bool charging: status === "Charging" || status === "Full"

    readonly property int power: readInteger(powerFile)
    readonly property int energy: readInteger(energyFile)
    readonly property int energyFull: readInteger(energyFullFile)

    readonly property int remainingMinutes: power > 0 && (status === "Charging" || status === "Discharging") ? Math.round((status === "Charging" ? Math.max(0, energyFull - energy) : energy) * 60 / power) : -1
    readonly property string remainingTime: remainingMinutes >= 0 ? formatDuration(remainingMinutes) : ""
    readonly property string detail: remainingTime.length > 0 ? remainingTime : status

    function readInteger(file) {
        if (!file.loaded)
            return 0;
        const value = Number(file.text().trim());
        return Number.isFinite(value) ? value : 0;
    }

    function formatDuration(totalMinutes) {
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        return hours > 0 ? `${hours}h${minutes}m` : `${minutes}m`;
    }

    FileView {
        id: capacityFile

        path: "/sys/class/power_supply/BAT0/capacity"
        preload: true
        printErrors: false
    }

    FileView {
        id: statusFile

        path: "/sys/class/power_supply/BAT0/status"
        preload: true
        printErrors: false
    }

    FileView {
        id: energyFile

        path: "/sys/class/power_supply/BAT0/energy_now"
        preload: true
        printErrors: false
    }

    FileView {
        id: energyFullFile

        path: "/sys/class/power_supply/BAT0/energy_full"
        preload: true
        printErrors: false
    }

    FileView {
        id: powerFile

        path: "/sys/class/power_supply/BAT0/power_now"
        preload: true
        printErrors: false
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            capacityFile.reload();
            statusFile.reload();
            energyFile.reload();
            energyFullFile.reload();
            powerFile.reload();
        }
    }
}
