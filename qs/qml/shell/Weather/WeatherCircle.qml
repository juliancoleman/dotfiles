import QtQuick
import ".."
import "../Clock"
import "../Common"
import "../Status"

// Condition and temperature, the way a menu bar shows them: side by side in a capsule along a top or
// bottom bar, stacked in a circle along a side bar. Rests before the notification circle (or the clock);
// docked into the notch it rides in a slot the clock provides. Clicked, it grows into the forecast panel,
// holding its corner nearest the clock and the screen edge.
Item {
    id: root

    property string edge: "right"
    property real diameter: 34
    // The clock's digit size, so a side-by-side temperature reads like the time.
    property int digitSize: Theme.horizontalDigit
    // Stacked in a side bar's circle, the reading sits at the size of the clock's AM/PM mark.
    property int periodSize: Theme.periodSize
    property real attach: 0
    property string motion: "easeOut"
    property bool docked: false
    property Item slot: null
    property Item bodySlot: null
    readonly property bool lent: docked && !!slot && !!bodySlot

    // Steps aside for anything that opens over its spot, like the notification panel in pill mode.
    property bool yielding: false
    readonly property bool present: ClockConfig.weatherEnabled && !!WeatherService.current && !yielding
    property real presence: 0
    readonly property real presenceP: Math.max(0, presence)
    readonly property bool hovered: hit.containsMouse
    readonly property bool pointerDown: hit.pressed
    property alias housingItem: housing

    property bool opened: false
    property real openProgress: 0
    readonly property real openP: Math.max(0, openProgress)
    readonly property bool closeActionInFace: lent && opened

    readonly property bool alongY: edge === "left" || edge === "right"
    // The capsule sits before the clock: to its left along a top/bottom bar, above it along a side bar.
    readonly property bool circleRight: alongY ? edge === "right" : true
    readonly property bool circleBottom: alongY ? true : edge === "bottom"
    readonly property real room: Math.max(2, Math.round(diameter * 0.1))
    readonly property int iconSize: Math.round(diameter * (alongY ? 0.46 : 0.5))
    readonly property int labelSize: alongY ? periodSize : digitSize
    readonly property real sidePad: Theme.padX + 3
    // Fused into the notch, the capsule's ends tighten to the status ring's inset so the reading sits as
    // far from the time as the ring does, with the notch's own padding making up the rest.
    readonly property real inset: sidePad + (room + 1 - sidePad) * Math.max(0, Math.min(1, attach))
    readonly property real iconGap: 5
    readonly property string reading: WeatherService.stale ? "–" : WeatherService.temperature
    // Length along the bar, before any end padding.
    readonly property real body: alongY ? diameter
        : Math.max(diameter, Math.round(2 * inset + iconSize + iconGap + label.implicitWidth))
    // Housing past the far end while fusing into the notch, matching the clock's end padding.
    property real endPad: 0

    // Room the pill has to open into; lent to the notch, the clock's housing decides.
    property real maxPanelHeight: Infinity
    // Lent to the notch, the clock's housing supplies the gutter.
    readonly property real pad: lent ? 0 : Theme.panelPad
    readonly property real panelWidth: 290 + pad * 2
    readonly property real panelHeight: panel.implicitHeight
    // What the open panel needs with any circle up to 40 across and a full gutter. Only the forecast's own
    // content moves it, never the circle or the docking, so the window isn't resized while those animate.
    readonly property real reserveHeight: 40 + panel.contentHeight + Theme.panelPad + 40
    readonly property real reserveWidth: 290 + Theme.panelPad * 2
    readonly property real restWidth: alongY ? diameter : body + endPad
    readonly property real restHeight: alongY ? diameter + endPad : diameter

    implicitWidth: lent ? restWidth : restWidth + (panelWidth - restWidth) * openP
    implicitHeight: lent ? restHeight : restHeight + (panelHeight - restHeight) * openP
    width: implicitWidth
    height: implicitHeight

    function open() {
        if (opened || !present)
            return
        opened = true
        run(openEase, "openProgress", 1)
        if (Date.now() - WeatherService.updatedAt > 5 * 60 * 1000)
            WeatherService.refresh()
    }

    function close() {
        if (!opened)
            return
        opened = false
        run(openEase, "openProgress", 0)
    }

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    function run(ease, property, next) {
        ease.stop()
        if (motion === "none") {
            root[property] = next
            return
        }
        ease.from = root[property]
        ease.to = next
        ease.start()
    }

    // A new condition (another place, or the sky changing) cross-fades in over the old one.
    readonly property string conditionIcon: WeatherService.icon
    property string shownIcon: conditionIcon
    property string previousIcon: ""
    property real iconFade: 1

    onConditionIconChanged: {
        if (conditionIcon === shownIcon)
            return
        fade.stop()
        previousIcon = shownIcon
        shownIcon = conditionIcon
        if (motion === "none" || presenceP < 0.001) {
            iconFade = 1
            return
        }
        iconFade = 0
        fade.start()
    }

    onPresentChanged: {
        run(ease, "presence", present ? 1 : 0)
        if (!present)
            close()
    }
    Component.onCompleted: presence = present ? 1 : 0

    NumberAnimation {
        id: fade
        target: root
        property: "iconFade"
        to: 1
        duration: Theme.durationFor(root.motion) * 1.6
        easing.type: Easing.InOutQuad
    }

    NumberAnimation {
        id: ease
        target: root
        property: "presence"
        duration: Theme.durationFor(root.motion) * 1.4
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

    Rectangle {
        id: housing
        readonly property real round: root.diameter / 2 * (1 - Math.min(1, root.openP)) + 14 * root.openP
        readonly property real square: round * (1 - Math.max(0, Math.min(1, root.attach)))
        // Screen-edge corners and the ones facing the clock square off as the circle fuses into the notch.
        function corner(outer, facingClock) {
            return outer || facingClock ? square : round
        }
        visible: !root.lent && root.presenceP > 0.001
        anchors.fill: parent
        color: Theme.surface
        clip: root.openP > 0.001
        scale: hit.containsMouse && !root.opened && root.openP < 0.001 ? 1.06 : 1
        transformOrigin: root.circleRight
            ? (root.circleBottom ? Item.BottomRight : Item.TopRight)
            : (root.circleBottom ? Item.BottomLeft : Item.TopLeft)
        topLeftRadius: corner(root.edge === "top" || root.edge === "left", false)
        topRightRadius: corner(root.edge === "top" || root.edge === "right", !root.alongY)
        bottomLeftRadius: corner(root.edge === "bottom" || root.edge === "left", root.alongY)
        bottomRightRadius: corner(root.edge === "bottom" || root.edge === "right", true)

        Behavior on scale {
            NumberAnimation {
                duration: Theme.durationFor(root.motion)
                easing.type: Theme.easingFor(root.motion)
                easing.overshoot: Theme.springOvershoot
            }
        }

        Item {
            id: panelBody
            parent: root.lent ? root.bodySlot : housing
            width: root.panelWidth
            height: root.panelHeight
            x: root.lent ? (parent.width - width) / 2 : root.circleRight ? housing.width - width : 0
            // Lent to the notch, the panel opens in the calendar's place, against the clock.
            y: root.lent ? (root.edge === "bottom" ? parent.height - height : 0)
                : root.circleBottom ? housing.height - height : 0
            opacity: Math.min(1, root.openP)
            visible: root.openP > 0.001
            enabled: root.opened

            // The same panel in the pill and the notch; the pill only keeps room for the capsule's corner.
            WeatherPanel {
                id: panel
                width: parent.width
                rowHeight: root.diameter
                pad: root.pad
                faceRoom: !root.lent && !root.circleBottom ? root.restWidth : 0
                footRoom: !root.lent && root.circleBottom ? root.diameter : 0
                maxHeight: root.lent ? Infinity : root.maxPanelHeight
                closeActionInFace: root.closeActionInFace
                onCloseRequested: root.close()
            }
        }

        Item {
            id: face
            parent: root.lent ? root.slot : housing
            width: root.alongY ? root.diameter : root.body
            height: root.diameter
            x: root.lent ? (parent.width - width) / 2 : root.circleRight ? housing.width - width : 0
            y: root.lent ? (parent.height - height) / 2 : root.circleBottom ? housing.height - height : 0
            opacity: Math.min(root.presenceP, root.lent ? 1 : 1 - root.openP)
            Accessible.role: Accessible.Button
            Accessible.name: root.opened ? I18n.tr("Close weather") : WeatherService.condition + ", " + root.reading

            // In the notch, opening weather replaces its cloud and temperature with the close action.


            Item {
                opacity: root.closeActionInFace ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationFor(root.motion); easing.type: Easing.OutCubic }
                }

                x: root.alongY ? (parent.width - width) / 2 : root.inset
                y: (parent.height - height) / 2 - (root.alongY ? root.labelSize * 0.45 : 0)
                width: root.iconSize
                height: root.iconSize

                StatusGlyph {
                    anchors.fill: parent
                    icon: root.previousIcon
                    opacity: 1 - root.iconFade
                    visible: opacity > 0.001
                }

                StatusGlyph {
                    anchors.fill: parent
                    icon: root.shownIcon
                    opacity: root.iconFade
                }
            }
            CloseMark {
                anchors.centerIn: parent
                shown: root.closeActionInFace
                motion: root.motion
            }


            TickerNumber {
                id: label
                x: root.alongY ? (parent.width - implicitWidth) / 2 : root.inset + root.iconSize + root.iconGap
                y: root.alongY ? parent.height - root.room - 1 - baselineOffset : (parent.height - implicitHeight) / 2
                value: WeatherService.stale ? NaN : WeatherService.degrees
                motion: root.motion
                fontPixelSize: root.labelSize
                fontWeight: root.alongY ? Font.DemiBold : Theme.clockFontWeight
                opacity: root.closeActionInFace ? 0 : 1
                Behavior on opacity {
                    NumberAnimation { duration: Theme.durationFor(root.motion); easing.type: Easing.OutCubic }
                }
            }

            MouseArea {
                id: hit
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: root.toggle()
            }
        }
    }
}
