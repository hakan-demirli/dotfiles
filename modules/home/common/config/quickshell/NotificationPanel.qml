pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    readonly property int collapsedLimit: 3
    readonly property int collapsedBodyLineLimit: 2

    property var expanded: ({})

    signal requestClose

    function toggleExpanded(key) {
        const expanded = Object.assign({}, root.expanded);
        expanded[key] = !expanded[key];
        root.expanded = expanded;
    }

    implicitWidth: Theme.metrics.menuWidth
    implicitHeight: Theme.metrics.panelExtraTallHeight
    focus: true

    Keys.onEscapePressed: requestClose()

    Component.onCompleted: NotificationService.clearOverflow()
    Component.onDestruction: NotificationService.markSeen(NotificationService.stored)

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
            subtitle: NotificationService.unseen > 0 ? `${NotificationService.unseen} new` : NotificationService.count > 0 ? "Nothing new" : "Nothing waiting"
            onClose: root.requestClose()
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.metrics.controlRowHeight
            radius: Theme.shape.large
            color: ShellPalette.surface
            border.width: Theme.metrics.stroke
            border.color: ShellPalette.indicator

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.space.medium
                anchors.rightMargin: Theme.space.medium
                spacing: Theme.space.medium

                Text {
                    text: NotificationService.doNotDisturb ? "\ue51d" : "\ue7f4"
                    color: NotificationService.doNotDisturb ? ShellPalette.foreground : ShellPalette.foregroundMuted
                    font.family: Theme.font.symbols
                    font.pixelSize: Theme.icon.medium
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

                readonly property bool expanded: root.expanded[modelData.key] === true
                readonly property bool muted: NotificationService.muted(modelData.key)
                readonly property int overflow: modelData.entries.length - root.collapsedLimit

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
                        visible: group.muted
                        text: `Muted until ${Qt.formatTime(new Date(NotificationService.mutedUntil[group.modelData.key] ?? 0), "HH:mm")}`
                        color: ShellPalette.foregroundMuted
                        font.family: Theme.font.plain
                        font.pixelSize: Theme.font.labelSmallSize
                        font.weight: Theme.font.labelSmallWeight
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
                        implicitWidth: Theme.metrics.compactIconButtonSize
                        implicitHeight: Theme.metrics.compactIconButtonSize
                        icon: group.muted ? "\ue7f4" : "\ue7f8"
                        onActivated: group.muted ? NotificationService.unmute(group.modelData.key) : NotificationService.mute(group.modelData.key)
                    }

                    MenuIconButton {
                        implicitWidth: Theme.metrics.compactIconButtonSize
                        implicitHeight: Theme.metrics.compactIconButtonSize
                        icon: "\ue872"
                        onActivated: NotificationService.clearGroup(group.modelData)
                    }
                }

                Repeater {
                    model: group.expanded ? group.modelData.entries : group.modelData.entries.slice(0, root.collapsedLimit)

                    NotificationCard {
                        required property var modelData

                        Layout.fillWidth: true
                        notification: modelData
                        now: clock.date
                        showApplication: false
                        bodyLineLimit: group.overflow > 0 && !group.expanded ? root.collapsedBodyLineLimit : Theme.metrics.notificationBodyLineLimit
                        onCloseRequested: NotificationService.dismiss(modelData)
                    }
                }

                ChoiceButton {
                    Layout.fillWidth: true
                    visible: group.overflow > 0
                    implicitHeight: Theme.metrics.compactButtonHeight
                    text: group.expanded ? "Show less" : `Show ${group.overflow} more`
                    onActivated: root.toggleExpanded(group.modelData.key)
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
