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

    implicitWidth: 47
    implicitHeight: 47

    radius: Theme.shape.medium
    color: placeholder ? Qt.alpha(ShellPalette.surface, 0.28) : ShellPalette.surface
    border.width: 1
    border.color: ShellPalette.indicator

    Rectangle {
        id: levelFill

        visible: !root.split && root.level >= 0
        x: 1
        width: parent.width - 2
        height: Math.round((parent.height - 2) * root.boundedLevel)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        topLeftRadius: height > parent.height - root.radius ? root.radius - 1 : 0
        topRightRadius: topLeftRadius
        bottomLeftRadius: root.radius - 1
        bottomRightRadius: root.radius - 1
        color: root.active ? ShellPalette.indicator : Qt.alpha(ShellPalette.foreground, 0.10)

        Behavior on height {
            NumberAnimation {
                duration: Theme.duration.medium1
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        visible: levelFill.visible && root.boundedLevel > 0 && root.boundedLevel < 1
        x: 2
        y: levelFill.y
        width: parent.width - 4
        height: 1
        color: Qt.alpha(ShellPalette.foreground, root.active ? 0.32 : 0.18)

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
        color: primaryArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : root.active && root.level < 0 ? Qt.alpha(ShellPalette.foreground, 0.07) : "transparent"

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
        color: secondaryArea.containsMouse ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : root.secondaryActive ? Qt.alpha(ShellPalette.foreground, 0.07) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.short3
            }
        }
    }

    Rectangle {
        visible: root.split
        width: 1
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
            font.family: "Material Symbols Rounded"
            font.pixelSize: root.split ? 17 : 27
            font.weight: 500
        }
    }

    Text {
        visible: !root.split && root.badgeIcon.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 3
        anchors.rightMargin: 3
        text: root.badgeIcon
        color: root.active ? ShellPalette.foreground : ShellPalette.foregroundMuted
        font.family: "Material Symbols Rounded"
        font.pixelSize: 10
        font.weight: 600
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
            font.family: "Material Symbols Rounded"
            font.pixelSize: 17
            font.weight: 500
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
