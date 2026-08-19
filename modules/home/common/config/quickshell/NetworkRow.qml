pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var network

    readonly property real signalLevel: Math.max(0, Math.min(1, network.signal / 100))
    readonly property int bars: Math.max(1, Math.ceil(signalLevel * Theme.metrics.signalBarCount))
    readonly property bool passwordRequired: !network.known && network.secured

    signal passwordRequested(var network)

    implicitHeight: Theme.metrics.controlRowHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.large
        color: root.network.active ? ShellPalette.indicator : area.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.short3
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space.medium
        anchors.rightMargin: Theme.space.medium
        spacing: Theme.space.medium

        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: Theme.metrics.listSpacing

            Repeater {
                model: Theme.metrics.signalBarCount

                Rectangle {
                    required property int index

                    width: Theme.metrics.signalBarWidth
                    height: Theme.metrics.signalBarBaseHeight + index * Theme.metrics.signalBarStep
                    y: Theme.icon.small - height
                    radius: Theme.metrics.stroke
                    color: index < root.bars ? ShellPalette.foreground : Qt.alpha(ShellPalette.foreground, Theme.opacity.inactive)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.network.name || "Hidden network"
                color: ShellPalette.foreground
                elide: Text.ElideRight
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.bodyLargeSize
                font.weight: root.network.active ? Theme.font.titleMediumWeight : Theme.font.bodyLargeWeight
            }

            Text {
                Layout.fillWidth: true
                text: {
                    if (NetworkService.connectingName === root.network.name)
                        return "Connecting...";
                    if (root.network.active)
                        return "Connected";
                    if (root.network.known)
                        return "Saved";
                    if (!root.network.secured)
                        return "Open";
                    return "Secured";
                }
                color: root.network.active ? ShellPalette.foreground : ShellPalette.foregroundMuted
                elide: Text.ElideRight
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.bodySmallSize
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.network.active ? "\ue5ca" : root.passwordRequired ? "\ue897" : "\ue5cc"
            color: root.network.active ? ShellPalette.foreground : ShellPalette.foregroundMuted
            font.family: Theme.font.symbols
            font.pixelSize: Theme.icon.small
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.network.active)
                NetworkService.disconnectNetwork(root.network);
            else if (root.passwordRequired)
                root.passwordRequested(root.network);
            else
                NetworkService.connectNetwork(root.network, "");
        }
    }
}
