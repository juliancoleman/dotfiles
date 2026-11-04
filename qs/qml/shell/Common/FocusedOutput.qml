pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The output niri has focused, for shortcuts that open something on "this" screen.
// Falls back to the first screen when niri can't say.
Singleton {
    id: root

    property var waiting: []

    function find(done) {
        waiting.push(done)
        if (!query.running)
            query.running = true
    }

    function answer(name) {
        const resolved = name || (Quickshell.screens.length ? Quickshell.screens[0].name : "")
        const callbacks = waiting
        waiting = []
        for (const done of callbacks)
            done(resolved)
    }

    Process {
        id: query
        command: ["niri", "msg", "--json", "focused-output"]
        stdout: StdioCollector {
            onStreamFinished: {
                let name = ""
                try {
                    name = JSON.parse(text).name || ""
                } catch (error) {
                }
                root.answer(name)
            }
        }
        onExited: code => {
            if (code !== 0)
                root.answer("")
        }
    }
}
