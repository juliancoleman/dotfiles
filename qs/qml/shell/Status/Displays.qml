pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The outputs niri drives and the refresh rates each offers at its current size, from `niri msg outputs`.
// A rate picked here is kept per output in the config and put back whenever the shell starts or the screens
// change: niri forgets a mode set over IPC when it restarts, or when that output's block in its own config
// changes.
Singleton {
    id: root

    // [{ name, width, height, current, rates }], rates in mHz, fastest first, one per whole hertz.
    property var outputs: []
    readonly property bool available: outputs.some(output => output.rates.length > 1)
    // A query was asked for while one ran; run again once it ends, since the answer may be stale.
    property bool requeried: false
    // The rate restore() last asked of each output, so a mode niri won't take is asked once, not forever.
    property var tried: ({})
    // Changes asked for while niri was still taking the last ones.
    property var queued: []

    function refresh() {
        if (query.running)
            requeried = true
        else
            query.running = true
    }

    function hertz(rate) {
        return Math.round(rate / 1000)
    }

    // One rate per whole hertz at the current size; of near twins (60 and 59.94 Hz) the exact one, else the
    // faster.
    function ratesOf(output, size) {
        const byHertz = {}
        for (const mode of output.modes || []) {
            if (mode.width !== size.width || mode.height !== size.height)
                continue
            const key = hertz(mode.refresh_rate)
            const held = byHertz[key]
            const exact = rate => rate % 1000 === 0
            if (held === undefined || (!exact(held) && (exact(mode.refresh_rate) || mode.refresh_rate > held)))
                byHertz[key] = mode.refresh_rate
        }
        return Object.keys(byHertz).map(key => byHertz[key]).sort((a, b) => b - a)
    }

    function parse(text) {
        let parsed = {}
        try {
            parsed = JSON.parse(text)
        } catch (error) {
            console.log("qs displays: unreadable niri outputs", error)
            return
        }
        const next = []
        for (const name of Object.keys(parsed).sort()) {
            const output = parsed[name]
            const mode = output.current_mode === null || output.current_mode === undefined
                ? null : output.modes[output.current_mode]
            // Off, or on a custom mode niri doesn't list.
            if (!mode)
                continue
            next.push({
                name: name,
                width: mode.width,
                height: mode.height,
                current: mode.refresh_rate,
                rates: ratesOf(output, mode)
            })
        }
        outputs = next
        restore()
    }

    function modeOf(output, rate) {
        return output.width + "x" + output.height + "@" + (rate / 1000).toFixed(3)
    }

    function setRate(name, rate) {
        const output = outputs.find(entry => entry.name === name)
        if (!output || output.rates.indexOf(rate) < 0)
            return
        const saved = Object.assign({}, ClockConfig.refreshRates)
        saved[name] = rate
        ClockConfig.refreshRates = saved
        ClockConfig.save()
        apply([[output, rate]])
    }

    // Saved rates the outputs aren't running, once both the config and the outputs are known.
    function restore() {
        if (!ClockConfig.loaded)
            return
        const changes = []
        for (const output of outputs) {
            const rate = ClockConfig.refreshRates[output.name]
            if (rate !== undefined && rate !== output.current && output.rates.indexOf(rate) >= 0
                    && tried[output.name] !== rate) {
                tried[output.name] = rate
                changes.push([output, rate])
            }
        }
        apply(changes)
    }

    function apply(changes) {
        if (changes.length === 0)
            return
        if (setter.running) {
            queued = queued.concat(changes)
            return
        }
        const args = []
        for (const change of changes)
            args.push(change[0].name, modeOf(change[0], change[1]))
        setter.command = ["sh", "-c", "while [ $# -gt 1 ]; do niri msg output \"$1\" mode \"$2\" || exit 1; shift 2; done",
                          "sh"].concat(args)
        setter.running = true
    }

    Connections {
        target: ClockConfig
        function onLoadedChanged() {
            root.restore()
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.tried = {}
            root.refresh()
        }
    }

    Process {
        id: query
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: {
            if (root.requeried) {
                root.requeried = false
                running = true
            }
        }
    }

    Process {
        id: setter
        onExited: code => {
            if (code !== 0)
                console.log("qs displays: niri refused a mode, exit", code)
            const next = root.queued
            root.queued = []
            if (next.length > 0)
                root.apply(next)
            else
                root.refresh()
        }
    }
}
