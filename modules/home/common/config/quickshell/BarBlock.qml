import QtQuick

Rectangle {
    id: root

    property string icon: ""
    property string badgeIcon: ""
    property string secondaryIcon: ""
    property bool split: false
    property bool active: false
    property bool secondaryActive: false
    property bool placeholder: false
    property bool scrollEnabled: false
    property real level: -1
    property string tooltip: ""
    property string tooltipPlacement: "left"

    readonly property real boundedLevel: Math.max(0, Math.min(1, level))
    readonly property bool hovered: primaryArea.containsMouse || secondaryArea.containsMouse

    property real scrollAccumulator: 0

    signal activated
    signal contextActivated
    signal secondaryActivated
    signal scrolled(int steps)

    implicitWidth: Theme.metrics.barThickness
    implicitHeight: Theme.metrics.barThickness

    radius: Theme.shape.medium
    color: placeholder ? Qt.alpha(ShellPalette.surface, Theme.opacity.placeholder) : ShellPalette.surface
    border.width: Theme.metrics.stroke
    border.color: ShellPalette.indicator

    Rectangle {
        id: levelFill

        visible: !root.split && root.level >= 0
        x: Theme.metrics.stroke
        width: parent.width - Theme.metrics.stroke * 2
        height: Math.round((parent.height - Theme.metrics.stroke * 2) * root.boundedLevel)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.metrics.stroke
        topLeftRadius: height > parent.height - root.radius ? root.radius - Theme.metrics.stroke : 0
        topRightRadius: topLeftRadius
        bottomLeftRadius: root.radius - Theme.metrics.stroke
        bottomRightRadius: root.radius - Theme.metrics.stroke
        color: root.active ? ShellPalette.indicator : Qt.alpha(ShellPalette.foreground, Theme.opacity.low)

        Behavior on height {
            NumberAnimation {
                duration: Theme.duration.medium1
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        visible: levelFill.visible && root.boundedLevel > 0 && root.boundedLevel < 1
        x: Theme.metrics.focusStroke
        y: levelFill.y
        width: parent.width - Theme.space.extraSmall
        height: Theme.metrics.stroke
        color: Qt.alpha(ShellPalette.foreground, root.active ? Theme.opacity.boundary : Theme.opacity.medium)

        Behavior on y {
            NumberAnimation {
                duration: Theme.duration.medium1
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.split ? parent.width / 2 : parent.width
        topLeftRadius: root.radius
        bottomLeftRadius: root.radius
        topRightRadius: root.split ? 0 : root.radius
        bottomRightRadius: root.split ? 0 : root.radius
        color: primaryArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : root.active && root.level < 0 ? Qt.alpha(ShellPalette.foreground, Theme.opacity.selected) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.short3
            }
        }
    }

    Rectangle {
        visible: root.split
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: parent.width / 2
        topRightRadius: root.radius
        bottomRightRadius: root.radius
        color: secondaryArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : root.secondaryActive ? Qt.alpha(ShellPalette.foreground, Theme.opacity.selected) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.short3
            }
        }
    }

    Rectangle {
        visible: root.split
        width: Theme.metrics.stroke
        height: parent.height - Theme.space.small * 2
        anchors.centerIn: parent
        color: ShellPalette.indicator
    }

    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.split ? parent.width / 2 : parent.width

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? ShellPalette.foreground : ShellPalette.foregroundMuted
            font.family: Theme.font.symbols
            font.pixelSize: root.split ? Theme.icon.compact : Theme.icon.medium
            font.weight: Theme.font.mediumWeight
        }
    }

    Text {
        visible: !root.split && root.badgeIcon.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.space.extraSmall
        anchors.rightMargin: Theme.space.extraSmall
        text: root.badgeIcon
        color: root.active ? ShellPalette.foreground : ShellPalette.foregroundMuted
        font.family: Theme.font.symbols
        font.pixelSize: Theme.icon.badge
        font.weight: Theme.font.mediumWeight
    }

    Item {
        visible: root.split
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: parent.width / 2

        Text {
            anchors.centerIn: parent
            text: root.secondaryIcon
            color: root.secondaryActive ? ShellPalette.foreground : ShellPalette.foregroundMuted
            font.family: Theme.font.symbols
            font.pixelSize: Theme.icon.compact
            font.weight: Theme.font.mediumWeight
        }
    }

    MouseArea {
        id: primaryArea

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.split ? parent.width / 2 : parent.width
        enabled: !root.placeholder
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root.contextActivated();
            else
                root.activated();
        }
        onWheel: function (wheel) {
            if (!root.scrollEnabled) {
                wheel.accepted = false;
                return;
            }

            const angled = wheel.angleDelta.y !== 0;
            const threshold = angled ? 120 : 40;
            root.scrollAccumulator += angled ? wheel.angleDelta.y : wheel.pixelDelta.y;

            const steps = root.scrollAccumulator > 0 ? Math.floor(root.scrollAccumulator / threshold) : Math.ceil(root.scrollAccumulator / threshold);
            if (steps !== 0) {
                root.scrollAccumulator -= steps * threshold;
                root.scrolled(-steps);
            }
            wheel.accepted = true;
        }
    }

    MouseArea {
        id: secondaryArea

        visible: root.split
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: parent.width / 2
        enabled: !root.placeholder
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.secondaryActivated()
    }

    HoverTip {
        text: root.tooltip
        requested: root.hovered
        placement: root.tooltipPlacement
    }
}
