import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager's global networking switch and the route this machine reaches the internet by.
// Quickshell's Networking exposes neither, so they come from nmcli and ip.
Scope {
    id: root

    property bool active: false
    // How often the panel re-reads while open, so a cable pulled or a lease renewed shows up.
    readonly property int refreshInterval: 3000
    // Any public address works: `ip route get` only asks which route would carry it.
    readonly property string probeAddress: "1.1.1.1"

    property bool on: true
    property string address: ""
    property string gateway: ""

    function parse(text) {
        const newline = text.indexOf("\n")
        const state = (newline < 0 ? text : text.slice(0, newline)).trim()
        on = state !== "disabled"
        let route = null
        try {
            route = JSON.parse(text.slice(newline + 1))[0] || null
        } catch (error) {
            route = null
        }
        address = route && route.prefsrc ? route.prefsrc : ""
        gateway = route && route.gateway ? route.gateway : ""
    }

    function refresh() {
        if (!reader.running)
            reader.running = true
    }

    function toggle() {
        on = !on
        switcher.command = ["nmcli", "networking", on ? "on" : "off"]
        switcher.running = true
    }

    Process {
        id: reader
        command: ["sh", "-c", "nmcli -t networking; ip -j route get " + root.probeAddress + " 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
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
}
