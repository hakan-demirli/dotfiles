import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: shell

    property string activeMenu: ""
    property bool barVisible: true

    function toggleMenu(menu) {
        activeMenu = activeMenu === menu ? "" : menu;
    }

    PanelWindow {
        id: panel

        property int thickness: Theme.metrics.barThickness

        property int armLength: thickness * 4

        screen: Quickshell.screens[0]
        visible: shell.barVisible

        anchors.bottom: true
        anchors.right: true

        implicitWidth: armLength
        implicitHeight: armLength

        color: "transparent"

        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            Region {
                x: panel.armLength - panel.thickness
                y: 0
                width: panel.thickness
                height: panel.armLength
            }

            Region {
                x: 0
                y: panel.armLength - panel.thickness
                width: panel.armLength
                height: panel.thickness
            }
        }

        CornerBar {
            anchors.fill: parent
            thickness: panel.thickness
            armLength: panel.armLength
            onMenuRequested: menu => shell.toggleMenu(menu)
        }
    }

    PanelWindow {
        id: menuWindow

        screen: panel.screen
        visible: shell.activeMenu.length > 0
        anchors.bottom: true
        anchors.right: true
        margins.bottom: panel.thickness + Theme.space.small
        margins.right: panel.thickness + Theme.space.small
        implicitWidth: menuSurface.implicitWidth
        implicitHeight: menuSurface.implicitHeight
        color: "transparent"

        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-menu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (!visible)
                shell.activeMenu = "";
        }

        onBackingWindowVisibleChanged: {
            if (!backingWindowVisible)
                SystemActions.runQueuedRecording();
        }

        MenuSurface {
            id: menuSurface

            anchors.fill: parent
            menu: shell.activeMenu
            onRequestClose: shell.activeMenu = ""
            onRequestMenu: menu => shell.activeMenu = menu
        }
    }

    PanelWindow {
        id: keyboardWindow

        readonly property bool floating: !KeyboardService.docked

        screen: panel.screen
        visible: KeyboardService.active

        anchors.top: keyboardWindow.floating
        anchors.bottom: true
        anchors.left: keyboardWindow.floating
        anchors.right: keyboardWindow.floating
        margins.bottom: keyboardWindow.floating ? 0 : Theme.space.small

        implicitWidth: keyboardPanel.width
        implicitHeight: keyboardPanel.height

        color: "transparent"

        aboveWindows: true
        exclusionMode: keyboardWindow.floating ? ExclusionMode.Ignore : ExclusionMode.Normal
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-keyboard"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {
            item: keyboardPanel
        }

        KeyboardPanel {
            id: keyboardPanel

            fieldWidth: keyboardWindow.screen.width
            fieldHeight: keyboardWindow.screen.height
            width: Math.min(keyboardWindow.screen.width - Theme.space.small * 2, keyboardPanel.implicitWidth)
            height: keyboardPanel.implicitHeight
            x: keyboardWindow.floating ? KeyboardService.positionX : 0
            y: keyboardWindow.floating ? KeyboardService.positionY : 0
            onRequestClose: KeyboardService.close()
        }
    }

    PanelWindow {
        id: toastWindow

        screen: panel.screen
        visible: NotificationService.popups.length > 0

        anchors.top: true
        anchors.right: true
        margins.top: Theme.space.small
        margins.right: Theme.space.small

        implicitWidth: toasts.implicitWidth
        implicitHeight: toasts.implicitHeight

        color: "transparent"

        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        NotificationToasts {
            id: toasts

            anchors.fill: parent
        }
    }

    IpcHandler {
        target: "shell"

        function menu(name: string): void {
            shell.toggleMenu(name);
        }

        function close(): void {
            shell.activeMenu = "";
        }

        function toggleBarVisibility(): void {
            shell.barVisible = !shell.barVisible;
            if (!shell.barVisible)
                shell.activeMenu = "";
        }
    }

    IpcHandler {
        target: "osk"

        function toggle(): void {
            KeyboardService.toggle();
        }

        function open(): void {
            KeyboardService.open();
        }

        function close(): void {
            KeyboardService.close();
        }
    }

    IpcHandler {
        target: "notifications"

        function toggle(): void {
            shell.toggleMenu("notifications");
        }

        function clear(): void {
            NotificationService.clear();
        }

        function toggleDoNotDisturb(): void {
            NotificationService.toggleDoNotDisturb();
        }

        function count(): int {
            return NotificationService.count;
        }

        function doNotDisturb(): bool {
            return NotificationService.doNotDisturb;
        }
    }
}
