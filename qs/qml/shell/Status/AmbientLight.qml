pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The ambient light sensor, shared by what follows the room: AutoBrightness for the screen, KeyboardBacklight
// for the keys. Reads the IIO attribute directly, so iio-sensor-proxy is optional.
Singleton {
    id: root

    // The sensor's `in_illuminance_input`, or "" when there's none.
    property string sensor: ""
    readonly property bool available: sensor !== ""
    // Followers of the room right now; the sensor is read only while any exist.
    property int watchers: 0
    // log10(1 + lux), smoothed, since eyes judge light by ratio. -1 until the first reading after reads begin.
    property real level: -1

    // A reading arrived, whether or not it moved `level`.
    signal sampled()

    function discover() {
        finder.running = true
    }

    function sample(text) {
        const reading = parseFloat(text)
        if (!isFinite(reading) || reading < 0)
            return
        const next = Math.log10(1 + reading)
        level = level < 0 ? next : level + 0.35 * (next - level)
        sampled()
    }

    // The next follower starts from the room as it is then, not as it was when the last one left.
    onWatchersChanged: {
        if (watchers === 0)
            level = -1
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
        path: root.watchers > 0 ? root.sensor : ""
        printErrors: false
        onLoaded: root.sample(text())
    }

    // sysfs attributes raise no inotify events, so the sensor is read once a second while anything follows it.
    Timer {
        interval: 1000
        repeat: true
        running: root.watchers > 0 && root.available
        onTriggered: reading.reload()
    }
}
