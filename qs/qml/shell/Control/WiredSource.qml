pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager's global networking switch and the route this machine reaches the internet by.
// Quickshell's Networking exposes neither, so they come from nmcli and ip; the interface's link speed,
// hardware address, and byte counters come from sysfs.
Singleton {
    id: root

    property int watchers: 0
    readonly property bool active: watchers > 0
    // Someone is showing throughput, so the counters are sampled every second instead of every refresh.
    property int meterWatchers: 0
    readonly property bool metering: meterWatchers > 0
    // How often the panel re-reads while open, so a cable pulled or a lease renewed shows up.
    readonly property int refreshInterval: 3000
    readonly property int meterInterval: 1000
    // Any public address works: `ip route get` only asks which route would carry it.
    readonly property string probeAddress: "1.1.1.1"

    property bool on: true
    property string address: ""
    property string prefix: ""
    property string gateway: ""
    property string device: ""
    property string connection: ""
    property var dns: []
    // Mbit/s as sysfs reports it; 0 when the link is down or the driver doesn't say.
    property int linkSpeed: 0
    property string hardwareAddress: ""
    // Bytes per second over the last sample interval.
    property real downRate: 0
    property real upRate: 0

    property real _rxBytes: NaN
    property real _txBytes: NaN
    property real _sampledAt: 0

    function parse(text) {
        const lines = text.split("\n")
        on = (lines[0] || "").trim() !== "disabled"
        let route = null
        try {
            route = JSON.parse(lines[1] || "[]")[0] || null
        } catch (error) {
            route = null
        }
        address = route && route.prefsrc ? route.prefsrc : ""
        gateway = route && route.gateway ? route.gateway : ""
        device = route && route.dev ? route.dev : ""
        // The rest only exists when a device carried the route.
        linkSpeed = Math.max(0, parseInt(lines[2], 10) || 0)
        hardwareAddress = (lines[3] || "").trim()
        const servers = []
        let name = ""
        let cidr = ""
        for (let i = 4; i < lines.length; ++i) {
            const line = lines[i]
            const colon = line.indexOf(":")
            if (colon < 0)
                continue
            const key = line.slice(0, colon)
            const value = line.slice(colon + 1).trim()
            if (key.startsWith("IP4.DNS"))
                servers.push(value)
            else if (key === "GENERAL.CONNECTION")
                name = value
            else if (key.startsWith("IP4.ADDRESS") && cidr === "")
                cidr = value
        }
        dns = servers
        connection = name
        const slash = cidr.indexOf("/")
        prefix = slash >= 0 ? cidr.slice(slash) : ""
    }

    function sample(text) {
        const parts = text.trim().split(/\s+/)
        const rx = parseFloat(parts[0])
        const tx = parseFloat(parts[1])
        const now = Date.now()
        if (isFinite(rx) && isFinite(tx) && !isNaN(_rxBytes) && now > _sampledAt) {
            const seconds = (now - _sampledAt) / 1000
            downRate = Math.max(0, (rx - _rxBytes) / seconds)
            upRate = Math.max(0, (tx - _txBytes) / seconds)
        }
        _rxBytes = isFinite(rx) ? rx : NaN
        _txBytes = isFinite(tx) ? tx : NaN
        _sampledAt = now
    }

    function refresh() {
        if (!reader.running)
            reader.running = true
    }

    // Whole numbers in the first unit that keeps them under 1000, so the digits can sit on a ticker.
    function rateParts(bytesPerSecond) {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"]
        let value = bytesPerSecond
        let unit = 0
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000
            ++unit
        }
        return { value: Math.round(value), unit: units[unit] }
    }

    function rateText(bytesPerSecond) {
        const parts = rateParts(bytesPerSecond)
        return parts.value + " " + parts.unit
    }

    function toggle() {
        on = !on
        switcher.command = ["nmcli", "networking", on ? "on" : "off"]
        switcher.running = true
    }

    onDeviceChanged: {
        _rxBytes = NaN
        downRate = 0
        upRate = 0
    }

    Process {
        id: reader
        // Line 1: networking state. Line 2: route JSON. Lines 3-4: link speed and MAC of that route's device.
        // Then nmcli's terse key:value lines for DNS, connection name, and CIDR address.
        command: ["sh", "-c",
            "nmcli -t networking; "
            + "r=$(ip -j route get " + root.probeAddress + " 2>/dev/null); echo \"$r\"; "
            + "d=$(printf '%s' \"$r\" | sed -n 's/.*\"dev\":\"\\([^\"]*\\)\".*/\\1/p'); "
            + "cat /sys/class/net/$d/speed 2>/dev/null || echo 0; "
            + "cat /sys/class/net/$d/address 2>/dev/null || echo; "
            + "[ -n \"$d\" ] && nmcli -t -f IP4.DNS,GENERAL.CONNECTION,IP4.ADDRESS dev show \"$d\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: counters
        command: ["sh", "-c", "cat /sys/class/net/" + root.device + "/statistics/rx_bytes "
            + "/sys/class/net/" + root.device + "/statistics/tx_bytes 2>/dev/null | tr '\\n' ' '"]
        stdout: StdioCollector {
            onStreamFinished: root.sample(text)
        }
    }

    Process {
        id: switcher
        onExited: root.refresh()
    }

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: root.meterInterval
        repeat: true
        running: root.metering && root.device !== ""
        triggeredOnStart: true
        onTriggered: if (!counters.running) counters.running = true
    }
}
