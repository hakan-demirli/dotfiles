import QtQuick

Rectangle {
    id: root

    property string text: ""
    property bool requested: false
    property string placement: "left"

    readonly property bool shown: requested && delay.ready && text.length > 0

    width: Math.min(label.implicitWidth + Theme.space.large, Theme.metrics.tooltipMaximumWidth)
    height: Math.max(Theme.metrics.tooltipMinimumHeight, label.implicitHeight + Theme.space.medium)
    x: placement === "top" ? (parent.width - width) / 2 : -width - Theme.space.small
    y: placement === "top" ? -height - Theme.space.small : (parent.height - height) / 2
    z: Theme.metrics.overlayZ
    visible: opacity > 0
    opacity: shown ? 1 : 0

    radius: Theme.shape.small
    color: ShellPalette.surface
    border.width: Theme.metrics.stroke
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

        interval: Theme.duration.extraLong4 + Theme.duration.short4
        onTriggered: ready = true
    }

    Text {
        id: label

        anchors.fill: parent
        anchors.leftMargin: Theme.space.small
        anchors.rightMargin: Theme.space.small
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
