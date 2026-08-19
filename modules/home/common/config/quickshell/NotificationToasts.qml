pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: stack.contentHeight

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ScriptModel {
        id: popupModel

        values: NotificationService.popups
    }

    ListView {
        id: stack

        anchors.fill: parent
        spacing: Theme.space.small
        interactive: false
        model: popupModel

        delegate: NotificationPopup {
            required property var modelData

            width: stack.width
            notification: modelData
            now: clock.date
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.duration.medium2
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                property: "x"
                from: stack.width
                to: 0
                duration: Theme.duration.medium2
                easing.type: Easing.OutCubic
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Theme.duration.short4
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                property: "x"
                to: stack.width
                duration: Theme.duration.short4
                easing.type: Easing.InCubic
            }
        }

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: Theme.duration.medium1
                easing.type: Easing.OutCubic
            }
        }
    }
}
