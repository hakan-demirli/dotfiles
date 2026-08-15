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

        // Arm thickness shared by the vertical and horizontal sections.
        property int thickness: 47
        // Four complete cells per arm is just under one sixth of this screen.
        property int armLength: thickness * 4

        screen: Quickshell.screens[0]
        visible: shell.barVisible

        anchors.bottom: true
        anchors.right: true

        implicitWidth: armLength
        implicitHeight: armLength

        color: "transparent"

        // Float over everything without reserving space, so no window is
        // pushed aside.
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Only the two arms accept input; the empty quadrant passes clicks
        // through to the windows beneath.
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
}
