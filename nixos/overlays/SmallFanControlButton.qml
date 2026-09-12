import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    property bool available: false
    property int maxRpm: 0

    signal clicked

    width: parent ? ((parent.width - parent.spacing * 3) / 4) : 48
    height: 48
    radius: Theme.cornerRadius + 4
    color: mouseArea.containsMouse ? Theme.primaryPressed : Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    opacity: available ? 1.0 : 0.6

    Row {
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "mode_fan"
            size: Theme.iconSizeSmall
            color: Theme.ccTileInactiveIcon
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.maxRpm > 0 ? (root.maxRpm + "") : "--"
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: Theme.ccTileInactiveIcon
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
}
