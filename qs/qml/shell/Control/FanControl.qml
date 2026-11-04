pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Client for qs-fan-helper. Holding the socket open is the lease: if the shell
// exits or stops renewing, the helper returns every fan to firmware control.
// A single lease serves every screen's panel; each open panel counts as a watcher.
Singleton {
    id: root

    property int watchers: 0
    readonly property bool active: watchers > 0
    property string path: "/run/qs-fan-helper.sock"

    readonly property bool connected: socket.connected
    property bool available: false
    property bool holding: false
    property bool busy: false
    property string reason: ""
    property string error: ""
    property var fans: []
    property int renewalMs: 2000

    readonly property bool ready: connected && available && fans.length > 0
    readonly property bool wanted: active || holding
    readonly property int manualCount: {
        let count = 0
        for (let i = 0; i < fans.length; ++i)
            if (fans[i].mode === "manual")
                ++count
        return count
    }
    readonly property int fastest: {
        let best = 0
        for (let i = 0; i < fans.length; ++i)
            best = Math.max(best, fans[i].rpm || 0)
        return best
    }

    property var pending: ({})

    function send(request) {
        if (!socket.connected)
            return
        socket.write(JSON.stringify(request) + "\n")
        socket.flush()
    }

    function setPercent(id, percent) {
        const next = Object.assign({}, pending)
        next[id] = Math.round(Math.max(0, Math.min(100, percent)))
        pending = next
        if (!coalesce.running)
            coalesce.start()
    }

    function setAuto(id) {
        const next = Object.assign({}, pending)
        delete next[id]
        pending = next
        send({ op: "auto", fan: id })
    }

    function apply(line) {
        let reply
        try {
            reply = JSON.parse(line)
        } catch (e) {
            return
        }
        available = reply.available === true
        holding = reply.holding === true
        busy = reply.busy === true
        reason = reply.reason || ""
        error = reply.ok ? "" : (reply.error || "")
        renewalMs = Math.max(500, (reply.renewalSeconds || 2) * 1000)
        fans = reply.fans || []
    }

    function reset() {
        available = false
        holding = false
        busy = false
        fans = []
        pending = {}
    }

    onWantedChanged: {
        if (wanted && !socket.connected)
            socket.connected = true
        else if (!wanted && socket.connected)
            socket.connected = false
    }

    Socket {
        id: socket
        path: root.path
        parser: SplitParser {
            onRead: line => root.apply(line)
        }
        onConnectionStateChanged: {
            if (connected)
                root.send({ op: "status" })
            else
                root.reset()
        }
    }

    // A missing socket (no helper on this host) just fails quietly; retry slowly while wanted.
    Timer {
        interval: 3000
        repeat: true
        running: root.wanted && !socket.connected
        onTriggered: socket.connected = true
    }

    Timer {
        interval: root.renewalMs
        repeat: true
        running: socket.connected
        onTriggered: root.send({ op: "status" })
    }

    Timer {
        id: coalesce
        interval: 120
        onTriggered: {
            const queued = root.pending
            root.pending = {}
            for (const id in queued)
                root.send({ op: "set", fan: id, percent: queued[id] })
        }
    }
}
