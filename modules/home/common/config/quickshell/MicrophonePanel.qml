pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool available: source && source.audio
    readonly property real volume: available ? source.audio.volume : 0
    readonly property var sources: {
        const result = [];
        for (const node of Pipewire.nodes.values) {
            if (!node.isStream && (node.type & PwNodeType.AudioSource))
                result.push(node);
        }
        result.sort((a, b) => {
            if (a === root.source)
                return -1;
            if (b === root.source)
                return 1;
            return a.description.localeCompare(b.description);
        });
        return result;
    }

    signal requestClose

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: Theme.metrics.panelListHeight
    focus: true

    Keys.onEscapePressed: requestClose()

    PwObjectTracker {
        objects: root.sources
    }

    ScriptModel {
        id: sourceModel

        values: root.sources
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.small

        MenuHeader {
            Layout.fillWidth: true
            title: "Microphone"
            subtitle: root.source ? root.source.description : "No input device"
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

                Rectangle {
                    implicitWidth: Theme.metrics.buttonHeight
                    implicitHeight: Theme.metrics.buttonHeight
                    radius: Theme.shape.full
                    color: muteArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : ShellPalette.indicator

                    Text {
                        anchors.centerIn: parent
                        text: root.available && root.source.audio.muted ? "\ue02b" : "\ue029"
                        color: root.available && !root.source.audio.muted ? ShellPalette.foreground : ShellPalette.foregroundMuted
                        font.family: Theme.font.symbols
                        font.pixelSize: Theme.icon.medium
                    }

                    MouseArea {
                        id: muteArea

                        anchors.fill: parent
                        enabled: root.available
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.source.audio.muted = !root.source.audio.muted
                    }
                }

                LevelSlider {
                    Layout.fillWidth: true
                    value: Math.min(root.volume, 1)
                    onMoved: value => {
                        if (root.available)
                            root.source.audio.volume = value;
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
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space.small
            text: "Input"
            color: ShellPalette.foregroundMuted
            font.family: Theme.font.plain
            font.pixelSize: Theme.font.labelMediumSize
            font.weight: Theme.font.labelMediumWeight
        }

        ListView {
            id: inputList

            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.metrics.listSpacing
            boundsBehavior: Flickable.StopAtBounds
            model: sourceModel

            delegate: Rectangle {
                id: input

                required property var modelData

                width: inputList.width
                height: Theme.metrics.listRowHeight
                radius: Theme.shape.large
                color: input.modelData === root.source ? ShellPalette.indicator : inputArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.medium
                    anchors.rightMargin: Theme.space.medium
                    spacing: Theme.space.medium

                    Text {
                        text: "\ue029"
                        color: ShellPalette.foreground
                        font.family: Theme.font.symbols
                        font.pixelSize: Theme.icon.medium
                    }

                    Text {
                        Layout.fillWidth: true
                        text: input.modelData.description
                        color: ShellPalette.foreground
                        elide: Text.ElideRight
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.bodyMediumSize
                        font.weight: input.modelData === root.source ? Theme.font.titleMediumWeight : Theme.font.bodyMediumWeight
                    }

                    Text {
                        visible: input.modelData === root.source
                        text: "\ue5ca"
                        color: ShellPalette.foreground
                        font.family: Theme.font.symbols
                        font.pixelSize: Theme.icon.small
                    }
                }

                MouseArea {
                    id: inputArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Pipewire.preferredDefaultAudioSource = input.modelData
                }
            }
        }
    }
}
