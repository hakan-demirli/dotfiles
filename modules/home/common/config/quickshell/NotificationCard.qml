pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property var notification
    required property date now

    property bool showApplication: true
    property int bodyLineLimit: Theme.metrics.notificationBodyLineLimit

    readonly property bool live: notification !== null

    readonly property int tier: live ? NotificationPolicy.tier(notification) : NotificationPolicy.Tier.Active
    readonly property bool critical: tier === NotificationPolicy.Tier.Critical
    readonly property bool passive: tier === NotificationPolicy.Tier.Passive
    readonly property var record: live ? NotificationService.record(notification) : null
    readonly property bool unseen: record !== null && !record.seen && tier >= NotificationPolicy.Tier.Active
    readonly property int repeats: record !== null ? record.repeats : 1
    readonly property string summary: live ? notification.summary : ""
    readonly property string body: live ? notification.body : ""
    readonly property string image: live ? notification.image : ""
    readonly property string icon: live && notification.appIcon.length > 0 ? Quickshell.iconPath(notification.appIcon, true) : ""
    readonly property string application: live ? NotificationService.applicationName(notification) : ""
    readonly property string age: live ? NotificationService.relativeTime(notification, now) : ""
    readonly property string code: live ? NotificationPolicy.code(notification) : ""
    readonly property var actions: live ? NotificationService.buttonActions(notification) : []
    readonly property bool activatable: live && NotificationService.activatable(notification)

    signal closeRequested

    implicitHeight: layout.implicitHeight + Theme.space.medium * 2

    Rectangle {
        anchors.fill: parent
        radius: Theme.shape.large
        color: ShellPalette.surface
        border.width: Theme.metrics.stroke
        border.color: root.critical ? Theme.palette.m3error : ShellPalette.indicator
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.activatable
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationService.activate(root.notification)
    }

    RowLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space.medium
        spacing: Theme.space.medium

        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            visible: root.image.length > 0
            implicitWidth: Theme.metrics.notificationImageSize
            implicitHeight: Theme.metrics.notificationImageSize
            radius: Theme.shape.small
            color: ShellPalette.background

            Image {
                anchors.fill: parent
                source: root.image
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Theme.metrics.notificationImageSize
                sourceSize.height: Theme.metrics.notificationImageSize
                asynchronous: true
            }
        }

        IconImage {
            Layout.alignment: Qt.AlignTop
            visible: root.image.length === 0 && root.icon.length > 0
            implicitSize: Theme.metrics.notificationAppIconSize
            source: root.icon
            asynchronous: true
        }

        Text {
            Layout.alignment: Qt.AlignTop
            visible: root.image.length === 0 && root.icon.length === 0
            text: root.critical ? "\ue002" : "\ue7f4"
            color: root.critical ? Theme.palette.m3error : ShellPalette.foregroundMuted
            font.family: Theme.font.symbols
            font.pixelSize: Theme.icon.medium
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space.extraSmall

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space.small

                Rectangle {
                    visible: root.unseen
                    implicitWidth: Theme.space.small
                    implicitHeight: Theme.space.small
                    radius: Theme.shape.full
                    color: Theme.palette.m3primary
                }

                Text {
                    Layout.fillWidth: true
                    text: root.summary
                    color: root.passive ? ShellPalette.foregroundMuted : ShellPalette.foreground
                    elide: Text.ElideRight
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.bodyLargeSize
                    font.weight: Theme.font.titleMediumWeight
                }

                Text {
                    visible: root.repeats > 1
                    text: `×${root.repeats}`
                    color: ShellPalette.foregroundMuted
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.labelSmallSize
                    font.weight: Theme.font.labelSmallWeight
                }

                Text {
                    text: root.age
                    visible: text.length > 0
                    color: ShellPalette.foregroundMuted
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.labelSmallSize
                    font.weight: Theme.font.labelSmallWeight
                }

                MenuIconButton {
                    implicitWidth: Theme.metrics.compactIconButtonSize
                    implicitHeight: Theme.metrics.compactIconButtonSize
                    icon: "\ue5cd"
                    onActivated: root.closeRequested()
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.showApplication
                text: root.application
                color: ShellPalette.foregroundMuted
                elide: Text.ElideRight
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.labelSmallSize
                font.weight: Theme.font.labelSmallWeight
            }

            Text {
                Layout.fillWidth: true
                visible: root.body.length > 0
                text: root.body
                color: ShellPalette.foregroundMuted
                textFormat: Text.StyledText
                linkColor: Theme.palette.m3primary
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: root.bodyLineLimit
                font.family: Theme.font.plain
                font.pixelSize: Theme.font.bodyMediumSize
                onLinkActivated: link => Quickshell.execDetached(["xdg-open", link])
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.space.extraSmall
                visible: root.actions.length > 0 || root.code.length > 0
                spacing: Theme.space.small

                ChoiceButton {
                    Layout.fillWidth: true
                    visible: root.code.length > 0
                    implicitHeight: Theme.metrics.compactButtonHeight
                    text: `Copy ${root.code}`
                    onActivated: NotificationService.copyCode(root.notification)
                }

                Repeater {
                    model: root.actions

                    ChoiceButton {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: Theme.metrics.compactButtonHeight
                        text: modelData.text
                        onActivated: NotificationService.invoke(root.notification, modelData)
                    }
                }
            }
        }
    }
}
