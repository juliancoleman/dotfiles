import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import ".."
import "../Clock"
import "../Common"
import "../Settings"
import "../Status"

// The status circle grows into this panel. The circle holds its corner (nearest the clock and the
// screen edge) while the housing opens away from both, mirroring how the clock opens the calendar.
Item {
    id: root

    property string edge: "right"
    property real diameter: 34
    property real attach: 0
    property string motion: "easeOut"
    property string batteryPercentage: "low"
    property int tailLabelSize: 0

    property bool opened: false
    property real openProgress: 0
    property real hoverProgress: 0
    readonly property real openP: Math.max(0, openProgress)
    readonly property real hoverP: Math.max(0, hoverProgress)
    readonly property real zoom: 1 + hoverP * (1 - Math.min(1, openP)) * (openZoom - 1)
    readonly property real openZoom: 1.06
    readonly property bool pointerDown: circleHit.pressed
    property alias housingItem: housing
    readonly property alias status: status
    readonly property bool circleHovered: circleHit.containsMouse

    // Docked into the notch, the circle and body live inside the clock's housing instead of this one.
    property bool docked: false
    property Item statusSlot: null
    property Item bodySlot: null
    readonly property bool lent: docked && !!statusSlot && !!bodySlot
    // Docked to the notch, the status circle itself becomes the close action, like weather and notifications.
    readonly property bool closeActionInFace: lent && opened
    // The panel has finished folding away.
    signal folded()

    readonly property bool circleRight: edge === "right"
    readonly property bool circleBottom: edge === "bottom"

    // Lent to the notch, the clock's housing supplies the gutter.
    readonly property real pad: lent ? 0 : Theme.panelPad
    readonly property real gap: Theme.tileGap
    readonly property real column: 70
    readonly property real gridWidth: column * 4 + gap * 3
    readonly property real panelWidth: gridWidth + pad * 2
    readonly property real panelHeight: diameter + Theme.panelHeaderGap + shownContent + pad

    // "" shows the grid; otherwise the id of the full-width page that replaced it. Settings are pages here
    // too: "settings" lists the sections, and "settings/<section>" holds one section's controls.
    property string page: ""
    readonly property string settingsPrefix: "settings/"
    readonly property bool onSettings: page === "settings" || page.startsWith(settingsPrefix)
    readonly property string settingsSection: page.startsWith(settingsPrefix) ? page.slice(settingsPrefix.length) : ""
    // The DualSense whose lights "bluetooth/dualsense" shows.
    property var dualSenseDevice: null
    // Pages declare themselves below (ControlPage); the one showing supplies the panel's height and title.
    readonly property var currentPage: {
        const pages = body.children
        for (let i = 0; i < pages.length; ++i)
            if (pages[i] instanceof ControlPage && pages[i].current)
                return pages[i]
        return null
    }
    readonly property real contentY: circleBottom ? pad : diameter + Theme.panelHeaderGap
    // Rows of a scrolling page stay within the height the bar reserves for this panel.
    readonly property real maxPageHeight: reserveHeight - diameter - Theme.panelHeaderGap - pad
    readonly property real pageContent: currentPage ? currentPage.height : grid.height
    property real shownContent: pageContent
    Behavior on shownContent {
        enabled: root.opened
        NumberAnimation {
            duration: Theme.durationFor(root.motion)
            easing.type: Theme.easingFor(root.motion)
            easing.overshoot: Theme.springOvershoot
        }
    }

    readonly property string pageTitle: currentPage ? currentPage.title : ""

    // One level up: a settings section to the section list, a DualSense's lights to Bluetooth, any other page
    // to the grid.
    function parentPage() {
        if (settingsSection !== "")
            return "settings"
        return page === "bluetooth/dualsense" ? "bluetooth" : ""
    }

    // Escape steps back out one level: section to settings, page to grid, grid to closed.
    function stepBack() {
        if (page !== "")
            page = parentPage()
        else
            close()
    }

    // Opens straight onto settings, or one section of it, as the launcher does. The page is picked before
    // opening so the height snaps rather than growing from the grid's.
    function openSettings(section) {
        page = section ? settingsPrefix + section : "settings"
        open()
    }

    // Super+Comma: settings when they aren't showing, closed when they are.
    function toggleSettings() {
        if (opened && onSettings)
            close()
        else
            openSettings("")
    }

    // Most the panel takes, so the bar can reserve room for the spring's overshoot. A constant: the window is
    // sized from it, and a layer-shell resize mid-animation drops a frame.
    readonly property real reserveHeight: 530
    readonly property real reserveWidth: gridWidth + Theme.panelPad * 2

    // Pad past the circle along the edge, grown in while fusing so docking into the clock lands flush.
    property real endPad: 0
    readonly property bool alongY: edge === "left" || edge === "right"
    readonly property real restWidth: status.width + (alongY ? 0 : endPad)
    readonly property real restHeight: status.height + (alongY ? endPad : 0)
    readonly property real housingWidth: lent ? 0 : restWidth + (panelWidth - restWidth) * openP
    readonly property real housingHeight: lent ? 0 : restHeight + (panelHeight - restHeight) * openP

    implicitWidth: housingWidth
    implicitHeight: housingHeight
    width: implicitWidth
    height: implicitHeight

    function open() {
        if (opened)
            return
        opened = true
        aimOpen(true)
        aimHover(false)
    }

    function close() {
        if (!opened)
            return
        opened = false
        aimOpen(false)
        aimHover(circleHit.containsMouse)
        if (motion === "none")
            page = ""
    }

    function toggle() {
        if (opened)
            close()
        else
            open()
    }

    function aimOpen(next) {
        openEase.aim(next ? 1 : 0)
    }

    function aimHover(next) {
        hoverEase.aim(next && !opened ? 1 : 0)
    }

    // Corners on the screen edge, and those facing the clock, square off as the circle fuses into the notch.
    function corner(outer, facingClock) {
        const radius = Math.min(status.width, status.height) / 2 * (1 - Math.min(1, openP)) + Theme.radius * openP
        return outer || facingClock ? radius * (1 - Math.max(0, Math.min(1, attach))) : radius
    }

    function batteryLine() {
        const battery = status.battery
        if (!battery.available)
            return ""
        const device = battery.device
        if (device.state === UPowerDeviceState.FullyCharged)
            return I18n.tr("Charged")
        if (battery.charging) {
            const full = Number(device.timeToFull)
            return full > 0 ? I18n.tr("%1 until full").arg(duration(full)) : I18n.tr("Charging")
        }
        const empty = Number(device.timeToEmpty)
        return empty > 0 ? I18n.tr("%1 left").arg(duration(empty)) : ""
    }

    function duration(seconds) {
        const minutes = Math.round(seconds / 60)
        const hours = Math.floor(minutes / 60)
        return hours > 0 ? hours + ":" + String(minutes % 60).padStart(2, "0") : I18n.tr("%1 min").arg(minutes)
    }

    readonly property var wifiDevice: {
        const list = Networking.devices ? Networking.devices.values : []
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].type === DeviceType.Wifi)
                return list[i]
        }
        return null
    }
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: {
        const list = Bluetooth.devices ? Bluetooth.devices.values : []
        const next = []
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].connected)
                next.push(list[i])
        }
        return next
    }

    Tween {
        id: openEase
        target: root
        property: "openProgress"
        motion: root.motion
        // The next open starts from the grid; reset once the panel has folded away unseen.
        onStopped: if (!root.opened) {
            root.page = ""
            root.folded()
        }
    }

    Tween {
        id: hoverEase
        target: root
        property: "hoverProgress"
        motion: root.motion
    }

    // The sources are shared by every screen's panel; each counts the panels showing it and polls (or runs
    // its meter taps) only while one does. A source is wanted only on the pages that show it: the grid has
    // the meters, usage, brightness, fans, what's running and (without Wi-Fi) wired; the audio pages their
    // meter; the fans, Ethernet, display and running pages their own.
    readonly property bool gridShown: opened && page === ""
    readonly property bool metersShown: gridShown || opened && (page === "output" || page === "input")
    readonly property bool fansShown: gridShown || opened && page === "fans"
    readonly property bool brightnessShown: gridShown || opened && page === "display"
    readonly property bool wiredWatched: !wifiDevice && (gridShown || opened && page === "ethernet")
    readonly property bool appsShown: gridShown || opened && page === "apps"
    onGridShownChanged: SystemSource.watchers += gridShown ? 1 : -1
    onBrightnessShownChanged: Brightness.watchers += brightnessShown ? 1 : -1
    onMetersShownChanged: Meter.watchers += metersShown ? 1 : -1
    onAppsShownChanged: RunningApps.watchers += appsShown ? 1 : -1
    onFansShownChanged: {
        const delta = fansShown ? 1 : -1
        FanSource.watchers += delta
        FanControl.watchers += delta
    }
    onWiredWatchedChanged: WiredSource.watchers += wiredWatched ? 1 : -1
    Component.onDestruction: {
        if (gridShown)
            SystemSource.watchers -= 1
        if (brightnessShown)
            Brightness.watchers -= 1
        if (metersShown)
            Meter.watchers -= 1
        if (fansShown) {
            FanSource.watchers -= 1
            FanControl.watchers -= 1
        }
        if (wiredWatched)
            WiredSource.watchers -= 1
        if (appsShown)
            RunningApps.watchers -= 1
    }

    Rectangle {
        id: housing
        visible: !root.lent
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
        topLeftRadius: root.corner(root.edge === "top" || root.edge === "left", true)
        topRightRadius: root.corner(root.edge === "top" || root.edge === "right", root.alongY)
        bottomLeftRadius: root.corner(root.edge === "bottom" || root.edge === "left", !root.alongY)
        bottomRightRadius: root.corner(root.edge === "bottom" || root.edge === "right", false)

        Item {
            id: body
            parent: root.lent ? root.bodySlot : housing
            width: root.panelWidth
            height: root.panelHeight
            x: root.lent ? 0 : root.circleRight ? housing.width - width : 0
            y: root.lent ? 0 : root.circleBottom ? housing.height - height : 0
            opacity: Math.min(1, root.openP)
            visible: root.openP > 0.001
            enabled: root.opened

            Item {
                id: header
                x: root.pad + Theme.panelHeaderInset
                y: root.circleBottom ? body.height - root.diameter : 0
                width: body.width - (root.pad + Theme.panelHeaderInset) * 2
                height: root.diameter

                PageLayer {
                    home: true
                    motion: root.motion
                    shown: root.page === ""
                    anchors.fill: parent

                    PanelCloseButton {
                        id: closeButton
                        opened: root.openP
                        motion: root.motion
                        label: I18n.tr("Close control center")
                        visible: !root.closeActionInFace
                        // Centered on the status circle it replaces, whichever end of the panel that is.
                        readonly property real ringCenter: root.diameter / 2 - (root.pad + Theme.panelHeaderInset)
                        triggerCenter: root.circleRight ? parent.width - ringCenter : ringCenter
                        onActivated: root.close()
                    }

                    Row {
                        id: batteryRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: root.circleRight ? (closeButton.visible ? closeButton.left : parent.right) : undefined
                        anchors.left: root.circleRight ? undefined : (closeButton.visible ? closeButton.right : parent.left)
                        anchors.rightMargin: 6
                        anchors.leftMargin: 6
                        layoutDirection: root.circleRight ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: 6
                        visible: root.status.battery.available

                        TickerNumber {
                            id: percent
                            value: root.status.batteryPercent
                            suffix: "%"
                            motion: root.motion
                            color: Theme.textPrimary
                            fontPixelSize: Theme.textStrong
                            fontWeight: Font.Medium
                        }

                        Text {
                            anchors.baseline: percent.baseline
                            text: root.batteryLine()
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textLabel
                        }
                    }

                    // Settings, power and Do Not Disturb live in the header, beside the battery.
                    SettingsButton {
                        id: settings
                        opened: root.openP
                        motion: root.motion
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.circleRight ? 0 : parent.width - width
                        onActivated: root.page = "settings"
                    }

                    SettingsButton {
                        id: power
                        opened: root.openP
                        motion: root.motion
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.circleRight ? settings.x + settings.width + 6 : settings.x - width - 6
                        icon: "power-off"
                        label: I18n.tr("Power")
                        onActivated: root.page = "power"
                    }

                    SettingsButton {
                        opened: root.openP
                        motion: root.motion
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.circleRight ? power.x + power.width + 6 : power.x - width - 6
                        icon: "moon"
                        label: I18n.tr("Do Not Disturb")
                        toggle: true
                        on: ClockConfig.doNotDisturb
                        onActivated: {
                            ClockConfig.doNotDisturb = !ClockConfig.doNotDisturb
                            ClockConfig.save()
                        }
                    }
                }

                PageLayer {
                    motion: root.motion
                    shown: root.page !== ""
                    anchors.fill: parent

                    BackButton {
                        anchors.left: parent.left
                        anchors.leftMargin: -Theme.panelHeaderInset
                        anchors.verticalCenter: parent.verticalCenter
                        activeFocusOnTab: root.page !== ""
                        title: root.pageTitle
                        onActivated: root.page = root.parentPage()
                    }
                }
            }

            ControlPage {
                panel: root
                name: "wifi"
                title: I18n.tr("Wi-Fi")

                WifiPage {
                    width: parent.width
                    device: root.wifiDevice
                    active: parent.active
                    motion: root.motion
                }
            }

            ControlPage {
                panel: root
                name: "ethernet"
                title: I18n.tr("Ethernet")

                EthernetPage {
                    width: parent.width
                    active: parent.active
                    motion: root.motion
                }
            }

            ControlPage {
                panel: root
                name: "bluetooth"
                title: I18n.tr("Bluetooth")
                // A DualSense's page goes deeper, so Bluetooth leaves the way the grid does.
                behind: root.page === "bluetooth/dualsense"

                BluetoothPage {
                    width: parent.width
                    adapter: root.adapter
                    active: parent.active
                    motion: root.motion
                    onDualSenseRequested: device => {
                        root.dualSenseDevice = device
                        root.page = "bluetooth/dualsense"
                    }
                }
            }

            ControlPage {
                panel: root
                name: "bluetooth/dualsense"
                title: I18n.tr("%1 lights").arg(DualSenseLights.model(root.dualSenseDevice ? root.dualSenseDevice.address : ""))

                DualSensePage {
                    width: parent.width
                    device: root.dualSenseDevice
                    motion: root.motion
                }
            }

            ControlPage {
                panel: root
                name: "output"
                title: I18n.tr("Output")

                AudioPage {
                    width: parent.width
                    source: root.status.output
                    motion: root.motion
                }
            }

            ControlPage {
                panel: root
                name: "input"
                title: I18n.tr("Input")

                AudioPage {
                    width: parent.width
                    input: true
                    source: root.status.input
                    motion: root.motion
                }
            }

            ControlPage {
                panel: root
                name: "fans"
                title: I18n.tr("Fans")

                FansPage {
                    width: parent.width
                    motion: root.motion
                }
            }

            ControlPage {
                panel: root
                name: "power"
                title: I18n.tr("Power")

                PowerPage {
                    width: parent.width
                    active: parent.active
                    motion: root.motion
                    onActed: root.close()
                }
            }

            ControlPage {
                panel: root
                name: "display"
                title: I18n.tr("Display")

                DisplayPage {
                    width: parent.width
                    active: parent.active
                    motion: root.motion
                }
            }

            ControlPage {
                panel: root
                name: "keyboard"
                title: I18n.tr("Keyboard")

                KeyboardPage {
                    width: parent.width
                    motion: root.motion
                }
            }

            ControlPage {
                panel: root
                name: "apps"
                title: I18n.tr("Running")

                AppsPage {
                    width: parent.width
                    active: parent.active
                    motion: root.motion
                    maxHeight: root.maxPageHeight
                    onActed: root.close()
                }
            }

            // One page for the section list and for each section; the title follows the section.
            ControlPage {
                panel: root
                name: "settings"
                current: root.onSettings
                readonly property var section: SettingsModel.section(root.settingsSection)
                title: root.settingsSection === "" ? I18n.tr("Settings") : section ? I18n.tr(section.title) : ""

                SettingsPages {
                    width: parent.width
                    section: root.settingsSection
                    motion: root.motion
                    active: parent.active
                    maxHeight: root.maxPageHeight
                    onSectionChosen: id => root.page = root.settingsPrefix + id
                }
            }

            PageLayer {
                home: true
                motion: root.motion
                shown: root.page === ""
                x: root.pad
                y: root.contentY
                width: root.gridWidth
                height: grid.height

                // One page, groups split by hairlines: links, faders, usage, fans. Rules take a gap either
                // side so each sits midway between its groups.
                Column {
                    id: grid
                    width: root.gridWidth
                    spacing: root.gap

                    Item {
                        id: links
                        width: parent.width
                        height: Theme.rowHeight
                        readonly property real cell: (width - Theme.line - root.gap * 2) / 2

                        ToggleTile {
                            width: links.cell
                            motion: root.motion
                            visible: !!root.wifiDevice
                            icon: Networking.wifiEnabled ? "wifi" : "wifi-off"
                            wifiBars: root.status.network.wifi ? root.status.network.bars : 3
                            on: Networking.wifiEnabled
                            title: I18n.tr("Wi-Fi")
                            subtitle: !Networking.wifiEnabled ? I18n.tr("Off")
                                : root.status.network.wifiNetwork ? root.status.network.wifiNetwork.name
                                : I18n.tr("Not connected")
                            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                            onOpened: root.page = "wifi"
                        }

                        // Without a Wi-Fi card, the same place holds the wired link: the knob is the kill switch
                        // for all networking, the row opens the link's details and throughput.
                        ToggleTile {
                            width: links.cell
                            motion: root.motion
                            visible: !root.wifiDevice
                            icon: WiredSource.on && WiredSource.address !== "" ? "ethernet" : "ethernet-off"
                            on: WiredSource.on
                            title: I18n.tr("Ethernet")
                            subtitle: !WiredSource.on ? I18n.tr("Off")
                                : WiredSource.address === "" ? I18n.tr("Not connected")
                                : WiredSource.address
                            onToggled: WiredSource.toggle()
                            onOpened: root.page = "ethernet"
                        }

                        Rule {
                            vertical: true
                            x: links.cell + root.gap
                            height: Theme.knobSize
                            anchors.verticalCenter: parent.verticalCenter
                            visible: bluetooth.visible
                        }

                        ToggleTile {
                            id: bluetooth
                            readonly property bool enabledNow: !!root.adapter && root.adapter.enabled
                            x: links.width - width
                            width: links.cell
                            motion: root.motion
                            visible: !!root.adapter
                            icon: enabledNow ? "bluetooth" : "bluetooth-off"
                            on: enabledNow
                            title: I18n.tr("Bluetooth")
                            subtitle: !enabledNow ? I18n.tr("Off")
                                : root.connectedDevices.length === 1 ? root.connectedDevices[0].name
                                : root.connectedDevices.length > 1 ? I18n.tr("%1 devices").arg(root.connectedDevices.length)
                                : I18n.tr("On")
                            onToggled: root.adapter.enabled = !root.adapter.enabled
                            onOpened: root.page = "bluetooth"
                        }
                    }

                    Rule { width: parent.width }

                    Column {
                        id: faders
                        width: parent.width
                        spacing: root.gap
                        visible: root.status.output.available || root.status.input.available || Brightness.available
                            || display.visible || KeyboardBacklight.available

                        SliderTile {
                            width: parent.width
                            motion: root.motion
                            visible: root.status.output.available
                            title: I18n.tr("Volume")
                            icon: root.status.output.muted || root.status.output.level <= 0.005 ? "volume-muted" : "volume"
                            value: root.status.output.level
                            muted: root.status.output.muted
                            meter: Meter.output
                            onMoved: next => {
                                const audio = root.status.output.sink.audio
                                audio.muted = false
                                audio.volume = next
                            }
                            onToggled: root.status.output.sink.audio.muted = !root.status.output.muted
                            opens: true
                            onOpened: root.page = "output"
                        }

                        SliderTile {
                            width: parent.width
                            motion: root.motion
                            visible: root.status.input.available
                            title: I18n.tr("Microphone")
                            icon: root.status.input.muted || root.status.input.level <= 0.005 ? "microphone-muted" : "microphone"
                            value: root.status.input.level
                            muted: root.status.input.muted
                            meter: Meter.input
                            meterActive: Meter.inputInUse
                            onMoved: next => {
                                const audio = root.status.input.sink.audio
                                audio.muted = false
                                audio.volume = next
                            }
                            onToggled: root.status.input.sink.audio.muted = !root.status.input.muted
                            opens: true
                            onOpened: root.page = "input"
                        }

                        SliderTile {
                            width: parent.width
                            motion: root.motion
                            visible: Brightness.available
                            title: I18n.tr("Brightness")
                            icon: "brightness"
                            toggleable: false
                            value: Brightness.level
                            onMoved: next => Brightness.set(next)
                            adjustable: !AutoBrightness.active
                            opens: true
                            onOpened: root.page = "display"
                        }

                        // Without a backlight there's no slider to open the display page from.
                        ToggleTile {
                            id: display
                            width: parent.width
                            motion: root.motion
                            visible: !Brightness.available && Displays.available
                            icon: "monitor"
                            toggleable: false
                            title: I18n.tr("Display")
                            subtitle: Displays.outputs.map(output => I18n.tr("%1 Hz").arg(Displays.hertz(output.current)))
                                .join(" · ")
                            onOpened: root.page = "display"
                        }

                        SliderTile {
                            width: parent.width
                            motion: root.motion
                            visible: KeyboardBacklight.available
                            title: I18n.tr("Keyboard brightness")
                            icon: "keyboard"
                            toggleable: false
                            value: KeyboardBacklight.level
                            onMoved: next => KeyboardBacklight.set(next)
                            opens: true
                            onOpened: root.page = "keyboard"
                        }
                    }

                    Rule {
                        width: parent.width
                        visible: faders.visible
                    }

                    UsageTile {
                        width: parent.width
                        motion: root.motion
                        readings: [
                            { icon: "memory", name: I18n.tr("Memory"), value: SystemSource.memory },
                            { icon: "cpu", name: I18n.tr("CPU"), value: SystemSource.cpu },
                            { icon: "disk", name: I18n.tr("Disk"), value: SystemSource.disk }
                        ]
                    }

                    Rule { width: parent.width }

                    // What's running, and how much of it has no window left to show for itself.
                    ToggleTile {
                        width: parent.width
                        motion: root.motion
                        icon: "view-large"
                        toggleable: false
                        readonly property int hidden: RunningApps.apps.filter(app => app.windows === 0).length
                        on: hidden > 0
                        title: I18n.tr("Running")
                        subtitle: (RunningApps.apps.length === 1 ? I18n.tr("1 app")
                                : I18n.tr("%1 apps").arg(RunningApps.apps.length))
                            + (hidden > 0 ? " · " + I18n.tr("%1 without a window").arg(hidden) : "")
                        onOpened: root.page = "apps"
                    }

                    Rule {
                        width: parent.width
                        visible: fans.visible
                    }

                    ToggleTile {
                        id: fans
                        width: parent.width
                        motion: root.motion
                        visible: FanSource.available || FanControl.ready
                        icon: "fan"
                        toggleable: false
                        on: FanControl.manualCount > 0
                        title: I18n.tr("Fans")
                        // The sysfs poller rests while the helper reports, so take speeds from whichever is live.
                        subtitle: (FanControl.manualCount > 0 ? I18n.tr("Manual") : I18n.tr("Auto")) + " · "
                            + FanSource.rpmText(FanControl.ready ? FanControl.fastest : FanSource.fastest)
                        onOpened: root.page = "fans"
                    }
                }
            }
        }

        StatusIndicator {
            id: status
            parent: root.lent ? root.statusSlot : housing
            housed: false
            x: root.lent ? 0 : root.circleRight ? housing.width - width : 0
            y: root.lent ? 0 : root.circleBottom ? housing.height - height : 0
            diameter: root.diameter
            edge: root.edge
            attach: root.attach
            motion: root.motion
            batteryPercentage: root.batteryPercentage
            tailLabelSize: root.tailLabelSize
            closeAction: root.closeActionInFace
            labelSuppressed: root.opened && !root.lent
            opacity: root.lent ? 1 : 1 - Math.min(1, root.openP)

            MouseArea {
                id: circleHit
                anchors.fill: parent
                enabled: !root.opened || root.closeActionInFace
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (!pressed) root.aimHover(containsMouse)
                Accessible.role: Accessible.Button
                Accessible.name: root.closeActionInFace ? I18n.tr("Close control center") : I18n.tr("Control center")
                onPressed: root.toggle()
                onReleased: root.aimHover(containsMouse)
            }
        }
    }
}
