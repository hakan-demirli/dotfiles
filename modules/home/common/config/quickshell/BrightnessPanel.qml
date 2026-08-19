import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    property int pendingPercent: -1

    readonly property int maximum: readInteger(maximumFile)
    readonly property int actualPercent: maximum > 0 ? Math.round(readInteger(valueFile) * 100 / maximum) : 0
    readonly property int shownPercent: pendingPercent >= 0 ? pendingPercent : actualPercent

    signal requestClose

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: content.implicitHeight + Theme.space.large * 2
    focus: true

    function readInteger(file) {
        const value = Number(file.text().trim());
        return Number.isFinite(value) ? value : 0;
    }

    function queueBrightness(value) {
        pendingPercent = Math.round(value * 100);
        applyTimer.restart();
    }

    Keys.onEscapePressed: requestClose()

    FileView {
        id: valueFile

        path: "/sys/class/backlight/intel_backlight/brightness"
        preload: true
        printErrors: false
    }

    FileView {
        id: maximumFile

        path: "/sys/class/backlight/intel_backlight/max_brightness"
        preload: true
        printErrors: false
    }

    Process {
        id: brightnessProcess

        onExited: refreshTimer.restart()
    }

    Timer {
        id: applyTimer

        interval: 50
        onTriggered: brightnessProcess.exec(["brightnessctl", "set", `${root.pendingPercent}%`,])
    }

    Timer {
        id: refreshTimer

        interval: 120
        onTriggered: {
            valueFile.reload();
            root.pendingPercent = -1;
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: true
        onTriggered: valueFile.reload()
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.medium

        MenuHeader {
            Layout.fillWidth: true
            title: "Brightness"
            subtitle: `${root.shownPercent}%`
            onClose: root.requestClose()
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.metrics.mediaControlHeight
            radius: Theme.shape.large
            color: ShellPalette.surface
            border.width: Theme.metrics.stroke
            border.color: ShellPalette.indicator

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space.medium
                anchors.rightMargin: Theme.space.medium
                spacing: Theme.space.medium

                Text {
                    text: "\ue3ac"
                    color: ShellPalette.foreground
                    font.family: Theme.font.symbols
                    font.pixelSize: Theme.icon.large
                }

                LevelSlider {
                    Layout.fillWidth: true
                    value: root.shownPercent / 100
                    onMoved: value => root.queueBrightness(value)
                }

                Text {
                    Layout.preferredWidth: Theme.metrics.percentageLabelWidth
                    text: `${root.shownPercent}%`
                    color: ShellPalette.foreground
                    horizontalAlignment: Text.AlignRight
                    font.family: Theme.font.mono
                    font.pixelSize: Theme.font.bodyMediumSize
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Refresh rate"
                color: ShellPalette.foreground
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.titleSmallSize
                font.weight: Theme.font.titleSmallWeight
            }

            Text {
                text: `${SystemActions.refreshRate} Hz`
                color: ShellPalette.foregroundMuted
                font.family: Theme.font.mono
                font.pixelSize: Theme.font.bodySmallSize
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.small

            ChoiceButton {
                Layout.fillWidth: true
                text: "Auto"
                checked: SystemActions.refreshPolicy === "auto"
                enabled: !SystemActions.actionBusy
                onActivated: SystemActions.setRefreshPolicy("auto")
            }

            ChoiceButton {
                Layout.fillWidth: true
                text: "48 Hz"
                checked: SystemActions.refreshPolicy === "manual-48"
                enabled: !SystemActions.actionBusy
                onActivated: SystemActions.setRefreshPolicy("48")
            }

            ChoiceButton {
                Layout.fillWidth: true
                text: "120 Hz"
                checked: SystemActions.refreshPolicy === "manual-120"
                enabled: !SystemActions.actionBusy
                onActivated: SystemActions.setRefreshPolicy("120")
            }
        }
    }
}
