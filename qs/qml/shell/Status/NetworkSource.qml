import QtQuick
import Quickshell
import Quickshell.Networking

Scope {
    id: root

    function connectedOf(list, type) {
        for (let i = 0; i < list.length; ++i) {
            const item = list[i]
            if (item && item.connected && (type === undefined || item.type === type))
                return item
        }
        return null
    }

    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property var wired: connectedOf(devices, DeviceType.Wired)
    readonly property var wifi: connectedOf(devices, DeviceType.Wifi)
    readonly property var wifiNetwork: wifi && wifi.networks ? connectedOf(wifi.networks.values) : null
    readonly property real signalStrength: wifiNetwork ? Math.max(0, Math.min(1, wifiNetwork.signalStrength)) : 0
    readonly property string icon: wired ? "ethernet" : wifi ? "wifi" : "ethernet-off"

    // 0..3 lit wifi arcs, with hysteresis so a signal hovering on a threshold doesn't flicker.
    property int bars: 0
    readonly property var thresholds: [0.25, 0.5, 0.75]
    readonly property real hysteresis: 0.04

    onSignalStrengthChanged: rebar(false)
    onWifiNetworkChanged: rebar(true)
    Component.onCompleted: rebar(true)

    function rebar(reset) {
        if (!wifiNetwork) {
            bars = 0
            return
        }
        const s = signalStrength
        if (reset) {
            bars = s < thresholds[0] ? 0 : s < thresholds[1] ? 1 : s < thresholds[2] ? 2 : 3
            return
        }
        let next = bars
        while (next < 3 && s >= thresholds[next] + hysteresis)
            ++next
        while (next > 0 && s < thresholds[next - 1] - hysteresis)
            --next
        bars = next
    }
}
