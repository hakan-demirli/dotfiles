import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    signal requestClose

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: content.implicitHeight + Theme.space.large * 2
    focus: true

    Keys.onEscapePressed: requestClose()

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    ColumnLayout {
        id: content

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
            implicitHeight: clockDigits.implicitHeight + Theme.space.extraLarge * 2
            radius: Theme.shape.large
            color: ShellPalette.surface
            border.width: Theme.metrics.stroke
            border.color: ShellPalette.indicator

            Row {
                id: clockDigits

                anchors.centerIn: parent
                spacing: Theme.space.medium

                Repeater {
                    model: [Qt.formatTime(clock.date, "HH"), Qt.formatTime(clock.date, "mm"),]

                    Text {
                        required property string modelData

                        text: modelData
                        color: ShellPalette.foreground
                        font.family: Theme.font.mono
                        font.pixelSize: Theme.font.displayMediumLine
                        font.weight: Theme.font.boldWeight
                    }
                }
            }
        }
    }
}
