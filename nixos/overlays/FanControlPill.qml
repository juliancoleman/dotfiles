import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property bool available: false
    property string mode: "none"
    property int percent: 0
    property int maxRpm: 0

    property int manualCount: 0

    iconName: "mode_fan"
    isActive: available && (mode === "manual" || mode === "mixed")

    primaryText: I18n.tr("Fans")

    secondaryText: {
        if (!available)
            return I18n.tr("Not available");
        if (mode === "mixed")
            return I18n.tr("Mixed") + " - " + manualCount + " " + I18n.tr("manual");
        if (mode === "manual")
            return I18n.tr("Manual") + " " + percent + "%";
        if (maxRpm > 0)
            return I18n.tr("Auto") + " " + maxRpm + " RPM";
        return I18n.tr("Auto");
    }

    iconColor: {
        if (!available)
            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5);
        if (mode === "manual")
            return Theme.primary;
        return Theme.surfaceText;
    }

    function applyStatus(text) {
        try {
            const d = JSON.parse(text || "{}");
            available = !!d.available;
            mode = d.mode || "none";
            percent = d.percent || 0;
            manualCount = d.manualCount || 0;
            let rpm = 0;
            for (const f of (d.fans || [])) {
                if ((f.rpm || 0) > rpm)
                    rpm = f.rpm;
            }
            maxRpm = rpm;
        } catch (e) {
            available = false;
        }
    }

    Process {
        id: statusProc
        command: ["dms-fanctl", "status"]
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
            statusProc.running = false;
            statusProc.running = true;
        }
    }

    onToggled: expandClicked()
}
