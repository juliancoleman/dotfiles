pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import ".."

// DualSense lightbars: the RGB indicator hid-playstation registers for a DualSense or DualSense Edge
// (`/sys/class/leds/inputN:rgb:indicator`), matched to its Bluetooth address through the input device's
// `uniq`. Each controller saved in `ClockConfig.dualsense` is painted here, effects included, by writing the
// LED's `multi_intensity`; the NixOS module grants that attribute to `users`.
Singleton {
    id: root

    // The kernel's own boot color: hid-playstation lights the bar blue at half strength.
    readonly property var defaults: ({ on: true, mode: "solid", color: "#0000ff", brightness: 0.5, speed: "medium" })
    // Swatches offered for a solid or breathing light, and the colors a fade walks through.
    readonly property var palette: ["#ffffff", "#ff0000", "#ff6000", "#ffd000", "#00ff40", "#00e0ff", "#0000ff",
        "#8000ff", "#ff00a0"]

    // Lowercase address → { directory, model } for every DualSense lightbar present now.
    property var found: ({})
    readonly property int frameMs: 40
    // A change of setting eases from what the bar shows to the new light over this long.
    readonly property int fadeMs: 400

    function key(address) {
        return String(address || "").toLowerCase()
    }

    function available(address) {
        return found[key(address)] !== undefined
    }

    // "DualSense" or "DualSense Edge", from the controller's product id.
    function model(address) {
        const entry = found[key(address)]
        return entry ? entry.model : "DualSense"
    }

    function settings(address) {
        return Object.assign({}, defaults, ClockConfig.dualsense[key(address)] || {})
    }

    function update(address, change) {
        const next = Object.assign({}, ClockConfig.dualsense)
        next[key(address)] = Object.assign(settings(address), change)
        ClockConfig.dualsense = next
        saver.restart()
    }

    function period(mode, speed) {
        const step = speed === "slow" ? 2 : speed === "fast" ? 0.5 : 1
        switch (mode) {
        case "breathe":
            return 3600 * step
        case "fade":
            return 2400 * step
        case "rainbow":
            return 7000 * step
        }
        return 0
    }

    function channels(color) {
        const c = Qt.color(color)
        return [c.r, c.g, c.b]
    }

    function mix(a, b, f) {
        return [a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f]
    }

    function ease(f) {
        return f * f * (3 - 2 * f)
    }

    // The light for one setting at `now`, before the change fade; 0–1 per channel.
    function light(s, now) {
        if (!s.on)
            return [0, 0, 0]
        const span = period(s.mode, s.speed)
        let rgb
        switch (s.mode) {
        case "breathe": {
            const swell = 0.5 - 0.5 * Math.cos(2 * Math.PI * (now % span) / span)
            rgb = channels(s.color).map(v => v * (0.12 + 0.88 * swell))
            break
        }
        case "fade": {
            const at = now / span
            const index = Math.floor(at) % palette.length
            // Hold each color for the first part of its turn, then ease into the next.
            const turn = at - Math.floor(at)
            const blend = turn < 0.4 ? 0 : ease((turn - 0.4) / 0.6)
            rgb = mix(channels(palette[index]), channels(palette[(index + 1) % palette.length]), blend)
            break
        }
        case "rainbow": {
            const c = Qt.hsva((now % span) / span, 1, 1, 1)
            rgb = [c.r, c.g, c.b]
            break
        }
        default:
            rgb = channels(s.color)
        }
        return rgb.map(v => v * s.brightness)
    }

    // Gamepads only: nothing else connecting can bring a lightbar.
    readonly property string connectedKey: {
        const list = Bluetooth.devices ? Bluetooth.devices.values : []
        return list.filter(d => d && d.connected && d.icon === "input-gaming").map(d => key(d.address)).sort().join(" ")
    }
    property int attempts: 0

    // A controller's LEDs register a moment after Bluetooth reports it connected, so a change is looked at
    // again for a few seconds until every connected gamepad that has a lightbar shows up. Nothing polls
    // otherwise.
    onConnectedKeyChanged: {
        attempts = 0
        if (scan.running)
            retry.restart()
        else
            scan.running = true
    }

    Process {
        id: scan
        running: true
        command: ["sh", "-c",
            "for l in /sys/class/leds/input*:rgb:indicator; do [ -e \"$l\" ] || continue; "
            + "case $(readlink -f \"$l\") in */*:054C:0CE6.*/*) m=DualSense;; */*:054C:0DF2.*/*) m='DualSense Edge';; "
            + "*) continue;; esac; "
            + "n=${l##*/}; n=${n%%:*}; printf '%s|%s|%s\\n' \"$(cat /sys/class/input/$n/uniq 2>/dev/null)\" \"$m\" \"$l\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {}
                for (const line of text.split("\n")) {
                    const fields = line.split("|")
                    if (fields.length === 3 && fields[0] !== "")
                        next[root.key(fields[0])] = { model: fields[1], directory: fields[2] }
                }
                if (JSON.stringify(next) !== JSON.stringify(root.found))
                    root.found = next
                const wanted = root.connectedKey === "" ? [] : root.connectedKey.split(" ")
                if (wanted.some(address => next[address] === undefined) && root.attempts < 5) {
                    root.attempts += 1
                    retry.restart()
                }
            }
        }
    }

    Timer {
        id: retry
        interval: 1000
        onTriggered: scan.running = true
    }

    Timer {
        id: saver
        interval: 400
        onTriggered: ClockConfig.save()
    }

    Instantiator {
        id: bars
        model: Object.keys(root.found).filter(address => ClockConfig.dualsense[address] !== undefined)

        delegate: QtObject {
            id: bar
            required property string modelData
            readonly property string directory: root.found[modelData] ? root.found[modelData].directory : ""
            readonly property var setting: root.settings(modelData)
            readonly property bool moving: setting.on && setting.mode !== "solid"
            property var shown: null
            property var from: null
            property real since: 0
            property string written: ""

            // Every change eases over from the light on the bar.
            onSettingChanged: {
                from = shown
                since = Date.now()
                ticker.start()
            }
            onDirectoryChanged: {
                written = ""
                ticker.start()
            }
            Component.onCompleted: ticker.start()

            function frame(now) {
                let rgb = root.light(setting, now)
                const elapsed = now - since
                if (from && elapsed < root.fadeMs)
                    rgb = root.mix(from, rgb, root.ease(elapsed / root.fadeMs))
                shown = rgb
                const text = rgb.map(v => Math.round(Math.max(0, Math.min(1, v)) * 255)).join(" ")
                if (text !== written && directory !== "") {
                    written = text
                    writer.setText(text + "\n")
                }
                return moving || (from !== null && elapsed < root.fadeMs)
            }

            // sysfs attributes can't be replaced by rename, so writes go straight to the file.
            readonly property FileView writer: FileView {
                path: bar.directory ? bar.directory + "/multi_intensity" : ""
                atomicWrites: false
                preload: false
                onSaveFailed: error => console.log("qs lights: write failed", bar.directory,
                                                   FileViewError.toString(error))
            }
        }
    }

    Timer {
        id: ticker
        interval: root.frameMs
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now()
            let busy = false
            for (let i = 0; i < bars.count; ++i) {
                const bar = bars.objectAt(i)
                if (bar && bar.frame(now))
                    busy = true
            }
            if (!busy)
                stop()
        }
    }
}
