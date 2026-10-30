pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Requires write access to the backlight's `brightness` attribute; the NixOS module grants it to `video`.
Singleton {
    id: root

    property string device: ""
    property int raw: -1
    property int maximum: 0
    readonly property bool available: maximum > 0 && raw >= 0
    readonly property real level: available ? Math.max(0, Math.min(1, raw / maximum)) : 0
    readonly property int stepSize: Math.max(1, Math.round(maximum * 0.05))
    readonly property int floor: Math.max(1, Math.round(maximum * 0.01))

    signal adjusted()

    function take(text) {
        const next = parseInt(text, 10)
        if (!isFinite(next))
            return
        const previous = raw
        raw = next
        if (previous >= 0 && next !== previous)
            adjusted()
    }

    function step(direction) {
        if (!available)
            return
        const next = Math.max(floor, Math.min(maximum, raw + direction * stepSize))
        if (next === raw) {
            adjusted()
            return
        }
        writer.setText(String(next))
        take(String(next))
    }

    function set(fraction) {
        if (!available)
            return
        const next = Math.max(floor, Math.min(maximum, Math.round(fraction * maximum)))
        if (next === raw)
            return
        writer.setText(String(next))
        take(String(next))
    }

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/backlight/*; do [ -r \"$d/brightness\" ] && echo \"$d\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    FileView {
        path: root.device ? root.device + "/max_brightness" : ""
        printErrors: false
        onLoaded: {
            const next = parseInt(text(), 10)
            root.maximum = isFinite(next) ? next : 0
        }
    }

    FileView {
        id: current
        path: root.device ? root.device + "/brightness" : ""
        printErrors: false
        onLoaded: root.take(text())
    }

    // sysfs attributes can't be replaced by rename, so writes go straight to the file.
    FileView {
        id: writer
        path: root.device ? root.device + "/brightness" : ""
        atomicWrites: false
        preload: false
        onSaveFailed: error => console.log("qs brightness: write failed", FileViewError.toString(error))
    }

    // sysfs attributes never raise inotify events, so poll the live value.
    Timer {
        interval: 200
        repeat: true
        running: root.device !== ""
        onTriggered: current.reload()
    }
}
