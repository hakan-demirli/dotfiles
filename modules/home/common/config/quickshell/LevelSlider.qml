import QtQuick

Item {
    id: root

    property real value: 0

    signal moved(real value)

    readonly property real boundedValue: Math.max(0, Math.min(1, value))

    implicitHeight: Theme.metrics.sliderHeight

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Theme.metrics.sliderTrackHeight
        radius: Theme.shape.full
        color: ShellPalette.surface
        border.width: Theme.metrics.stroke
        border.color: ShellPalette.indicator

        Rectangle {
            width: parent.width * root.boundedValue
            height: parent.height
            radius: parent.radius
            color: ShellPalette.indicator
        }
    }

    Rectangle {
        width: Theme.metrics.sliderHandleSize
        height: Theme.metrics.sliderHandleSize
        radius: Theme.shape.full
        x: Math.max(0, Math.min(parent.width - width, parent.width * root.boundedValue - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        color: ShellPalette.foreground
        border.width: Theme.metrics.focusStroke
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
