pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root

    signal requestPanel

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

        Rectangle {
            visible: NotificationService.overflow > 0
            anchors.right: parent.right
            implicitWidth: overflowLabel.implicitWidth + Theme.space.large * 2
            implicitHeight: Theme.metrics.compactButtonHeight
            radius: Theme.shape.full
            color: overflowArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : ShellPalette.surface
            border.width: Theme.metrics.stroke
            border.color: ShellPalette.indicator

            Text {
                id: overflowLabel

                anchors.centerIn: parent
                text: `${NotificationService.overflow} more in notifications`
                color: ShellPalette.foreground
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.labelMediumSize
                font.weight: Theme.font.labelMediumWeight
            }

            MouseArea {
                id: overflowArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.requestPanel()
            }
        }
    }
}
