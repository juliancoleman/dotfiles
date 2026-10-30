pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The system-wide location switch. While off, GeoClue refuses to start, so nothing on the machine
// (weather, automatic time zone, browsers) can look up where it is. Needs services.qs.locationServices.
Singleton {
    id: root

    readonly property string offMarker: "/var/lib/qs/location-off"
    property bool installed: false
    property bool enabled: false
    property bool busy: false
    property string error: ""

    function check() {
        probe.running = true
    }

    function setEnabled(on) {
        if (!installed || busy || on === enabled)
            return
        busy = true
        error = ""
        toggle.command = ["systemctl", "--no-ask-password", "start", on ? "qs-location-on.service" : "qs-location-off.service"]
        toggle.running = true
    }

    Component.onCompleted: check()

    Process {
        id: probe
        command: ["sh", "-c", "systemctl cat qs-location-on.service >/dev/null 2>&1 || exit 2; test ! -e " + root.offMarker]
        onExited: code => {
            root.installed = code !== 2
            root.enabled = code === 0
        }
    }

    Process {
        id: toggle
        stderr: StdioCollector { id: complaint }
        onExited: code => {
            root.busy = false
            if (code !== 0)
                root.error = complaint.text.trim() || qsTr("Couldn't change location services")
            root.check()
        }
    }
}
