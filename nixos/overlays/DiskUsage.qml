import QtQuick
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property string mountPath: (widgetData && widgetData.mountPath !== undefined) ? widgetData.mountPath : "/"
    property bool isHovered: mouseArea.containsMouse
    property bool isAutoHideBar: false

    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null;
        }

        const currentMountPath = root.mountPath || "/";

        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === currentMountPath) {
                return DgopService.diskMounts[i];
            }
        }

        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === "/") {
                return DgopService.diskMounts[i];
            }
        }

        return DgopService.diskMounts[0] || null;
    }

    readonly property var listedMounts: {
        const mounts = DgopService.diskMounts || [];
        const extra = extraMounts || [];
        const seen = {};
        const out = [];
        for (const m of mounts.concat(extra)) {
            if (!m || !m.mount || seen[m.mount])
                continue;
            seen[m.mount] = true;
            out.push(m);
        }
        return out;
    }

    property var extraMounts: []

    property real diskUsagePercent: {
        let maxPct = 0;
        for (const m of listedMounts) {
            const pctStr = (m.percent || "0").toString().replace("%", "");
            const pct = parseFloat(pctStr) || 0;
            if (pct > maxPct)
                maxPct = pct;
        }
        return maxPct;
    }

    function openDisksMonitor() {
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

    function parseExtraMounts(text) {
        const rows = [];
        const parts = (text || "").split("---GVFS---");
        const findmntText = (parts[0] || "").trim();
        if (findmntText) {
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
                "fstype": fstype,
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
        DgopService.addRef(["diskmounts"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["diskmounts"]);
    }

    readonly property real minTooltipY: {
        if (!parentScreen || !isVerticalOrientation) {
            return 0;
        }

        if (isAutoHideBar) {
            return 0;
        }

        if (parentScreen.y > 0) {
            const spacing = barConfig?.spacing ?? 4;
            const offset = barThickness + spacing;
            return offset;
        }

        return 0;
    }

    Connections {
        function onWidgetDataChanged() {
            root.mountPath = Qt.binding(() => {
                return (root.widgetData && root.widgetData.mountPath !== undefined) ? root.widgetData.mountPath : "/";
            });

            root.selectedMount = Qt.binding(() => {
                if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
                    return null;
                }

                const currentMountPath = root.mountPath || "/";

                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === currentMountPath) {
                        return DgopService.diskMounts[i];
                    }
                }

                for (let i = 0; i < DgopService.diskMounts.length; i++) {
                    if (DgopService.diskMounts[i].mount === "/") {
                        return DgopService.diskMounts[i];
                    }
                }

                return DgopService.diskMounts[0] || null;
            });
        }

        target: SettingsData
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : diskContent.implicitWidth
            implicitHeight: root.isVerticalOrientation ? diskColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: diskColumn
                visible: root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 1

                DankIcon {
                    name: "storage"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.noBackground)
                    color: {
                        if (root.diskUsagePercent > 90) {
                            return Theme.tempDanger;
                        }
                        if (root.diskUsagePercent > 75) {
                            return Theme.tempWarning;
                        }
                        return Theme.surfaceText;
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                            return "--";
                        }
                        return root.diskUsagePercent.toFixed(0);
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: diskContent
                visible: !root.isVerticalOrientation
                anchors.centerIn: parent
                spacing: 3

                DankIcon {
                    name: "storage"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.noBackground)
                    color: {
                        if (root.diskUsagePercent > 90) {
                            return Theme.tempDanger;
                        }
                        if (root.diskUsagePercent > 75) {
                            return Theme.tempWarning;
                        }
                        return Theme.surfaceText;
                    }
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: {
                        if (!root.selectedMount) {
                            return "--";
                        }
                        return root.selectedMount.mount;
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone
                }

                StyledText {
                    text: {
                        if (root.diskUsagePercent === undefined || root.diskUsagePercent === null || root.diskUsagePercent === 0) {
                            return "--%";
                        }
                        return root.diskUsagePercent.toFixed(0) + "%";
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone

                    StyledTextMetrics {
                        id: diskBaseline
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        text: "100%"
                    }

                    width: Math.max(diskBaseline.width, paintedWidth)

                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: tooltipLoader
        active: false
        sourceComponent: DankTooltip {}
    }

    MouseArea {
        id: mouseArea
        z: 1
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.openDisksMonitor()
        onEntered: {
            if (!root.isVerticalOrientation || listedMounts.length === 0)
                return;
            tooltipLoader.active = true;
            if (tooltipLoader.item) {
                const globalPos = mapToGlobal(width / 2, height / 2);
                const currentScreen = root.parentScreen || Screen;
                const screenX = currentScreen ? currentScreen.x : 0;
                const screenY = currentScreen ? currentScreen.y : 0;
                const relativeY = globalPos.y - screenY;
                const adjustedY = relativeY + root.minTooltipY;
                const tooltipX = root.axis?.edge === "left" ? (root.barThickness + root.barSpacing + Theme.spacingXS) : (currentScreen.width - root.barThickness - root.barSpacing - Theme.spacingXS);
                const isLeft = root.axis?.edge === "left";
                const summary = listedMounts.map(m => (m.mount + " " + (m.percent || ""))).join("\n");
                tooltipLoader.item.show(summary, screenX + tooltipX, adjustedY, currentScreen, isLeft, !isLeft);
            }
        }
        onExited: {
            if (tooltipLoader.item) {
                tooltipLoader.item.hide();
            }
            tooltipLoader.active = false;
        }
    }
}
