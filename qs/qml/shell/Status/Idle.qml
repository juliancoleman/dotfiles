pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Writes hypridle's listeners from `display.screenOff`: lock and power the screen off together, and on a laptop
// suspend ten minutes later. hypridle does the watching and honors every inhibitor (video and calls reach it
// through niri, which serves org.freedesktop.ScreenSaver; logind idle locks directly). programs.qs.idle sources
// this file from hypridle's config and seeds it; without that file the setting isn't offered.
Singleton {
    id: root

    readonly property string path: Quickshell.env("QS_IDLE_FILE")
        || (Quickshell.env("HOME") || "") + "/.config/qs/hypridle.conf"
    property bool installed: false
    // What the file held when last read or written; a rewrite happens only when this differs.
    property string written: ""
    readonly property int suspendDelay: 10 * 60

    readonly property string wanted: {
        const timeout = ClockConfig.screenOffMinutes * 60
        let text = "# Written by qs from display.screenOff; changes here are overwritten.\n"
            + "listener {\n"
            + "    timeout = " + timeout + "\n"
            + "    on-timeout = loginctl lock-session; niri msg action power-off-monitors\n"
            + "    on-resume = niri msg action power-on-monitors\n"
            + "}\n"
        if (battery.available)
            text += "\nlistener {\n"
                + "    timeout = " + (timeout + suspendDelay) + "\n"
                + "    on-timeout = systemctl suspend\n"
                + "}\n"
        return text
    }

    // The battery and the config both arrive a moment after start; settle before writing so hypridle restarts
    // once, not once per arrival.
    onWantedChanged: sync()

    function sync() {
        settle.restart()
    }

    BatterySource {
        id: battery
    }

    Timer {
        id: settle
        interval: 2000
        onTriggered: {
            if (!root.installed || !ClockConfig.loaded || root.wanted === root.written)
                return
            root.written = root.wanted
            writer.setText(root.wanted)
        }
    }

    FileView {
        path: root.path
        printErrors: false
        onLoaded: {
            root.written = text()
            root.installed = true
            settle.restart()
        }
    }

    FileView {
        id: writer
        path: root.path
        atomicWrites: true
        preload: false
        onSaved: restart.running = true
        onSaveFailed: error => console.log("qs idle: write failed", FileViewError.toString(error))
    }

    // hypridle reads its config once, at start.
    Process {
        id: restart
        command: ["systemctl", "--user", "restart", "hypridle.service"]
        onExited: code => {
            if (code !== 0)
                console.log("qs idle: restarting hypridle failed, exit", code)
        }
    }
}
