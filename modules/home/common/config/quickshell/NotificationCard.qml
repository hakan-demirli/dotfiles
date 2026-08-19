pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

Item {
    id: root

    required property var notification
    required property date now

    property bool showApplication: true

    readonly property bool live: notification !== null

    readonly property bool critical: live && notification.urgency === NotificationUrgency.Critical
    readonly property string summary: live ? notification.summary : ""
    readonly property string body: live ? notification.body : ""
    readonly property string image: live ? notification.image : ""
    readonly property string icon: live && notification.appIcon.length > 0 ? Quickshell.iconPath(notification.appIcon, true) : ""
    readonly property string application: live ? NotificationService.applicationName(notification) : ""
    readonly property string age: live ? NotificationService.relativeTime(notification, now) : ""
    readonly property string code: live ? NotificationService.code(notification) : ""
    readonly property var actions: live ? NotificationService.buttonActions(notification) : []
    readonly property var fallback: live ? NotificationService.defaultAction(notification) : null

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
        enabled: root.fallback !== null
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationService.invoke(root.notification, root.fallback)
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

                Text {
                    Layout.fillWidth: true
                    text: root.summary
                    color: ShellPalette.foreground
                    elide: Text.ElideRight
                    font.family: Theme.font.plain
                    font.pixelSize: Theme.font.bodyLargeSize
                    font.weight: Theme.font.titleMediumWeight
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
                    onActivated: NotificationService.dismiss(root.notification)
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
                maximumLineCount: Theme.metrics.notificationBodyLineLimit
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
