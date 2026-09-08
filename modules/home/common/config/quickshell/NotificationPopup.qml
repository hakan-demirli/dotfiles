import QtQuick

Item {
    id: root

    required property var notification
    required property date now

    readonly property int lifetime: notification ? NotificationService.timeout(notification) : 0

    implicitHeight: card.implicitHeight

    Component.onCompleted: entrance.start()

    HoverHandler {
        id: hover
    }

    Timer {
        interval: root.lifetime
        running: root.lifetime > 0 && !hover.hovered
        onTriggered: NotificationService.retire(root.notification)
    }

    ParallelAnimation {
        id: entrance

        NumberAnimation {
            target: card
            property: "opacity"
            to: 1
            duration: Theme.duration.medium2
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: entranceOffset
            property: "x"
            to: 0
            duration: Theme.duration.medium2
            easing.type: Easing.OutCubic
        }
    }

    NotificationCard {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        opacity: 0
        transform: Translate {
            id: entranceOffset

            x: root.width
        }
        notification: root.notification
        now: root.now
    }
}
