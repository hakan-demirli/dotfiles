pragma Singleton

import QtQuick

QtObject {
    readonly property color background: Theme.palette.m3surfaceContainerLow
    readonly property color surface: Theme.palette.m3surfaceContainer
    readonly property color indicator: Theme.palette.m3outlineVariant
    readonly property color foreground: Theme.palette.m3onSurface
    readonly property color foregroundMuted: Qt.alpha(foreground, Theme.opacity.muted)
}
