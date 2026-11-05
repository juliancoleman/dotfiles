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
    readonly property Item trailSlot: verticalEdge ? vFace.trailSlot : hFace.trailSlot
    readonly property Item leadSlot: verticalEdge ? vFace.leadSlot : hFace.leadSlot
    readonly property Item accessorySlot: verticalEdge ? vFace.accessorySlot : hFace.accessorySlot
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
    readonly property real gridHeight: monthGrid.implicitHeight
    readonly property real maxGridHeight: monthGrid.weekHeight + 6
        + 6 * monthGrid.cell + 5 * monthGrid.gap
    readonly property real calendarHeight: headerH + 6 + gridHeight
    readonly property real maxCalendarHeight: headerH + 6 + maxGridHeight
    readonly property real sideDateGap: 8
    readonly property real columnHeight: vFace.timeHeight + leadSpan + trailSpan
    // The docked date spans the whole notch beside it rather than only the time.
    readonly property real sideDateSpan: trailing > 0 || leading > 0
        ? Math.max(vFace.sideDateBlock, columnHeight) : vFace.sideDateBlock
    readonly property real panelWidth: vFace.sideDateColumn * hoverP * (1 - Math.min(1, expanded))
        + calendarWidth * openP + accessoryWidth * accessoryP
    readonly property real panelHeight: sideDateSpan * hoverP * (1 - Math.min(1, expanded))
        + calendarHeight * openP + accessoryHeight * accessoryP
    // Beside a side notch, hover's date sits a small gap from the time; an open panel takes the shared gutter.
    readonly property real sideGap: sideDateGap * hoverP * (1 - Math.min(1, expanded))
        + Theme.panelPad * Math.min(1, expanded)
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
                                        "July", "August", "September", "October", "November", "December"]
    readonly property var dayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var dayMarks: ["日", "月", "火", "水", "木", "金", "土"]
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    readonly property string monthTitle: localeName === "jp"
        ? viewYear + "年" + (viewMonth + 1) + "月"
        : monthNames[viewMonth] + " " + viewYear

    // The date line and its three-line side form, both following the clock and locale directly.
    readonly property date today: systemClock.date
    readonly property string shortMonth: monthNames[today.getMonth()].slice(0, 3)
    readonly property string dateText: localeName === "jp"
        ? dayMarks[today.getDay()] + "曜日 " + today.getFullYear() + "年" + (today.getMonth() + 1) + "月" + today.getDate() + "日"
        : dayNames[today.getDay()] + " " + shortMonth + " " + today.getDate() + " " + today.getFullYear()
    readonly property string sideWeek: localeName === "jp"
        ? dayMarks[today.getDay()] + "曜" : dayNames[today.getDay()].slice(0, 3)
    readonly property string sideDay: localeName === "jp"
        ? (today.getMonth() + 1) + "月" + today.getDate() + "日" : shortMonth + " " + today.getDate()
    readonly property string sideYear: localeName === "jp" ? today.getFullYear() + "年" : String(today.getFullYear())

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
    readonly property bool housingMoving: gapEase.running || notchEase.running

    readonly property real springRoom: 1.16
    readonly property real reservedWidth: Math.ceil((verticalEdge
        ? (vFace.timeColumn + Theme.panelPad + Math.max(calendarWidth, accessoryWidth)) * openZoom
            + (Theme.padX + 12) * 2 + Theme.floatMargin
        : (Math.max(hFace.digitsWidth + hFace.periodWidth + Theme.periodGap + leadSpan + trailSpan,
                    dateMeasure.implicitWidth, calendarWidth, accessoryWidth) + 8) * openZoom
            + (Theme.padX + 12) * 2) * springRoom)
    readonly property real reservedHeight: Math.ceil((verticalEdge
        ? Math.max(vFace.timeHeight + vFace.periodHeight + leadSpan + trailSpan,
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
        const radius = hovered * (1 - Math.min(1, expanded)) + Theme.radius * Math.min(1, expanded)
        return outer ? radius * (1 - notchAmount) : radius
    }

    function padded(value) {
        return value < 10 ? "0" + value : String(value)
    }

    function aimHover(open) {
        hoverEase.aim((open || calendarOpen || accessoryOpen) ? 1 : 0)
    }

    function closeCalendar() {
        if (!calendarOpen)
            return
        calendarOpen = false
        openEase.aim(0)
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
        openEase.aim(1)
        Qt.callLater(function () { root.forceActiveFocus() })
    }

    // Whether a point (in `from`'s coordinates) lands on the time digits, with a finger's slack around them.
    function onTime(from, x, y) {
        const face = verticalEdge ? vFace.timeItem : hFace.timeItem
        const p = face.mapFromItem(from, x, y)
        const slack = Theme.px(6)
        return p.x >= -slack && p.y >= -slack && p.x <= face.width + slack && p.y <= face.height + slack
    }

    function shiftMonth(delta) {
        const next = new Date(viewYear, viewMonth + delta, 1)
        viewYear = next.getFullYear()
        viewMonth = next.getMonth()
        monthGrid.show(viewYear, viewMonth, true)
    }

    function layoutSlots(slotMotion) {
        const instant = !ready || slotMotion === "snap" || slotMotion === "none"
        const period = !use24Hour && showPeriod
        vFace.layoutSlots(period, slotMotion, instant)
        hFace.layoutSlots(period, slotMotion, instant)
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
        layoutSlots(slotMotion)
    }

    function moveHousing(instant) {
        const nextGap = presentation === "pill" ? Theme.floatMargin : 0
        const nextNotch = presentation === "notch" ? 1 : 0
        if (instant) {
            gapEase.stop()
            notchEase.stop()
            edgeGap = nextGap
            notchAmount = nextNotch
            return
        }
        gapEase.aim(nextGap)
        notchEase.aim(nextNotch)
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
        Qt.callLater(layoutSlots, "snap")
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

    Tween { id: gapEase; target: root; property: "edgeGap"; motion: root.motion }
    Tween { id: notchEase; target: root; property: "notchAmount"; motion: root.motion }
    Tween { id: hoverEase; target: root; property: "hoverProgress"; motion: root.motion }
    Tween { id: openEase; target: root; property: "openProgress"; motion: root.motion }

    Text {
        id: dateMeasure
        visible: false
        text: root.dateText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.dateSize
        font.weight: Theme.clockFontWeight
        font.letterSpacing: 0.2
    }

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
            // With a panel docked in the housing, only the time itself opens the calendar; presses on the
            // panel's gutter would otherwise swap it for the calendar.
            onPressed: mouse => {
                if (root.accessoryOpen && !root.onTime(hover, mouse.x, mouse.y))
                    return
                root.toggleCalendar()
            }
            onReleased: root.aimHover(root.pointerInside)
        }

        VerticalFace { id: vFace; clock: root }
        HorizontalFace { id: hFace; clock: root }
    }

    MonthGrid {
        id: monthGrid
        parent: root.verticalEdge ? vFace.gridSlot : hFace.gridSlot
        localeName: root.localeName
        today: systemClock.date
        motionDuration: Theme.motionDuration
        motionCurve: Theme.easingFor(root.motion)
        motionNone: root.motion === "none"
    }
}
