pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Live signal on the default output and input, as the mixer meter beside a fader: what's actually
// flowing, as opposed to the volume that was set. Each side is `pw-record | qs-meter` streaming
// peak/RMS lines, run only while something on screen is showing a meter.
Singleton {
    id: root

    property int watchers: 0
    readonly property bool active: watchers > 0

    // Last window's peak on a 60 dB scale, 0..1: a meter reads in decibels, not linear amplitude.
    readonly property real output: outputTap.level
    readonly property real input: inputTap.level
    // Capture streams: programs (and PipeWire's own filter chains) reading from a source.
    readonly property var captureStreams: {
        const list = Pipewire.nodes ? Pipewire.nodes.values : []
        return list.filter(node => node && node.isStream && node.audio && !node.isSink)
    }
    // Some program other than this meter is pulling from the microphone, so its ring means "you're heard".
    // Filter-chain halves (a DSP'd microphone) carry `node.link-group`; they aren't listeners.
    readonly property bool inputInUse: captureStreams.some(node => node.name !== tapName
        && node.ready && !node.properties["node.link-group"])
    readonly property string tapName: "qs-meter"
    readonly property real range: 60

    PwObjectTracker {
        objects: root.captureStreams
    }

    Tap {
        id: outputTap
        sink: true
        target: Pipewire.defaultAudioSink
    }

    Tap {
        id: inputTap
        sink: false
        target: Pipewire.defaultAudioSource
    }

    component Tap: Item {
        id: tap

        property bool sink: false
        property var target: null
        property real level: 0

        readonly property bool wanted: root.active && !!target
        onWantedChanged: if (!wanted) level = 0
        onTargetChanged: if (reader.running) { reader.running = false; restart.start() }

        Timer {
            id: restart
            interval: 50
            onTriggered: if (tap.wanted) reader.running = true
        }

        Process {
            id: reader
            running: tap.wanted
            // pw-record's stdout is a fully buffered stdio pipe (8 KiB ≈ half a second at this rate), so
            // it runs unbuffered; windows then arrive as fast as qs-meter cuts them.
            command: ["sh", "-c",
                "exec stdbuf -o0 pw-record --raw --format s16 --rate 8000 --channels 1 --latency 30ms"
                + " -P '{ node.name = " + root.tapName + (tap.sink ? ", stream.capture.sink = true" : "") + " }'"
                + " - | exec qs-meter --rate 8000 --fps 30"]
            stdout: SplitParser {
                onRead: line => {
                    const peak = parseFloat(line)
                    if (!isFinite(peak))
                        return
                    tap.level = peak <= 0 ? 0 : Math.max(0, Math.min(1, 1 + 20 * Math.log10(peak) / root.range))
                }
            }
        }
    }
}
