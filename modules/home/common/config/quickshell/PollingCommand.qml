import QtQuick
import Quickshell.Io

Item {
    id: root

    property var command: []
    property int interval: 5000
    property bool active: true
    readonly property bool running: process.running

    signal output(string text)

    function refresh() {
        if (active && !process.running)
            process.running = true;
    }

    width: 0
    height: 0
    visible: false

    Process {
        id: process

        command: root.command
        running: root.active
        stdout: StdioCollector {
            onStreamFinished: root.output(text)
        }
    }

    Timer {
        interval: root.interval
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }
}
