import QtQuick
import "../Common"

// A calendar header's previous/next month button, widening in as the calendar opens.
Item {
    id: arrow

    required property Item clock
    property int delta: -1
    property real opened: 0

    width: 28 * opened
    height: clock.headerH
    opacity: Math.max(opened, activeFocus ? 1 : 0)
    activeFocusOnTab: opened > 0.85
    Accessible.role: Accessible.Button
    Accessible.name: delta < 0 ? I18n.tr("Previous month") : I18n.tr("Next month")
    Accessible.onPressAction: arrow.activate()

    function activate() {
        clock.shiftMonth(delta)
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 7
        color: arrow.activeFocus ? Qt.rgba(0.72, 0.76, 1, 0.16) : "transparent"
        border.width: arrow.activeFocus ? 1 : 0
        border.color: Theme.today
    }

    Text {
        anchors.centerIn: parent
        text: arrow.delta < 0 ? "‹" : "›"
        color: hit.pressed || arrow.activeFocus ? Theme.today : Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: 16
        font.weight: Font.Medium
    }

    Keys.onReturnPressed: arrow.activate()
    Keys.onEnterPressed: arrow.activate()
    Keys.onSpacePressed: arrow.activate()

    MouseArea {
        id: hit
        anchors.fill: parent
        enabled: arrow.opened > 0.45
        cursorShape: Qt.PointingHandCursor
        onClicked: arrow.activate()
    }
}
