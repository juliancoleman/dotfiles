pragma Singleton

import QtQuick
import Quickshell
import "../Common"
import "../Launcher"

// Super+Comma: settings open or close on the bar of the output niri has focused.
// Each bar's control center holds its own settings pages, so this only says which screen should toggle.
Singleton {
    signal toggleRequested(string screenName)

    function toggle() {
        LauncherState.close()
        FocusedOutput.find(name => toggleRequested(name))
    }
}
