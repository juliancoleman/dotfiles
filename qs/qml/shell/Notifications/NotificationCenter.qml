import QtQuick
import ".."
import "../Common"
import "../Clock"
import "../Control"
import "../Status"

// The notification circle drops out of the clock's leading end and grows into this panel. It holds its
// corner (nearest the clock and the screen edge) while the housing opens away from both.
Item {
    id: root

    property string edge: "right"
    property real diameter: 34
    property real attach: 0
    property string motion: "easeOut"
    property int mediaDwell: 2500

    readonly property bool present: NotificationService.count > 0
    property real presence: 0
    readonly property real presenceP: Math.max(0, presence)

    property bool opened: false
    // A new arrival peeks out of the circle as a single card, unless Do Not Disturb is on or another
    // panel on this bar is using the space (quiet). Peeking never takes keyboard focus.
    property bool peeking: false
    property bool quiet: false
    property int peekDwell: 5000
    property int peekId: -1
    readonly property bool showing: opened || peeking
    readonly property bool peekMode: peeking && !opened
    property real openProgress: 0
    property real hoverProgress: 0
    readonly property real openP: Math.max(0, openProgress)
    readonly property real hoverP: Math.max(0, hoverProgress)
    readonly property real openZoom: 1.06
    readonly property real zoom: 1 + hoverP * (1 - Math.min(1, openP)) * (openZoom - 1)
    readonly property bool pointerDown: circleHit.pressed
    property alias housingItem: housing
    readonly property alias badge: badge
    readonly property bool circleHovered: circleHit.containsMouse

    // Docked into the notch, the circle and body live inside the clock's housing instead of this one.
    property bool docked: false
    property Item badgeSlot: null
    property Item bodySlot: null
    readonly property bool lent: docked && !!badgeSlot && !!bodySlot
    readonly property bool closeActionInBadge: lent && opened

    readonly property bool alongY: edge === "left" || edge === "right"
    // The circle sits before the clock: to its left along a top/bottom bar, above it along a side bar.
    readonly property bool circleRight: alongY ? edge === "right" : true
    readonly property bool circleBottom: alongY ? true : edge === "bottom"
    // Lent to the notch, the panel opens in the calendar's place and lays out like the control center.
    readonly property bool headerBottom: lent ? edge === "bottom" : circleBottom
    readonly property bool mirrored: !lent && circleRight

    // Media and count sit inset in the circle; the notch's leading pad is measured to them.
    readonly property real inset: 4
    property real endPad: 0

    // Lent to the notch, the clock's housing supplies the gutter.
    readonly property real pad: lent ? 0 : Theme.panelPad
    readonly property real panelWidth: 298 + pad * 2
    readonly property real listMax: 330
    readonly property real listContent: Math.min(listMax, list.implicitHeight)
    property real shownContent: listContent
    Behavior on shownContent {
        enabled: root.opened
        NumberAnimation {
            duration: Theme.durationFor(root.motion)
            easing.type: Theme.easingFor(root.motion)
            easing.overshoot: Theme.springOvershoot
        }
    }
    readonly property real fullHeight: diameter + Theme.panelHeaderGap + shownContent + pad
    // Beside the circle in the pill; on its own in the notch's shared space.
    readonly property real peekWidth: panelWidth - (lent ? pad * 2 : pad + diameter + 4)
    readonly property real peekHeight: lent ? peekRow.implicitHeight + pad * 2
        : Math.max(diameter, peekRow.implicitHeight + pad * 2)
    property real panelHeight: peekMode ? peekHeight : fullHeight
    Behavior on panelHeight {
        enabled: root.openP > 0.01
        NumberAnimation {
            duration: Theme.durationFor(root.motion)
            easing.type: Theme.easingFor(root.motion)
            easing.overshoot: Theme.springOvershoot
        }
    }
    readonly property real reserveHeight: diameter + Theme.panelHeaderGap + listMax + pad + 40

    readonly property real restWidth: diameter + (alongY ? 0 : endPad)
    readonly property real restHeight: diameter + (alongY ? endPad : 0)
    readonly property real housingWidth: lent ? 0 : restWidth + (panelWidth - restWidth) * openP
    readonly property real housingHeight: lent ? 0 : restHeight + (panelHeight - restHeight) * openP

    implicitWidth: housingWidth
    implicitHeight: housingHeight
    width: implicitWidth
    height: implicitHeight

    onPresentChanged: {
        run(presenceEase, "presence", present ? 1 : 0)
        if (!present)
            close()
    }
    Component.onCompleted: presence = present ? 1 : 0

    onOpenedChanged: NotificationService.setPanelOpen(opened)
    onQuietChanged: if (quiet) endPeek()

    function open() {
        if (opened || !present)
            return
        opened = true
        peeking = false
        run(openEase, "openProgress", 1)
        aimHover(false)
    }

    function close() {
        if (!showing)
            return
        opened = false
        peeking = false
        run(openEase, "openProgress", 0)
        aimHover(circleHit.containsMouse)
    }

    function peek() {
        if (opened || quiet || ClockConfig.doNotDisturb || !newest)
            return
        peekId = newest.id
        peeking = true
        peekTimer.restart()
        run(openEase, "openProgress", 1)
        aimHover(false)
    }

    function endPeek() {
        if (!peeking)
            return
        peeking = false
        if (!opened) {
            run(openEase, "openProgress", 0)
            aimHover(circleHit.containsMouse)
        }
    }

    // The peeked notification went away (dismissed, expired, acted on): fold back rather than show another.
    function checkPeek() {
        if (peeking && (!newest || newest.id !== peekId))
            endPeek()
    }

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    function aimHover(next) {
        run(hoverEase, "hoverProgress", next && !showing ? 1 : 0)
    }

    function run(ease, property, next) {
        if (motion === "none") {
            ease.stop()
            root[property] = next
            return
        }
        if (!ease.running && Math.abs(root[property] - next) < 0.001)
            return
        ease.stop()
        ease.from = root[property]
        ease.to = next
        ease.start()
    }

    // Corners on the screen edge, and those facing the clock, square off as the circle fuses into the notch.
    function corner(outer, facingClock) {
        const radius = diameter / 2 * (1 - Math.min(1, openP)) + 14 * openP
        return outer || facingClock ? radius * (1 - Math.max(0, Math.min(1, attach))) : radius
    }

    NumberAnimation {
        id: openEase
        target: root
        property: "openProgress"
        duration: Theme.durationFor(root.motion)
        easing.type: Theme.easingFor(root.motion)
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
        id: presenceEase
        target: root
        property: "presence"
        duration: Theme.durationFor(root.motion) * 1.4
        easing.type: Theme.easingFor(root.motion)
        easing.overshoot: Theme.springOvershoot
    }

    // The newest notification's media shows first; after the dwell the circle settles on the count.
    // Do Not Disturb keeps the circle on the count.
    property bool showMedia: false
    readonly property var newest: NotificationService.newest
    onNewestChanged: {
        if (newest)
            reveal()
        Qt.callLater(checkPeek)
    }
    function reveal() {
        if (ClockConfig.doNotDisturb)
            return
        showMedia = true
        dwell.restart()
    }

    Connections {
        target: NotificationService
        function onArrived() {
            root.reveal()
            root.peek()
        }
    }

    Connections {
        target: ClockConfig
        function onDoNotDisturbChanged() {
            if (!ClockConfig.doNotDisturb)
                return
            root.showMedia = false
            root.endPeek()
        }
    }

    Timer {
        id: dwell
        interval: root.mediaDwell
        onTriggered: root.showMedia = false
    }

    Timer {
        id: peekTimer
        interval: root.peekDwell
        onTriggered: peekHover.hovered || circleHit.containsMouse ? restart() : root.endPeek()
    }

    Rectangle {
        id: housing
        visible: !root.lent && root.presenceP > 0.001
        width: root.housingWidth
        height: root.housingHeight
        x: root.circleRight ? root.width - width : 0
        y: root.circleBottom ? root.height - height : 0
        scale: root.zoom
        transformOrigin: root.circleRight
            ? (root.circleBottom ? Item.BottomRight : Item.TopRight)
            : (root.circleBottom ? Item.BottomLeft : Item.TopLeft)
        color: Theme.surface
        clip: true
        topLeftRadius: root.corner(root.edge === "top" || root.edge === "left", false)
        topRightRadius: root.corner(root.edge === "top" || root.edge === "right", !root.alongY)
        bottomLeftRadius: root.corner(root.edge === "bottom" || root.edge === "left", root.alongY)
        bottomRightRadius: root.corner(root.edge === "bottom" || root.edge === "right", true)

        Item {
            id: body
            parent: root.lent ? root.bodySlot : housing
            width: root.panelWidth
            height: root.panelHeight
            x: root.lent ? (parent.width - width) / 2 : root.circleRight ? housing.width - width : 0
            y: root.lent ? (root.headerBottom ? parent.height - height : 0)
                : root.circleBottom ? housing.height - height : 0
            opacity: Math.min(1, root.openP)
            visible: root.openP > 0.001
            enabled: root.showing

            property real fullFade: root.peekMode ? 0 : 1
            Behavior on fullFade {
                NumberAnimation {
                    duration: Theme.durationFor(root.motion)
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                anchors.fill: parent
                opacity: 1 - body.fullFade
                visible: opacity > 0.01
                enabled: root.peekMode

                HoverHandler { id: peekHover }

                NotificationRow {
                    id: peekRow
                    handle: root.newest
                    notificationId: root.newest ? root.newest.id : -1
                    motion: root.motion
                    width: root.peekWidth
                    x: root.lent || root.circleRight ? root.pad : root.diameter + 4
                    y: root.lent || !root.circleBottom ? root.pad : body.height - root.pad - height
                }
            }

            Item {
                id: header
                opacity: body.fullFade
                visible: opacity > 0.01
                x: root.pad + Theme.panelHeaderInset
                y: root.headerBottom ? body.height - root.diameter : 0
                width: body.width - (root.pad + Theme.panelHeaderInset) * 2
                height: root.diameter

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: root.mirrored ? parent.right : undefined
                    anchors.left: root.mirrored ? undefined : parent.left
                    anchors.rightMargin: root.mirrored ? root.diameter - 4 : 0
                    anchors.leftMargin: root.mirrored || root.closeActionInBadge ? 0 : root.diameter - 4
                    spacing: 6

                    Text {
                        id: title
                        text: qsTr("Notifications")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.baseline: title.baseline
                        text: NotificationService.count
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.features: { "tnum": 1 }
                    }
                }
                SettingsButton {
                    id: closeButton
                    opened: root.openP
                    visible: !root.closeActionInBadge
                    icon: "close"
                    label: qsTr("Close notifications")
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.mirrored
                        ? parent.width - width / 2 - (root.diameter / 2 - (root.pad + Theme.panelHeaderInset))
                        : 0
                    onActivated: root.close()
                }

                Item {
                    id: clear
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.mirrored ? -4 : parent.width - width + 4
                    width: clearLabel.implicitWidth + 16
                    height: 26
                    activeFocusOnTab: root.opened
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Clear all")
                    Keys.onReturnPressed: NotificationService.clearAll()
                    Keys.onSpacePressed: NotificationService.clearAll()

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: clearHit.containsMouse || clear.activeFocus ? Theme.track : "transparent"
                        border.width: clear.activeFocus ? 1 : 0
                        border.color: Theme.today
                    }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: qsTr("Clear all")
                        color: clearHit.containsMouse ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: clearHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.clearAll()
                    }
                }
            }

            MomentumFlickable {
                opacity: body.fullFade
                visible: opacity > 0.01
                x: root.pad
                y: root.headerBottom ? root.pad : root.diameter + Theme.panelHeaderGap
                width: body.width - root.pad * 2
                height: root.shownContent
                contentHeight: list.implicitHeight

                Column {
                    id: list
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: NotificationService.model

                        NotificationRow {
                            width: list.width
                            motion: root.motion
                        }
                    }
                }
            }
        }

        Item {
            id: badge
            parent: root.lent ? root.badgeSlot : housing
            width: root.diameter
            height: root.diameter
            x: root.lent ? (parent.width - width) / 2 : root.circleRight ? housing.width - width : 0
            y: root.lent ? (parent.height - height) / 2 : root.circleBottom ? housing.height - height : 0
            opacity: root.lent ? Math.min(1, root.presenceP) : 1 - Math.min(1, root.openP)

            readonly property real face: root.diameter - root.inset * 2
            readonly property string media: NotificationService.mediaFor(root.newest)

            Rectangle {
                id: face
                anchors.centerIn: parent
                width: badge.face
                height: badge.face
                radius: width / 2
                color: Theme.ink
                border.width: NotificationService.newestCritical ? 1.5 : 0
                border.color: Qt.lighter(Theme.danger, 1.8)
                opacity: 1
                clip: true

                Item {
                    anchors.fill: parent
                    opacity: root.closeActionInBadge ? 0 : root.showMedia ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Image {
                        id: picture
                        anchors.fill: parent
                        anchors.margins: face.border.width
                        source: badge.media
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(badge.face * 2, badge.face * 2)
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    StatusGlyph {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        visible: !picture.visible
                        icon: "bell"
                    }
                }

                StatusGlyph {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    opacity: root.closeActionInBadge ? 0 : root.showMedia ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    icon: ClockConfig.doNotDisturb ? "moon" : "bell"
                }
                CloseMark {
                    anchors.centerIn: parent
                    shown: root.closeActionInBadge
                    motion: root.motion
                }
            }

            // The count rides on the bell's corner so it never reads as a workspace number.
            Rectangle {
                x: badge.width - width - 1
                y: 1
                width: Math.max(height, count.implicitWidth + 6)
                height: 13
                radius: height / 2
                color: Theme.today
                opacity: root.closeActionInBadge || ClockConfig.doNotDisturb ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                Text {
                    id: count
                    anchors.centerIn: parent
                    text: NotificationService.count > 99 ? "99+" : NotificationService.count
                    color: Theme.todayInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            MouseArea {
                id: circleHit
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.lent || !root.opened
                Accessible.role: Accessible.Button
                Accessible.name: root.opened ? qsTr("Close notifications") : qsTr("Notifications")
                onContainsMouseChanged: if (!pressed) root.aimHover(containsMouse)
                onPressed: root.toggle()
                onReleased: root.aimHover(containsMouse)
            }
        }
    }
}
