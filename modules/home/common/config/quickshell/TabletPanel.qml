import QtQuick
import QtQuick.Layouts

Item {
    id: root

    signal requestClose

    implicitWidth: 380
    implicitHeight: 280
    focus: true

    Keys.onEscapePressed: requestClose()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.medium

        MenuHeader {
            Layout.fillWidth: true
            title: "Tablet controls"
            subtitle: "Input and orientation"
            onClose: root.requestClose()
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Theme.space.small
            columnSpacing: Theme.space.small

            ChoiceButton {
                Layout.fillWidth: true
                text: SystemActions.awake ? "Awake: On" : "Awake: Off"
                checked: SystemActions.awake
                enabled: !SystemActions.actionBusy
                onActivated: SystemActions.toggleAwake()
            }

            ChoiceButton {
                Layout.fillWidth: true
                text: SystemActions.rotationLocked ? "Rotation: Locked" : "Rotation: Auto"
                checked: SystemActions.rotationLocked
                enabled: !SystemActions.actionBusy
                onActivated: SystemActions.toggleRotationLock()
            }

            ChoiceButton {
                Layout.fillWidth: true
                text: "Keyboard"
                enabled: !SystemActions.actionBusy
                onActivated: SystemActions.toggleKeyboard()
            }

            ChoiceButton {
                Layout.fillWidth: true
                text: SystemActions.tabletLocked ? "Tablet: Locked" : "Tablet: Auto"
                checked: SystemActions.tabletLocked
                enabled: !SystemActions.actionBusy
                onActivated: SystemActions.toggleTabletLock()
            }
        }
    }
}
