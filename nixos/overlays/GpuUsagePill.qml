import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property bool available: false
    property real util: 0
    property real temp: 0
    property real memUsed: 0
    property real memTotal: 0
    property string gpuName: ""

    iconName: "auto_awesome_mosaic"
    isActive: available && util > 0
    primaryText: I18n.tr("GPU")

    secondaryText: {
        if (!available)
            return I18n.tr("Not available");
        const bits = [];
        bits.push(Math.round(util) + "%");
        if (temp > 0)
            bits.push(Math.round(temp) + "C");
        if (memTotal > 0)
            bits.push(Math.round(memUsed) + " / " + Math.round(memTotal) + " MiB");
        return bits.join("  ");
    }

    iconColor: {
        if (!available)
            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5);
        if (util > 90 || temp > 80)
            return Theme.error;
        if (util > 70 || temp > 70)
            return Theme.warning;
        return Theme.surfaceText;
    }

    function applyStatus(text) {
        try {
            const d = JSON.parse(text || "{}");
            available = !!d.available;
            util = d.util || 0;
            temp = d.temp || 0;
            memUsed = d.memUsed || 0;
            memTotal = d.memTotal || 0;
            gpuName = d.name || "";
        } catch (e) {
            available = false;
        }
    }

    Process {
        id: statusProc
        command: ["dms-gpustat"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (statusProc.running)
                return;
            statusProc.running = true;
        }
    }

    onToggled: expandClicked()
}
