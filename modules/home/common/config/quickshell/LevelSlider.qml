import QtQuick

Item {
    id: root

    property real value: 0

    signal moved(real value)

    readonly property real boundedValue: Math.max(0, Math.min(1, value))

    implicitHeight: 40

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        radius: height / 2
        color: ShellPalette.surface
        border.width: 1
        border.color: ShellPalette.indicator

        Rectangle {
            width: parent.width * root.boundedValue
            height: parent.height
            radius: parent.radius
            color: ShellPalette.indicator
        }
    }

    Rectangle {
        width: 20
        height: 20
        radius: height / 2
        x: Math.max(0, Math.min(parent.width - width, parent.width * root.boundedValue - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: ShellPalette.foreground
        border.width: 2
        border.color: ShellPalette.indicator
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function update(mouseX) {
            root.moved(Math.max(0, Math.min(1, mouseX / width)));
        }

        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                update(mouse.x);
        }
    }
}
