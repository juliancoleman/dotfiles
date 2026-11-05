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
        id: titleBox
        anchors.centerIn: parent
        width: Math.max(0, header.width - 2 * Theme.px(28) * header.opened)
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
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - width) / 2
            opacity: header.opened
            text: header.clock.monthTitle
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
            font.weight: Theme.fontWeightStrong
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

    // The page rule the month title is set above.
    Rule {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        opacity: header.opened
        visible: opacity > 0
    }
}
