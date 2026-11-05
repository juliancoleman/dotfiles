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
        // The desktop shows behind, as it does behind the bar, so the surface reads as it will.
        color: "transparent"

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
