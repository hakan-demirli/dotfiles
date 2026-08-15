import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose

    implicitWidth: 380
    implicitHeight: 410
    focus: true

    Keys.onEscapePressed: requestClose()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
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
            onActivated: SystemActions.power("sleep")
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue897"
            title: "Hibernate"
            onActivated: SystemActions.power("hibernate")
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue9ba"
            title: "Log out"
            onActivated: SystemActions.power("logout")
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue042"
            title: "Restart"
            onActivated: SystemActions.power("reboot")
        }

        ControlTile {
            Layout.fillWidth: true
            icon: "\ue8ac"
            title: "Shut down"
            onActivated: SystemActions.power("shutdown")
        }
    }
}
