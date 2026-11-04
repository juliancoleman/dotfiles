import QtQuick
import "../Common"

// A top or bottom bar's face: the time in one row, with the date line, calendar, or accessory panel
// unfolding beneath it (above it on the bottom edge).
Item {
    id: face

    required property Item clock
    readonly property Item housing: clock.housingItem
    readonly property real gridGap: 6 * clock.openP
    readonly property real dateReveal: Math.max(clock.hoverP * (1 - Math.min(1, clock.accessoryP)), clock.openP)
    readonly property real headerShown: clock.headerH * dateReveal
    readonly property real gridShown: clock.gridHeight * clock.openP
    readonly property real accessoryShown: clock.accessoryHeight * clock.accessoryP
    readonly property real tail: headerShown + gridGap + gridShown + accessoryShown
    readonly property real dateGap: 6 * clock.reveal + 2 * clock.expanded
    readonly property real digitsWidth: digits.implicitWidth
    readonly property real periodWidth: Math.max(ja.implicitWidth, en.implicitWidth)
    readonly property real timeSpan: headSlot.shown + digitsWidth + tailSlot.shown
    readonly property real rowSpan: clock.leadSpan + timeSpan + clock.trailSpan
    readonly property real glyphHeight: digits.implicitHeight
    readonly property real notchLineHeight: Math.ceil(notchTrack.ascent + notchTrack.descent)
    readonly property real timeBox: glyphHeight
        + Math.max(0, notchLineHeight - glyphHeight) * clock.notchAmount
    readonly property real timeLead: (timeBox - glyphHeight) / 2
        + (housing.restBottom - housing.restTop) / 2
    readonly property real headerY: clock.dateAboveTime ? 0 : timeLead + glyphHeight + dateGap
    readonly property real gridY: headerShown + gridGap + (clock.dateAboveTime ? 0 : timeLead + glyphHeight + dateGap)
    // Content wider than the row centers on the housing rather than the body, so the body grows by
    // the housing's pad skew; the row is nudged back to hold its resting place as the pads change.
    readonly property real padSkew: Math.abs(housing.padRight - housing.padLeft)
    readonly property real bodyWidth: Math.max(rowSpan, (header.implicitWidth + padSkew) * dateReveal,
                                               (clock.accessoryWidth + padSkew) * clock.accessoryP)
    readonly property real centerX: (bodyWidth + housing.padRight - housing.padLeft) / 2
    readonly property real bodyHeight: timeBox + dateGap + tail
    readonly property real timeY: (clock.dateAboveTime ? tail + dateGap : 0) + timeLead
    readonly property real rowNudge: ((housing.restLeft - housing.restRight)
                                      - (housing.padLeft - housing.padRight)) / 2 / clock.zoom
    readonly property real timeShift: (bodyWidth - rowSpan) / 2 + rowNudge
    readonly property real timeX: timeShift + clock.leadSpan
    readonly property Item trailSlot: trailSlotItem
    readonly property Item leadSlot: leadSlotItem
    readonly property Item accessorySlot: accessorySlotItem
    readonly property Item gridSlot: gridSlotItem
    // The digits themselves, so the housing can tell a press on the time from one on panel gutter.
    readonly property Item timeItem: digits

    visible: !clock.verticalEdge
    implicitWidth: bodyWidth * clock.zoom
    implicitHeight: bodyHeight * clock.zoom
    width: implicitWidth
    height: implicitHeight
    x: housing.padLeft + (housing.width - housing.padLeft - housing.padRight - width) / 2
    y: clock.dateAboveTime
        ? housing.height - housing.padBottom - height
        : housing.padTop

    function layoutSlots(period, slotMotion, instant) {
        headSlot.go(period && clock.periodLeads ? ja.implicitWidth + Theme.periodGap : 0, slotMotion, instant)
        tailSlot.go(period && !clock.periodLeads ? en.implicitWidth + Theme.periodGap : 0, slotMotion, instant)
    }

    // The mark grows with the notch; its slot follows rather than clipping it. Both marks resize in the
    // same frame, so the relayout is deferred and runs once per frame instead of once per mark.
    function followMark() {
        if (clock.ready)
            Qt.callLater(clock.layoutSlots, "snap")
    }

    Reveal { id: headSlot; visible: false }
    Reveal { id: tailSlot; visible: false }

    // The face's digits stay on the Latin face in every locale, so the JP face's taller line
    // can't resize the housing.
    FontMetrics {
        id: notchTrack
        font.family: Theme.latinFontFamily
        font.pixelSize: Theme.notchLine
        font.weight: Theme.clockFontWeight
        font.kerning: false
    }

    Item {
        id: body
        width: face.bodyWidth
        height: face.bodyHeight
        scale: face.clock.zoom
        transformOrigin: face.clock.dateAboveTime ? Item.Bottom : Item.Top
        x: (face.width - width) / 2
        y: face.clock.dateAboveTime ? face.height - height : 0

        MonthHeader {
            id: header
            clock: face.clock
            inlineDate: true
            opened: face.clock.openP
            width: implicitWidth
            height: face.headerShown
            clip: true
            opacity: face.dateReveal * face.clock.calendarFade
            x: face.centerX - width / 2
            y: face.headerY
        }

        Item {
            id: accessorySlotItem
            width: face.clock.accessoryWidth
            height: face.accessoryShown
            clip: true
            opacity: face.clock.accessoryFade
            visible: face.clock.accessoryP > 0.001
            x: face.centerX - width / 2
            y: face.gridY

            MouseArea { anchors.fill: parent }
        }

        Item {
            id: trailSlotItem
            visible: face.clock.trailing > 0
            x: face.timeX + face.timeSpan + Theme.padX + 3
            y: face.timeY + face.glyphHeight / 2 - height / 2
            width: face.clock.trailing
            height: face.clock.restingThickness
        }

        Item {
            id: leadSlotItem
            visible: face.clock.leading > 0
            x: face.timeShift
            y: trailSlotItem.y
            width: face.clock.leading
            height: face.clock.restingThickness
        }

        Item {
            id: gridSlotItem
            width: face.clock.calendarWidth
            height: face.gridShown
            clip: true
            opacity: face.clock.openP * face.clock.calendarFade
            x: face.centerX - width / 2
            y: face.gridY
        }

        Item {
            x: face.timeX
            y: face.timeY
            width: headSlot.shown
            height: digits.implicitHeight
            clip: true

            Period {
                id: ja
                clock: face.clock
                kana: true
                fontPixelSize: face.clock.facePeriod
                onImplicitWidthChanged: face.followMark()
                anchors.right: parent.right
                anchors.rightMargin: Theme.periodGap
                y: ones.baselineOffset - baselineOffset
            }
        }

        Row {
            id: digits
            x: face.timeX + headSlot.shown
            y: face.timeY
            spacing: 0
            Glyph {
                clock: face.clock
                digit: face.clock.hourTens
                color: face.clock.hourTensMuted ? Theme.textSecondary : Theme.textPrimary
            }
            Glyph { id: ones; clock: face.clock; digit: face.clock.hourOnes }
            Text {
                text: ":"
                width: implicitWidth
                height: ones.implicitHeight
                color: Theme.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.latinFontFamily
                font.pixelSize: face.clock.faceDigit
                font.weight: Theme.clockFontWeight
                font.kerning: false
            }
            Glyph { clock: face.clock; digit: face.clock.minuteTens }
            Glyph { clock: face.clock; digit: face.clock.minuteOnes }
        }

        Item {
            x: face.timeX + headSlot.shown + digits.implicitWidth
            y: face.timeY
            width: tailSlot.shown
            height: digits.implicitHeight
            clip: true

            Period {
                id: en
                clock: face.clock
                fontPixelSize: face.clock.facePeriod
                onImplicitWidthChanged: face.followMark()
                anchors.left: parent.left
                anchors.leftMargin: Theme.periodGap
                y: ones.baselineOffset - baselineOffset
            }
        }
    }
}
