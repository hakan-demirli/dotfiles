import QtQuick

Rectangle {
    id: root

    property string menu: ""

    signal requestClose
    signal requestMenu(string menu)

    implicitWidth: content.item ? content.item.implicitWidth : 380
    implicitHeight: content.item ? content.item.implicitHeight : 240

    radius: Theme.shape.extraLarge
    color: ShellPalette.background
    border.width: 1
    border.color: ShellPalette.indicator
    clip: true

    Loader {
        id: content

        anchors.fill: parent
        sourceComponent: {
            switch (root.menu) {
            case "control": return controlComponent;
            case "wifi": return wifiComponent;
            case "bluetooth": return bluetoothComponent;
            case "audio": return audioComponent;
            case "microphone": return microphoneComponent;
            case "brightness": return brightnessComponent;
            case "battery": return batteryComponent;
            case "clock": return clockComponent;
            case "recording": return recordingComponent;
            case "tablet": return tabletComponent;
            case "power": return powerComponent;
            default: return null;
            }
        }
    }

    Component {
        id: controlComponent

        ControlPanel {
            onRequestClose: root.requestClose()
            onRequestMenu: menu => root.requestMenu(menu)
        }
    }

    Component {
        id: wifiComponent

        NetworkPanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: bluetoothComponent

        BluetoothPanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: audioComponent

        AudioPanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: brightnessComponent

        BrightnessPanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: microphoneComponent

        MicrophonePanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: batteryComponent

        BatteryPanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: clockComponent

        ClockPanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: recordingComponent

        ScreenRecordPanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: tabletComponent

        TabletPanel {
            onRequestClose: root.requestClose()
        }
    }

    Component {
        id: powerComponent

        PowerPanel {
            onRequestClose: root.requestClose()
        }
    }
}
