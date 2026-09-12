import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    property string mountPath: "/"
    property string instanceId: ""
    property var extraMounts: []

    iconName: listedMounts.some(m => isSamba(m)) ? "folder_shared" : "storage"

    readonly property var listedMounts: {
        const seen = {};
        const out = [];
        const add = m => {
            if (!m || !m.mount || seen[m.mount])
                return;
            seen[m.mount] = true;
            out.push(m);
        };
        for (const m of (DgopService.diskMounts || []))
            add(m);
        for (const m of extraMounts)
            add(m);
        return out;
    }

    property var selectedMount: {
        const mounts = listedMounts;
        if (!mounts.length)
            return null;
        return mounts.find(m => m.mount === mountPath) || mounts.find(m => m.mount === "/") || mounts[0];
    }

    property real usagePercent: {
        let maxPct = 0;
        for (const m of listedMounts) {
            const percentStr = (m.percent || "0").toString().replace("%", "");
            const pct = parseFloat(percentStr) || 0;
            if (pct > maxPct)
                maxPct = pct;
        }
        return maxPct;
    }

    function isSamba(m) {
        const mp = (m?.mount || "").toLowerCase();
        const fs = (m?.fstype || "").toLowerCase();
        const dev = (m?.device || "").toLowerCase();
        return fs.indexOf("cifs") !== -1 || fs.indexOf("smb") !== -1 || mp.indexOf("smb-share") !== -1 || dev.indexOf("//") === 0;
    }

    function parseExtraMounts(text) {
        const rows = [];
        const parts = (text || "").split("---GVFS---");
        const findmntText = (parts[0] || "").trim();
        if (findmntText && findmntText !== "{}") {
            try {
                const data = JSON.parse(findmntText);
                for (const fs of (data.filesystems || [])) {
                    if (!fs || !fs.target)
                        continue;
                    rows.push({
                        "device": fs.source || "",
                        "mount": fs.target,
                        "fstype": fs.fstype || "",
                        "size": fs.size || "",
                        "used": fs.used || "",
                        "avail": fs.avail || "",
                        "percent": fs["use%"] || ""
                    });
                }
            } catch (e) {
            }
        }
        const gvfsText = (parts[1] || "").trim();
        for (const line of gvfsText.split("\n")) {
            const trimmed = line.trim();
            if (!trimmed)
                continue;
            const cols = trimmed.split(/\s+/);
            if (cols.length < 7)
                continue;
            const percent = cols[cols.length - 1];
            const avail = cols[cols.length - 2];
            const used = cols[cols.length - 3];
            const size = cols[cols.length - 4];
            const fstype = cols[cols.length - 5];
            const target = cols[cols.length - 6];
            const device = cols.slice(0, cols.length - 6).join(" ");
            rows.push({
                "device": device,
                "mount": target,
                "fstype": fstype.indexOf("smb") !== -1 || target.indexOf("smb-share") !== -1 ? "cifs" : fstype,
                "size": size,
                "used": used,
                "avail": avail,
                "percent": percent
            });
        }
        return rows;
    }

    isActive: listedMounts.length > 0

    primaryText: {
        if (listedMounts.length > 1)
            return I18n.tr("Disks");
        if (!selectedMount)
            return I18n.tr("Disk Usage");
        return selectedMount.mount === "/" ? I18n.tr("Disk") : selectedMount.mount;
    }

    secondaryText: {
        if (listedMounts.length === 0)
            return I18n.tr("No disk data");
        if (listedMounts.length > 1)
            return listedMounts.length + " " + I18n.tr("volumes") + " - " + usagePercent.toFixed(0) + "%";
        const m = selectedMount;
        return `${m.used} / ${m.size} (${usagePercent.toFixed(0)}%)`;
    }

    iconColor: {
        if (listedMounts.length === 0)
            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5);
        if (usagePercent > 90)
            return Theme.error;
        if (usagePercent > 75)
            return Theme.warning;
        return Theme.surfaceText;
    }

    Process {
        id: extraMountProc
        command: ["sh", "-c", "findmnt -J -t cifs,smb3,nfs,nfs4,fuse.sshfs 2>/dev/null || echo '{\"filesystems\":[]}'; echo '---GVFS---'; gvfs=\"/run/user/$(id -u)/gvfs\"; if [ -d \"$gvfs\" ]; then for d in \"$gvfs\"/*; do [ -d \"$d\" ] || continue; df -h --output=source,target,fstype,size,used,avail,pcent \"$d\" 2>/dev/null | tail -n +2; done; fi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.extraMounts = root.parseExtraMounts(text)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            extraMountProc.running = false;
            extraMountProc.running = true;
        }
    }

    Component.onCompleted: {
        DgopService.addRef(["diskmounts"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"]);
    }

    onToggled: {
        expandClicked();
    }
}
