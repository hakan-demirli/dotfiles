import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property bool showBack: false

    signal back
    signal close

    implicitHeight: 44

    RowLayout {
        anchors.fill: parent
        spacing: Theme.space.small

        Rectangle {
            visible: root.showBack
            implicitWidth: 32
            implicitHeight: 32
            radius: Theme.shape.full
            color: backArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "\ue5c4"
                color: ShellPalette.foreground
                font.family: "Material Symbols Rounded"
                font.pixelSize: 19
            }

            MouseArea {
                id: backArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.title
            color: ShellPalette.foreground
            elide: Text.ElideRight
            font.family: Theme.font.plain
            font.pixelSize: Theme.font.titleMediumSize
            font.weight: Theme.font.titleMediumWeight
        }

        Rectangle {
            implicitWidth: 32
            implicitHeight: 32
            radius: Theme.shape.full
            color: closeArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "\ue5cd"
                color: ShellPalette.foreground
                font.family: "Material Symbols Rounded"
                font.pixelSize: 19
            }

            MouseArea {
                id: closeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
            }
        }
    }
}
