pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: stack.implicitHeight

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ScriptModel {
        id: popupModel

        objectProp: "id"
        values: NotificationService.popups
    }

    Column {
        id: stack

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space.small

        move: Transition {
            id: moveTransition

            NumberAnimation {
                property: "y"
                duration: moveTransition.ViewTransition.targetItems.length === 0 ? Theme.duration.medium2 : 0
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: popupModel

            delegate: NotificationPopup {
                required property var modelData

                width: stack.width
                notification: modelData
                now: clock.date
            }
        }
    }
}
