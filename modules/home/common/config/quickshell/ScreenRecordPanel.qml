import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool recording: SystemActions.recordingState === "recording"
    readonly property bool transitional: ["selecting", "starting", "stopping", "copying",].includes(SystemActions.recordingState)

    signal requestClose

    implicitWidth: 380
    implicitHeight: 310
    focus: true

    Keys.onEscapePressed: requestClose()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.medium

        MenuHeader {
            Layout.fillWidth: true
            title: "Screen recording"
            subtitle: SystemActions.recordingState.charAt(0).toUpperCase() + SystemActions.recordingState.slice(1)
            onClose: root.requestClose()
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 110
            radius: Theme.shape.large
            color: root.recording ? ShellPalette.indicator : ShellPalette.surface
            border.width: 1
            border.color: ShellPalette.indicator

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.space.medium

                Text {
                    text: root.recording ? "\ue061" : "\ue04b"
                    color: ShellPalette.foreground
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 38
                }

                ColumnLayout {
                    spacing: 0

                    Text {
                        text: root.recording ? "Recording" : "Ready"
                        color: ShellPalette.foreground
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.titleLargeSize
                        font.weight: Theme.font.titleLargeWeight
                    }

                    Text {
                        text: root.recording ? "System audio is included" : "Choose the display or a region"
                        color: ShellPalette.foregroundMuted
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.bodySmallSize
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.small

            ChoiceButton {
                Layout.fillWidth: true
                visible: !root.recording
                text: "Display"
                enabled: !root.transitional && !SystemActions.actionBusy
                onActivated: {
                    SystemActions.queueRecording("output");
                    root.requestClose();
                }
            }

            ChoiceButton {
                Layout.fillWidth: true
                visible: !root.recording
                text: "Select region"
                enabled: !root.transitional && !SystemActions.actionBusy
                onActivated: {
                    SystemActions.queueRecording("region");
                    root.requestClose();
                }
            }

            ChoiceButton {
                Layout.fillWidth: true
                visible: root.recording
                text: "Stop recording"
                checked: true
                enabled: !root.transitional && !SystemActions.actionBusy
                onActivated: {
                    SystemActions.stopRecording();
                    root.requestClose();
                }
            }
        }
    }
}
