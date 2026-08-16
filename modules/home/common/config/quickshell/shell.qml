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

        property int thickness: 47

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
        margins.bottom: panel.thickness + 8
        margins.right: panel.thickness + 8
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
        id: toastWindow

        screen: panel.screen
        visible: NotificationService.popups.length > 0

        anchors.top: true
        anchors.right: true
        margins.top: 8
        margins.right: 8

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
