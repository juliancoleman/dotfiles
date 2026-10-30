pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the launcher is open and on which output: it opens from the bar on the output niri has focused.
Singleton {
    id: root

    property bool opened: false
    property string screenName: ""

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    function open() {
        if (!opened && !locate.running)
            locate.running = true
    }

    function close() {
        opened = false
    }

    function show(name) {
        screenName = name || (Quickshell.screens.length ? Quickshell.screens[0].name : "")
        opened = true
    }

    Process {
        id: locate
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = ""
                try {
                    name = JSON.parse(text).name || ""
                } catch (error) {
                }
                root.show(name)
            }
        }
        onExited: code => {
            if (code !== 0)
                root.show("")
        }
    }
}
