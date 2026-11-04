import QtQuick
import "../Common"
import "../Status"

// A subpage's header: a chevron and the page's title, returning to the page it came from.
Item {
    id: back

    property string title: ""
    signal activated()

    width: row.width + 12
    height: 28
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Back")
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: hit.containsMouse || back.activeFocus ? Theme.track : "transparent"
        border.width: back.activeFocus ? 1 : 0
        border.color: Theme.today
    }

    Row {
        id: row
        x: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        StatusGlyph {
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            icon: "chevron-left"
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: back.title
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 13
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
