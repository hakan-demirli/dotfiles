import QtQuick

Rectangle {
    id: root

    property string text: ""
    property bool checked: false

    signal activated

    implicitHeight: 44
    radius: Theme.shape.full
    color: checked
        ? ShellPalette.indicator
        : area.containsMouse
            ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity)
            : ShellPalette.surface
    border.width: 1
    border.color: ShellPalette.indicator

    Text {
        anchors.centerIn: parent
        text: root.text
        color: root.enabled
            ? ShellPalette.foreground
            : ShellPalette.foregroundMuted
        font.family: Theme.font.plain
        font.pixelSize: Theme.font.labelMediumSize
        font.weight: Theme.font.labelMediumWeight
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
