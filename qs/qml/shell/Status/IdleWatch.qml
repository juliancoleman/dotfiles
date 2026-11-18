import QtQuick
import Quickshell.Wayland

// An IdleMonitor whose wait can change while it runs. IdleMonitor asks the compositor for its timeout when
// it is enabled and keeps that one (Quickshell 0.3.2): a timeout changed afterwards is never taken up. So
// `watching` and `wait` stand in for `enabled` and `timeout`, and the monitor is taken down and set up again
// around every change. A new wait counts from then.
IdleMonitor {
    id: monitor

    property bool watching: false
    // Seconds without input; 0 never goes idle.
    property real wait: 0

    enabled: false

    function arm() {
        enabled = false
        timeout = wait
        enabled = watching && wait > 0
    }

    onWatchingChanged: arm()
    onWaitChanged: arm()
    Component.onCompleted: arm()
}
