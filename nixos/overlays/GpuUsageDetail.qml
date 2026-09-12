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
    property string gpuName: ""
    property real util: 0
    property real temp: 0
    property real fan: 0
    property real memUtil: 0
    property real memUsed: 0
    property real memTotal: 0
    property real power: 0
    property real powerLimit: 0
    property real coreClock: 0
    property real memClock: 0

    implicitHeight: contentColumn.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    function applyStatus(text) {
        try {
            const d = JSON.parse(text || "{}");
            available = !!d.available;
            gpuName = d.name || "";
            util = d.util || 0;
            temp = d.temp || 0;
            fan = d.fan || 0;
            memUtil = d.memUtil || 0;
            memUsed = d.memUsed || 0;
            memTotal = d.memTotal || 0;
            power = d.power || 0;
            powerLimit = d.powerLimit || 0;
            coreClock = d.coreClock || 0;
            memClock = d.memClock || 0;
        } catch (e) {
            available = false;
        }
    }

    function hotColor(u, t) {
        if (u > 90 || t > 80)
            return Theme.error;
        if (u > 70 || t > 70)
            return Theme.warning;
        return Theme.primary;
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
                name: "auto_awesome_mosaic"
                size: Theme.iconSizeLarge
                color: root.available ? root.hotColor(root.util, root.temp) : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: parent.width - Theme.iconSizeLarge - parent.spacing

                StyledText {
                    text: I18n.tr("GPU")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                StyledText {
                    text: root.available ? (root.gpuName || I18n.tr("NVIDIA")) : I18n.tr("No GPU stats")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 10
            radius: 5
            visible: root.available
            color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

            Rectangle {
                width: parent.width * Math.min(root.util / 100, 1)
                height: parent.height
                radius: parent.radius
                color: root.hotColor(root.util, root.temp)
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.available

            Repeater {
                model: [
                    {
                        "label": I18n.tr("Usage"),
                        "value": Math.round(root.util) + "%"
                    },
                    {
                        "label": I18n.tr("Temp"),
                        "value": Math.round(root.temp) + "C"
                    },
                    {
                        "label": I18n.tr("Fan"),
                        "value": Math.round(root.fan) + "%"
                    }
                ]

                StyledRect {
                    required property var modelData
                    width: (parent.width - Theme.spacingM * 2) / 3
                    height: 56
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: modelData.value
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS
            visible: root.available

            StyledText {
                text: I18n.tr("VRAM") + "  " + Math.round(root.memUsed) + " / " + Math.round(root.memTotal) + " MiB"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
            }

            Rectangle {
                width: parent.width
                height: 10
                radius: 5
                color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                Rectangle {
                    width: parent.width * Math.min((root.memTotal > 0 ? root.memUsed / root.memTotal : 0), 1)
                    height: parent.height
                    radius: parent.radius
                    color: (root.memTotal > 0 && root.memUsed / root.memTotal > 0.9) ? Theme.error : Theme.primary
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM
            visible: root.available

            Repeater {
                model: [
                    {
                        "label": I18n.tr("Power"),
                        "value": Math.round(root.power) + " / " + Math.round(root.powerLimit) + " W"
                    },
                    {
                        "label": I18n.tr("Core"),
                        "value": Math.round(root.coreClock) + " MHz"
                    },
                    {
                        "label": I18n.tr("Memory"),
                        "value": Math.round(root.memClock) + " MHz"
                    }
                ]

                StyledRect {
                    required property var modelData
                    width: (parent.width - Theme.spacingM * 2) / 3
                    height: 56
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        width: parent.width - Theme.spacingS

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: modelData.value
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
