pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The backlight follows the ambient light sensor while ClockConfig.autoBrightness is on. Lux maps onto a log
// curve, since eyes judge light by ratio, plus the user's bias. The sliders only read while it runs; the
// brightness keys still work, and where they land isn't fought but kept as the offset from the curve, so
// "a little brighter than auto" stays that way as the room changes. Reads the IIO attribute directly, so
// iio-sensor-proxy is optional.
Singleton {
    id: root

    // The sensor's `in_illuminance_input`, or "" when there's none.
    property string sensor: ""
    readonly property bool available: sensor !== "" && Brightness.available
    readonly property bool active: available && ClockConfig.autoBrightness

    // log10(1 + lux), smoothed; the curve's input. -1 until the first reading after switching on.
    property real level: -1
    // The backlight fraction being ramped toward, -1 for none yet.
    property real target: -1

    // Under this change in target the backlight holds still, so a flickering reading doesn't hunt.
    readonly property real deadband: 0.03
    // Per ramp tick (40 ms): about a fifth of the range a second.
    readonly property real rampStep: 0.008

    function discover() {
        finder.running = true
    }

    function curve(logLux) {
        return 0.06 + 0.22 * logLux
    }

    function clamp(value, low, high) {
        return Math.max(low, Math.min(high, value))
    }

    function sample(text) {
        const reading = parseFloat(text)
        if (!isFinite(reading) || reading < 0)
            return
        const next = Math.log10(1 + reading)
        level = level < 0 ? next : level + 0.35 * (next - level)
        aim()
    }

    function aim() {
        if (!active || level < 0)
            return
        const next = clamp(curve(level) + ClockConfig.brightnessBias, 0, 1)
        if (target >= 0 && Math.abs(next - target) < deadband)
            return
        target = next
        ramp.start()
    }

    onActiveChanged: {
        level = -1
        target = -1
        ramp.stop()
    }

    Connections {
        target: Brightness
        // The brightness keys: keep where they landed, as the curve's new offset.
        function onChosen() {
            if (!root.active || root.level < 0)
                return
            ramp.stop()
            root.target = Brightness.level
            ClockConfig.brightnessBias = Math.round(root.clamp(Brightness.level - root.curve(root.level), -1, 1) * 100) / 100
            saveBias.restart()
        }
    }

    Process {
        id: finder
        command: ["sh", "-c", "for f in /sys/bus/iio/devices/*/in_illuminance_input; do [ -r \"$f\" ] && echo \"$f\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: root.sensor = text.trim()
        }
    }

    FileView {
        id: reading
        path: root.active ? root.sensor : ""
        printErrors: false
        onLoaded: root.sample(text())
    }

    // sysfs attributes raise no inotify events, so the sensor is read once a second while following it.
    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: reading.reload()
    }

    Timer {
        id: ramp
        interval: 40
        repeat: true
        onTriggered: {
            const gap = root.target - Brightness.level
            if (root.target < 0 || Math.abs(gap) * Brightness.maximum < 1) {
                stop()
                return
            }
            const step = Math.max(root.rampStep, 1 / Brightness.maximum)
            Brightness.follow(Brightness.level + Math.sign(gap) * Math.min(Math.abs(gap), step))
            // Rounding to the backlight's steps can leave the level where it was; finish there.
            if (Math.abs(root.target - Brightness.level) >= Math.abs(gap))
                stop()
        }
    }

    // The bias is saved once the keys have settled, not on every step.
    Timer {
        id: saveBias
        interval: 1500
        onTriggered: ClockConfig.save()
    }
}
