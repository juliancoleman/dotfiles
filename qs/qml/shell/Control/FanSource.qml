pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Common"

// Fan speeds straight from sysfs. One read at startup gates the tile; afterwards it only polls
// while a panel on some screen is open and the helper isn't already reporting the same fans.
Singleton {
    id: root

    property int watchers: 0
    readonly property bool active: watchers > 0
    property var fans: []
    readonly property alias rows: rows
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

    function parse(text) {
        const next = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; ++i) {
            const parts = lines[i].split("|")
            if (parts.length < 5)
                continue
            const rpm = parseInt(parts[3], 10)
            if (!isFinite(rpm))
                continue
            // pwmN is 0..255; -1 when the driver exposes no duty for this header.
            const pwm = parseInt(parts[4], 10)
            next.push({
                id: parts[0] + "/" + parts[1],
                label: parts[2] || parts[1],
                rpm: rpm,
                percent: isFinite(pwm) ? Math.round(pwm * 100 / 255) : -1
            })
        }
        fans = next
        FanControl.syncRows(rows, next)
    }

    ListModel {
        id: rows
    }

    Process {
        id: reader
        running: true
        command: ["sh", "-c",
            "for f in /sys/class/hwmon/hwmon*/fan*_input; do [ -r \"$f\" ] || continue; "
            + "b=${f%_input}; h=${f%/*}; n=${b##*/fan}; "
            + "printf '%s|%s|%s|%s|%s\\n' \"$(cat \"$h/name\")\" \"${b##*/}\" "
            + "\"$(cat \"${b}_label\" 2>/dev/null)\" \"$(cat \"$f\")\" \"$(cat \"$h/pwm$n\" 2>/dev/null)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active && !FanControl.ready
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }
}
