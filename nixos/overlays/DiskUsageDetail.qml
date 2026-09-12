import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property string currentMountPath: "/"
    property string instanceId: ""
    property var extraMounts: []

    signal mountPathChanged(string newMountPath)

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

    implicitHeight: diskColumn.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

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

    function isSamba(m) {
        const mp = (m?.mount || "").toLowerCase();
        const fs = (m?.fstype || "").toLowerCase();
        const dev = (m?.device || "").toLowerCase();
        return fs.indexOf("cifs") !== -1 || fs.indexOf("smb") !== -1 || mp.indexOf("smb-share") !== -1 || dev.indexOf("//") === 0;
    }

    function isRemote(m) {
        if (isSamba(m))
            return true;
        const fs = (m?.fstype || "").toLowerCase();
        return fs.indexOf("nfs") !== -1 || fs.indexOf("sshfs") !== -1;
    }

    function mountTitle(m) {
        const mp = m?.mount || "";
        if (mp === "/")
            return I18n.tr("Root Filesystem");
        const gvfs = mp.match(/smb-share:server=([^,]+)(?:,share=([^,/]+))?/);
        if (gvfs)
            return gvfs[2] ? (gvfs[2] + " on " + gvfs[1]) : ("Samba " + gvfs[1]);
        const dev = m?.device || "";
        if (dev.indexOf("//") === 0)
            return dev.replace(/^\/\//, "");
        if (isSamba(m))
            return I18n.tr("Samba") + " - " + (dev || mp);
        return mp;
    }

    function mountIcon(m) {
        const mp = m?.mount || "";
        if (isSamba(m))
            return "folder_shared";
        if (isRemote(m))
            return "cloud";
        if (mp === "/")
            return "storage";
        if (mp.indexOf("boot") !== -1)
            return "memory";
        if (mp.indexOf("media") !== -1 || mp.indexOf("mnt") !== -1)
            return "usb";
        return "folder";
    }

    function usagePercent(m) {
        const percentStr = (m?.percent || "0").toString().replace("%", "");
        return parseFloat(percentStr) || 0;
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

    Column {
        id: diskColumn
        width: parent.width - Theme.spacingL * 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingS

        StyledText {
            text: I18n.tr("Connected drives")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: Theme.surfaceVariantText
        }

        Item {
            width: parent.width
            height: 80
            visible: root.listedMounts.length === 0

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: DgopService.dgopAvailable ? "storage" : "error"
                    size: 28
                    color: DgopService.dgopAvailable ? Theme.primary : Theme.error
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: DgopService.dgopAvailable ? I18n.tr("No disk data available") : I18n.tr("dgop not available")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                }
            }
        }

        Repeater {
            model: root.listedMounts

            Rectangle {
                id: mountCard
                required property var modelData

                width: parent.width
                height: 76
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                border.color: modelData.mount === root.currentMountPath ? Theme.primary : "transparent"
                border.width: modelData.mount === root.currentMountPath ? 2 : 0

                readonly property real pct: root.usagePercent(modelData)
                readonly property bool samba: root.isSamba(modelData)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingM
                    spacing: Theme.spacingM

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        width: 40

                        DankIcon {
                            name: root.mountIcon(mountCard.modelData)
                            size: Theme.iconSize
                            color: {
                                if (mountCard.pct > 90)
                                    return Theme.error;
                                if (mountCard.pct > 75)
                                    return Theme.warning;
                                return mountCard.modelData.mount === root.currentMountPath ? Theme.primary : Theme.surfaceText;
                            }
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: mountCard.pct.toFixed(0) + "%"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40 - parent.spacing
                        spacing: 4

                        StyledText {
                            text: root.mountTitle(mountCard.modelData)
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        StyledText {
                            text: {
                                const used = mountCard.modelData.used || "?";
                                const size = mountCard.modelData.size || "?";
                                const kind = mountCard.samba ? I18n.tr("Samba") : (mountCard.modelData.fstype || "");
                                if (kind)
                                    return used + " / " + size + " - " + kind;
                                return used + " / " + size;
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

                            Rectangle {
                                width: parent.width * Math.min(mountCard.pct / 100, 1)
                                height: parent.height
                                radius: parent.radius
                                color: mountCard.pct > 90 ? Theme.error : (mountCard.pct > 75 ? Theme.warning : Theme.primary)
                            }
                        }
                    }
                }

                DankRipple {
                    id: mountRipple
                    cornerRadius: parent.radius
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => mountRipple.trigger(mouse.x, mouse.y)
                    onClicked: {
                        root.currentMountPath = mountCard.modelData.mount;
                        root.mountPathChanged(mountCard.modelData.mount);
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: Theme.cornerRadius
            z: 20
            visible: root.listedMounts.length > 0
            color: Theme.withAlpha(Theme.primary, monitorMouse.containsMouse ? 0.18 : 0.10)

            StyledText {
                anchors.centerIn: parent
                text: I18n.tr("Open disk monitor")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.primary
            }

            MouseArea {
                id: monitorMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (PopoutService.processListModalLoader)
                        PopoutService.processListModalLoader.active = true;
                    Qt.callLater(() => {
                        const modal = PopoutService.processListModal;
                        if (!modal)
                            return;
                        modal.currentTab = 2;
                        modal.show();
                    });
                }
            }
        }
    }
}
