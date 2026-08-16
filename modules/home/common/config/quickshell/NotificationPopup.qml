import QtQuick

Item {
    id: root

    required property var notification
    required property date now

    readonly property int lifetime: notification ? NotificationService.timeout(notification) : 0

    implicitHeight: card.implicitHeight

    HoverHandler {
        id: hover
    }

    Timer {
        interval: root.lifetime
        running: root.lifetime > 0 && !hover.hovered
        onTriggered: NotificationService.retire(root.notification)
    }

    NotificationCard {
        id: card

        anchors.left: parent.left
        anchors.right: parent.right
        notification: root.notification
        now: root.now
    }
}
