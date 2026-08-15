import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    signal requestClose

    implicitWidth: 380
    implicitHeight: 250
    focus: true

    Keys.onEscapePressed: requestClose()

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.medium

        MenuHeader {
            Layout.fillWidth: true
            title: "Time"
            subtitle: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")
            onClose: root.requestClose()
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.shape.large
            color: ShellPalette.surface
            border.width: 1
            border.color: ShellPalette.indicator

            Row {
                anchors.centerIn: parent
                spacing: Theme.space.medium

                Repeater {
                    model: [
                        Qt.formatTime(clock.date, "HH"),
                        Qt.formatTime(clock.date, "mm"),
                    ]

                    Text {
                        required property string modelData

                        text: modelData
                        color: ShellPalette.foreground
                        font.family: Theme.font.mono
                        font.pixelSize: 52
                        font.weight: 700
                    }
                }
            }
        }
    }
}
