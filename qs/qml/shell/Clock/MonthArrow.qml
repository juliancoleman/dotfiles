import QtQuick
import "../Common"

// A calendar header's previous/next month button, widening in as the calendar opens: a guillemet in a
// hover box.
Item {
    id: arrow

    required property Item clock
    property int delta: -1
    property real opened: 0

    width: Theme.px(28) * opened
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
        anchors.centerIn: parent
        width: parent.width - 2
        height: parent.height - 2
        radius: Theme.radiusInput
        color: hit.pressed ? Theme.press : hit.containsMouse ? Theme.lift : Theme.clear
        border.width: arrow.activeFocus ? Theme.line : 0
        border.color: Theme.today
    }

    Text {
        anchors.centerIn: parent
        text: arrow.delta < 0 ? "‹" : "›"
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textTitle
        font.weight: Font.Medium
    }

    Keys.onReturnPressed: arrow.activate()
    Keys.onEnterPressed: arrow.activate()
    Keys.onSpacePressed: arrow.activate()

    MouseArea {
        id: hit
        anchors.fill: parent
        enabled: arrow.opened > 0.45
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: arrow.activate()
    }
}
