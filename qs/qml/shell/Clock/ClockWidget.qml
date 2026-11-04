import QtQuick
import Quickshell
import "../Common"

Item {
    id: root

    property string edge: "right"
    property string localeName: "en"
    property bool use24Hour: true
    // Whether a 12-hour clock shows its AM/PM (午前/午後) mark.
    property bool showPeriod: true
    property string motion: "easeOut"
    property string presentation: "pill"

    readonly property bool verticalEdge: edge === "left" || edge === "right"
    readonly property bool horizontalEdge: !verticalEdge
    readonly property bool dateAboveTime: edge === "bottom"
    readonly property real openZoom: 1.06
    property real hoverProgress: 0
    property real openProgress: 0
    property bool calendarOpen: false
    readonly property bool pointerDown: hover.pressed
    readonly property real hoverP: Math.max(0, hoverProgress)
    readonly property real openP: Math.max(0, openProgress)
    readonly property real reveal: Math.max(hoverP, openP)

    // In the notch, the status circle rides inside the housing after the time (trailSlot), and the
    // control center opens in the calendar's place (accessorySlot), so the whole notch moves as one.
    property real trailing: 0
    // Housing pad past the trailing circle, so both ends of the notch read the same.
    property real trailingPad: 0
    // The notification circle rides before the time the same way (leadSlot).
    property real leading: 0
    property real leadingPad: 0
    property real leadReveal: 1
    // How far a fusing notification circle squares off the end facing it.
    property real leadFuse: 0
    property bool externalHover: false
    property bool accessoryOpen: false
    property real accessoryProgress: 0
    property real accessoryWidth: 0
    property real accessoryHeight: 0
    readonly property Item trailSlot: verticalEdge ? vTrailSlot : hTrailSlot
    readonly property Item leadSlot: verticalEdge ? vLeadSlot : hLeadSlot
    readonly property Item accessorySlot: verticalEdge ? vAccessorySlot : hAccessorySlot
    readonly property real accessoryP: Math.max(0, accessoryProgress)
    // Summed rather than maxed so a swap between the two stays fully expanded throughout.
    readonly property real expanded: Math.max(openP, accessoryP, Math.min(1, openP + accessoryP))
    // Swapping calendar and control center hands over halfway so their contents never overlap.
    readonly property real calendarFade: Math.max(0, 1 - 2 * accessoryP)
    readonly property real accessoryFade: Math.max(0, 1 - 2 * openP)
    readonly property bool pointerInside: hover.containsMouse || externalHover
    readonly property real trailSpan: trailing > 0 ? (verticalEdge ? Theme.padY : Theme.padX + 3) + trailing : 0
    // leading arrives already scaled by how far its circles have appeared; the gap before the time follows them.
    readonly property real leadSpan: leading > 0 ? (verticalEdge ? Theme.padY : Theme.padX + 3) * leadReveal + leading : 0
    readonly property real leadEndPad: (verticalEdge ? Theme.padY : Theme.padX + 3)
        + (leading > 0 ? (leadingPad - (verticalEdge ? Theme.padY : Theme.padX + 3)) * leadReveal : 0)

    // Hover keeps hoverP at 1 while the calendar or an accessory is open, so the zoom holds and the row stays put.
    readonly property real zoom: 1 + hoverP * (openZoom - 1)
    property string dateText: ""
    property string sideWeek: ""
    property string sideDay: ""
    property string sideYear: ""
    property alias housingItem: housing
    readonly property bool periodLeads: localeName === "jp"
    readonly property int digitSize: verticalEdge ? Theme.verticalDigit : Theme.horizontalDigit
    readonly property real notchMix: Math.max(0, Math.min(1, notchAmount))
    readonly property int faceDigit: Math.round(Theme.horizontalDigit + (Theme.notchDigit - Theme.horizontalDigit) * notchMix)
    readonly property int facePeriod: Math.round(Theme.periodSize + (Theme.notchPeriod - Theme.periodSize) * notchMix)
    readonly property int periodSize: verticalEdge ? Theme.periodSize : facePeriod
    readonly property real housingWidth: housing.width
    readonly property real housingHeight: housing.height
    readonly property real restingHousingWidth: vFace.timeColumn
        + Theme.notchOuterPad + Theme.notchInnerPad
    readonly property real restingHousingHeight: hFace.notchLineHeight
        + Theme.notchOuterPad + Theme.notchInnerPad
    // Cross-edge thickness of the closed housing, tracking the pill/notch transition.
    readonly property real restingThickness: (verticalEdge ? vFace.timeColumn : hFace.timeBox)
        + housing.baseOuter + housing.baseInner
    readonly property real headerH: 22
    readonly property real calendarWidth: monthGrid.implicitWidth
    readonly property real maxGridHeight: monthGrid.weekHeight + 6
        + 6 * monthGrid.cell + 5 * monthGrid.gap
    readonly property real calendarHeight: headerH + 6 + monthGrid.implicitHeight
    readonly property real maxCalendarHeight: headerH + 6 + maxGridHeight
    readonly property real sideDateGap: 8
    readonly property real sideDateColumn: Math.max(sideWeekLabel.implicitWidth,
                                                     sideDayLabel.implicitWidth,
                                                     sideYearLabel.implicitWidth)
    readonly property real sideDateBlock: sideWeekLabel.implicitHeight + sideDayLabel.implicitHeight
        + sideYearLabel.implicitHeight + 6
    readonly property real columnHeight: vFace.implicitHeight + leadSpan + trailSpan
    // The docked date spans the whole notch beside it rather than only the time.
    readonly property real sideDateSpan: trailing > 0 || leading > 0 ? Math.max(sideDateBlock, columnHeight) : sideDateBlock
    readonly property real panelWidth: sideDateColumn * hoverP * (1 - Math.min(1, expanded))
        + calendarWidth * openP + accessoryWidth * accessoryP
    readonly property real panelHeight: sideDateSpan * hoverP * (1 - Math.min(1, expanded))
        + calendarHeight * openP + accessoryHeight * accessoryP
    // Beside a side notch, hover's date sits a small gap from the time; an open panel takes the shared gutter.
    readonly property real sideGap: sideDateGap * hoverP * (1 - Math.min(1, expanded))
        + Theme.panelPad * Math.min(1, expanded)
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                        "July", "August", "September", "October", "November", "December"]
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    readonly property string monthTitle: localeName === "jp"
        ? viewYear + "年" + (viewMonth + 1) + "月"
        : monthNames[viewMonth] + " " + viewYear

    property bool ready: false
    property string hourTens: ""
    property string hourOnes: "0"
    property bool hourTensMuted: false
    property string minuteTens: "0"
    property string minuteOnes: "0"
    property string latinMark: "A"
    property string kanaMark: "前"
    property bool animateTicker: false
    property bool animateLatin: false
    property bool animateKana: false
    property real edgeGap: Theme.floatMargin
    property real notchAmount: 0
    property int housingCurve: Easing.OutCubic
    readonly property bool housingMoving: gapEase.running || notchEase.running

    readonly property real springRoom: 1.16
    readonly property real reservedWidth: Math.ceil((verticalEdge
        ? (vFace.timeColumn + Theme.panelPad + Math.max(calendarWidth, accessoryWidth)) * openZoom
            + (Theme.padX + 12) * 2 + Theme.floatMargin
        : (Math.max(hDigits.implicitWidth + Math.max(hJa.implicitWidth, hEn.implicitWidth) + Theme.periodGap
                        + leadSpan + trailSpan,
                    dateMeasure.implicitWidth, calendarWidth, accessoryWidth) + 8) * openZoom
            + (Theme.padX + 12) * 2) * springRoom)
    readonly property real reservedHeight: Math.ceil((verticalEdge
        ? Math.max(vFace.implicitHeight + Math.max(vJa.implicitHeight, vEn.implicitHeight) + leadSpan + trailSpan,
                   maxCalendarHeight, accessoryHeight) * openZoom + (Theme.padY + 10) * 2
        : (Math.max(hFace.glyphHeight, hFace.notchLineHeight) + Math.max(maxCalendarHeight, accessoryHeight) + 12)
            * openZoom + Theme.padY + Theme.floatMargin + 18) * springRoom)
    implicitWidth: reservedWidth
    implicitHeight: reservedHeight
    width: implicitWidth
    height: implicitHeight
    focus: calendarOpen

    // While fusing with the status circle, the end facing it squares off so the two meet flat; once
    // docked the circle supplies the round end itself.
    function corner(outer, facingCircle, facingLead) {
        const base = cornerRadius(outer)
        const trail = facingCircle && trailing === 0 ? 1 - notchMix : 1
        const lead = facingLead && leading === 0 ? 1 - notchMix * Math.max(0, Math.min(1, leadFuse)) : 1
        return base * Math.min(trail, lead)
    }

    function cornerRadius(outer) {
        const capsule = verticalEdge
            ? (vFace.timeColumn + Theme.padX * 2) / 2
            : (Math.max(hFace.glyphHeight, hFace.notchLineHeight) + Theme.padY * 2) / 2
        const hovered = capsule * (verticalEdge ? 1 - Math.min(1, hoverP) * (1 - Math.min(1, expanded)) * 0.45 : 1)
        const radius = hovered * (1 - Math.min(1, expanded)) + 14 * Math.min(1, expanded)
        return outer ? radius * (1 - notchAmount) : radius
    }

    function padded(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function formatDate(value) {
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        if (localeName === "jp") {
            const marks = ["日", "月", "火", "水", "木", "金", "土"]
            const days = ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"]
            sideWeek = marks[value.getDay()] + "曜"
            sideDay = (value.getMonth() + 1) + "月" + value.getDate() + "日"
            sideYear = value.getFullYear() + "年"
            return days[value.getDay()] + " " + value.getFullYear() + "年"
                + (value.getMonth() + 1) + "月" + value.getDate() + "日"
        }
        const shortDays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        sideWeek = shortDays[value.getDay()]
        sideDay = months[value.getMonth()] + " " + value.getDate()
        sideYear = String(value.getFullYear())
        return days[value.getDay()] + " " + months[value.getMonth()] + " "
            + value.getDate() + " " + value.getFullYear()
    }

    function aimHover(open) {
        const next = (open || calendarOpen || accessoryOpen) ? 1 : 0
        if (motion === "none") {
            hoverEase.stop()
            hoverProgress = next
            return
        }
        if (!hoverEase.running && Math.abs(hoverProgress - next) < 0.001)
            return
        hoverEase.stop()
        hoverEase.from = hoverProgress
        hoverEase.to = next
        hoverEase.start()
    }

    function aimOpen(open) {
        const next = open ? 1 : 0
        if (motion === "none") {
            openEase.stop()
            openProgress = next
            return
        }
        if (!openEase.running && Math.abs(openProgress - next) < 0.001)
            return
        openEase.stop()
        openEase.from = openProgress
        openEase.to = next
        openEase.start()
    }

    function closeCalendar() {
        if (!calendarOpen)
            return
        calendarOpen = false
        aimOpen(false)
        aimHover(pointerInside)
    }

    onPointerInsideChanged: if (!hover.pressed) aimHover(pointerInside)
    onAccessoryOpenChanged: aimHover(pointerInside)

    function toggleCalendar() {
        if (calendarOpen) {
            closeCalendar()
            return
        }
        const now = systemClock.date
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
        monthGrid.show(viewYear, viewMonth, false)
        calendarOpen = true
        aimHover(true)
        aimOpen(true)
        Qt.callLater(function () { root.forceActiveFocus() })
    }

    function shiftMonth(delta) {
        const next = new Date(viewYear, viewMonth + delta, 1)
        viewYear = next.getFullYear()
        viewMonth = next.getMonth()
        monthGrid.show(viewYear, viewMonth, true)
    }

    function layoutSlots(slotMotion) {
        const instant = !ready || slotMotion === "snap" || slotMotion === "none"
        const vLead = vJa.implicitHeight + Theme.stackGap
        const hLead = hJa.implicitWidth + Theme.periodGap
        const period = !use24Hour && showPeriod
        vHead.go(period && periodLeads ? vLead : 0, slotMotion, instant)
        vTail.go(period && !periodLeads ? vEn.implicitHeight + Theme.stackGap : 0, slotMotion, instant)
        hHead.go(period && periodLeads ? hLead : 0, slotMotion, instant)
        hTail.go(period && !periodLeads ? hEn.implicitWidth + Theme.periodGap : 0, slotMotion, instant)
    }

    function updateFormattedTime(value, mayAnimate, slotMotion) {
        const hours = value.getHours()
        const minutes = padded(value.getMinutes())
        const shownHour = use24Hour ? hours : (hours % 12 || 12)
        const nextHour = padded(shownHour)
        const nextTens = nextHour.charAt(0)
        const nextOnes = nextHour.charAt(1)
        const nextMinuteTens = minutes.charAt(0)
        const nextMinuteOnes = minutes.charAt(1)
        const nextLatin = hours < 12 ? "A" : "P"
        const nextKana = hours < 12 ? "前" : "後"
        animateTicker = mayAnimate && (hourTens !== nextTens || hourOnes !== nextOnes
            || minuteTens !== nextMinuteTens || minuteOnes !== nextMinuteOnes)
        animateLatin = mayAnimate && latinMark !== nextLatin
        animateKana = mayAnimate && kanaMark !== nextKana
        hourTens = nextTens
        hourOnes = nextOnes
        minuteTens = nextMinuteTens
        minuteOnes = nextMinuteOnes
        latinMark = nextLatin
        kanaMark = nextKana
        hourTensMuted = hourTens === "0"
        dateText = formatDate(value)
        layoutSlots(slotMotion)
    }

    function moveHousing(instant) {
        const nextGap = presentation === "pill" ? Theme.floatMargin : 0
        const nextNotch = presentation === "notch" ? 1 : 0
        if (instant || motion === "none") {
            gapEase.stop()
            notchEase.stop()
            edgeGap = nextGap
            notchAmount = nextNotch
            return
        }
        housingCurve = Theme.easingFor(motion)
        gapEase.stop()
        notchEase.stop()
        gapEase.from = edgeGap
        gapEase.to = nextGap
        notchEase.from = notchAmount
        notchEase.to = nextNotch
        gapEase.start()
        notchEase.start()
    }

    onUse24HourChanged: if (ready) updateFormattedTime(systemClock.date, true, motion)
    onShowPeriodChanged: if (ready) updateFormattedTime(systemClock.date, true, motion)
    onVerticalEdgeChanged: if (ready) updateFormattedTime(systemClock.date, false, motion)
    onEdgeChanged: if (ready && !calendarOpen) {
        hoverEase.stop()
        hoverProgress = 0
    }
    onPeriodLeadsChanged: if (ready) updateFormattedTime(systemClock.date, true, motion)
    onPresentationChanged: if (ready) {
        moveHousing(false)
        Qt.callLater(function () { layoutSlots("snap") })
    }
    Component.onCompleted: {
        moveHousing(true)
        updateFormattedTime(systemClock.date, false, "snap")
        const now = systemClock.date
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
        monthGrid.show(viewYear, viewMonth, false)
        ready = true
    }

    Keys.onEscapePressed: function (event) {
        if (!calendarOpen)
            return
        toggleCalendar()
        event.accepted = true
    }
    Keys.onLeftPressed: function (event) {
        if (!calendarOpen)
            return
        shiftMonth(-1)
        event.accepted = true
    }
    Keys.onRightPressed: function (event) {
        if (!calendarOpen)
            return
        shiftMonth(1)
        event.accepted = true
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    Connections {
        target: systemClock
        function onDateChanged() {
            root.updateFormattedTime(systemClock.date, true, root.motion)
        }
    }

    NumberAnimation {
        id: gapEase
        target: root
        property: "edgeGap"
        duration: Theme.durationFor(root.motion)
        easing.type: root.housingCurve
        easing.overshoot: Theme.springOvershoot
    }

    NumberAnimation {
        id: notchEase
        target: root
        property: "notchAmount"
        duration: Theme.durationFor(root.motion)
        easing.type: root.housingCurve
        easing.overshoot: Theme.springOvershoot
    }

    NumberAnimation {
        id: hoverEase
        target: root
        property: "hoverProgress"
        duration: Theme.durationFor(root.motion)
        easing.type: Theme.easingFor(root.motion)
        easing.overshoot: Theme.springOvershoot
    }

    NumberAnimation {
        id: openEase
        target: root
        property: "openProgress"
        duration: Theme.durationFor(root.motion)
        easing.type: Theme.easingFor(root.motion)
        easing.overshoot: Theme.springOvershoot
    }

    Text {
        id: dateMeasure
        visible: false
        text: root.dateText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.dateSize
        font.weight: Theme.clockFontWeight
        font.letterSpacing: 0.2
    }

    Reveal { id: vHead; visible: false }
    Reveal { id: vTail; visible: false }
    Reveal { id: hHead; visible: false }
    Reveal { id: hTail; visible: false }

    Rectangle {
        id: housing
        width: (root.verticalEdge
                ? (vFace.timeColumn + root.sideGap + root.panelWidth) * root.zoom
                : hFace.implicitWidth) + padLeft + padRight
        height: (root.verticalEdge
                 ? Math.max(root.columnHeight, root.panelHeight) * root.zoom
                 : hFace.implicitHeight) + padTop + padBottom
        x: root.edge === "left" ? root.edgeGap
            : root.edge === "right" ? root.width - width - root.edgeGap
            : (root.width - width) / 2
        y: root.verticalEdge
            ? (root.height - height) / 2
            : root.edge === "top" ? root.edgeGap
            : root.height - height - root.edgeGap
        color: Theme.surface
        border.width: 0
        clip: true
        topLeftRadius: root.corner(root.edge === "top" || root.edge === "left", false, true)
        topRightRadius: root.corner(root.edge === "top" || root.edge === "right", !root.verticalEdge, root.verticalEdge)
        bottomLeftRadius: root.corner(root.edge === "bottom" || root.edge === "left", root.verticalEdge, !root.verticalEdge)
        bottomRightRadius: root.corner(root.edge === "bottom" || root.edge === "right", true, false)

        readonly property real breath: 8 * root.expanded
        readonly property real baseOuter: Theme.notchOuterPad * root.notchAmount + Theme.padX * (1 - root.notchAmount)
        readonly property real baseInner: Theme.notchInnerPad * root.notchAmount + Theme.padX * (1 - root.notchAmount)
        // An open panel in a top or bottom notch, calendar included, gets the shared gutter on its sides and far end.
        readonly property real gutter: root.verticalEdge ? 0 : Math.min(1, root.expanded)
        function toGutter(pad) { return pad * (1 - gutter) + Theme.panelPad * gutter }
        // The row's resting pads; the open housing's breath and gutter surround the panel, not the row.
        readonly property real restLeft: root.leadEndPad
        readonly property real restRight: root.trailing > 0 ? root.trailingPad : Theme.padX + 3
        readonly property real restTop: root.edge === "bottom" ? baseInner : baseOuter
        readonly property real restBottom: root.edge === "top" ? baseInner : baseOuter
        readonly property real padLeft: root.edge === "right" ? baseInner + breath
            : root.edge === "left" ? baseOuter
            : toGutter(restLeft + breath)
        readonly property real padRight: root.edge === "left" ? baseInner + breath
            : root.edge === "right" ? baseOuter
            : toGutter(restRight + breath)
        readonly property real padTop: root.edge === "bottom" ? toGutter(baseInner + breath)
            : root.edge === "top" ? baseOuter
            : root.leadEndPad + breath
        readonly property real padBottom: root.edge === "top" ? toGutter(baseInner + breath)
            : root.edge === "bottom" ? baseOuter
            : (root.trailing > 0 ? root.trailingPad : Theme.padY) + breath

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onPressed: root.toggleCalendar()
            onReleased: root.aimHover(root.pointerInside)
        }

        Item {
            id: vBlock
            visible: root.verticalEdge
            width: vFace.timeColumn + root.sideGap + root.panelWidth
            height: Math.max(root.columnHeight, root.panelHeight)
            scale: root.zoom
            transformOrigin: root.edge === "right" ? Item.Right : Item.Left
            x: root.edge === "right" ? housing.width - housing.padRight - width : housing.padLeft
            y: housing.padTop + (housing.height - housing.padTop - housing.padBottom - height) / 2

            Item {
                id: vFace
                readonly property real timeColumn: Math.max(vHour.implicitWidth, vMinute.implicitWidth,
                                                             vJa.implicitWidth, vEn.implicitWidth)
                clip: true
                implicitWidth: timeColumn
                implicitHeight: vHead.shown + vHour.implicitHeight + vMinute.implicitHeight + vTail.shown
                width: implicitWidth
                height: implicitHeight
                x: root.edge === "right" ? parent.width - width : 0
                y: (parent.height - root.columnHeight) / 2 + root.leadSpan

                Item {
                    width: parent.width
                    height: vHead.shown
                    clip: true

                    JapanesePeriod {
                        id: vJa
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.stackGap
                    }
                }

                Row {
                    id: vHour
                    y: vHead.shown
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0

                    Glyph {
                        compact: true
                        digit: root.hourTens
                        color: root.hourTensMuted ? Theme.textSecondary : Theme.textPrimary
                    }
                    Glyph {
                        compact: true
                        digit: root.hourOnes
                    }
                }

                Row {
                    id: vMinute
                    y: vHour.y + vHour.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 0
                    Glyph { compact: true; digit: root.minuteTens }
                    Glyph { compact: true; digit: root.minuteOnes }
                }

                Item {
                    y: vMinute.y + vMinute.implicitHeight
                    width: parent.width
                    height: vTail.shown
                    clip: true

                    EnglishPeriod {
                        id: vEn
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: Theme.stackGap
                    }
                }
            }

            // Spans the notch's full thickness, from the housing's screen edge to its inner edge.
            Item {
                id: vTrailSlot
                z: 1
                visible: root.verticalEdge && root.trailing > 0
                x: vFace.x - (root.edge === "right" ? housing.baseInner : housing.baseOuter)
                y: vFace.y + vFace.height + Theme.padY
                width: root.restingThickness
                height: root.trailing
            }

            Item {
                id: vLeadSlot
                visible: root.verticalEdge && root.leading > 0
                x: vTrailSlot.x
                y: vFace.y - Theme.padY - height
                width: root.restingThickness
                height: root.leading
            }

            Item {
                id: panel
                width: root.panelWidth
                height: root.panelHeight
                clip: true
                x: root.edge === "right" ? 0 : vFace.width + root.sideGap
                y: (parent.height - height) / 2

                Item {
                    id: vAccessorySlot
                    width: root.accessoryWidth
                    height: root.accessoryHeight
                    x: (parent.width - width) / 2
                    opacity: root.accessoryFade
                    visible: root.accessoryP > 0.001

                    MouseArea { anchors.fill: parent }
                }

                Item {
                    id: sideStack
                    width: root.sideDateColumn
                    height: root.sideDateSpan
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(0, (parent.height - height) * (1 - root.expanded) / 2)
                    opacity: root.hoverP * Math.max(0, 1 - root.expanded)

                    // Lines spread to fill a taller span, but only up to a gap that still reads as one date.
                    readonly property real lines: sideWeekLabel.implicitHeight + sideDayLabel.implicitHeight
                        + sideYearLabel.implicitHeight
                    readonly property real lineGap: Math.min(8, Math.max(3, (height - lines) / 2))
                    readonly property real lineTop: (height - lines - lineGap * 2) / 2

                    function lineY(order, line) {
                        return order === 0 ? lineTop
                            : order === 1 ? (height - line.implicitHeight) / 2
                            : height - lineTop - line.implicitHeight
                    }

                    Text {
                        id: sideWeekLabel
                        width: parent.width
                        y: sideStack.lineY(root.localeName === "jp" ? 2 : 0, this)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.sideWeek
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.dateSize
                        font.weight: Theme.clockFontWeight
                    }
                    Text {
                        id: sideDayLabel
                        width: parent.width
                        y: sideStack.lineY(1, this)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.sideDay
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.dateSize
                        font.weight: Theme.clockFontWeight
                    }
                    Text {
                        id: sideYearLabel
                        width: parent.width
                        y: sideStack.lineY(root.localeName === "jp" ? 0 : 2, this)
                        horizontalAlignment: Text.AlignHCenter
                        text: root.sideYear
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.dateSize
                        font.weight: Theme.clockFontWeight
                    }
                }

                MonthHeader {
                    id: vHeader
                    inlineDate: true
                    opened: root.openP
                    width: parent.width
                    height: root.headerH
                    y: 0
                    z: 2
                    opacity: root.openP * root.calendarFade
                }

                Item {
                    id: vSlot
                    width: monthGrid.implicitWidth
                    height: monthGrid.implicitHeight * root.openP
                    clip: true
                    opacity: root.openP * root.calendarFade
                    x: (parent.width - width) / 2
                    y: root.headerH + 6
                }
            }
        }

        Item {
            id: hFace
            visible: !root.verticalEdge
            readonly property real gridGap: 6 * root.openP
            readonly property real dateReveal: Math.max(root.hoverP * (1 - Math.min(1, root.accessoryP)), root.openP)
            readonly property real headerShown: root.headerH * dateReveal
            readonly property real gridShown: monthGrid.implicitHeight * root.openP
            readonly property real accessoryShown: root.accessoryHeight * root.accessoryP
            readonly property real tail: headerShown + gridGap + gridShown + accessoryShown
            readonly property real dateGap: 6 * root.reveal + 2 * root.expanded
            readonly property real timeSpan: hHead.shown + hDigits.implicitWidth + hTail.shown
            readonly property real rowSpan: root.leadSpan + timeSpan + root.trailSpan
            readonly property real glyphHeight: hDigits.implicitHeight
            readonly property real notchLineHeight: Math.ceil(notchTrack.ascent + notchTrack.descent)
            readonly property real timeBox: glyphHeight
                + Math.max(0, notchLineHeight - glyphHeight) * root.notchAmount
            readonly property real timeLead: (timeBox - glyphHeight) / 2
                + (housing.restBottom - housing.restTop) / 2
            readonly property real headerY: root.dateAboveTime ? 0 : timeLead + glyphHeight + dateGap
            readonly property real gridY: headerShown + gridGap + (root.dateAboveTime ? 0 : timeLead + glyphHeight + dateGap)
            // Content wider than the row centers on the housing rather than the body, so the body grows by
            // the housing's pad skew; the row is nudged back to hold its resting place as the pads change.
            readonly property real padSkew: Math.abs(housing.padRight - housing.padLeft)
            readonly property real bodyWidth: Math.max(rowSpan, (hHeader.implicitWidth + padSkew) * dateReveal,
                                                       (root.accessoryWidth + padSkew) * root.accessoryP)
            readonly property real centerX: (bodyWidth + housing.padRight - housing.padLeft) / 2
            readonly property real bodyHeight: timeBox + dateGap + tail
            readonly property real timeY: (root.dateAboveTime ? tail + dateGap : 0) + timeLead
            readonly property real rowNudge: ((housing.restLeft - housing.restRight)
                                              - (housing.padLeft - housing.padRight)) / 2 / root.zoom
            readonly property real timeShift: (bodyWidth - rowSpan) / 2 + rowNudge
            readonly property real timeX: timeShift + root.leadSpan
            implicitWidth: bodyWidth * root.zoom
            implicitHeight: bodyHeight * root.zoom
            width: implicitWidth
            height: implicitHeight
            x: housing.padLeft + (housing.width - housing.padLeft - housing.padRight - width) / 2
            y: root.dateAboveTime
                ? housing.height - housing.padBottom - height
                : housing.padTop

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
                id: hBody
                width: hFace.bodyWidth
                height: hFace.bodyHeight
                scale: root.zoom
                transformOrigin: root.dateAboveTime ? Item.Bottom : Item.Top
                x: (hFace.width - width) / 2
                y: root.dateAboveTime ? hFace.height - height : 0

                MonthHeader {
                    id: hHeader
                    inlineDate: true
                    opened: root.openP
                    width: implicitWidth
                    height: hFace.headerShown
                    clip: true
                    opacity: hFace.dateReveal * root.calendarFade
                    x: hFace.centerX - width / 2
                    y: hFace.headerY
                }

                Item {
                    id: hAccessorySlot
                    width: root.accessoryWidth
                    height: hFace.accessoryShown
                    clip: true
                    opacity: root.accessoryFade
                    visible: root.accessoryP > 0.001
                    x: hFace.centerX - width / 2
                    y: hFace.gridY

                    MouseArea { anchors.fill: parent }
                }

                Item {
                    id: hTrailSlot
                    visible: root.trailing > 0
                    x: hFace.timeX + hFace.timeSpan + Theme.padX + 3
                    y: hFace.timeY + hFace.glyphHeight / 2 - height / 2
                    width: root.trailing
                    height: root.restingThickness
                }

                Item {
                    id: hLeadSlot
                    visible: root.leading > 0
                    x: hFace.timeShift
                    y: hTrailSlot.y
                    width: root.leading
                    height: root.restingThickness
                }

                Item {
                    id: hSlot
                    width: monthGrid.implicitWidth
                    height: hFace.gridShown
                    clip: true
                    opacity: root.openP * root.calendarFade
                    x: hFace.centerX - width / 2
                    y: hFace.gridY
                }

                Item {
                    x: hFace.timeX
                    y: hFace.timeY
                    width: hHead.shown
                    height: hDigits.implicitHeight
                    clip: true

                    JapanesePeriod {
                        id: hJa
                        fontPixelSize: root.facePeriod
                        // The mark grows with the notch; its slot follows rather than clipping it.
                        onImplicitWidthChanged: if (root.ready) root.layoutSlots("snap")
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.periodGap
                        y: hOnes.baselineOffset - baselineOffset
                    }
                }

                Row {
                    id: hDigits
                    x: hFace.timeX + hHead.shown
                    y: hFace.timeY
                    spacing: 0
                    Glyph {
                        id: hTens
                        digit: root.hourTens
                        color: root.hourTensMuted ? Theme.textSecondary : Theme.textPrimary
                    }
                    Glyph { id: hOnes; digit: root.hourOnes }
                    Text {
                        text: ":"
                        width: implicitWidth
                        height: hOnes.implicitHeight
                        color: Theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.latinFontFamily
                        font.pixelSize: root.faceDigit
                        font.weight: Theme.clockFontWeight
                        font.kerning: false
                    }
                    Glyph { digit: root.minuteTens }
                    Glyph { digit: root.minuteOnes }
                }

                Item {
                    x: hFace.timeX + hHead.shown + hDigits.implicitWidth
                    y: hFace.timeY
                    width: hTail.shown
                    height: hDigits.implicitHeight
                    clip: true

                    EnglishPeriod {
                        id: hEn
                        fontPixelSize: root.facePeriod
                        onImplicitWidthChanged: if (root.ready) root.layoutSlots("snap")
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.periodGap
                        y: hOnes.baselineOffset - baselineOffset
                    }
                }
            }
        }
    }

    MonthGrid {
        id: monthGrid
        parent: root.verticalEdge ? vSlot : hSlot
        localeName: root.localeName
        today: systemClock.date
        motionDuration: Theme.motionDuration
        motionCurve: Theme.easingFor(root.motion)
        motionNone: root.motion === "none"
    }

    component MonthArrow: Item {
        id: arrow

        property int delta: -1
        property real opened: 0

        width: 28 * opened
        height: root.headerH
        opacity: Math.max(opened, activeFocus ? 1 : 0)
        activeFocusOnTab: opened > 0.85
        Accessible.role: Accessible.Button
        Accessible.name: delta < 0 ? I18n.tr("Previous month") : I18n.tr("Next month")
        Accessible.onPressAction: root.shiftMonth(delta)

        function activate() {
            root.shiftMonth(delta)
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

    component MonthHeader: Item {
        id: header

        property real opened: 0
        property bool inlineDate: true

        implicitWidth: inlineDate
            ? dateLine.implicitWidth * (1 - opened) + Math.max(dateLine.implicitWidth, monthGrid.implicitWidth) * opened
            : monthGrid.implicitWidth
        implicitHeight: root.headerH

        MonthArrow {
            id: prevArrow
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
                text: root.dateText
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.dateSize
                font.weight: Theme.clockFontWeight
                font.letterSpacing: 0.2
            }

            Text {
                anchors.centerIn: parent
                opacity: header.opened
                text: root.monthTitle
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        MonthArrow {
            id: nextArrow
            delta: 1
            opened: header.opened
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            KeyNavigation.backtab: prevArrow
        }
    }

    component Glyph: DigitTicker {
        property bool compact: false
        motion: root.motion
        animateChange: root.animateTicker
        fontPixelSize: compact ? Theme.verticalDigit : root.faceDigit
        fontFamily: Theme.latinFontFamily
        color: Theme.textPrimary
    }

    component EnglishPeriod: Item {
        property real fontPixelSize: Theme.periodSize
        readonly property real shift: Math.max(0, em.baselineOffset - mark.baselineOffset)
        implicitWidth: em.x + em.implicitWidth
        implicitHeight: Math.max(mark.y + mark.implicitHeight, em.y + em.implicitHeight)
        baselineOffset: mark.y + mark.baselineOffset

        DigitTicker {
            id: mark
            y: shift
            digit: root.latinMark
            samples: ["A", "P"]
            motion: root.motion
            animateChange: root.animateLatin
            fontPixelSize: parent.fontPixelSize
            fontFamily: Theme.latinFontFamily
            color: Theme.textSecondary
        }
        Text {
            id: em
            x: mark.implicitWidth
            y: mark.y + mark.baselineOffset - baselineOffset
            text: "M"
            color: Theme.textSecondary
            font.family: Theme.latinFontFamily
            font.pixelSize: parent.fontPixelSize
            font.weight: Theme.clockFontWeight
            font.letterSpacing: 0.3
        }
    }

    component JapanesePeriod: Item {
        property real fontPixelSize: Theme.periodSize
        readonly property real shift: Math.max(0, mark.baselineOffset - noon.baselineOffset)
        implicitWidth: mark.x + mark.implicitWidth
        implicitHeight: Math.max(noon.y + noon.implicitHeight, mark.y + mark.implicitHeight)
        baselineOffset: noon.y + noon.baselineOffset

        Text {
            id: noon
            y: shift
            text: "午"
            color: Theme.textSecondary
            font.family: Theme.jaFontFamily
            font.pixelSize: parent.fontPixelSize
            font.weight: Theme.clockFontWeight
        }
        DigitTicker {
            id: mark
            x: noon.implicitWidth
            y: noon.y + noon.baselineOffset - baselineOffset
            digit: root.kanaMark
            samples: ["前", "後"]
            motion: root.motion
            animateChange: root.animateKana
            fontPixelSize: parent.fontPixelSize
            fontFamily: Theme.jaFontFamily
            color: Theme.textSecondary
        }
    }

    component Reveal: Item {
        id: reveal
        property bool across: false
        property real cross: 0
        property real span: 0
        readonly property real shown: Math.max(0, span)
        property real target: 0
        implicitWidth: across ? span : childrenRect.width
        implicitHeight: across ? cross : span
        width: implicitWidth
        height: implicitHeight
        clip: true

        property int curve: Easing.OutCubic

        function go(next, slotMotion, instant) {
            if (instant || Math.abs(next - target) < 0.4 && Math.abs(next - span) < 0.4) {
                ease.stop()
                target = next
                span = next
                return
            }
            target = next
            ease.stop()
            curve = Theme.easingFor(slotMotion)
            ease.from = span
            ease.to = next
            ease.start()
        }

        NumberAnimation {
            id: ease
            target: reveal
            property: "span"
            duration: Theme.motionDuration
            easing.type: reveal.curve
            easing.overshoot: Theme.springOvershoot
        }
    }
}
