import QtQuick
import "../Common"
import "../Status"

// A subpage's header: a chevron and the page's title, returning to the page it came from. Hover lifts a box
// behind both.
Item {
    id: back

    property string title: ""
    property string motion: "spring"
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
        color: hit.pressed ? Theme.press : hit.containsMouse ? Theme.lift : Theme.clear
        border.width: back.activeFocus ? Theme.line : 0
        border.color: Theme.today

        Behavior on color {
            Settle {
                motion: back.motion
                factor: Theme.hoverFade
            }
        }
    }

    Row {
        id: row
        x: Theme.panelHeaderInset
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.px(4)

        StatusGlyph {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(14)
            height: width
            icon: "chevron-left"
        }

        PanelTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: back.title
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
