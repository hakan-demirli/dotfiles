pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    signal requestClose

    implicitWidth: 380
    implicitHeight: 560
    focus: true

    Keys.onEscapePressed: requestClose()

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ScriptModel {
        id: groupModel

        values: NotificationService.groups
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.space.large
        spacing: Theme.space.small

        MenuHeader {
            Layout.fillWidth: true
            title: "Notifications"
            subtitle: NotificationService.count > 0 ? `${NotificationService.count} waiting` : "Nothing waiting"
            onClose: root.requestClose()
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 60
            radius: Theme.shape.large
            color: ShellPalette.surface
            border.width: 1
            border.color: ShellPalette.indicator

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space.medium
                anchors.rightMargin: Theme.space.medium
                spacing: Theme.space.medium

                Text {
                    text: NotificationService.doNotDisturb ? "\ue51d" : "\ue7f4"
                    color: NotificationService.doNotDisturb ? ShellPalette.foreground : ShellPalette.foregroundMuted
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 24
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        text: "Do not disturb"
                        color: ShellPalette.foreground
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.bodyLargeSize
                        font.weight: Theme.font.titleMediumWeight
                    }

                    Text {
                        text: NotificationService.doNotDisturb ? "Only critical alerts appear" : "Popups on arrival"
                        color: ShellPalette.foregroundMuted
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.bodySmallSize
                    }
                }

                ToggleSwitch {
                    checked: NotificationService.doNotDisturb
                    onToggled: NotificationService.toggleDoNotDisturb()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.count === 0
            text: "No notifications"
            color: ShellPalette.foregroundMuted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.font.plain
            font.pixelSize: Theme.font.bodyMediumSize
        }

        ListView {
            id: groupList

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: count > 0
            clip: true
            spacing: Theme.space.medium
            boundsBehavior: Flickable.StopAtBounds
            model: groupModel

            delegate: ColumnLayout {
                id: group

                required property var modelData

                width: groupList.width
                spacing: Theme.space.extraSmall

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.space.extraSmall
                    Layout.rightMargin: Theme.space.extraSmall
                    spacing: Theme.space.small

                    Text {
                        Layout.fillWidth: true
                        text: group.modelData.name
                        color: ShellPalette.foregroundMuted
                        elide: Text.ElideRight
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.labelMediumSize
                        font.weight: Theme.font.labelMediumWeight
                    }

                    Text {
                        visible: group.modelData.entries.length > 1
                        text: group.modelData.entries.length
                        color: ShellPalette.foregroundMuted
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.labelSmallSize
                        font.weight: Theme.font.labelSmallWeight
                    }

                    MenuIconButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        icon: "\ue872"
                        onActivated: NotificationService.clearGroup(group.modelData)
                    }
                }

                Repeater {
                    model: group.modelData.entries

                    NotificationCard {
                        required property var modelData

                        Layout.fillWidth: true
                        notification: modelData
                        now: clock.date
                        showApplication: false
                    }
                }
            }
        }

        ChoiceButton {
            Layout.fillWidth: true
            visible: NotificationService.count > 0
            text: "Clear all"
            onActivated: NotificationService.clear()
        }
    }
}
