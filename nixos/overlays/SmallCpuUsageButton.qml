import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property real usage: DgopService.cpuUsage || 0
    property bool enabled: DgopService.dgopAvailable

    signal clicked

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: Theme.cornerRadius + 4

    function hoverTint(base) {
        const factor = 1.2;
        return Theme.isLightMode ? Qt.darker(base, factor) : Qt.lighter(base, factor);
    }

    readonly property color _tileBg: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)

    color: mouseArea.containsMouse ? Theme.primaryPressed : _tileBg
    border.color: "transparent"
    border.width: 0
    antialiasing: true
    opacity: enabled ? 1.0 : 0.6

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: hoverTint(root.color)
        opacity: mouseArea.pressed ? 0.3 : (mouseArea.containsMouse ? 0.2 : 0.0)
        visible: opacity > 0
        antialiasing: true
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "memory"
            size: Theme.iconSizeSmall
            color: {
                if (root.usage > 80)
                    return Theme.error;
                if (root.usage > 60)
                    return Theme.warning;
                return Theme.ccTileInactiveIcon;
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                text: I18n.tr("CPU")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }

            StyledText {
                text: root.usage > 0 ? `${root.usage.toFixed(0)}%` : "--"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: {
                    if (root.usage > 80)
                        return Theme.error;
                    if (root.usage > 60)
                        return Theme.warning;
                    return Theme.ccTileInactiveIcon;
                }
            }
        }
    }

    DankRipple {
        id: ripple
        cornerRadius: root.radius
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: root.clicked()
    }

    Component.onCompleted: {
        DgopService.addRef(["cpu"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu"]);
    }
}
