import QtQuick

Rectangle {
    id: root

    property string text: ""
    property bool requested: false
    property string placement: "left"

    readonly property bool shown: requested && delay.ready && text.length > 0

    width: Math.min(label.implicitWidth + 16, 138)
    height: Math.max(26, label.implicitHeight + 12)
    x: placement === "top" ? (parent.width - width) / 2 : -width - 6
    y: placement === "top" ? -height - 6 : (parent.height - height) / 2
    z: 1000
    visible: opacity > 0
    opacity: shown ? 1 : 0

    radius: Theme.shape.small
    color: ShellPalette.surface
    border.width: 1
    border.color: ShellPalette.indicator

    onRequestedChanged: {
        if (requested)
            delay.restart();
        else
            delay.ready = false;
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.duration.short2
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: delay

        property bool ready: false

        interval: 1200
        onTriggered: ready = true
    }

    Text {
        id: label

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.text
        color: ShellPalette.foreground
        font.family: Theme.font.plain
        font.pixelSize: Theme.font.labelSmallSize
        font.weight: Theme.font.labelSmallWeight
    }
}
