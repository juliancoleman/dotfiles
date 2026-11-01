import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import ".."
import "../Clock"
import "../Common"
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

    readonly property bool circleRight: edge === "right"
    readonly property bool circleBottom: edge === "bottom"

    readonly property real pad: 8
    readonly property real gap: 6
    readonly property real column: 70
    readonly property real gridWidth: column * 4 + gap * 3
    readonly property real panelWidth: gridWidth + pad * 2
    readonly property real panelHeight: diameter + 2 + shownContent + pad

    // "" shows the grid; otherwise the id of the full-width page that replaced it.
    property string page: ""
    readonly property real pageContent: page === "wifi" ? wifiPage.implicitHeight
        : page === "bluetooth" ? bluetoothPage.implicitHeight
        : page === "fans" ? fansPage.implicitHeight
        : page === "output" ? outputPage.implicitHeight
        : page === "input" ? inputPage.implicitHeight
        : page === "power" ? powerPage.implicitHeight
        : grid.height
    property real shownContent: pageContent
    Behavior on shownContent {
        enabled: root.opened
        NumberAnimation {
            duration: Theme.durationFor(root.motion)
            easing.type: Theme.easingFor(root.motion)
            easing.overshoot: Theme.springOvershoot
        }
    }

    // Escape steps back out one level: page to grid, grid to closed.
    function stepBack() {
        if (page !== "")
            page = ""
        else
            close()
    }
    // Tallest the panel gets, so the bar can reserve room for the spring's overshoot.
    readonly property real reserveHeight: 420

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
        run(openEase, "openProgress", next ? 1 : 0)
    }

    function aimHover(next) {
        run(hoverEase, "hoverProgress", next && !opened ? 1 : 0)
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
        const radius = Math.min(status.width, status.height) / 2 * (1 - Math.min(1, openP)) + 14 * openP
        return outer || facingClock ? radius * (1 - Math.max(0, Math.min(1, attach))) : radius
    }

    function batteryLine() {
        const battery = status.battery
        if (!battery.available)
            return ""
        const device = battery.device
        if (device.state === UPowerDeviceState.FullyCharged)
            return qsTr("Charged")
        if (battery.charging) {
            const full = Number(device.timeToFull)
            return full > 0 ? qsTr("%1 until full").arg(duration(full)) : qsTr("Charging")
        }
        const empty = Number(device.timeToEmpty)
        return empty > 0 ? qsTr("%1 left").arg(duration(empty)) : ""
    }

    function duration(seconds) {
        const minutes = Math.round(seconds / 60)
        const hours = Math.floor(minutes / 60)
        return hours > 0 ? hours + ":" + String(minutes % 60).padStart(2, "0") : minutes + " min"
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

    NumberAnimation {
        id: openEase
        target: root
        property: "openProgress"
        duration: Theme.durationFor(root.motion)
        easing.type: Theme.easingFor(root.motion)
        easing.overshoot: Theme.springOvershoot
        // The next open starts from the grid; reset once the panel has folded away unseen.
        onStopped: if (!root.opened) root.page = ""
    }

    NumberAnimation {
        id: hoverEase
        target: root
        property: "hoverProgress"
        duration: Theme.durationFor(root.motion)
        easing.type: Theme.easingFor(root.motion)
        easing.overshoot: Theme.springOvershoot
    }

    FanSource {
        id: fans
        active: root.opened
    }

    FanControl {
        id: fanControl
        active: root.opened
    }

    SystemSource {
        id: usage
        active: root.opened
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
                x: root.pad + 4
                y: root.circleBottom ? body.height - root.diameter : 0
                width: body.width - (root.pad + 4) * 2
                height: root.diameter

                PageLayer {
                    home: true
                    shown: root.page === ""
                    anchors.fill: parent

                    SettingsButton {
                        id: closeButton
                        opened: root.openP
                        icon: "close"
                        label: qsTr("Close")
                        anchors.verticalCenter: parent.verticalCenter
                        // Center the close mark over the status circle, like the weather panel:
                        // the circle's center sits 17px from the body edge, the header 12px, so +5.
                        x: root.circleRight ? parent.width - width / 2 - (root.diameter / 2 - (root.pad + 4)) : 0
                        onActivated: root.close()
                    }

                    Row {
                        id: batteryRow
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: root.circleRight ? closeButton.left : undefined
                        anchors.left: root.circleRight ? undefined : closeButton.right
                        anchors.rightMargin: 6
                        anchors.leftMargin: 6
                        layoutDirection: root.circleRight ? Qt.RightToLeft : Qt.LeftToRight
                        spacing: 6
                        visible: root.status.battery.available

                        Text {
                            id: percent
                            text: root.status.batteryPercent + "%"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }

                        Text {
                            anchors.baseline: percent.baseline
                            text: root.batteryLine()
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    SettingsButton {
                        id: settings
                        opened: root.openP
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.circleRight ? 0 : parent.width - width
                        onActivated: {
                            root.close()
                            ClockConfig.settingsOpen = true
                        }
                    }

                    SettingsButton {
                        id: power
                        opened: root.openP
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.circleRight ? settings.x + settings.width + 6 : settings.x - width - 6
                        icon: "power-off"
                        label: qsTr("Power")
                        onActivated: root.page = "power"
                    }

                    SettingsButton {
                        opened: root.openP
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.circleRight ? power.x + power.width + 6 : power.x - width - 6
                        icon: "moon"
                        label: qsTr("Do Not Disturb")
                        toggle: true
                        on: ClockConfig.doNotDisturb
                        onActivated: {
                            ClockConfig.doNotDisturb = !ClockConfig.doNotDisturb
                            ClockConfig.save()
                        }
                    }
                }

                PageLayer {
                    shown: root.page !== ""
                    anchors.fill: parent

                    Item {
                        id: back
                        anchors.left: parent.left
                        anchors.leftMargin: -4
                        anchors.verticalCenter: parent.verticalCenter
                        width: backRow.width + 12
                        height: 28
                        activeFocusOnTab: root.page !== ""
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Back")
                        Keys.onReturnPressed: root.page = ""
                        Keys.onSpacePressed: root.page = ""

                        Rectangle {
                            anchors.fill: parent
                            radius: 8
                            color: backHit.containsMouse || back.activeFocus ? Theme.track : "transparent"
                            border.width: back.activeFocus ? 1 : 0
                            border.color: Theme.today
                        }

                        Row {
                            id: backRow
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4

                            StatusGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 14
                                icon: "chevron-left"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.page === "wifi" ? qsTr("Wi-Fi")
                                    : root.page === "bluetooth" ? qsTr("Bluetooth")
                                    : root.page === "fans" ? qsTr("Fans")
                                    : root.page === "output" ? qsTr("Output")
                                    : root.page === "input" ? qsTr("Input")
                                    : root.page === "power" ? qsTr("Power") : ""
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }
                        }

                        MouseArea {
                            id: backHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.page = ""
                        }
                    }
                }
            }

            readonly property real contentY: root.circleBottom ? root.pad : root.diameter + 2

            PageLayer {
                shown: root.page === "wifi"
                x: root.pad
                y: body.contentY
                width: root.gridWidth
                height: wifiPage.implicitHeight

                WifiPage {
                    id: wifiPage
                    width: parent.width
                    device: root.wifiDevice
                    active: root.opened && root.page === "wifi"
                    motion: root.motion
                }
            }

            PageLayer {
                shown: root.page === "bluetooth"
                x: root.pad
                y: body.contentY
                width: root.gridWidth
                height: bluetoothPage.implicitHeight

                BluetoothPage {
                    id: bluetoothPage
                    width: parent.width
                    adapter: root.adapter
                    active: root.opened && root.page === "bluetooth"
                    motion: root.motion
                }
            }

            PageLayer {
                shown: root.page === "output"
                x: root.pad
                y: body.contentY
                width: root.gridWidth
                height: outputPage.implicitHeight

                AudioPage {
                    id: outputPage
                    width: parent.width
                    source: root.status.output
                    motion: root.motion
                }
            }

            PageLayer {
                shown: root.page === "input"
                x: root.pad
                y: body.contentY
                width: root.gridWidth
                height: inputPage.implicitHeight

                AudioPage {
                    id: inputPage
                    width: parent.width
                    input: true
                    source: root.status.input
                    motion: root.motion
                }
            }

            PageLayer {
                shown: root.page === "fans"
                x: root.pad
                y: body.contentY
                width: root.gridWidth
                height: fansPage.implicitHeight

                FansPage {
                    id: fansPage
                    width: parent.width
                    source: fans
                    control: fanControl
                    motion: root.motion
                }
            }

            PageLayer {
                shown: root.page === "power"
                x: root.pad
                y: body.contentY
                width: root.gridWidth
                height: powerPage.implicitHeight

                PowerPage {
                    id: powerPage
                    width: parent.width
                    active: root.opened && root.page === "power"
                    motion: root.motion
                    onActed: root.close()
                }
            }

            PageLayer {
                home: true
                shown: root.page === ""
                x: root.pad
                y: body.contentY
                width: root.gridWidth
                height: grid.height

                Flow {
                    id: grid
                    width: root.gridWidth
                    spacing: root.gap

                    ToggleTile {
                        width: root.column * 2 + root.gap
                        motion: root.motion
                        visible: !!root.wifiDevice
                        icon: Networking.wifiEnabled ? "wifi" : "wifi-off"
                        wifiBars: root.status.network.wifi ? root.status.network.bars : 3
                        on: Networking.wifiEnabled
                        title: qsTr("Wi-Fi")
                        subtitle: !Networking.wifiEnabled ? qsTr("Off")
                            : root.status.network.wifiNetwork ? root.status.network.wifiNetwork.name
                            : qsTr("Not connected")
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                        onOpened: root.page = "wifi"
                    }

                    ToggleTile {
                        width: root.column * 2 + root.gap
                        motion: root.motion
                        visible: !!root.adapter
                        readonly property bool enabledNow: !!root.adapter && root.adapter.enabled
                        icon: enabledNow ? "bluetooth" : "bluetooth-off"
                        on: enabledNow
                        title: qsTr("Bluetooth")
                        subtitle: !enabledNow ? qsTr("Off")
                            : root.connectedDevices.length === 1 ? root.connectedDevices[0].name
                            : root.connectedDevices.length > 1 ? qsTr("%1 devices").arg(root.connectedDevices.length)
                            : qsTr("On")
                        onToggled: root.adapter.enabled = !root.adapter.enabled
                        onOpened: root.page = "bluetooth"
                    }
                    SliderTile {
                        width: root.gridWidth
                        motion: root.motion
                        visible: root.status.output.available
                        title: qsTr("Volume")
                        icon: root.status.output.muted || root.status.output.level <= 0.005 ? "volume-muted" : "volume"
                        value: root.status.output.level
                        muted: root.status.output.muted
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
                        width: root.gridWidth
                        motion: root.motion
                        visible: root.status.input.available
                        title: qsTr("Microphone")
                        icon: root.status.input.muted || root.status.input.level <= 0.005 ? "microphone-muted" : "microphone"
                        value: root.status.input.level
                        muted: root.status.input.muted
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
                        width: root.gridWidth
                        motion: root.motion
                        visible: Brightness.available
                        title: qsTr("Brightness")
                        icon: "brightness"
                        toggleable: false
                        value: Brightness.level
                        onMoved: next => Brightness.set(next)
                    }

                    UsageTile {
                        width: root.gridWidth
                        readings: [
                            { icon: "memory", name: qsTr("Memory"), value: usage.memory },
                            { icon: "cpu", name: qsTr("CPU"), value: usage.cpu },
                            { icon: "disk", name: qsTr("Disk"), value: usage.disk }
                        ]
                    }

                    ToggleTile {
                        width: root.gridWidth
                        motion: root.motion
                        visible: fans.available || fanControl.ready
                        icon: "fan"
                        toggleable: false
                        on: fanControl.manualCount > 0
                        title: qsTr("Fans")
                        subtitle: fanControl.manualCount > 0
                            ? qsTr("Manual") + " · " + fans.rpmText(fans.fastest)
                            : fans.summary
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
            labelSuppressed: root.opened && !root.lent
            opacity: root.lent ? 1 : 1 - Math.min(1, root.openP)

            MouseArea {
                id: circleHit
                enabled: !root.opened
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (!pressed) root.aimHover(containsMouse)
                onPressed: root.toggle()
                onReleased: root.aimHover(containsMouse)
            }
        }
    }

    component PageLayer: Item {
        id: layer

        property bool shown: false
        property bool home: false
        property real shift: shown ? 0 : home ? -24 : 24

        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        enabled: shown
        transform: Translate { x: layer.shift }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durationFor(root.motion)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on shift {
            NumberAnimation {
                duration: Theme.durationFor(root.motion)
                easing.type: Theme.easingFor(root.motion)
                easing.overshoot: Theme.springOvershoot
            }
        }
    }
}
