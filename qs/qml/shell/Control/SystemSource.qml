import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool active: false
    property real cpu: 0
    property real memory: 0
    property real disk: 0

    property real _busy: -1
    property real _total: -1

    function parse(text) {
        const lines = text.split("\n")
        let memTotal = 0
        let memAvailable = 0
        for (let i = 0; i < lines.length; ++i) {
            const fields = lines[i].trim().split(/\s+/)
            if (fields[0] === "cpu") {
                const values = fields.slice(1).map(Number)
                const total = values.reduce((sum, v) => sum + v, 0)
                const busy = total - values[3] - (values[4] || 0)
                if (_total >= 0 && total > _total)
                    cpu = Math.max(0, Math.min(1, (busy - _busy) / (total - _total)))
                _busy = busy
                _total = total
            } else if (fields[0] === "MemTotal:") {
                memTotal = Number(fields[1])
            } else if (fields[0] === "MemAvailable:") {
                memAvailable = Number(fields[1])
            } else if (fields.length >= 6 && fields[5] === "/") {
                const size = Number(fields[1])
                const used = Number(fields[2])
                if (size > 0)
                    disk = Math.max(0, Math.min(1, used / size))
            }
        }
        if (memTotal > 0)
            memory = Math.max(0, Math.min(1, 1 - memAvailable / memTotal))
    }

    // CPU usage is a delta between samples, so take one at startup to have a baseline on first open.
    Process {
        id: reader
        running: true
        command: ["sh", "-c", "head -n 1 /proc/stat; grep -E '^Mem(Total|Available):' /proc/meminfo; df -Pk / | tail -n 1"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }
}
