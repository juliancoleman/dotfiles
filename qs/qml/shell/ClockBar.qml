import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "."
import "Clock"
import "Common"
import "Control"
import "Launcher"
import "Notifications"
import "Secure"
import "Settings"
import "Weather"

PanelWindow {
    id: root

    required property var modelData

    readonly property string placement: ClockConfig.placement
    readonly property bool vertical: placement === "left" || placement === "right"
    readonly property bool calendarOpen: clock.calendarOpen
    readonly property bool controlsOpen: controls.opened
    readonly property bool notesOpen: notes.opened
    readonly property bool weatherOpen: weather.opened
    readonly property bool anyOpen: calendarOpen || controlsOpen || notesOpen || weatherOpen
    // One keyboard grab at a time: secrets are asked for on the first screen only.
    readonly property bool secureShown: SecureInput.active && modelData === Quickshell.screens[0]
    readonly property bool launcherShown: LauncherState.opened && !SecureInput.active
        && modelData.name === LauncherState.screenName
    // The secure prompt and the launcher take over the whole bar; everything else fades beneath them.
    readonly property bool covered: secureShown || launcherShown
    readonly property real coverFade: 1 - Math.max(secure.pc, launcher.pc)

    function closePanels() {
        closeExcept(null)
    }

    function closeAll() {
        closePanels()
        LauncherState.close()
    }

    // The panels share the bar's space, so opening one closes the rest.
    function closeExcept(kept) {
        if (kept !== clock)
            clock.closeCalendar()
        if (kept !== controls)
            controls.close()
        if (kept !== notes)
            notes.close()
        if (kept !== weather)
            weather.close()
    }

    onCalendarOpenChanged: if (calendarOpen) closeExcept(clock)
    onControlsOpenChanged: if (controlsOpen) closeExcept(controls)
    onNotesOpenChanged: if (notesOpen) closeExcept(notes)
    onWeatherOpenChanged: if (weatherOpen) closeExcept(weather)
    onSecureShownChanged: if (secureShown) closeAll()
    onLauncherShownChanged: if (launcherShown) closePanels()

    // Super+Comma: settings are control-center pages, toggled on the focused output's bar.
    Connections {
        target: SettingsState
        function onToggleRequested(screenName) {
            if (screenName === root.modelData.name)
                controls.toggleSettings()
        }
    }

    readonly property real diameter: clock.restingThickness
    readonly property real join: Math.max(0, Math.min(1, clock.notchAmount))
    readonly property real statusGap: Theme.statusGap * (1 - join)
    // Once fully fused, the notch is one unit: the circle and control center move into the clock's housing.
    readonly property bool docked: ClockConfig.presentation === "notch" && join > 0.999
    // While fusing, the clock and circle center as a pair so docking (which centers them as one) doesn't jump.
    readonly property real lift: docked ? 0
        : join * (statusGap + (vertical ? controls.status.height : controls.status.width) + controls.endPad
                  - notesSpan - weatherSpan) / 2
    // What the notch's far end needs past the circle to match the clock's leading pad.
    readonly property real endPad: Math.max(0, (vertical ? Theme.padY : Theme.padX + 3) - controls.status.endRoom)
    readonly property real notesEndPad: Math.max(0, (vertical ? Theme.padY : Theme.padX + 3) - notes.inset)
    readonly property real weatherEndPad: vertical ? notesEndPad : Math.max(0, Theme.padX + 3 - weather.inset)
    readonly property real leadEndPad: notesEndPad + (weatherEndPad - notesEndPad) * Math.min(1, weatherP)
    readonly property real axis: clock.edgeGap + diameter / 2

    // The notification circle drops out of the clock's leading end, opposite the status circle.
    readonly property real notesP: notes.presenceP
    readonly property real notesSpan: (statusGap + diameter + notes.endPad) * notesP
    readonly property real clockStart: vertical ? clock.y + clock.housingItem.y : clock.x + clock.housingItem.x
    readonly property real notesAlong: clockStart - (statusGap + diameter) * notesP
    // Weather rests one circle further out, before the notification circle when there is one.
    readonly property real weatherP: weather.presenceP
    readonly property real weatherSpan: (statusGap + weather.body) * weatherP + weather.endPad
    readonly property real weatherAlong: notesAlong - (statusGap + weather.body) * weatherP
    readonly property real leadP: Math.max(notesP, weatherP)
    readonly property real notesCross: vertical
        ? (placement === "right" ? width - axis : axis) - diameter / 2
        : (placement === "top" ? axis : height - axis) - diameter / 2

    // Where the status circle rests; the control center grows out of it from this corner.
    readonly property real circleX: vertical
        ? (placement === "right" ? width - axis : axis) - diameter / 2
        : clock.x + clock.housingItem.x + clock.housingItem.width + statusGap
    readonly property real circleY: vertical
        ? clock.y + clock.housingItem.y + clock.housingItem.height + statusGap
        : (placement === "top" ? axis : height - axis) - diameter / 2

    screen: modelData
    // The bar spans its whole screen edge so the clock stays centered and the panel has room to open.
    implicitWidth: vertical ? Math.max(clock.width, clock.edgeGap
        + Math.max(controls.panelWidth, weather.panelWidth, secure.openW, launcher.maxW) * clock.springRoom) : 0
    implicitHeight: vertical ? 0 : Math.max(clock.height, clock.edgeGap
        + Math.max(controls.reserveHeight, notes.reserveHeight, weather.reserveHeight, launcher.maxH)
        * clock.springRoom)
    exclusiveZone: ClockConfig.presentation === "notch"
        ? Math.ceil(vertical ? clock.restingHousingWidth : clock.restingHousingHeight) : 0
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: anyOpen || covered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Shortcut {
        enabled: root.calendarOpen
        sequence: "Left"
        context: Qt.WindowShortcut
        onActivated: clock.shiftMonth(-1)
    }
    Shortcut {
        enabled: root.calendarOpen
        sequence: "Right"
        context: Qt.WindowShortcut
        onActivated: clock.shiftMonth(1)
    }
    Shortcut {
        enabled: root.anyOpen || root.secureShown
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: root.secureShown ? SecureInput.cancel()
            : root.controlsOpen ? controls.stepBack() : root.closeAll()
    }

    anchors {
        top: placement === "top" || vertical
        right: placement === "right" || !vertical
        bottom: placement === "bottom" || vertical
        left: placement === "left" || !vertical
    }

    property Item maskItem: clock.housingItem
    property Item controlsMask: controls.housingItem
    property Item secureMask: secure.housingItem
    property Item notesMask: notes.housingItem
    property Item weatherMask: weatherRegion
    property Item launcherMask: launcher.housingItem
    // A region only follows its own item's geometry, and the weather housing fills a parent that moves
    // under it, so the mask tracks this stand-in at the window's top level instead.
    Item {
        id: weatherRegion
        x: weather.x
        y: weather.y
        width: weather.housingItem.visible ? weather.width : 0
        height: weather.housingItem.visible ? weather.height : 0
    }
    onPlacementChanged: {
        maskItem = null
        controlsMask = null
        secureMask = null
        notesMask = null
        weatherMask = null
        launcherMask = null
        Qt.callLater(function () {
            maskItem = clock.housingItem
            controlsMask = controls.housingItem
            secureMask = secure.housingItem
            notesMask = notes.housingItem
            weatherMask = weatherRegion
            launcherMask = launcher.housingItem
        })
    }

    mask: Region {
        item: root.maskItem

        Region {
            item: root.controlsMask
        }
        Region {
            item: root.notesMask
        }
        Region {
            item: root.weatherMask
        }
        Region {
            item: root.secureMask
        }
        Region {
            item: root.launcherMask
        }
    }

    Loader {
        active: (root.anyOpen || root.launcherShown) && !clock.pointerDown && !controls.pointerDown && !notes.pointerDown && !weather.pointerDown
        sourceComponent: dismissWindow
    }

    Component {
        id: dismissWindow
        PanelWindow {
            screen: root.screen
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.layer: WlrLayer.Top

            anchors {
                top: true
                right: true
                bottom: true
                left: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeAll()
            }
        }
    }

    // Floats over the desktop: one shadow from everything's combined outline, drawn beneath the real
    // scene so the fused circles cast a single shape and the text keeps its own rendering.
    // The effect blurs an offscreen copy of its source, so the copy covers only what is drawn, not the
    // whole strip the bar reserves for its panels.
    readonly property rect shadowRect: {
        const pad = 40
        let left = clock.x + clock.housingItem.x
        let top = clock.y + clock.housingItem.y
        let right = left + clock.housingItem.width
        let bottom = top + clock.housingItem.height
        for (const item of [notes, weather, controls, secure, launcher]) {
            left = Math.min(left, item.x)
            top = Math.min(top, item.y)
            right = Math.max(right, item.x + item.width)
            bottom = Math.max(bottom, item.y + item.height)
        }
        return Qt.rect(left - pad, top - pad, right - left + pad * 2, bottom - top + pad * 2)
    }

    Loader {
        active: ClockConfig.shadow
        x: root.shadowRect.x
        y: root.shadowRect.y
        width: root.shadowRect.width
        height: root.shadowRect.height
        sourceComponent: Item {
            ShaderEffectSource {
                id: copy
                anchors.fill: parent
                visible: false
                sourceItem: scene
                sourceRect: root.shadowRect
            }
            MultiEffect {
                anchors.fill: parent
                source: copy
                shadowEnabled: true
                shadowColor: "black"
                shadowOpacity: 0.45
                shadowBlur: 0.8
                blurMax: 32
                shadowVerticalOffset: 4
            }
        }
    }

    Item {
        id: scene
        anchors.fill: parent

        // Docked, the clock's leading slot holds weather at the far end, then notifications next to the time.
        Item {
            id: weatherSlot
            parent: clock.leadSlot
            width: root.vertical ? parent.width : weather.body * root.weatherP
            height: root.vertical ? weather.body * root.weatherP : parent.height
        }

        Item {
            id: notesSlot
            parent: clock.leadSlot
            x: root.vertical ? 0 : weatherSlot.width
            y: root.vertical ? weatherSlot.height : 0
            width: root.vertical ? parent.width : root.diameter * root.notesP
            height: root.vertical ? root.diameter * root.notesP : parent.height
        }

        // Declared before the clock so the notification circle emerges from beneath its leading end.
        NotificationCenter {
            id: notes
            x: root.vertical
                ? (circleRight ? root.notesCross + root.diameter - width : root.notesCross)
                : root.notesAlong + root.diameter - width
            y: root.vertical
                ? root.notesAlong + root.diameter - height
                : (circleBottom ? root.notesCross + root.diameter - height : root.notesCross)
            diameter: root.diameter
            edge: root.placement
            attach: root.join
            motion: ClockConfig.motion
            // The notch's end padding belongs to whichever circle sits outermost.
            endPad: root.notesEndPad * root.join * (1 - Math.min(1, root.weatherP))
            opacity: root.coverFade
            enabled: !root.covered
            quiet: root.calendarOpen || root.controlsOpen || root.weatherOpen || root.covered
            docked: root.docked
            badgeSlot: notesSlot
            bodySlot: clock.accessorySlot
        }

        WeatherCircle {
            id: weather
            x: root.vertical
                ? (circleRight ? root.notesCross + root.diameter - width : root.notesCross)
                : root.weatherAlong + body - width
            y: root.vertical
                ? root.weatherAlong + body - height
                : (circleBottom ? root.notesCross + root.diameter - height : root.notesCross)
            diameter: root.diameter
            digitSize: clock.faceDigit
            periodSize: clock.periodSize
            edge: root.placement
            attach: root.join
            motion: ClockConfig.motion
            endPad: root.weatherEndPad * root.join * Math.min(1, root.weatherP)
            opacity: root.coverFade
            enabled: !root.covered
            docked: root.docked
            yielding: !root.docked && notes.showing
            // Fades out beneath the notification panel growing over its spot, not on top of it.
            z: yielding ? -1 : 0
            slot: weatherSlot
            bodySlot: clock.accessorySlot
            // Along a side bar the pill opens upward from above the clock, so the space above it is the limit.
            maxPanelHeight: root.vertical ? root.weatherAlong + body - Theme.floatMargin : Infinity
        }

        // Holds the weather circle to whatever follows it, the notification circle or the clock.
        Rectangle {
            readonly property real drop: {
                const t = Math.max(0, Math.min(1, (root.weatherP - 0.5) / 0.5))
                return 1 - t * t * (3 - 2 * t)
            }
            readonly property real fuse: Math.max(0, (root.join - 0.6) / 0.4)
            readonly property real cross: root.diameter * Math.max(drop, fuse)
            readonly property real start: root.weatherAlong + weather.body / 2
            readonly property real span: (root.notesP > 0.001 ? root.notesAlong + root.diameter / 2 : root.clockStart) - start
            // Beneath the circles, so while it widens into the notch it never covers their contents.
            z: -1
            visible: root.weatherP > 0.001 && !root.docked && cross > 0.5
            color: Theme.surface
            opacity: root.coverFade
            x: root.vertical ? root.notesCross + (root.diameter - cross) / 2 : start
            y: root.vertical ? start : root.notesCross + (root.diameter - cross) / 2
            width: root.vertical ? cross : span
            height: root.vertical ? span : cross
        }

        // The water drop: a neck holds the separating circle to the clock, thinning until it lets go. While
        // fusing into the notch it widens again, like the status circle's.
        Rectangle {
            readonly property real drop: {
                const t = Math.max(0, Math.min(1, (root.notesP - 0.5) / 0.5))
                return 1 - t * t * (3 - 2 * t)
            }
            readonly property real fuse: Math.max(0, (root.join - 0.6) / 0.4)
            readonly property real cross: root.diameter * Math.max(drop, fuse)
            readonly property real start: root.notesAlong + root.diameter / 2
            readonly property real span: root.clockStart - root.notesAlong
            z: -1
            visible: root.notesP > 0.001 && !root.docked && cross > 0.5
            color: Theme.surface
            opacity: root.coverFade
            x: root.vertical ? root.notesCross + (root.diameter - cross) / 2 : start
            y: root.vertical ? start : root.notesCross + (root.diameter - cross) / 2
            width: root.vertical ? cross : span
            height: root.vertical ? span : cross
        }

        // Fuses the status circle into the notch: the gap closes and this neck widens with the pill-to-notch motion.
        Rectangle {
            readonly property Item housing: clock.housingItem
            // Forms only once the gap is nearly closed, so it never stretches into a hairline across it.
            readonly property real cross: root.diameter * Math.max(0, (root.join - 0.6) / 0.4)
            readonly property real housingEnd: root.vertical
                ? clock.y + housing.y + housing.height
                : clock.x + housing.x + housing.width
            readonly property real start: housingEnd - root.diameter / 2
            readonly property real span: (root.vertical ? root.circleY : root.circleX) + root.diameter / 2 - start
            visible: root.join > 0.001 && !root.docked
            color: Theme.surface
            x: root.vertical ? root.circleX + (root.diameter - cross) / 2 : start
            y: root.vertical ? start : root.circleY + (root.diameter - cross) / 2
            width: root.vertical ? cross : span
            height: root.vertical ? span : cross
        }

        ClockWidget {
            id: clock
            x: root.vertical ? (root.placement === "right" ? root.width - width : 0) : (root.width - width) / 2 - root.lift
            y: root.vertical ? (root.height - height) / 2 - root.lift : (root.placement === "bottom" ? root.height - height : 0)
            edge: root.placement
            localeName: ClockConfig.locale
            use24Hour: ClockConfig.use24Hour
            showPeriod: ClockConfig.showPeriod
            motion: ClockConfig.motion
            presentation: ClockConfig.presentation
            opacity: root.coverFade
            enabled: !root.covered
            trailing: root.docked ? (root.vertical ? controls.status.height : controls.status.width) : 0
            trailingPad: root.endPad
            leading: root.docked && root.leadP > 0.001 ? root.diameter * root.notesP + weather.body * root.weatherP : 0
            leadingPad: root.leadEndPad
            leadReveal: root.leadP
            leadFuse: root.leadP
            externalHover: root.docked && (controls.circleHovered || notes.circleHovered || weather.hovered)
            // The control center, notifications, and weather share the calendar's place; a swap blends their sizes.
            readonly property real controlsWeight: controls.openP
            readonly property real notesWeight: notes.openP
            readonly property real weatherWeight: weather.openP
            readonly property real weights: controlsWeight + notesWeight + weatherWeight
            accessoryOpen: root.docked && (controls.opened || notes.showing || weather.opened)
            accessoryProgress: root.docked ? weights : 0
            accessoryWidth: weights > 0.001
                ? (controls.panelWidth * controlsWeight + notes.panelWidth * notesWeight
                   + weather.panelWidth * weatherWeight) / weights
                : notes.showing ? notes.panelWidth : weather.opened ? weather.panelWidth : controls.panelWidth
            accessoryHeight: weights > 0.001
                ? (controls.panelHeight * controlsWeight + notes.panelHeight * notesWeight
                   + weather.panelHeight * weatherWeight) / weights
                : notes.showing ? notes.panelHeight : weather.opened ? weather.panelHeight : controls.panelHeight
        }

        ControlCenter {
            id: controls
            x: circleRight ? root.circleX + root.diameter - width : root.circleX
            y: circleBottom ? root.circleY + root.diameter - height : root.circleY
            diameter: root.diameter
            edge: root.placement
            attach: root.join
            motion: ClockConfig.motion
            batteryPercentage: ClockConfig.batteryPercentage
            tailLabelSize: clock.periodSize
            endPad: root.endPad * root.join
            opacity: root.coverFade
            enabled: !root.covered
            docked: root.docked
            statusSlot: clock.trailSlot
            bodySlot: clock.accessorySlot
        }

        SecurePrompt {
            id: secure
            edge: root.placement
            from: Qt.rect(clock.x + clock.housingItem.x, clock.y + clock.housingItem.y,
                          clock.housingItem.width, clock.housingItem.height)
            notch: clock.notchAmount
            motion: ClockConfig.motion
            shown: root.secureShown
        }

        LauncherPanel {
            id: launcher
            edge: root.placement
            from: secure.from
            notch: clock.notchAmount
            motion: ClockConfig.motion
            shown: root.launcherShown
            onSettingChosen: section => controls.openSettings(section)
        }
    }
}
