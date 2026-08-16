import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property bool busy: false

    signal activated

    implicitWidth: 40
    implicitHeight: 40
    radius: Theme.shape.full
    color: area.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : "transparent"

    Text {
        id: glyph

        anchors.centerIn: parent
        text: root.icon
        color: root.enabled ? ShellPalette.foreground : ShellPalette.foregroundMuted
        font.family: "Material Symbols Rounded"
        font.pixelSize: 22

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.busy
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
