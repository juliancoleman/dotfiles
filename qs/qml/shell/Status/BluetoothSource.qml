import QtQuick
import Quickshell
import Quickshell.Bluetooth

Scope {
    id: root

    readonly property int connectedCount: {
        const list = Bluetooth.devices ? Bluetooth.devices.values : []
        let count = 0
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].connected)
                ++count
        }
        return count
    }

    signal deviceConnected()

    property int _last: 0
    property bool _settled: false

    onConnectedCountChanged: {
        if (_settled && connectedCount > _last)
            deviceConnected()
        _last = connectedCount
    }

    // BlueZ reports already-connected devices as they enumerate at startup; don't announce those.
    Timer {
        running: true
        interval: 3000
        onTriggered: {
            root._last = root.connectedCount
            root._settled = true
        }
    }
}
