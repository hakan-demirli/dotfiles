pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    property bool tuning: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: sink && sink.audio
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property var sinkProperties: sink ? sink.properties || ({}) : ({})
    readonly property string sinkAddress: (sinkProperties["api.bluez5.address"] || "").toUpperCase()
    readonly property bool tunable: CmfService.present && sinkAddress === CmfService.address
    readonly property var sinks: {
        const result = [];
        for (const node of Pipewire.nodes.values) {
            if (node.isSink && !node.isStream)
                result.push(node);
        }
        result.sort((a, b) => {
            if (a === root.sink)
                return -1;
            if (b === root.sink)
                return 1;
            return a.description.localeCompare(b.description);
        });
        return result;
    }

    signal requestClose

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: tuning ? Theme.metrics.panelDialogHeight : Theme.metrics.panelListHeight
    focus: true

    onTunableChanged: {
        if (!tunable)
            tuning = false;
    }

    function outputIcon(node) {
        if (!node)
            return "\ue32d";
        const properties = node.properties || {};
        const identity = `${node.name} ${node.description} ${properties["node.name"] || ""}`;
        if (properties["device.api"] === "bluez5" || /headphones?|headsets?|bluez_output/i.test(identity))
            return "\ue310";
        if (/hdmi|displayport/i.test(identity))
            return "\ue333";
        return "\ue050";
    }

    Keys.onEscapePressed: requestClose()

    PwObjectTracker {
        objects: root.sinks
    }

    ScriptModel {
        id: sinkModel

        values: root.sinks
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.small

        MenuHeader {
            Layout.fillWidth: true
            title: root.tuning ? "Headphones" : "Sound"
            subtitle: root.tuning ? CmfService.status : root.sink ? root.sink.description : "No output device"
            showBack: root.tuning
            onBack: root.tuning = false
            onClose: root.requestClose()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.tuning
            spacing: Theme.space.small

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

                    Rectangle {
                        implicitWidth: Theme.metrics.buttonHeight
                        implicitHeight: Theme.metrics.buttonHeight
                        radius: Theme.shape.full
                        color: muteArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : ShellPalette.indicator

                        Text {
                            anchors.centerIn: parent
                            text: root.available && root.sink.audio.muted ? "\ue04f" : root.outputIcon(root.sink)
                            color: root.available && !root.sink.audio.muted ? ShellPalette.foreground : ShellPalette.foregroundMuted
                            font.family: Theme.font.symbols
                            font.pixelSize: Theme.icon.medium
                        }

                        MouseArea {
                            id: muteArea

                            anchors.fill: parent
                            enabled: root.available
                            hoverEnabled: true
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.sink.audio.muted = !root.sink.audio.muted
                        }
                    }

                    LevelSlider {
                        Layout.fillWidth: true
                        value: Math.min(root.volume, 1)
                        onMoved: value => {
                            if (root.available)
                                root.sink.audio.volume = value;
                        }
                    }

                    Text {
                        Layout.preferredWidth: Theme.metrics.percentageLabelWidth
                        text: `${Math.round(root.volume * 100)}%`
                        color: ShellPalette.foreground
                        horizontalAlignment: Text.AlignRight
                        font.family: Theme.font.mono
                        font.pixelSize: Theme.font.bodyMediumSize
                    }

                    MenuIconButton {
                        visible: root.tunable
                        icon: "\ue8b8"
                        onActivated: root.tuning = true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space.small
                text: "Output"
                color: ShellPalette.foregroundMuted
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.labelMediumSize
                font.weight: Theme.font.labelMediumWeight
            }

            ListView {
                id: outputList

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.metrics.listSpacing
                boundsBehavior: Flickable.StopAtBounds
                model: sinkModel

                delegate: Rectangle {
                    id: output

                    required property var modelData

                    width: outputList.width
                    height: Theme.metrics.listRowHeight
                    radius: Theme.shape.large
                    color: output.modelData === root.sink ? ShellPalette.indicator : outputArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.space.medium
                        anchors.rightMargin: Theme.space.medium
                        spacing: Theme.space.medium

                        Text {
                            text: root.outputIcon(output.modelData)
                            color: ShellPalette.foreground
                            font.family: Theme.font.symbols
                            font.pixelSize: Theme.icon.medium
                        }

                        Text {
                            Layout.fillWidth: true
                            text: output.modelData.description
                            color: ShellPalette.foreground
                            elide: Text.ElideRight
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodyMediumSize
                            font.weight: output.modelData === root.sink ? Theme.font.titleMediumWeight : Theme.font.bodyMediumWeight
                        }

                        Text {
                            visible: output.modelData === root.sink
                            text: "\ue5ca"
                            color: ShellPalette.foreground
                            font.family: Theme.font.symbols
                            font.pixelSize: Theme.icon.small
                        }
                    }

                    MouseArea {
                        id: outputArea

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = output.modelData
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.tuning
            spacing: Theme.space.small

            Text {
                Layout.fillWidth: true
                text: "Noise control"
                color: ShellPalette.foregroundMuted
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.labelMediumSize
                font.weight: Theme.font.labelMediumWeight
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space.small

                ChoiceButton {
                    Layout.fillWidth: true
                    text: "Off"
                    enabled: CmfService.available
                    checked: CmfService.noise === CmfService.Noise.Off
                    onActivated: CmfService.setNoise(CmfService.Noise.Off)
                }

                ChoiceButton {
                    Layout.fillWidth: true
                    text: "Transparency"
                    enabled: CmfService.available
                    checked: CmfService.noise === CmfService.Noise.Transparency
                    onActivated: CmfService.setNoise(CmfService.Noise.Transparency)
                }

                ChoiceButton {
                    Layout.fillWidth: true
                    text: "Cancelling"
                    enabled: CmfService.available
                    checked: CmfService.cancelling
                    onActivated: CmfService.resume()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: CmfService.cancelling
                spacing: Theme.space.small

                ChoiceButton {
                    Layout.fillWidth: true
                    text: "Low"
                    enabled: CmfService.available
                    checked: CmfService.noise === CmfService.Noise.Low
                    onActivated: CmfService.setNoise(CmfService.Noise.Low)
                }

                ChoiceButton {
                    Layout.fillWidth: true
                    text: "Mid"
                    enabled: CmfService.available
                    checked: CmfService.noise === CmfService.Noise.Mid
                    onActivated: CmfService.setNoise(CmfService.Noise.Mid)
                }

                ChoiceButton {
                    Layout.fillWidth: true
                    text: "High"
                    enabled: CmfService.available
                    checked: CmfService.noise === CmfService.Noise.High
                    onActivated: CmfService.setNoise(CmfService.Noise.High)
                }

                ChoiceButton {
                    Layout.fillWidth: true
                    text: "Adaptive"
                    enabled: CmfService.available
                    checked: CmfService.noise === CmfService.Noise.Adaptive
                    onActivated: CmfService.setNoise(CmfService.Noise.Adaptive)
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Theme.metrics.controlRowHeight
                radius: Theme.shape.large
                color: ShellPalette.surface
                border.width: Theme.metrics.stroke
                border.color: ShellPalette.indicator

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.medium
                    anchors.rightMargin: Theme.space.medium
                    spacing: Theme.space.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "LDAC"
                            color: ShellPalette.foreground
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodyLargeSize
                            font.weight: Theme.font.titleMediumWeight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: CmfService.restarting ? "The headphones are restarting" : "Switching this restarts the headphones"
                            color: ShellPalette.foregroundMuted
                            elide: Text.ElideRight
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodySmallSize
                        }
                    }

                    ToggleSwitch {
                        enabled: CmfService.available
                        checked: CmfService.ldac
                        onToggled: checked => CmfService.setLdac(checked)
                    }
                }
            }
        }
    }
}
