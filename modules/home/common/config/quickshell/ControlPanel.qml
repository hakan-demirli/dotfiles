import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

Item {
    id: root

    signal requestClose
    signal requestMenu(string menu)

    implicitWidth: 380
    implicitHeight: 430
    focus: true

    Keys.onEscapePressed: requestClose()

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.small

        MenuHeader {
            Layout.fillWidth: true
            title: "Control center"
            subtitle: "System controls"
            onClose: root.requestClose()
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Theme.space.small
            columnSpacing: Theme.space.small

            ControlTile {
                Layout.fillWidth: true
                icon: NetworkService.wifiEnabled ? "\ue63e" : "\ue648"
                title: "Wi-Fi"
                subtitle: NetworkService.activeNetwork
                    ? NetworkService.activeNetwork.name
                    : NetworkService.wifiEnabled ? "Disconnected" : "Off"
                onActivated: root.requestMenu("wifi")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: "\ue1a7"
                title: "Bluetooth"
                subtitle: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled
                    ? "On"
                    : "Off"
                onActivated: root.requestMenu("bluetooth")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: "\ue32d"
                title: "Sound"
                subtitle: Pipewire.defaultAudioSink
                    ? Pipewire.defaultAudioSink.description
                    : "No output"
                onActivated: root.requestMenu("audio")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: Pipewire.defaultAudioSource
                        && Pipewire.defaultAudioSource.audio
                        && Pipewire.defaultAudioSource.audio.muted
                    ? "\ue02b"
                    : "\ue029"
                title: "Microphone"
                subtitle: Pipewire.defaultAudioSource
                    ? Pipewire.defaultAudioSource.description
                    : "No input"
                onActivated: root.requestMenu("microphone")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: "\ue3ac"
                title: "Display"
                subtitle: `${SystemActions.refreshRate} Hz`
                onActivated: root.requestMenu("brightness")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: BatteryService.charging ? "\ue1a3" : "\ue1a4"
                title: "Battery"
                subtitle: BatteryService.percentage >= 0
                    ? `${BatteryService.percentage}% - ${BatteryService.detail}`
                    : "Unavailable"
                onActivated: root.requestMenu("battery")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: SystemActions.recordingState === "recording" ? "\ue061" : "\ue04b"
                title: "Record"
                subtitle: SystemActions.recordingState
                onActivated: root.requestMenu("recording")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: "\ue32f"
                title: "Tablet"
                subtitle: SystemActions.rotationLocked ? "Rotation locked" : "Auto rotate"
                onActivated: root.requestMenu("tablet")
            }

            ControlTile {
                Layout.fillWidth: true
                icon: "\ue7f4"
                title: "Notifications"
                subtitle: "Open notification center"
                onActivated: {
                    SystemActions.toggleNotifications();
                    root.requestClose();
                }
            }

            ControlTile {
                Layout.fillWidth: true
                icon: "\ue8ac"
                title: "Power"
                subtitle: "Session and system"
                onActivated: root.requestMenu("power")
            }
        }
    }
}
