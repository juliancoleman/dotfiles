import QtQuick
import "."
import "../Clock"
import "../Common"

Item {
    id: root

    property string motion: "easeOut"
    // "always" or "low": whether the battery percentage sits in the arc at every level or only at 20% and below.
    property string batteryPercentage: "low"
    property int controlDwell: 1500
    property int temporaryDwell: 1600
    readonly property real lowThreshold: 20

    // Temporary icon priorities, highest first. Network shows when no temporary icon holds the slot.
    readonly property int bluetoothPriority: 4
    readonly property int powerPriority: 3
    readonly property int controlPriority: 2
    readonly property int mediaPriority: 1

    // The arc owner: "", "volume", "microphone", or "brightness". Empty means the arc shows battery.
    // Controls own the arc for their whole activity, even while a higher-priority icon holds the slot.
    property string control: ""

    property string slotKind: ""
    property int slotPriority: -1
    property string slotIcon: ""
    property string slotDirection: "neutral"

    readonly property int batteryPercent: Math.round(battery.percentage * 100)
    readonly property bool batteryLow: battery.available && batteryPercent <= lowThreshold
    readonly property real arcValue: control === "volume" ? (output.muted ? 0 : output.level)
        : control === "microphone" ? (input.muted ? 0 : input.level)
        : control === "brightness" ? Brightness.level
        : battery.available ? battery.percentage : 0
    // Set while something nearby already shows the battery percentage.
    property bool labelSuppressed: false
    readonly property bool labelShown: !closeAction && control === "" && battery.available && !labelSuppressed
        && (batteryPercentage === "always" || batteryLow)
    readonly property color arcColor: control !== "" ? Theme.textPrimary
        : battery.charging ? Theme.charging
        : batteryLow ? Theme.danger
        : Theme.textPrimary

    // Opening the panel replaces the full status indicator with a centered close action.
    property bool closeAction: false
    readonly property string icon: slotIcon !== "" ? slotIcon : network.icon

    property string shownIcon: ""
    property bool _ready: false

    readonly property int motionDuration: Theme.durationFor(motion)
    readonly property int motionCurve: Theme.easingFor(motion)

    property real shownValue: arcValue
    property real shownGap: labelShown ? 1 : 0
    property color shownColor: arcColor

    Behavior on shownValue {
        NumberAnimation {
            duration: root.motionDuration
            easing.type: root.motionCurve
            easing.overshoot: Theme.springOvershoot
        }
    }
    Behavior on shownGap {
        NumberAnimation {
            duration: root.motionDuration
            easing.type: root.motionCurve
            easing.overshoot: Theme.springOvershoot
        }
    }
    Behavior on shownColor {
        ColorAnimation {
            duration: root.motionDuration
        }
    }

    readonly property alias battery: battery
    readonly property alias network: network
    readonly property alias output: output
    readonly property alias input: input

    property real diameter: 34
    property string edge: "right"
    // false when a parent (the control center) draws the housing behind the circle.
    property bool housed: true
    // 0 floats as a circle; 1 squares the screen-edge corners so the circle reads as part of the notch.
    property real attach: 0
    readonly property real attached: Math.max(0, Math.min(1, attach))
    readonly property bool alongY: edge === "left" || edge === "right"
    // Clearance between the arc's outer stroke edge and the circle housing it.
    readonly property real room: Math.max(2, Math.round(diameter * 0.1)) + attached
    readonly property real stroke: Math.max(0.75, diameter * 0.07 - 1) + attached
    // A notch is too narrow to fit the percentage inside the ring, so it moves past the circle along the edge.
    readonly property real iconPad: (Math.max(2, diameter * 0.09) + 2) * (1 - attached) + 3 * attached
    readonly property real iconSize: diameter - 2 * (room + stroke + iconPad)
    // Outside the ring, the percentage matches the clock's meridiem; 0 keeps the ring-sized label.
    property int tailLabelSize: 0
    readonly property int ringLabelSize: Math.max(7, Math.round(diameter * 0.26))
    readonly property int labelSize: Math.round(ringLabelSize
        + ((tailLabelSize > 0 ? tailLabelSize : ringLabelSize) - ringLabelSize) * attached)
    readonly property real tailLength: alongY ? label.implicitHeight : label.implicitWidth + room
    readonly property real tail: tailLength * attached * Math.max(0, Math.min(1, shownGap))
    // Space this indicator leaves past its far end: the ring's inset, or what's left below the label.
    readonly property real endRoom: alongY ? room * (1 - 0.5 * Math.min(1, tail / Math.max(1, tailLength))) : room

    implicitWidth: diameter + (alongY ? 0 : tail)
    implicitHeight: diameter + (alongY ? tail : 0)
    width: implicitWidth
    height: implicitHeight

    // Higher priority preempts, lower priority is dropped, and the same priority replaces and resets the dwell.
    function offer(kind, priority, nextIcon, direction, dwell) {
        if (slotPriority > priority)
            return
        const same = nextIcon === slotIcon
        slotKind = kind
        slotPriority = priority
        slotDirection = direction
        slotIcon = nextIcon
        slotTimer.interval = dwell
        slotTimer.restart()
        if (same && direction !== "neutral")
            present(nextIcon, direction)
    }

    function clearSlot(kind) {
        if (slotKind !== kind)
            return
        slotTimer.stop()
        slotKind = ""
        slotPriority = -1
        slotDirection = "neutral"
        slotIcon = ""
    }

    function controlIcon(kind) {
        switch (kind) {
        case "volume":
            return output.muted || output.level <= 0.005 ? "volume-muted" : "volume"
        case "microphone":
            return input.muted || input.level <= 0.005 ? "microphone-muted" : "microphone"
        default:
            return "brightness"
        }
    }

    function showControl(kind) {
        control = kind
        controlTimer.restart()
        offer("control", controlPriority, controlIcon(kind), "neutral", controlDwell)
    }

    function present(nextIcon, direction) {
        swap.stop()
        outgoing.icon = shownIcon
        outgoing.wifiBars = network.bars
        outgoing.level = output.level
        shownIcon = nextIcon
        const travel = iconSize * 0.9
        slide.from = direction === "next" ? travel : direction === "previous" ? -travel : 0
        slide.to = -slide.from
        slide.pop = direction === "neutral" ? 0.6 : 1
        swap.restart()
    }

    onIconChanged: {
        if (_ready && icon !== shownIcon)
            present(icon, slotDirection)
    }

    Component.onCompleted: {
        shownIcon = icon
        _ready = true
    }

    BatterySource {
        id: battery
        onPowerConnected: root.offer("power", root.powerPriority, "power", "neutral", root.temporaryDwell)
        onPowerDisconnected: root.clearSlot("power")
    }

    NetworkSource { id: network }

    AudioSource {
        id: output
        onAdjusted: root.showControl("volume")
    }

    AudioSource {
        id: input
        input: true
        onAdjusted: root.showControl("microphone")
    }

    Connections {
        target: Brightness
        function onAdjusted() {
            root.showControl("brightness")
        }
    }

    Connections {
        target: Media
        function onMediaEvent(resultingPlaying, direction) {
            root.offer("media", root.mediaPriority, resultingPlaying ? "play" : "pause", direction,
                       root.temporaryDwell)
        }
    }

    BluetoothSource {
        onDeviceConnected: root.offer("bluetooth", root.bluetoothPriority, "bluetooth", "neutral",
                                      root.temporaryDwell)
    }

    Timer {
        id: controlTimer
        interval: root.controlDwell
        onTriggered: root.control = ""
    }

    Timer {
        id: slotTimer
        onTriggered: root.clearSlot(root.slotKind)
    }

    Rectangle {
        readonly property real round: Math.min(width, height) / 2
        readonly property real square: round * (1 - Math.max(0, Math.min(1, root.attach)))
        visible: root.housed
        anchors.fill: parent
        color: Theme.surface
        topLeftRadius: root.edge === "top" || root.edge === "left" ? square : round
        topRightRadius: root.edge === "top" || root.edge === "right" ? square : round
        bottomLeftRadius: root.edge === "bottom" || root.edge === "left" ? square : round
        bottomRightRadius: root.edge === "bottom" || root.edge === "right" ? square : round
    }

    StatusArc {
        id: arc
        x: root.room
        y: root.room
        width: root.diameter - 2 * root.room
        height: width
        lineWidth: root.stroke
        visible: !root.closeAction
        value: root.shownValue
        gap: root.shownGap * (1 - root.attached)
        gapWidth: label.implicitWidth + 2
        fillColor: root.shownColor
    }

    TickerNumber {
        id: label
        // Baseline on the arc's outer edge keeps the digits inside the circle, in the ring's unfilled bottom.
        readonly property real ringX: (root.diameter - implicitWidth) / 2
        readonly property real ringY: arc.y + arc.height - baselineOffset
        readonly property real tailX: root.alongY ? ringX : root.diameter
        readonly property real tailY: root.alongY ? root.diameter - root.room / 2 : (root.diameter - implicitHeight) / 2
        value: root.batteryPercent
        motion: root.motion
        opacity: root.closeAction ? 0 : Math.max(0, Math.min(1, root.shownGap))
        fontPixelSize: root.labelSize
        // Inside the ring the digits need the extra weight; beside it they set like the clock's.
        fontWeight: root.attached > 0.5 ? Theme.clockFontWeight : Font.DemiBold
        x: ringX + (tailX - ringX) * root.attached
        y: ringY + (tailY - ringY) * root.attached
    }

    Item {
        x: (root.diameter - width) / 2
        y: (root.diameter - height) / 2 - root.labelSize * 0.3 * Math.max(0, Math.min(1, root.shownGap)) * (1 - root.attached)
        width: root.iconSize
        height: root.iconSize
        visible: !root.closeAction
        clip: swap.running && slide.from !== 0

        StatusGlyph {
            id: outgoing
            anchors.fill: parent
            opacity: 0
            transform: Translate { id: outgoingShift }
        }

        StatusGlyph {
            id: incoming
            anchors.fill: parent
            icon: root.shownIcon
            wifiBars: network.bars
            level: root.shownIcon === "microphone" ? input.level : output.level
            transform: Translate { id: incomingShift }
        }
    }
    // Centered on the ring itself, not the whole item, which can include the battery tail.
    CloseMark {
        x: (root.diameter - width) / 2
        y: (root.diameter - height) / 2
        shown: root.closeAction
        motion: root.motion
    }



    // Next enters from the right and previous from the left; neutral swaps pop in place.
    QtObject {
        id: slide
        property real from: 0
        property real to: 0
        property real pop: 0.6
    }

    ParallelAnimation {
        id: swap

        NumberAnimation {
            target: outgoing
            property: "opacity"
            from: 1
            to: 0
            duration: root.motionDuration * 0.6
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: outgoing
            property: "scale"
            from: 1
            to: slide.pop
            duration: root.motionDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: outgoingShift
            property: "x"
            from: 0
            to: slide.to
            duration: root.motionDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: incoming
            property: "opacity"
            from: 0
            to: 1
            duration: root.motionDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: incoming
            property: "scale"
            from: slide.pop
            to: 1
            duration: root.motionDuration
            easing.type: root.motionCurve
            easing.overshoot: Theme.springOvershoot
        }
        NumberAnimation {
            target: incomingShift
            property: "x"
            from: slide.from
            to: 0
            duration: root.motionDuration
            easing.type: root.motionCurve
            easing.overshoot: Theme.springOvershoot
        }
    }
}
