pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

// The keyboard's backlight, kept the way a MacBook keeps its own. The keys are lit at the user's level
// (`keyboard.brightness`: the slider and the keyboard-brightness keys) while in use, fade out after
// `keyboard.offAfter` seconds without input or when the idle screen turns off, and fade back on any input.
// With `keyboard.adaptive` and a light sensor they also wait for low light: dark in a bright room, lit below
// that, and dimmer the darker it gets, since lit keys need less there. Setting the level in a bright room
// lights them anyway, until the room has been dim once.
// Requires write access to the LED's `brightness` attribute; the NixOS module grants it to `video`.
Singleton {
    id: root

    property string device: ""
    property int maximum: 0
    // What the LED was last told; -1 until one is found.
    property int raw: -1
    readonly property bool available: maximum > 0 && raw >= 0

    // The user's level: how bright the keys are when lit.
    readonly property real level: ClockConfig.keyboardBrightness
    readonly property real stepSize: 0.1

    readonly property bool adaptive: available && ClockConfig.keyboardAdaptive && AmbientLight.available
    // Unused for `keyboard.offAfter`, or the screen has gone off with idle.
    readonly property bool resting: unused.isIdle || screenOff.isIdle
    // The sensor is read only while the keys could be lit.
    readonly property bool following: adaptive && !resting

    // The room in log10(1 + lux): too bright for lit keys to show from about 160 lux, low light again under
    // about 80, so a reading between the two doesn't flick them on and off.
    readonly property real brightAbove: 2.2
    readonly property real dimBelow: 1.9
    property bool bright: false
    // The user asked for light while the room was bright.
    property bool forced: false
    // The share of the level the keys get in low light: half in the dark, all of it at `dimBelow`.
    property real trim: 1
    // Under this change the trim holds still, so a flickering reading doesn't hunt.
    readonly property real deadband: 0.05

    // The LED fraction wanted now; -1 until there's a backlight and a level to go by.
    readonly property real wanted: !available || !ClockConfig.loaded ? -1
        : resting ? 0
        : !adaptive ? level
        : bright ? (forced ? level : 0)
        : level * trim
    // The LED fraction as it is, fading toward `wanted`.
    property real shown: 0

    // The keyboard-brightness keys moved the level.
    signal adjusted()

    function discover() {
        finder.running = true
        AmbientLight.discover()
    }

    // The user's own change lands at once; fades are for the room and for rest.
    function set(fraction) {
        if (!available)
            return
        forced = bright
        ClockConfig.keyboardBrightness = Math.round(Math.max(0, Math.min(1, fraction)) * 100) / 100
        fade.stop()
        if (wanted >= 0)
            shown = wanted
        saveLevel.restart()
    }

    function step(direction) {
        if (!available)
            return
        set(level + direction * stepSize)
        adjusted()
    }

    onFollowingChanged: AmbientLight.watchers += following ? 1 : -1

    onWantedChanged: {
        if (wanted < 0)
            return
        fade.to = wanted
        fade.restart()
    }

    onShownChanged: {
        const next = Math.round(shown * maximum)
        if (!available || next === raw)
            return
        raw = next
        writer.setText(String(next))
    }

    Connections {
        target: AmbientLight
        function onSampled() {
            const room = AmbientLight.level
            if (room >= root.brightAbove)
                root.bright = true
            else if (room <= root.dimBelow)
                root.bright = false
            if (!root.bright)
                root.forced = false
            const next = 0.5 + 0.5 * Math.min(1, room / root.dimBelow)
            if (Math.abs(next - root.trim) >= root.deadband)
                root.trim = next
        }
    }

    // ext-idle-notify through the compositor: any key, pointer or touch input counts as use. Inhibitors don't
    // hold it: a film keeps the screen awake, not the keys lit.
    IdleWatch {
        id: unused
        watching: root.available
        wait: ClockConfig.keyboardOffAfter
        respectInhibitors: false
    }

    // The same wait, inhibitors included, as the listener Idle gives hypridle to turn the screen off: the keys
    // go dark with it, whatever their own timeout.
    IdleWatch {
        id: screenOff
        watching: root.available && Idle.installed
        wait: ClockConfig.screenOffMinutes * 60
        respectInhibitors: true
    }

    NumberAnimation {
        id: fade
        target: root
        property: "shown"
        duration: 500
        easing.type: Easing.InOutQuad
    }

    // The first keyboard LED this user may write, with its range and where it stands, so the first fade starts
    // from there.
    Process {
        id: finder
        command: ["sh", "-c", "for d in /sys/class/leds/*kbd_backlight; do [ -w \"$d/brightness\" ] && echo \"$d $(cat \"$d/max_brightness\") $(cat \"$d/brightness\")\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim().split(" ")
                const most = parseInt(found[1], 10)
                const now = parseInt(found[2], 10)
                if (found.length !== 3 || !(most > 0) || !isFinite(now))
                    return
                root.shown = Math.max(0, Math.min(1, now / most))
                root.device = found[0]
                root.maximum = most
                root.raw = now
            }
        }
    }

    // sysfs attributes can't be replaced by rename, so writes go straight to the file; blocking keeps a fade's
    // steps in order.
    FileView {
        id: writer
        path: root.device ? root.device + "/brightness" : ""
        atomicWrites: false
        blockWrites: true
        preload: false
        onSaveFailed: error => console.log("qs keyboard backlight: write failed", FileViewError.toString(error))
    }

    // The level is saved once the slider or the keys have settled, not on every step.
    Timer {
        id: saveLevel
        interval: 1500
        onTriggered: ClockConfig.save()
    }
}
