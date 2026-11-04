pragma Singleton

import QtQuick
import Quickshell
import "../Common"

// Whether the launcher is open and on which output: it opens from the bar on the output niri has focused.
Singleton {
    id: root

    property bool opened: false
    property bool locating: false
    property string screenName: ""

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    function open() {
        if (opened || locating)
            return
        locating = true
        FocusedOutput.find(function (name) {
            locating = false
            screenName = name
            opened = true
        })
    }

    function close() {
        opened = false
    }
}
