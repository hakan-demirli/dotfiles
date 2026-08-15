import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: {
        if (!adapter)
            return [];
        const result = [];
        for (const device of adapter.devices.values)
            result.push(device);
        result.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return (a.name || a.deviceName).localeCompare(b.name || b.deviceName);
        });
        return result;
    }

    signal requestClose

    implicitWidth: 380
    implicitHeight: 480
    focus: true

    Keys.onEscapePressed: requestClose()

    function updateDiscovery() {
        if (adapter)
            adapter.discovering = adapter.enabled;
    }

    function rescan() {
        if (!adapter || !adapter.enabled)
            return;
        if (adapter.discovering)
            adapter.discovering = false;
        discoveryRestart.restart();
    }

    Component.onCompleted: updateDiscovery()
    Component.onDestruction: {
        if (adapter)
            adapter.discovering = false;
    }
    onAdapterChanged: updateDiscovery()

    ScriptModel {
        id: deviceModel

        values: root.devices
    }

    Timer {
        id: discoveryRestart

        interval: 200
        onTriggered: {
            if (root.adapter && root.adapter.enabled)
                root.adapter.discovering = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.small

        MenuHeader {
            Layout.fillWidth: true
            title: "Bluetooth"
            subtitle: root.adapter
                ? root.adapter.enabled ? "Nearby devices" : "Bluetooth is off"
                : "No adapter"
            onClose: root.requestClose()
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 60
            radius: Theme.shape.large
            color: ShellPalette.surface
            border.width: 1
            border.color: ShellPalette.indicator

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space.medium
                anchors.rightMargin: Theme.space.medium
                spacing: Theme.space.medium

                Text {
                    text: "\ue1a7"
                    color: root.adapter && root.adapter.enabled
                        ? ShellPalette.foreground
                        : ShellPalette.foregroundMuted
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 25
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Bluetooth"
                        color: ShellPalette.foreground
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.bodyLargeSize
                        font.weight: Theme.font.titleMediumWeight
                    }

                    Text {
                        text: root.adapter && root.adapter.enabled ? "On" : "Off"
                        color: ShellPalette.foregroundMuted
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.bodySmallSize
                    }
                }

                MenuIconButton {
                    icon: "\ue5d5"
                    busy: root.adapter ? root.adapter.discovering : false
                    enabled: root.adapter && root.adapter.enabled
                    onActivated: root.rescan()
                }

                ToggleSwitch {
                    enabled: root.adapter !== null
                    checked: root.adapter ? root.adapter.enabled : false
                    onToggled: checked => {
                        root.adapter.enabled = checked;
                        root.adapter.discovering = checked;
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.adapter || !root.adapter.enabled || deviceModel.values.length === 0
            text: !root.adapter
                ? "No Bluetooth adapter was found."
                : root.adapter.enabled ? "Searching for devices..." : "Turn on Bluetooth to see devices."
            color: ShellPalette.foregroundMuted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.font.plain
            font.pixelSize: Theme.font.bodyMediumSize
        }

        ListView {
            id: deviceList

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.adapter && root.adapter.enabled && count > 0
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: deviceModel

            delegate: Rectangle {
                required property var modelData

                width: deviceList.width
                height: 60
                radius: Theme.shape.large
                color: modelData.connected
                    ? ShellPalette.indicator
                    : deviceArea.containsMouse
                        ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity)
                        : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space.medium
                    anchors.rightMargin: Theme.space.medium
                    spacing: Theme.space.medium

                    Text {
                        text: modelData.icon && /headset|headphones|audio/.test(modelData.icon)
                            ? "\ue310"
                            : "\ue1a7"
                        color: ShellPalette.foreground
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 23
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name || modelData.deviceName || "Unknown device"
                            color: ShellPalette.foreground
                            elide: Text.ElideRight
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodyLargeSize
                            font.weight: modelData.connected
                                ? Theme.font.titleMediumWeight
                                : Theme.font.bodyLargeWeight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (modelData.pairing)
                                    return "Pairing...";
                                if (modelData.state === BluetoothDeviceState.Connecting)
                                    return "Connecting...";
                                if (modelData.connected)
                                    return modelData.batteryAvailable
                                        ? `Connected - ${Math.round((modelData.battery > 1 ? modelData.battery / 100 : modelData.battery) * 100)}%`
                                        : "Connected";
                                return modelData.paired ? "Paired" : "Available";
                            }
                            color: modelData.connected
                                ? ShellPalette.foreground
                                : ShellPalette.foregroundMuted
                            elide: Text.ElideRight
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodySmallSize
                        }
                    }

                    Text {
                        text: modelData.connected ? "\ue5ca" : "\ue5cc"
                        color: modelData.connected
                            ? ShellPalette.foreground
                            : ShellPalette.foregroundMuted
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 20
                    }
                }

                MouseArea {
                    id: deviceArea

                    anchors.fill: parent
                    enabled: !modelData.pairing
                        && modelData.state !== BluetoothDeviceState.Connecting
                        && modelData.state !== BluetoothDeviceState.Disconnecting
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (modelData.connected)
                            modelData.disconnect();
                        else if (modelData.paired)
                            modelData.connect();
                        else
                            modelData.pair();
                    }
                }
            }
        }
    }
}
