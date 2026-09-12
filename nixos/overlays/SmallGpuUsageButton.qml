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
    property real util: 0
    property real temp: 0

    signal clicked

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: Theme.cornerRadius + 4
    color: mouseArea.containsMouse ? Theme.primaryPressed : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    opacity: available ? 1.0 : 0.6

    function applyStatus(text) {
        try {
            const d = JSON.parse(text || "{}");
            available = !!d.available;
            util = d.util || 0;
            temp = d.temp || 0;
        } catch (e) {
            available = false;
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "auto_awesome_mosaic"
            size: Theme.iconSizeSmall
            color: {
                if (root.util > 90 || root.temp > 80)
                    return Theme.error;
                if (root.util > 70 || root.temp > 70)
                    return Theme.warning;
                return Theme.ccTileInactiveIcon;
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                text: I18n.tr("GPU")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                text: root.available ? (Math.round(root.util) + "%") : "--"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: Theme.ccTileInactiveIcon
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.available
        onClicked: root.clicked()
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
}
