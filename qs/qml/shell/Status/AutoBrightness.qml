pragma Singleton

import QtQuick
import Quickshell
import ".."

// The backlight follows the ambient light sensor while ClockConfig.autoBrightness is on. Lux maps onto a log
// curve, since eyes judge light by ratio, plus the user's bias. The sliders only read while it runs; the
// brightness keys still work, and where they land isn't fought but kept as the offset from the curve, so
// "a little brighter than auto" stays that way as the room changes.
Singleton {
    id: root

    readonly property bool available: AmbientLight.available && Brightness.available
    readonly property bool active: available && ClockConfig.autoBrightness

    // The backlight fraction being ramped toward, -1 for none yet.
    property real target: -1

    // Under this change in target the backlight holds still, so a flickering reading doesn't hunt.
    readonly property real deadband: 0.03
    // Per ramp tick (40 ms): about a fifth of the range a second.
    readonly property real rampStep: 0.008

    function discover() {
        AmbientLight.discover()
    }

    // The backlight fraction for a smoothed log10(1 + lux).
    function curve(logLux) {
        return 0.06 + 0.22 * logLux
    }

    function clamp(value, low, high) {
        return Math.max(low, Math.min(high, value))
    }

    function aim() {
        if (!active || AmbientLight.level < 0)
            return
        const next = clamp(curve(AmbientLight.level) + ClockConfig.brightnessBias, 0, 1)
        if (target >= 0 && Math.abs(next - target) < deadband)
            return
        target = next
        ramp.start()
    }

    onActiveChanged: {
        AmbientLight.watchers += active ? 1 : -1
        target = -1
        ramp.stop()
    }

    Connections {
        target: AmbientLight
        function onSampled() {
            root.aim()
        }
    }

    Connections {
        target: Brightness
        // The brightness keys: keep where they landed, as the curve's new offset.
        function onChosen() {
            if (!root.active || AmbientLight.level < 0)
                return
            ramp.stop()
            root.target = Brightness.level
            ClockConfig.brightnessBias = Math.round(root.clamp(Brightness.level - root.curve(AmbientLight.level), -1, 1) * 100) / 100
            saveBias.restart()
        }
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
