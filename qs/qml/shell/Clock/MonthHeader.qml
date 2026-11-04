import QtQuick
import "../Common"

// The date line that becomes the calendar's month title and arrows as the calendar opens.
Item {
    id: header

    required property Item clock
    property real opened: 0
    property bool inlineDate: true

    implicitWidth: inlineDate
        ? dateLine.implicitWidth * (1 - opened) + Math.max(dateLine.implicitWidth, clock.calendarWidth) * opened
        : clock.calendarWidth
    implicitHeight: clock.headerH

    MonthArrow {
        id: prevArrow
        clock: header.clock
        delta: -1
        opened: header.opened
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        KeyNavigation.tab: nextArrow
    }

    Item {
        anchors.centerIn: parent
        width: Math.max(0, header.width - 56 * header.opened)
        height: header.height

        Text {
            id: dateLine
            anchors.centerIn: parent
            opacity: header.inlineDate ? 1 - header.opened : 0
            text: header.clock.dateText
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.dateSize
            font.weight: Theme.clockFontWeight
            font.letterSpacing: 0.2
        }

        Text {
            anchors.centerIn: parent
            opacity: header.opened
            text: header.clock.monthTitle
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }
    }

    MonthArrow {
        id: nextArrow
        clock: header.clock
        delta: 1
        opened: header.opened
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        KeyNavigation.backtab: prevArrow
    }
}
