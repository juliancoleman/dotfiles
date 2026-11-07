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

    // Open panels showing the slider; the live value is polled only while any exist.
    property int watchers: 0

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

    // Key presses waiting on a fresh read, summed, and when the shell last wrote the value itself.
    property int pendingSteps: 0
    property double lastWrite: 0

    function step(direction) {
        if (!available)
            return
        // Unpolled while no slider shows it, so a step waits for the live value rather than the last one seen,
        // unless this shell just wrote it (held keys): a re-read could land before that write and undo it.
        if (watchers === 0 && Date.now() - lastWrite > 1000) {
            const waiting = pendingSteps !== 0
            pendingSteps += direction
            if (!waiting)
                current.reload()
            return
        }
        move(direction)
    }

    function move(steps) {
        const next = Math.max(floor, Math.min(maximum, raw + steps * stepSize))
        if (next === raw) {
            adjusted()
            return
        }
        lastWrite = Date.now()
        writer.setText(String(next))
        take(String(next))
    }

    function set(fraction) {
        if (!available)
            return
        const next = Math.max(floor, Math.min(maximum, Math.round(fraction * maximum)))
        if (next === raw)
            return
        lastWrite = Date.now()
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
        onLoaded: {
            root.take(text())
            if (root.pendingSteps !== 0) {
                const steps = root.pendingSteps
                root.pendingSteps = 0
                root.move(steps)
            }
        }
    }

    // sysfs attributes can't be replaced by rename, so writes go straight to the file.
    FileView {
        id: writer
        path: root.device ? root.device + "/brightness" : ""
        atomicWrites: false
        preload: false
        onSaveFailed: error => console.log("qs brightness: write failed", FileViewError.toString(error))
    }

    // sysfs attributes never raise inotify events, so the slider polls the live value while it's on screen to
    // follow external writes. Nothing else needs them: the brightness keys come through step(), which updates
    // `raw` and announces the change itself.
    Timer {
        interval: 200
        repeat: true
        triggeredOnStart: true
        running: root.device !== "" && root.watchers > 0
        onTriggered: current.reload()
    }
}
