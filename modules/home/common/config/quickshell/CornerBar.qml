import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// An L shaped corner decoration hugging the bottom right of the screen, with
// the vertical arm on the right edge and the foot running left along the
// bottom edge. Both arms share a thickness and a length, so the shape reads as
// a bracket rather than a bar with a stub.
//
// The window behind this is a square bounding box; the empty quadrant is
// removed from the input region by the mask in shell.qml, so clicks there
// reach whatever is underneath.
Item {
    id: root

    signal menuRequested(string menu)

    // Thickness of each arm, and the size of one block.
    property int thickness: 47
    // Length of each arm, measured from the outer corner.
    property int armLength: thickness * 4
    property int gap: Theme.space.extraSmall

    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property bool audioAvailable: audioSink && audioSink.audio
    readonly property bool audioMuted: !audioAvailable || audioSink.audio.muted
    readonly property real audioVolume: audioSink && audioSink.audio
        ? audioSink.audio.volume
        : 0
    readonly property var audioProperties: audioSink ? audioSink.properties : ({})
    readonly property string audioIdentity: audioSink
        ? `${audioSink.name} ${audioSink.description} ${audioProperties["node.name"] || ""}`
        : ""
    readonly property bool audioBluetooth: audioProperties["device.api"] === "bluez5"
        || audioIdentity.includes("bluez_output")
    readonly property bool audioHeadphones: audioBluetooth
        || /headphones?|headsets?/i.test(audioIdentity)
    readonly property bool audioDisplay: /hdmi|displayport/i.test(audioIdentity)
    readonly property string audioIcon: audioHeadphones
        ? "\ue310"
        : audioDisplay
            ? "\ue333"
            : audioMuted
                ? "\ue04f"
                : audioVolume < 0.5 ? "\ue04d" : "\ue050"
    readonly property var wifiNetwork: NetworkService.activeNetwork
    readonly property real wifiLevel: wifiNetwork
        ? Math.max(0, Math.min(1, wifiNetwork.signal / 100))
        : -1
    readonly property string audioTooltip: audioAvailable
        ? `${audioSink.description} - ${Math.round(audioVolume * 100)}%${audioMuted ? " muted" : ""}`
        : "No audio output"
    readonly property string wifiTooltip: !NetworkService.wifiEnabled
        ? "Wi-Fi off"
        : wifiNetwork
            ? `${wifiNetwork.name} - ${Math.round(wifiLevel * 100)}%`
            : "Wi-Fi disconnected"
    readonly property int brightnessMaximum: readInteger(brightnessMaximumFile)
    readonly property int brightnessPercent: brightnessMaximum > 0
        ? Math.round(readInteger(brightnessValueFile) * 100 / brightnessMaximum)
        : -1
    readonly property int batteryPercent: batteryCapacityFile.loaded
        ? readInteger(batteryCapacityFile)
        : -1
    readonly property string batteryStatus: batteryStatusFile.loaded
        ? batteryStatusFile.text().trim()
        : ""
    readonly property bool batteryCharging: batteryStatus === "Charging"
        || batteryStatus === "Full"

    readonly property int blockSize: thickness - gap * 2
    // Offset of the corner cell, shared by both arms.
    readonly property int corner: armLength - thickness

    implicitWidth: armLength
    implicitHeight: armLength

    function readInteger(file) {
        const value = Number(file.text().trim());
        return Number.isFinite(value) ? value : 0;
    }

    function adjustVolume(steps) {
        if (!audioAvailable)
            return;
        const next = Math.max(0, Math.min(1, audioVolume + steps * 0.05));
        audioSink.audio.volume = Math.round(next * 100) / 100;
    }

    function adjustBrightness(steps) {
        const amount = Math.abs(steps) * 5;
        brightnessControl.exec([
            "brightnessctl",
            "set",
            `${amount}%${steps > 0 ? "+" : "-"}`,
        ]);
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Process {
        id: brightnessControl
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    FileView {
        id: brightnessValueFile

        path: "/sys/class/backlight/intel_backlight/brightness"
        preload: true
        printErrors: false
    }

    FileView {
        id: brightnessMaximumFile

        path: "/sys/class/backlight/intel_backlight/max_brightness"
        preload: true
        printErrors: false
    }

    FileView {
        id: batteryCapacityFile

        path: "/sys/class/power_supply/BAT0/capacity"
        preload: true
        printErrors: false
    }

    FileView {
        id: batteryStatusFile

        path: "/sys/class/power_supply/BAT0/status"
        preload: true
        printErrors: false
    }

    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: brightnessValueFile.reload()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            batteryCapacityFile.reload();
            batteryStatusFile.reload();
        }
    }

    // ------------------------------------------------------------ surface
    // Vertical arm, running up the right edge. Only the exposed top end is
    // rounded; the right side sits flush against the screen edge.
    Rectangle {
        x: root.corner
        y: 0
        width: root.thickness
        height: root.armLength
        color: ShellPalette.background
        topLeftRadius: Theme.shape.medium
        topRightRadius: Theme.shape.medium
    }

    // Horizontal arm, running left along the bottom edge. Only the exposed
    // left end is rounded.
    Rectangle {
        x: 0
        y: root.corner
        width: root.armLength
        height: root.thickness
        color: ShellPalette.background
        topLeftRadius: Theme.shape.medium
        bottomLeftRadius: Theme.shape.medium
    }

    // ------------------------------------------------------------- blocks
    // Battery completes the vertical arm above brightness.
    BarBlock {
        x: root.corner + root.gap
        y: root.corner - root.thickness * 3 + root.gap
        width: root.blockSize
        height: root.blockSize
        icon: root.batteryCharging ? "\ue1a3" : "\ue1a4"
        active: root.batteryPercent >= 0
        level: root.batteryPercent >= 0 ? root.batteryPercent / 100 : -1
        tooltip: root.batteryPercent >= 0
            ? `Battery ${root.batteryPercent}% - ${root.batteryStatus}`
            : "Battery unavailable"
        onActivated: root.menuRequested("battery")
    }

    // Time spans the two outer cells of the horizontal foot.
    TimeBlock {
        x: root.corner - root.thickness * 3 + root.gap
        y: root.corner + root.gap
        width: root.thickness * 2 - root.gap * 2
        height: root.blockSize
        hours: Qt.formatTime(clock.date, "HH")
        minutes: Qt.formatTime(clock.date, "mm")
        tooltip: Qt.formatDate(clock.date, "ddd d MMM")
        onActivated: root.menuRequested("clock")
    }

    // Occupied cells run outward from the corner: left along the foot and up
    // the vertical arm.
    BarBlock {
        id: menuBlock

        x: root.corner + root.gap
        y: root.corner + root.gap
        width: root.blockSize
        height: root.blockSize
        icon: "\ue5c3"
        active: true
        onActivated: root.menuRequested("control")
    }

    BarBlock {
        id: soundBlock

        x: root.corner - root.thickness + root.gap
        y: root.corner + root.gap
        width: root.blockSize
        height: root.blockSize
        icon: root.audioIcon
        badgeIcon: root.audioBluetooth ? "\ue1a7" : ""
        active: root.audioAvailable && !root.audioMuted
        scrollEnabled: true
        level: root.audioAvailable ? Math.min(root.audioVolume, 1) : -1
        tooltip: root.audioTooltip
        tooltipPlacement: "top"
        onActivated: root.menuRequested("audio")
        onContextActivated: {
            if (root.audioAvailable)
                root.audioSink.audio.muted = !root.audioSink.audio.muted;
        }
        onScrolled: function(steps) {
            root.adjustVolume(steps);
        }
    }

    BarBlock {
        id: networkBlock

        x: root.corner + root.gap
        y: root.corner - root.thickness + root.gap
        width: root.blockSize
        height: root.blockSize
        icon: NetworkService.wifiEnabled ? "\ue63e" : "\ue648"
        active: root.wifiNetwork !== null
        level: root.wifiLevel
        tooltip: root.wifiTooltip
        onActivated: root.menuRequested("wifi")
    }

    BarBlock {
        id: brightnessBlock

        x: root.corner + root.gap
        y: root.corner - root.thickness * 2 + root.gap
        width: root.blockSize
        height: root.blockSize
        icon: "\ue3ac"
        active: root.brightnessPercent > 0
        scrollEnabled: true
        level: root.brightnessPercent >= 0 ? root.brightnessPercent / 100 : -1
        tooltip: root.brightnessPercent >= 0
            ? `Brightness ${root.brightnessPercent}%`
            : "Brightness unavailable"
        onActivated: root.menuRequested("brightness")
        onScrolled: function(steps) {
            root.adjustBrightness(steps);
        }
    }
}
