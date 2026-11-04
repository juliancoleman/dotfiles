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
    readonly property real inset: Theme.px(4)
    property real endPad: 0

    // Lent to the notch, the clock's housing supplies the gutter.
    readonly property real pad: lent ? 0 : Theme.panelPad
    readonly property real panelWidth: Theme.px(298) + pad * 2
    readonly property real listMax: Theme.px(330)
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
    // The pop-up's one notification is drawn bare, the panel standing in for its card, so its content sits
    // on the panel's gutter; the row's own inset is taken back out of the panel's pad.
    readonly property real peekInset: pad - peekRow.inset
    readonly property real peekWidth: panelWidth - peekInset * 2
    readonly property real peekHeight: lent ? peekRow.implicitHeight + peekInset * 2
        : Math.max(diameter, peekRow.implicitHeight + peekInset * 2)
    property real panelHeight: peekMode ? peekHeight : fullHeight
    Behavior on panelHeight {
        enabled: root.openP > 0.01
        NumberAnimation {
            duration: Theme.durationFor(root.motion)
            easing.type: Theme.easingFor(root.motion)
            easing.overshoot: Theme.springOvershoot
        }
    }
    // Tallest the panel gets, with any circle up to 40 across: a constant, since the window is sized from
    // it and a layer-shell resize mid-animation drops a frame.
    readonly property real reserveHeight: Theme.px(40) + Theme.panelHeaderGap + listMax + Theme.panelPad + Theme.px(40)
    readonly property real reserveWidth: Theme.px(298) + Theme.panelPad * 2

    readonly property real restWidth: diameter + (alongY ? 0 : endPad)
    readonly property real restHeight: diameter + (alongY ? endPad : 0)
    readonly property real housingWidth: lent ? 0 : restWidth + (panelWidth - restWidth) * openP
    readonly property real housingHeight: lent ? 0 : restHeight + (panelHeight - restHeight) * openP

    implicitWidth: housingWidth
    implicitHeight: housingHeight
    width: implicitWidth
    height: implicitHeight

    onPresentChanged: {
        presenceEase.aim(present ? 1 : 0)
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
        openEase.aim(1)
        aimHover(false)
    }

    function close() {
        if (!showing)
            return
        opened = false
        peeking = false
        openEase.aim(0)
        aimHover(circleHit.containsMouse)
    }

    function peek() {
        if (opened || quiet || ClockConfig.doNotDisturb || !newest)
            return
        peekId = newest.id
        peeking = true
        peekTimer.restart()
        openEase.aim(1)
        aimHover(false)
    }

    function endPeek() {
        if (!peeking)
            return
        peeking = false
        if (!opened) {
            openEase.aim(0)
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
        hoverEase.aim(next && !showing ? 1 : 0)
    }

    // Corners on the screen edge, and those facing the clock, square off as the circle fuses into the notch.
    function corner(outer, facingClock) {
        // 14 is the fused housing's corner, shared with the weather circle's housing; not a container radius.
        const radius = diameter / 2 * (1 - Math.min(1, openP)) + 14 * openP
        return outer || facingClock ? radius * (1 - Math.max(0, Math.min(1, attach))) : radius
    }

    Tween {
        id: openEase
        target: root
        property: "openProgress"
        motion: root.motion
    }

    Tween {
        id: hoverEase
        target: root
        property: "hoverProgress"
        motion: root.motion
    }

    Tween {
        id: presenceEase
        target: root
        property: "presence"
        motion: root.motion
        duration: Theme.durationFor(root.motion) * 1.4
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
            // Only cross-fades between a showing peek and the full list; opening straight into a peek must not
            // flash the full header on the way.
            Behavior on fullFade {
                enabled: root.openP > 0.01
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
                    bare: true
                    width: root.peekWidth
                    x: root.peekInset
                    y: root.lent || !root.circleBottom ? root.peekInset : body.height - root.peekInset - height
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
                    anchors.rightMargin: root.mirrored ? root.diameter - Theme.panelHeaderInset : 0
                    anchors.leftMargin: root.mirrored || root.closeActionInBadge ? 0 : root.diameter - Theme.panelHeaderInset
                    spacing: Theme.tileGap

                    Text {
                        id: title
                        text: I18n.tr("Notifications")
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textStrong
                        font.weight: Font.Medium
                    }

                    Text {
                        anchors.baseline: title.baseline
                        text: NotificationService.count
                        color: Theme.textSecondary
                        font.family: Theme.latinFontFamily
                        font.pixelSize: Theme.textLabel
                        font.features: { "tnum": 1 }
                    }
                }
                SettingsButton {
                    id: closeButton
                    opened: root.openP
                    motion: root.motion
                    visible: !root.closeActionInBadge
                    icon: "close"
                    label: I18n.tr("Close notifications")
                    anchors.verticalCenter: parent.verticalCenter
                    // Centered on the badge it replaces, whichever end of the panel that is.
                    readonly property real badgeCenter: root.diameter / 2 - (root.pad + Theme.panelHeaderInset)
                    x: root.mirrored ? parent.width - badgeCenter - width / 2 : badgeCenter - width / 2
                    onActivated: root.close()
                }

                Item {
                    id: clear
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.mirrored ? -Theme.panelHeaderInset : parent.width - width + Theme.panelHeaderInset
                    width: clearLabel.implicitWidth + Theme.px(16)
                    height: Theme.px(26)
                    activeFocusOnTab: root.opened
                    Accessible.role: Accessible.Button
                    Accessible.name: I18n.tr("Clear all")
                    Keys.onReturnPressed: NotificationService.clearAll()
                    Keys.onSpacePressed: NotificationService.clearAll()

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusInput
                        color: clearHit.containsMouse || clear.activeFocus ? Theme.track : "transparent"
                        border.width: clear.activeFocus ? 1 : 0
                        border.color: Theme.today
                    }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: I18n.tr("Clear all")
                        color: clearHit.containsMouse ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textLabel
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
                    spacing: Theme.tileGap

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
                // A critical arrival rings the circle in lightened danger: a warning state, not decoration.
                border.width: NotificationService.newestCritical ? 1.5 : 0
                border.color: Qt.lighter(Theme.danger, 1.8)
                opacity: 1
                clip: true

                Item {
                    anchors.fill: parent
                    opacity: root.closeActionInBadge ? 0 : root.showMedia ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFor(root.motion) * 0.72; easing.type: Easing.OutCubic } }

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
                        width: Theme.px(14)
                        height: Theme.px(14)
                        visible: !picture.visible
                        icon: "bell"
                    }
                }

                StatusGlyph {
                    anchors.centerIn: parent
                    width: Theme.px(14)
                    height: Theme.px(14)
                    opacity: root.closeActionInBadge ? 0 : root.showMedia ? 0 : 1
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: Theme.durationFor(root.motion) * 0.72; easing.type: Easing.OutCubic } }
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
                width: Math.max(height, count.implicitWidth + Theme.tileGap)
                height: Theme.px(13)
                radius: height / 2
                color: Theme.today
                opacity: root.closeActionInBadge || ClockConfig.doNotDisturb ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Theme.durationFor(root.motion) * 0.72; easing.type: Easing.OutCubic } }

                Text {
                    id: count
                    anchors.centerIn: parent
                    text: NotificationService.count > 99 ? "99+" : NotificationService.count
                    color: Theme.todayInk
                    font.family: Theme.latinFontFamily
                    font.pixelSize: Theme.px(9)
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
                Accessible.name: root.opened ? I18n.tr("Close notifications") : I18n.tr("Notifications")
                onContainsMouseChanged: if (!pressed) root.aimHover(containsMouse)
                onPressed: root.toggle()
                onReleased: root.aimHover(containsMouse)
            }
        }
    }
}
