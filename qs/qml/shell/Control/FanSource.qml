import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"

Scope {
    id: root

    // Poll only while something is showing fan speeds; one read at startup gates the tile.
    property bool active: false
    property var fans: []
    readonly property bool available: fans.length > 0
    readonly property int fastest: {
        let best = 0
        for (let i = 0; i < fans.length; ++i)
            best = Math.max(best, fans[i].rpm)
        return best
    }

    function rpmText(rpm) {
        return rpm > 0 ? I18n.tr("%1 rpm").arg(rpm.toLocaleString(Qt.locale(I18n.qtLocale), "f", 0)) : I18n.tr("Idle")
    }

    readonly property string summary: I18n.tr("Auto") + " · " + rpmText(fastest)

    function parse(text) {
        const next = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const parts = lines[i].split("|")
            if (parts.length < 4)
                continue
            const rpm = parseInt(parts[3], 10)
            if (!isFinite(rpm))
                continue
            next.push({
                id: parts[0] + "/" + parts[1],
                label: parts[2] || parts[1],
                rpm: rpm
            })
        }
        fans = next
    }

    Process {
        id: reader
        running: true
        command: ["sh", "-c",
            "for f in /sys/class/hwmon/hwmon*/fan*_input; do [ -r \"$f\" ] || continue; "
            + "b=${f%_input}; h=${f%/*}; "
            + "printf '%s|%s|%s|%s\\n' \"$(cat \"$h/name\")\" \"${b##*/}\" "
            + "\"$(cat \"${b}_label\" 2>/dev/null)\" \"$(cat \"$f\")\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }
}
