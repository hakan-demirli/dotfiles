pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var pendingNetwork: null
    property string password: ""
    property bool passwordVisible: false
    property string errorMessage: ""

    readonly property var sortedNetworks: NetworkService.networks

    signal requestClose

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: pendingNetwork ? Theme.metrics.panelDialogHeight : Theme.metrics.panelTallHeight
    focus: true

    function beginPassword(network) {
        pendingNetwork = network;
        password = "";
        errorMessage = "";
        Qt.callLater(() => passwordInput.forceActiveFocus());
    }

    function cancelPassword() {
        pendingNetwork = null;
        password = "";
        errorMessage = "";
        forceActiveFocus();
    }

    function connectPending() {
        if (!pendingNetwork || password.length < 8)
            return;
        errorMessage = "";
        NetworkService.connectNetwork(pendingNetwork, password);
    }

    Component.onCompleted: NetworkService.refresh(true)

    Keys.onEscapePressed: {
        if (pendingNetwork)
            cancelPassword();
        else
            requestClose();
    }

    ScriptModel {
        id: networkModel

        values: root.sortedNetworks
    }

    Connections {
        target: NetworkService

        function onActiveNetworkChanged() {
            if (root.pendingNetwork && NetworkService.activeNetwork && root.pendingNetwork.name === NetworkService.activeNetwork.name)
                root.cancelPassword();
        }

        function onLastErrorChanged() {
            root.errorMessage = NetworkService.lastError;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.small

        MenuHeader {
            Layout.fillWidth: true
            title: root.pendingNetwork ? root.pendingNetwork.name : "Network"
            subtitle: root.pendingNetwork ? "Enter the network password" : NetworkService.status
            showBack: root.pendingNetwork !== null
            onBack: root.cancelPassword()
            onClose: root.requestClose()
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.pendingNetwork === null
            spacing: Theme.space.small

            Rectangle {
                Layout.fillWidth: true
                visible: NetworkService.wiredDevice !== null
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

                    Text {
                        text: "\ueb2f"
                        color: NetworkService.wiredConnected ? ShellPalette.foreground : ShellPalette.foregroundMuted
                        font.family: Theme.font.symbols
                        font.pixelSize: Theme.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: NetworkService.wiredConnected ? NetworkService.connectionName : "Ethernet"
                            color: ShellPalette.foreground
                            elide: Text.ElideRight
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodyLargeSize
                            font.weight: Theme.font.titleMediumWeight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: NetworkService.wiredConnected ? NetworkService.status : NetworkService.wiredDevice.available ? "Not connected" : "Cable unplugged"
                            color: ShellPalette.foregroundMuted
                            elide: Text.ElideRight
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodySmallSize
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: NetworkService.wirelessDevice !== null
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

                    Text {
                        text: NetworkService.wifiEnabled ? "\ue63e" : "\ue648"
                        color: NetworkService.wifiEnabled ? ShellPalette.foreground : ShellPalette.foregroundMuted
                        font.family: Theme.font.symbols
                        font.pixelSize: Theme.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: "Wi-Fi"
                            color: ShellPalette.foreground
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodyLargeSize
                            font.weight: Theme.font.titleMediumWeight
                        }

                        Text {
                            text: NetworkService.wifiEnabled ? "On" : "Off"
                            color: ShellPalette.foregroundMuted
                            font.family: Theme.font.plain
                            font.pixelSize: Theme.font.bodySmallSize
                        }
                    }

                    MenuIconButton {
                        icon: "\ue5d5"
                        busy: NetworkService.scanning
                        enabled: NetworkService.wifiAvailable
                        onActivated: NetworkService.refresh(true)
                    }

                    ToggleSwitch {
                        checked: NetworkService.wifiEnabled
                        onToggled: checked => NetworkService.setWifi(checked)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: ShellPalette.foreground
                wrapMode: Text.Wrap
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.bodySmallSize
            }

            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !NetworkService.wifiAvailable || networkModel.values.length === 0
                text: NetworkService.wifiAvailable ? "Searching for networks..." : "Turn on Wi-Fi to see nearby networks."
                color: ShellPalette.foregroundMuted
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.bodyMediumSize
            }

            ListView {
                id: networkList

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: NetworkService.wifiAvailable && count > 0
                clip: true
                spacing: Theme.metrics.listSpacing
                boundsBehavior: Flickable.StopAtBounds
                model: networkModel

                delegate: NetworkRow {
                    required property var modelData

                    width: networkList.width
                    network: modelData
                    onPasswordRequested: network => root.beginPassword(network)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.pendingNetwork !== null
            spacing: Theme.space.medium

            Item {
                Layout.fillHeight: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "\ue63e"
                color: ShellPalette.foreground
                font.family: Theme.font.symbols
                font.pixelSize: Theme.icon.extraLarge
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Theme.metrics.textFieldHeight
                radius: Theme.shape.medium
                color: ShellPalette.surface
                border.width: passwordInput.activeFocus ? Theme.metrics.focusStroke : Theme.metrics.stroke
                border.color: passwordInput.activeFocus ? ShellPalette.foreground : ShellPalette.indicator

                TextInput {
                    id: passwordInput

                    anchors.left: parent.left
                    anchors.right: showPassword.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Theme.space.medium
                    anchors.rightMargin: Theme.space.small
                    text: root.password
                    color: ShellPalette.foreground
                    selectionColor: ShellPalette.indicator
                    selectedTextColor: ShellPalette.foreground
                    echoMode: root.passwordVisible ? TextInput.Normal : TextInput.Password
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.bodyLargeSize
                    onTextChanged: root.password = text
                    Keys.onReturnPressed: root.connectPending()
                }

                Text {
                    id: showPassword

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Theme.space.medium
                    text: root.passwordVisible ? "\ue8f5" : "\ue8f4"
                    color: ShellPalette.foregroundMuted
                    font.family: Theme.font.symbols
                    font.pixelSize: Theme.icon.small

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Theme.space.medium
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.passwordVisible = !root.passwordVisible
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.errorMessage.length > 0
                text: root.errorMessage
                color: ShellPalette.foreground
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.bodySmallSize
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Theme.metrics.primaryButtonHeight
                radius: Theme.shape.full
                color: root.password.length >= 8 ? ShellPalette.foreground : ShellPalette.indicator

                Text {
                    anchors.centerIn: parent
                    text: root.pendingNetwork && NetworkService.connectingName === root.pendingNetwork.name ? "Connecting..." : "Connect"
                    color: root.password.length >= 8 ? ShellPalette.background : ShellPalette.foregroundMuted
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.labelLargeSize
                    font.weight: Theme.font.labelLargeWeight
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.password.length >= 8 && root.pendingNetwork && NetworkService.connectingName !== root.pendingNetwork.name
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.connectPending()
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
