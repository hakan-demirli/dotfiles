pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    signal requestClose

    property real fieldWidth: 0
    property real fieldHeight: 0

    readonly property real gap: Theme.metrics.keyboardGap
    readonly property real padding: Theme.space.small
    readonly property real rowWidth: root.width - root.padding * 2
    readonly property real maximumX: Math.max(0, root.fieldWidth - root.width)
    readonly property real maximumY: Math.max(0, root.fieldHeight - root.height)
    readonly property real restX: root.maximumX / 2
    readonly property real restY: root.maximumY - root.padding

    implicitWidth: Theme.metrics.keyboardMaximumWidth
    implicitHeight: content.implicitHeight + root.padding * 2

    radius: Theme.shape.extraLarge
    color: ShellPalette.background
    border.width: Theme.metrics.stroke
    border.color: ShellPalette.indicator

    onMaximumXChanged: KeyboardService.place(root.clampedX(KeyboardService.positionX), KeyboardService.positionY)
    onMaximumYChanged: KeyboardService.place(KeyboardService.positionX, root.clampedY(KeyboardService.positionY))

    function clampedX(x) {
        return Math.max(0, Math.min(root.maximumX, x));
    }

    function clampedY(y) {
        return Math.max(0, Math.min(root.maximumY, y));
    }

    Connections {
        target: KeyboardService

        function onDockedChanged() {
            if (!KeyboardService.docked)
                KeyboardService.place(root.restX, root.restY);
        }
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: root.padding
        spacing: root.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: root.gap

            ChoiceButton {
                implicitWidth: Theme.metrics.menuWidth / Theme.metrics.menuColumns
                implicitHeight: Theme.metrics.compactButtonHeight
                text: KeyboardService.docked ? "Docked" : "Floating"
                checked: KeyboardService.docked
                onActivated: KeyboardService.docked = !KeyboardService.docked
            }

            Item {
                id: grip

                Layout.fillWidth: true
                Layout.fillHeight: true

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.metrics.touchTarget
                    height: Theme.metrics.focusStroke
                    radius: Theme.shape.full
                    color: dragArea.active || dragHover.hovered ? ShellPalette.foreground : ShellPalette.foregroundMuted

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.duration.short3
                        }
                    }
                }

                HoverHandler {
                    id: dragHover

                    cursorShape: Qt.SizeAllCursor
                }

                DragHandler {
                    id: dragArea

                    property real originX: 0
                    property real originY: 0

                    target: null
                    onActiveChanged: {
                        if (!dragArea.active)
                            return;
                        KeyboardService.docked = false;
                        dragArea.originX = KeyboardService.positionX;
                        dragArea.originY = KeyboardService.positionY;
                    }
                    onActiveTranslationChanged: {
                        if (dragArea.active)
                            KeyboardService.place(root.clampedX(dragArea.originX + dragArea.activeTranslation.x), root.clampedY(dragArea.originY + dragArea.activeTranslation.y));
                    }
                }
            }

            MenuIconButton {
                icon: "\ue31a"
                onActivated: root.requestClose()
            }
        }

        Repeater {
            model: KeyboardLayout.rows

            delegate: Row {
                id: keyRow

                required property var modelData

                readonly property real unit: (root.rowWidth - (keyRow.modelData.length - 1) * root.gap) / KeyboardLayout.units

                Layout.fillWidth: true
                spacing: root.gap

                Repeater {
                    model: keyRow.modelData

                    delegate: KeyboardKey {
                        required property var modelData

                        key: modelData
                        width: keyRow.unit * KeyboardLayout.widthOf(modelData)
                    }
                }
            }
        }
    }
}
