import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: Theme.metrics.switchWidth
    implicitHeight: Theme.metrics.switchHeight
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    radius: Theme.shape.full
    color: checked ? ShellPalette.indicator : ShellPalette.surface
    border.width: Theme.metrics.stroke
    border.color: ShellPalette.indicator

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.short4
        }
    }

    Rectangle {
        width: Theme.metrics.switchHandleSize
        height: Theme.metrics.switchHandleSize
        radius: Theme.shape.full
        y: (parent.height - height) / 2
        x: root.checked ? parent.width - width - Theme.space.extraSmall : Theme.space.extraSmall
        color: root.checked ? ShellPalette.foreground : ShellPalette.foregroundMuted

        Behavior on x {
            NumberAnimation {
                duration: Theme.duration.short4
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
