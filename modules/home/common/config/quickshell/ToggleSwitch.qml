import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32
    Layout.minimumWidth: implicitWidth
    Layout.preferredWidth: implicitWidth
    Layout.maximumWidth: implicitWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.maximumHeight: implicitHeight
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    radius: height / 2
    color: checked ? ShellPalette.indicator : ShellPalette.surface
    border.width: 1
    border.color: ShellPalette.indicator

    Behavior on color {
        ColorAnimation {
            duration: Theme.duration.short4
        }
    }

    Rectangle {
        width: 24
        height: 24
        radius: height / 2
        y: (parent.height - height) / 2
        x: root.checked ? parent.width - width - 4 : 4
        color: root.checked
            ? ShellPalette.foreground
            : ShellPalette.foregroundMuted

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
