import QtQuick

Rectangle {
    id: root

    property string hours: "--"
    property string minutes: "--"
    property string tooltip: ""

    signal activated

    implicitWidth: 47
    implicitHeight: 47

    radius: Theme.shape.medium
    color: ShellPalette.surface
    border.width: 1
    border.color: ShellPalette.indicator

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: area.containsMouse
            ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity)
            : Qt.alpha(ShellPalette.foreground, 0.04)

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.short3
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.space.small

        Repeater {
            model: [root.hours, root.minutes]

            Text {
                required property string modelData

                text: modelData
                color: ShellPalette.foreground
                font.family: Theme.font.mono
                font.pixelSize: 24
                font.weight: 700
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    HoverTip {
        text: root.tooltip
        requested: area.containsMouse
        placement: "top"
    }
}
