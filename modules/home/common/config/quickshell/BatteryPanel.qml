import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    readonly property int percentage: capacityFile.loaded
        ? Number(capacityFile.text().trim())
        : 0
    readonly property string status: statusFile.loaded
        ? statusFile.text().trim()
        : "Unavailable"

    signal requestClose

    implicitWidth: 380
    implicitHeight: 410
    focus: true

    Keys.onEscapePressed: requestClose()

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

    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            capacityFile.reload();
            statusFile.reload();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.medium

        MenuHeader {
            Layout.fillWidth: true
            title: "Battery"
            subtitle: `${root.status} - ${SystemActions.powerProfile}`
            onClose: root.requestClose()
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 180
            radius: Theme.shape.large
            color: ShellPalette.surface
            border.width: 1
            border.color: ShellPalette.indicator
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * Math.max(0, Math.min(1, root.percentage / 100))
                color: ShellPalette.indicator

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.duration.medium2
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.space.extraSmall

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.status === "Charging" ? "\ue1a3" : "\ue1a4"
                    color: ShellPalette.foreground
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 38
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: `${root.percentage}%`
                    color: ShellPalette.foreground
                    font.family: Theme.font.mono
                    font.pixelSize: Theme.font.headlineMediumSize
                    font.weight: Theme.font.headlineMediumWeight
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.status
                    color: ShellPalette.foregroundMuted
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.bodyMediumSize
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Performance"
                color: ShellPalette.foreground
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.titleSmallSize
                font.weight: Theme.font.titleSmallWeight
            }

            Text {
                text: SystemActions.fanRpm > 0
                    ? `${SystemActions.fanRpm} RPM`
                    : "Fan idle"
                color: ShellPalette.foregroundMuted
                font.family: Theme.font.mono
                font.pixelSize: Theme.font.bodySmallSize
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.small

            Repeater {
                model: ["turbo", "balanced", "silent"]

                ChoiceButton {
                    required property string modelData

                    Layout.fillWidth: true
                    text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    checked: SystemActions.powerProfile === modelData
                    enabled: !SystemActions.actionBusy
                    onActivated: SystemActions.setPowerProfile(modelData)
                }
            }
        }
    }
}
