import QtCore
import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool available: false
    property string mode: "none"
    property int manualCount: 0
    property int busyFanId: 0
    property int pendingFanId: 0
    property int pendingPercent: 50
    property var fanLabels: ({})
    property var overrides: ({})
    property int editingFanId: 0
    property int adjustingFanId: 0
    property bool writingLabels: false
    property bool writingOverrides: false
    property int epoch: 0
    property var queuedAction: null

    readonly property bool isManual: mode === "manual" || mode === "mixed"

    ListModel {
        id: fanModel
    }

    implicitHeight: contentColumn.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    function mapFan(n) {
        return {
            "fanId": n.id,
            "rpm": n.rpm || 0,
            "pwm": n.pwm || 0,
            "percent": n.percent || 0,
            "enable": n.enable || 0
        };
    }

    function overridePct(id) {
        const v = overrides[String(id)];
        return (v === undefined || v === null) ? -1 : Number(v);
    }

    function addOverride(id, pct, persist) {
        const clamped = Math.max(15, Math.min(100, Math.round(pct)));
        const next = Object.assign({}, overrides);
        next[String(id)] = clamped;
        overrides = next;
        if (persist !== false)
            saveOverrides();
        return clamped;
    }

    function removeOverride(id) {
        const next = Object.assign({}, overrides);
        delete next[String(id)];
        overrides = next;
        saveOverrides();
    }

    function clearOverrides() {
        overrides = ({});
        saveOverrides();
    }

    function holdArgs() {
        const args = ["dms-fanctl", "hold"];
        const keys = Object.keys(overrides);
        for (let i = 0; i < keys.length; i++)
            args.push(keys[i] + "=" + overrides[keys[i]]);
        return args;
    }

    function recomputeMode() {
        let manual = 0;
        let auto = 0;
        for (let i = 0; i < fanModel.count; i++) {
            if (Number(fanModel.get(i).enable) === 1)
                manual++;
            else
                auto++;
        }
        if (manual === 0)
            mode = "auto";
        else if (auto === 0)
            mode = "manual";
        else
            mode = "mixed";
        manualCount = manual;
    }

    function patchFan(id, fields) {
        for (let i = 0; i < fanModel.count; i++) {
            if (Number(fanModel.get(i).fanId) !== Number(id))
                continue;
            for (const k of Object.keys(fields))
                fanModel.setProperty(i, k, fields[k]);
            break;
        }
        recomputeMode();
    }

    function syncFans(incoming, rpmOnly) {
        if (!incoming || incoming.length === 0)
            return;
        if (fanModel.count !== incoming.length) {
            fanModel.clear();
            for (let i = 0; i < incoming.length; i++)
                fanModel.append(mapFan(incoming[i]));
            for (let i = 0; i < fanModel.count; i++) {
                const ov = root.overridePct(fanModel.get(i).fanId);
                if (ov >= 0) {
                    fanModel.setProperty(i, "enable", 1);
                    fanModel.setProperty(i, "percent", ov);
                }
            }
            return;
        }
        for (let i = 0; i < incoming.length; i++) {
            const n = incoming[i];
            const ov = root.overridePct(n.id);
            fanModel.setProperty(i, "rpm", n.rpm || 0);
            if (ov >= 0) {
                fanModel.setProperty(i, "enable", 1);
                if (root.busyFanId !== n.id)
                    fanModel.setProperty(i, "percent", ov);
            } else if (!rpmOnly) {
                fanModel.setProperty(i, "pwm", n.pwm || 0);
                fanModel.setProperty(i, "percent", n.percent || 0);
                fanModel.setProperty(i, "enable", n.enable || 0);
            }
        }
    }

    function applyStatus(text, rpmOnly) {
        try {
            const d = JSON.parse(text || "{}");
            if (!d.available) {
                if (fanModel.count === 0)
                    available = false;
                return;
            }
            available = true;
            syncFans(d.fans || [], !!rpmOnly);
            recomputeMode();
        } catch (e) {
            if (fanModel.count === 0)
                available = false;
        }
    }

    function refresh() {
        if (actionProc.running || sliderDebounce.running)
            return;
        if (Object.keys(root.overrides).length > 0) {
            runAction(holdArgs());
            return;
        }
        if (statusProc.running)
            return;
        statusProc.startedEpoch = root.epoch;
        statusProc.running = true;
    }

    function runAction(args) {
        root.epoch += 1;
        if (actionProc.running) {
            root.queuedAction = args;
            return;
        }
        actionProc.command = args;
        actionProc.running = true;
    }

    function setAutoAll() {
        adjustingFanId = 0;
        clearOverrides();
        for (let i = 0; i < fanModel.count; i++)
            fanModel.setProperty(i, "enable", 5);
        recomputeMode();
        runAction(["dms-fanctl", "auto"]);
    }

    function setAutoOne(id) {
        if (adjustingFanId === id)
            adjustingFanId = 0;
        removeOverride(id);
        patchFan(id, {
            "enable": 5
        });
        runAction(["dms-fanctl", "auto", "" + id]);
    }

    function setManualOne(id, pct) {
        const clamped = addOverride(id, pct);
        busyFanId = id;
        adjustingFanId = id;
        patchFan(id, {
            "enable": 1,
            "percent": clamped
        });
        runAction(["dms-fanctl", "manual", "" + id, "" + clamped]);
    }

    function collapseSlider() {
        sliderDebounce.stop();
        if (pendingFanId > 0) {
            addOverride(pendingFanId, pendingPercent);
            runAction(["dms-fanctl", "manual", "" + pendingFanId, "" + pendingPercent]);
            pendingFanId = 0;
        }
        busyFanId = 0;
        adjustingFanId = 0;
        saveOverrides();
    }

    function loadLabels(text) {
        try {
            const d = JSON.parse(text || "{}");
            const next = {};
            if (d && typeof d === "object" && !Array.isArray(d)) {
                for (const k of Object.keys(d)) {
                    if (typeof d[k] === "string" && d[k].trim())
                        next[k] = d[k].trim();
                }
            }
            fanLabels = next;
        } catch (e) {
            fanLabels = ({});
        }
    }

    function saveLabels() {
        writingLabels = true;
        labelsFile.setText(JSON.stringify(fanLabels, null, 2) + "\n");
    }

    function loadOverrides(text) {
        try {
            const d = JSON.parse(text || "{}");
            const next = {};
            if (d && typeof d === "object" && !Array.isArray(d)) {
                for (const k of Object.keys(d)) {
                    const n = Number(d[k]);
                    if ((k === "1" || k === "2" || k === "3" || k === "4" || k === "5" || k === "6") && n >= 15 && n <= 100)
                        next[k] = n;
                }
            }
            overrides = next;
            for (const k of Object.keys(next)) {
                patchFan(Number(k), {
                    "enable": 1,
                    "percent": next[k]
                });
            }
        } catch (e) {
            overrides = ({});
        }
    }

    function saveOverrides() {
        writingOverrides = true;
        overridesFile.setText(JSON.stringify(overrides, null, 2) + "\n");
    }

    function fanName(id) {
        const n = fanLabels["" + id];
        if (n && String(n).trim())
            return String(n).trim();
        return I18n.tr("Fan") + " " + id;
    }

    function setFanLabel(id, name) {
        const key = "" + id;
        const fallback = I18n.tr("Fan") + " " + id;
        const trimmed = (name || "").trim().slice(0, 48);
        const next = Object.assign({}, fanLabels);
        if (!trimmed || trimmed === fallback)
            delete next[key];
        else
            next[key] = trimmed;
        fanLabels = next;
        saveLabels();
    }

    FileView {
        id: labelsFile
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell/fan-labels.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (root.writingLabels) {
                root.writingLabels = false;
                return;
            }
            root.loadLabels(labelsFile.text());
        }
        onLoadFailed: error => {
            root.writingLabels = false;
            root.fanLabels = ({});
        }
    }

    FileView {
        id: overridesFile
        path: StandardPaths.writableLocation(StandardPaths.ConfigLocation) + "/DankMaterialShell/fan-overrides.json"
        blockLoading: true
        blockWrites: true
        atomicWrites: true
        watchChanges: true
        onLoaded: {
            if (root.writingOverrides) {
                root.writingOverrides = false;
                return;
            }
            root.loadOverrides(overridesFile.text());
        }
        onLoadFailed: error => {
            root.writingOverrides = false;
        }
    }

    Process {
        id: statusProc
        property int startedEpoch: 0
        command: ["dms-fanctl", "status"]
        running: false
        onRunningChanged: {
            if (running)
                startedEpoch = root.epoch;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const rpmOnly = statusProc.startedEpoch !== root.epoch || root.busyFanId !== 0;
                root.applyStatus(text, rpmOnly);
            }
        }
    }

    Process {
        id: actionProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyStatus(text, false);
                root.busyFanId = 0;
                while (root.queuedAction) {
                    const next = root.queuedAction;
                    root.queuedAction = null;
                    if (next[1] === "hold" && Object.keys(root.overrides).length === 0)
                        continue;
                    actionProc.command = next;
                    actionProc.running = true;
                    break;
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: sliderDebounce
        interval: 120
        repeat: false
        onTriggered: root.setManualOne(root.pendingFanId, root.pendingPercent)
    }

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingL * 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: "mode_fan"
                size: Theme.iconSizeLarge
                color: root.isManual ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: parent.width - Theme.iconSizeLarge - parent.spacing

                StyledText {
                    text: I18n.tr("Fans")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                StyledText {
                    text: {
                        if (!root.available)
                            return I18n.tr("No PWM controller");
                        if (root.mode === "mixed")
                            return root.manualCount + " " + I18n.tr("manual") + " / " + I18n.tr("rest automatic");
                        if (root.mode === "manual")
                            return I18n.tr("All manual");
                        return I18n.tr("All automatic");
                    }
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: Theme.cornerRadius
            visible: root.available
            color: !root.isManual ? Theme.ccTileActiveBg : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

            StyledText {
                anchors.centerIn: parent
                text: I18n.tr("All automatic")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: !root.isManual ? Theme.ccTileActiveText : Theme.surfaceText
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setAutoAll()
            }
        }

        Repeater {
            model: fanModel

            Column {
                id: fanCol
                required property int fanId
                required property int rpm
                required property int percent
                required property int enable
                width: parent.width
                spacing: Theme.spacingXS

                readonly property bool fanManual: Number(enable) === 1
                readonly property bool adjusting: root.adjustingFanId === fanId
                readonly property int fanPct: percent || 0
                readonly property bool editing: root.editingFanId === fanId
                readonly property string customName: {
                    const n = root.fanLabels["" + fanId];
                    return (n && String(n).trim()) ? String(n).trim() : "";
                }
                readonly property string displayName: customName || (I18n.tr("Fan") + " " + fanId)
                readonly property string rpmText: rpm > 0 ? (rpm + " RPM") : "--"
                property bool editorArmed: false

                function commitLabel() {
                    editorArmed = false;
                    root.setFanLabel(fanId, labelInput.text);
                    root.editingFanId = 0;
                }

                function cancelEdit() {
                    editorArmed = false;
                    root.editingFanId = 0;
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingS
                    height: fanCol.editing ? 30 : 22

                    Item {
                        width: parent.width - 72 - (fanCol.fanManual && !fanCol.adjusting ? 44 : 0) - parent.spacing * (fanCol.fanManual && !fanCol.adjusting ? 2 : 1)
                        height: parent.height

                        StyledText {
                            anchors.left: parent.left
                            anchors.right: editIcon.left
                            anchors.rightMargin: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !fanCol.editing
                            text: fanCol.displayName
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: nameHover.containsMouse ? Theme.primary : Theme.surfaceText
                            elide: Text.ElideRight
                        }

                        DankIcon {
                            id: editIcon
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !fanCol.editing
                            name: "edit"
                            size: 14
                            color: nameHover.containsMouse ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.55)
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: fanCol.editing
                            radius: Theme.cornerRadius
                            color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                            border.color: Theme.primary
                            border.width: 1

                            TextInput {
                                id: labelInput
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spacingS
                                anchors.rightMargin: Theme.spacingS
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                selectionColor: Theme.primaryContainer
                                selectedTextColor: Theme.primary
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                selectByMouse: true
                                maximumLength: 48
                                onAccepted: fanCol.commitLabel()
                                onActiveFocusChanged: {
                                    if (activeFocus)
                                        fanCol.editorArmed = true;
                                    else if (fanCol.editorArmed && fanCol.editing)
                                        fanCol.commitLabel();
                                }
                                Keys.onEscapePressed: event => {
                                    event.accepted = true;
                                    fanCol.cancelEdit();
                                }
                            }
                        }

                        MouseArea {
                            id: nameHover
                            anchors.fill: parent
                            visible: !fanCol.editing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                fanCol.editorArmed = false;
                                labelInput.text = fanCol.displayName;
                                root.editingFanId = fanId;
                                Qt.callLater(() => {
                                    labelInput.forceActiveFocus();
                                    labelInput.selectAll();
                                });
                            }
                        }
                    }

                    Rectangle {
                        width: 40
                        height: 24
                        radius: Theme.cornerRadius
                        visible: fanCol.fanManual && !fanCol.adjusting
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.withAlpha(Theme.primary, 0.14)

                        StyledText {
                            anchors.centerIn: parent
                            text: fanCol.fanPct + "%"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.adjustingFanId = fanId
                        }
                    }

                    Rectangle {
                        width: 72
                        height: 24
                        radius: Theme.cornerRadius
                        anchors.verticalCenter: parent.verticalCenter
                        color: fanCol.adjusting || !fanCol.fanManual ? Theme.ccTileActiveBg : Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                        StyledText {
                            anchors.centerIn: parent
                            text: {
                                if (fanCol.adjusting)
                                    return I18n.tr("Done");
                                if (fanCol.fanManual)
                                    return I18n.tr("Auto");
                                return I18n.tr("Override");
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: fanCol.adjusting || !fanCol.fanManual ? Theme.ccTileActiveText : Theme.surfaceText
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (fanCol.editing)
                                    fanCol.commitLabel();
                                if (fanCol.adjusting)
                                    root.collapseSlider();
                                else if (fanCol.fanManual)
                                    root.setAutoOne(fanId);
                                else
                                    root.setManualOne(fanId, fanCol.fanPct > 0 ? fanCol.fanPct : 50);
                            }
                        }
                    }
                }

                StyledText {
                    text: fanCol.customName ? (I18n.tr("Fan") + " " + fanId + "  " + fanCol.rpmText) : fanCol.rpmText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    width: parent.width
                    elide: Text.ElideRight
                }

                Row {
                    width: parent.width
                    height: 40
                    visible: fanCol.adjusting
                    spacing: 0

                    DankIcon {
                        name: "speed"
                        size: Theme.iconSize
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.iconSize + Theme.spacingS * 2
                    }

                    DankSlider {
                        id: fanSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Theme.iconSize - Theme.spacingS * 2
                        enabled: true
                        minimum: 15
                        maximum: 100
                        showValue: true
                        unit: "%"
                        thumbOutlineColor: Theme.surfaceContainerHigh
                        trackColor: Theme.withAlpha(Theme.outline, 0.45)
                        onSliderValueChanged: function (newValue) {
                            const pct = Math.max(15, Math.min(100, newValue));
                            root.pendingFanId = fanId;
                            root.pendingPercent = pct;
                            root.busyFanId = fanId;
                            root.addOverride(fanId, pct, false);
                            root.patchFan(fanId, {
                                "percent": pct
                            });
                            sliderDebounce.restart();
                        }
                    }

                    Binding {
                        target: fanSlider
                        property: "value"
                        value: Math.min(100, Math.max(15, fanCol.fanPct))
                        when: !fanSlider.isDragging
                    }
                }
            }
        }
    }
}
