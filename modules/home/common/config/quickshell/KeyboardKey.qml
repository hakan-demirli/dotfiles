import QtQuick

Rectangle {
    id: root

    property var key

    readonly property int kind: KeyboardLayout.kindOf(root.key)
    readonly property bool dual: root.kind === KeyboardLayout.Kind.Character && KeyboardLayout.isDual(root.key)
    readonly property bool symbol: root.key.icon !== undefined
    readonly property bool locked: root.kind === KeyboardLayout.Kind.Lock ? KeyboardService.lockedCode === root.key.code : root.kind === KeyboardLayout.Kind.Modifier && KeyboardService.latchOf(root.key.code) === KeyboardService.Latch.Locked
    readonly property bool held: root.kind === KeyboardLayout.Kind.Modifier && KeyboardService.latchOf(root.key.code) !== KeyboardService.Latch.Free
    readonly property bool highlighted: root.held || root.locked

    readonly property string caption: {
        if (root.kind !== KeyboardLayout.Kind.Character)
            return root.symbol ? root.key.icon : root.key.label;
        return KeyboardService.upper ? KeyboardLayout.shiftedOf(root.key) : root.key.base;
    }

    implicitHeight: Theme.metrics.keyboardKeyHeight
    radius: Theme.shape.small
    color: root.highlighted ? ShellPalette.indicator : tap.pressed ? Qt.alpha(ShellPalette.foreground, Theme.state.pressedOpacity) : hover.hovered ? Qt.alpha(ShellPalette.foreground, Theme.state.hoverOpacity) : ShellPalette.surface
    border.width: root.locked ? Theme.metrics.focusStroke : Theme.metrics.stroke
    border.color: root.locked ? ShellPalette.foregroundMuted : ShellPalette.indicator

    Text {
        visible: !root.dual
        anchors.centerIn: parent
        text: root.caption
        color: ShellPalette.foreground
        font.family: root.symbol ? Theme.font.symbols : Theme.font.plain
        font.pixelSize: root.symbol ? Theme.icon.small : root.kind === KeyboardLayout.Kind.Character ? Theme.font.bodyLargeSize : Theme.font.labelMediumSize
        font.weight: Theme.font.mediumWeight
    }

    Text {
        visible: root.dual
        anchors.top: parent.top
        anchors.topMargin: Theme.space.extraSmall
        anchors.horizontalCenter: parent.horizontalCenter
        text: KeyboardLayout.shiftedOf(root.key)
        color: KeyboardService.shifted ? ShellPalette.foreground : ShellPalette.foregroundMuted
        font.family: Theme.font.plain
        font.pixelSize: Theme.font.labelSmallSize
        font.weight: Theme.font.mediumWeight
    }

    Text {
        visible: root.dual
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.extraSmall
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.key.base
        color: KeyboardService.shifted ? ShellPalette.foregroundMuted : ShellPalette.foreground
        font.family: Theme.font.plain
        font.pixelSize: Theme.font.bodyMediumSize
        font.weight: Theme.font.mediumWeight
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        gesturePolicy: TapHandler.ReleaseWithinBounds
        onPressedChanged: {
            if (tap.pressed)
                root.begin();
            else
                root.finish();
        }
    }

    function begin() {
        if (root.kind === KeyboardLayout.Kind.Character || root.kind === KeyboardLayout.Kind.Action)
            KeyboardService.press(root.key.code);
    }

    function finish() {
        switch (root.kind) {
        case KeyboardLayout.Kind.Modifier:
            KeyboardService.cycleModifier(root.key.code);
            return;
        case KeyboardLayout.Kind.Lock:
            KeyboardService.toggleLock(root.key.code);
            return;
        default:
            KeyboardService.release(root.key.code);
        }
    }
}
