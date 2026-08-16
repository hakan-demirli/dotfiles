import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""

    signal activated

    implicitHeight: 64
    radius: Theme.shape.large
    color: area.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : ShellPalette.surface
    border.width: 1
    border.color: ShellPalette.indicator

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space.medium
        anchors.rightMargin: Theme.space.medium
        spacing: Theme.space.medium

        Text {
            text: root.icon
            color: ShellPalette.foreground
            font.family: "Material Symbols Rounded"
            font.pixelSize: 25
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: ShellPalette.foreground
                elide: Text.ElideRight
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.bodyLargeSize
                font.weight: Theme.font.titleMediumWeight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: ShellPalette.foregroundMuted
                elide: Text.ElideRight
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.bodySmallSize
            }
        }

        Text {
            text: "\ue5cc"
            color: ShellPalette.foregroundMuted
            font.family: "Material Symbols Rounded"
            font.pixelSize: 20
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
