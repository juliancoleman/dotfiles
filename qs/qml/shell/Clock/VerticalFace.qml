import QtQuick
import "../Common"

// A side bar's face: hour stacked over minute with the AM/PM mark above or below, and beside it the
// hover date, the calendar, or an accessory panel.
Item {
    id: face

    required property Item clock
    readonly property Item housing: clock.housingItem
    readonly property real timeColumn: Math.max(hour.implicitWidth, minute.implicitWidth,
                                                ja.implicitWidth, en.implicitWidth)
    readonly property real timeHeight: time.implicitHeight
    readonly property real periodHeight: Math.max(ja.implicitHeight, en.implicitHeight)
    readonly property real sideDateColumn: Math.max(weekLabel.implicitWidth, dayLabel.implicitWidth,
                                                    yearLabel.implicitWidth)
    readonly property real sideDateBlock: weekLabel.implicitHeight + dayLabel.implicitHeight
        + yearLabel.implicitHeight + 6
    readonly property Item trailSlot: trailSlotItem
    readonly property Item leadSlot: leadSlotItem
    readonly property Item accessorySlot: accessorySlotItem
    readonly property Item gridSlot: gridSlotItem
    readonly property Item timeItem: time

    visible: clock.verticalEdge
    width: timeColumn + clock.sideGap + clock.panelWidth
    height: Math.max(clock.columnHeight, clock.panelHeight)
    scale: clock.zoom
    transformOrigin: clock.edge === "right" ? Item.Right : Item.Left
    x: clock.edge === "right" ? housing.width - housing.padRight - width : housing.padLeft
    y: housing.padTop + (housing.height - housing.padTop - housing.padBottom - height) / 2

    function layoutSlots(period, slotMotion, instant) {
        head.go(period && clock.periodLeads ? ja.implicitHeight + Theme.stackGap : 0, slotMotion, instant)
        tail.go(period && !clock.periodLeads ? en.implicitHeight + Theme.stackGap : 0, slotMotion, instant)
    }

    Reveal { id: head; visible: false }
    Reveal { id: tail; visible: false }

    Item {
        id: time
        clip: true
        implicitWidth: face.timeColumn
        implicitHeight: head.shown + hour.implicitHeight + minute.implicitHeight + tail.shown
        width: implicitWidth
        height: implicitHeight
        x: face.clock.edge === "right" ? parent.width - width : 0
        y: (parent.height - face.clock.columnHeight) / 2 + face.clock.leadSpan

        Item {
            width: parent.width
            height: head.shown
            clip: true

            Period {
                id: ja
                clock: face.clock
                kana: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.stackGap
            }
        }

        Row {
            id: hour
            y: head.shown
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Glyph {
                clock: face.clock
                compact: true
                digit: face.clock.hourTens
                color: face.clock.hourTensMuted ? Theme.textSecondary : Theme.textPrimary
            }
            Glyph {
                clock: face.clock
                compact: true
                digit: face.clock.hourOnes
            }
        }

        Row {
            id: minute
            y: hour.y + hour.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            Glyph { clock: face.clock; compact: true; digit: face.clock.minuteTens }
            Glyph { clock: face.clock; compact: true; digit: face.clock.minuteOnes }
        }

        Item {
            y: minute.y + minute.implicitHeight
            width: parent.width
            height: tail.shown
            clip: true

            Period {
                id: en
                clock: face.clock
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.stackGap
            }
        }
    }

    // Spans the notch's full thickness, from the housing's screen edge to its inner edge.
    Item {
        id: trailSlotItem
        z: 1
        visible: face.clock.verticalEdge && face.clock.trailing > 0
        x: time.x - (face.clock.edge === "right" ? face.housing.baseInner : face.housing.baseOuter)
        y: time.y + time.height + Theme.padY
        width: face.clock.restingThickness
        height: face.clock.trailing
    }

    Item {
        id: leadSlotItem
        visible: face.clock.verticalEdge && face.clock.leading > 0
        x: trailSlotItem.x
        y: time.y - Theme.padY - height
        width: face.clock.restingThickness
        height: face.clock.leading
    }

    Item {
        id: panel
        width: face.clock.panelWidth
        height: face.clock.panelHeight
        clip: true
        x: face.clock.edge === "right" ? 0 : time.width + face.clock.sideGap
        y: (parent.height - height) / 2

        Item {
            id: accessorySlotItem
            width: face.clock.accessoryWidth
            height: face.clock.accessoryHeight
            x: (parent.width - width) / 2
            opacity: face.clock.accessoryFade
            visible: face.clock.accessoryP > 0.001

            MouseArea { anchors.fill: parent }
        }

        Item {
            id: sideStack
            width: face.sideDateColumn
            height: face.clock.sideDateSpan
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(0, (parent.height - height) * (1 - face.clock.expanded) / 2)
            opacity: face.clock.hoverP * Math.max(0, 1 - face.clock.expanded)

            // Lines spread to fill a taller span, but only up to a gap that still reads as one date.
            readonly property real lines: weekLabel.implicitHeight + dayLabel.implicitHeight
                + yearLabel.implicitHeight
            readonly property real lineGap: Math.min(8, Math.max(3, (height - lines) / 2))
            readonly property real lineTop: (height - lines - lineGap * 2) / 2

            function lineY(order, line) {
                return order === 0 ? lineTop
                    : order === 1 ? (height - line.implicitHeight) / 2
                    : height - lineTop - line.implicitHeight
            }

            Text {
                id: weekLabel
                width: parent.width
                y: sideStack.lineY(face.clock.localeName === "jp" ? 2 : 0, this)
                horizontalAlignment: Text.AlignHCenter
                text: face.clock.sideWeek
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.dateSize
                font.weight: Theme.clockFontWeight
            }
            Text {
                id: dayLabel
                width: parent.width
                y: sideStack.lineY(1, this)
                horizontalAlignment: Text.AlignHCenter
                text: face.clock.sideDay
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.dateSize
                font.weight: Theme.clockFontWeight
            }
            Text {
                id: yearLabel
                width: parent.width
                y: sideStack.lineY(face.clock.localeName === "jp" ? 0 : 2, this)
                horizontalAlignment: Text.AlignHCenter
                text: face.clock.sideYear
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.dateSize
                font.weight: Theme.clockFontWeight
            }
        }

        MonthHeader {
            clock: face.clock
            inlineDate: true
            opened: face.clock.openP
            width: parent.width
            height: face.clock.headerH
            y: 0
            z: 2
            opacity: face.clock.openP * face.clock.calendarFade
        }

        Item {
            id: gridSlotItem
            width: face.clock.calendarWidth
            height: face.clock.gridHeight * face.clock.openP
            clip: true
            opacity: face.clock.openP * face.clock.calendarFade
            x: (parent.width - width) / 2
            y: face.clock.headerH + 6
        }
    }
}
