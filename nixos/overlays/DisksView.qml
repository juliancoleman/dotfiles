import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024)
            return bytesPerSec.toFixed(0) + " B/s";
        if (bytesPerSec < 1024 * 1024)
            return (bytesPerSec / 1024).toFixed(1) + " KB/s";
        if (bytesPerSec < 1024 * 1024 * 1024)
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s";
        return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(2) + " GB/s";
    }

    property var extraMounts: []

    readonly property var allMounts: {
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
        DgopService.addRef(["disk", "diskmounts"]);
    }

    Component.onDestruction: {
        DgopService.removeRef(["disk", "diskmounts"]);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingXL

                Column {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS

                    Row {
                        spacing: Theme.spacingS

                        DankIcon {
                            name: "storage"
                            size: Theme.iconSize
                            color: Theme.primary
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            text: I18n.tr("Disk I/O", "disk io header in system monitor")
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: Theme.spacingL

                        Row {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Read:", "disk read label")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: root.formatSpeed(DgopService.diskReadRate)
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: Theme.primary
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS

                            StyledText {
                                text: I18n.tr("Write:", "disk write label")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                            }

                            StyledText {
                                text: root.formatSpeed(DgopService.diskWriteRate)
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: Theme.warning
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.cornerRadius
            color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Row {
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "folder"
                        size: Theme.iconSize - 2
                        color: Theme.secondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Mount Points", "mount points header in system monitor")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.outlineLight
                }

                DankListView {
                    id: mountListView

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4

                    model: root.allMounts

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: mountListView.width
                        height: 60
                        radius: Theme.cornerRadius
                        color: mountMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06) : "transparent"

                        readonly property real usedPct: {
                            const pctStr = modelData?.percent ?? "0%";
                            return parseFloat(pctStr.replace("%", "")) / 100;
                        }

                        MouseArea {
                            id: mountMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS
                            spacing: Theme.spacingM

                            Column {
                                Layout.fillWidth: true
                                spacing: Theme.spacingXS

                                Row {
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: {
                                            const mp = modelData?.mount ?? "";
                                            const fs = (modelData?.fstype ?? "").toLowerCase();
                                            const dev = (modelData?.device ?? "").toLowerCase();
                                            if (fs.indexOf("cifs") !== -1 || fs.indexOf("smb") !== -1 || mp.indexOf("smb-share") !== -1 || dev.indexOf("//") === 0)
                                                return "folder_shared";
                                            if (fs.indexOf("nfs") !== -1 || fs.indexOf("sshfs") !== -1)
                                                return "cloud";
                                            if (mp === "/")
                                                return "home";
                                            if (mp === "/home")
                                                return "person";
                                            if (mp.includes("boot"))
                                                return "memory";
                                            if (mp.includes("media") || mp.includes("mnt"))
                                                return "usb";
                                            return "folder";
                                        }
                                        size: Theme.iconSize - 4
                                        color: Theme.surfaceText
                                        opacity: 0.8
                                    }

                                    StyledText {
                                        text: modelData?.mount ?? ""
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: SettingsData.monoFontFamily
                                        font.weight: Font.Medium
                                        color: Theme.surfaceText
                                    }
                                }

                                Row {
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: modelData?.device ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: "•"
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: modelData?.fstype ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            Column {
                                Layout.preferredWidth: 200
                                spacing: Theme.spacingXS

                                Rectangle {
                                    width: parent.width
                                    height: 8
                                    radius: 4
                                    color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)

                                    Rectangle {
                                        width: parent.width * Math.min(1, parent.parent.parent.parent.usedPct)
                                        height: parent.height
                                        radius: 4
                                        color: {
                                            const pct = parent.parent.parent.parent.usedPct;
                                            if (pct > 0.95)
                                                return Theme.error;
                                            if (pct > 0.85)
                                                return Theme.warning;
                                            return Theme.primary;
                                        }

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: Theme.shortDuration
                                            }
                                        }
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    spacing: Theme.spacingS

                                    StyledText {
                                        text: modelData?.used ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: "/"
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: modelData?.size ?? ""
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        font.family: SettingsData.monoFontFamily
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }

                            StyledText {
                                Layout.preferredWidth: 50
                                text: modelData?.percent ?? ""
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: SettingsData.monoFontFamily
                                font.weight: Font.Bold
                                color: {
                                    const pct = parent.parent.usedPct;
                                    if (pct > 0.95)
                                        return Theme.error;
                                    if (pct > 0.85)
                                        return Theme.warning;
                                    return Theme.surfaceText;
                                }
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 300
                        height: 80
                        radius: Theme.cornerRadius
                        color: "transparent"
                        visible: root.allMounts.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingM

                            DankIcon {
                                name: "storage"
                                size: 32
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: I18n.tr("No mount points found", "empty state in disk mounts list")
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceVariantText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
