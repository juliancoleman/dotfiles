import QtQuick
import "../Common"
import "../Status"

// A subpage's header: a chevron and the page's title, returning to the page it came from.
Item {
    id: back

    property string title: ""
    signal activated()

    width: row.width + Theme.px(12)
    height: Theme.px(28)
    Accessible.role: Accessible.Button
    Accessible.name: I18n.tr("Back")
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusInput
        color: hit.containsMouse || back.activeFocus ? Theme.track : "transparent"
        border.width: back.activeFocus ? 1 : 0
        border.color: Theme.today
    }

    Row {
        id: row
        x: Theme.panelHeaderInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        StatusGlyph {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(14)
            height: Theme.px(14)
            icon: "chevron-left"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: back.title
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textStrong
            font.weight: Font.Medium
        }
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: back.activated()
    }
}
