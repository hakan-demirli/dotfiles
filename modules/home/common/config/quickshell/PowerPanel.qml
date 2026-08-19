import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string pendingAction: ""

    signal requestClose

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: actionLayout.implicitHeight + Theme.space.large * 2
    focus: true

    function actionIcon(action) {
        switch (action) {
        case "suspend":
            return "\ue1a6";
        case "hibernate":
            return "\ue897";
        case "logout":
            return "\ue9ba";
        case "reboot":
            return "\ue042";
        case "shutdown":
            return "\ue8ac";
        default:
            return "";
        }
    }

    function actionTitle(action) {
        switch (action) {
        case "suspend":
            return "Suspend";
        case "hibernate":
            return "Hibernate";
        case "logout":
            return "Log out";
        case "reboot":
            return "Restart";
        case "shutdown":
            return "Shut down";
        default:
            return "";
        }
    }

    function actionPrompt(action) {
        switch (action) {
        case "suspend":
            return "Suspend this device now?";
        case "hibernate":
            return "Hibernate this device now?";
        case "logout":
            return "Log out of this session now?";
        case "reboot":
            return "Restart this device now?";
        case "shutdown":
            return "Shut down this device now?";
        default:
            return "";
        }
    }

    function confirmAction() {
        const action = pendingAction;
        pendingAction = "";
        requestClose();
        SystemActions.executePowerAction(action);
    }

    Keys.onEscapePressed: {
        if (pendingAction)
            pendingAction = "";
        else
            requestClose();
    }

    ColumnLayout {
        id: actionLayout

        anchors.fill: parent
        anchors.margins: Theme.space.large
        visible: root.pendingAction.length === 0
        spacing: Theme.space.small

        MenuHeader {
            Layout.fillWidth: true
            title: "Power"
            subtitle: "Session and system"
            onClose: root.requestClose()
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue1a6"
            title: "Suspend"
            onActivated: root.pendingAction = "suspend"
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue897"
            title: "Hibernate"
            onActivated: root.pendingAction = "hibernate"
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue9ba"
            title: "Log out"
            onActivated: root.pendingAction = "logout"
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue042"
            title: "Restart"
            onActivated: root.pendingAction = "reboot"
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue8ac"
            title: "Shut down"
            onActivated: root.pendingAction = "shutdown"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        visible: root.pendingAction.length > 0
        spacing: Theme.space.medium

        MenuHeader {
            Layout.fillWidth: true
            title: "Confirm action"
            showBack: true
            onBack: root.pendingAction = ""
            onClose: root.requestClose()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.shape.large
            color: ShellPalette.surface
            border.width: Theme.metrics.stroke
            border.color: ShellPalette.indicator

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - Theme.space.extraLarge * 2
                spacing: Theme.space.small

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.actionIcon(root.pendingAction)
                    color: ShellPalette.foreground
                    font.family: Theme.font.symbols
                    font.pixelSize: Theme.icon.hero
                }

                Text {
                    Layout.fillWidth: true
                    text: root.actionTitle(root.pendingAction)
                    color: ShellPalette.foreground
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.titleLargeSize
                    font.weight: Theme.font.titleLargeWeight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.actionPrompt(root.pendingAction)
                    color: ShellPalette.foregroundMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.bodyMediumSize
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space.small

            ChoiceButton {
                Layout.fillWidth: true
                text: "Cancel"
                onActivated: root.pendingAction = ""
            }

            ChoiceButton {
                Layout.fillWidth: true
                text: root.actionTitle(root.pendingAction)
                checked: true
                onActivated: root.confirmAction()
            }
        }
    }
}
