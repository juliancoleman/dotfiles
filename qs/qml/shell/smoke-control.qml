import QtQuick
import Quickshell
import Quickshell.Wayland
import "Control"

ShellRoot {
    PanelWindow {
        id: win
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-smoke"
        anchors.top: true
        anchors.right: true
        margins.top: 120
        margins.right: 120
        implicitWidth: 360
        implicitHeight: 460
        color: "#20000000"

        ControlCenter {
            id: cc
            x: win.width - width - 10
            y: 10
            edge: "right"
            motion: "easeOut"
            Component.onCompleted: { cc.page = "ethernet"; cc.open() }
        }
    }
}
