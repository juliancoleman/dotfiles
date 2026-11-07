import QtQuick
import Quickshell.Bluetooth
import "../Common"

Item {
    id: page

    property var adapter: null
    property bool active: false
    property string motion: "easeOut"
    readonly property real maxListHeight: 240
    readonly property bool powered: !!adapter && adapter.enabled

    // Addresses we started pairing from here; once paired they're trusted and connected.
    property var pairing: ({})
    // The device's lights page was asked for (from its row's settings button).
    signal lightsRequested(var device)

    implicitHeight: content.implicitHeight

    function rank(device) {
        return device.connected ? 3 : device.state === BluetoothDeviceState.Connecting ? 2 : device.paired ? 1 : 0
    }

    readonly property var devices: {
        const list = adapter && adapter.devices ? adapter.devices.values : []
        return list.filter(d => d && (d.paired || d.connected || d.deviceName !== ""))
            .sort((a, b) => rank(b) - rank(a) || a.name.localeCompare(b.name))
    }

    // BlueZ's freedesktop icon name (from the device class or LE appearance) picks the glyph.
    readonly property var kinds: ({
        "input-gaming": "gamepad",
        "audio-headset": "headset",
        "audio-headphones": "headphones",
        "audio-card": "speaker",
        "multimedia-player": "speaker",
        "input-keyboard": "keyboard",
        "input-mouse": "mouse",
        "input-tablet": "tablet",
        "phone": "phone",
        "computer": "laptop",
        "video-display": "tv",
        "camera-video": "video",
        "camera-photo": "camera",
        "printer": "printer",
        "scanner": "printer"
    })
    // Plenty of LE devices report no class at all; their names usually say what they are.
    readonly property var namedKinds: [
        { pattern: /controller|gamepad|dualsense|dualshock|xbox|joy-?con|8bitdo/i, kind: "gamepad" },
        { pattern: /buds|airpods|headphone|earbud|\bwh-|\bwf-|beats/i, kind: "headphones" },
        { pattern: /keyboard|keychron/i, kind: "keyboard" },
        { pattern: /mouse|trackpad|mx master|mx anywhere/i, kind: "mouse" },
        { pattern: /watch|band\b/i, kind: "watch" },
        { pattern: /speaker|soundbar|soundlink|jbl/i, kind: "speaker" },
        { pattern: /iphone|pixel|galaxy|phone/i, kind: "phone" },
        { pattern: /macbook|laptop|thinkpad/i, kind: "laptop" },
        { pattern: /\btv\b|bravia/i, kind: "tv" }
    ]

    function kind(device) {
        const known = kinds[device.icon]
        if (known)
            return known
        for (const entry of namedKinds) {
            if (entry.pattern.test(device.name))
                return entry.kind
        }
        return "bluetooth"
    }

    function actions(device) {
        const list = []
        if (device.connected && Lightbars.available(device.address))
            list.push({ id: "lights", icon: "settings", label: I18n.tr("Lights") })
        // BlueZ keeps a record for trusted devices even after their pairing is lost; those need forgetting
        // before they can pair again.
        if (device.paired || device.bonded || device.trusted)
            list.push({ id: "forget", icon: "close", label: I18n.tr("Forget device") })
        return list
    }

    // Paired without a stored link key: BlueZ refuses HID from such devices, so it only looks connected.
    function unsaved(device) {
        return device.paired && !device.bonded
    }

    function status(device) {
        if (device.pairing)
            return I18n.tr("Pairing…")
        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return I18n.tr("Connecting…")
        case BluetoothDeviceState.Disconnecting:
            return I18n.tr("Disconnecting…")
        }
        if (page.unsaved(device))
            return I18n.tr("Not saved · forget and pair again")
        if (device.connected)
            return device.batteryAvailable
                ? I18n.tr("Connected · %1%").arg(Math.round(device.battery * 100)) : I18n.tr("Connected")
        return device.paired ? I18n.tr("Paired") : ""
    }

    function activate(device) {
        if (device.connected) {
            device.disconnect()
            return
        }
        if (device.paired) {
            device.connect()
            return
        }
        if (device.pairing) {
            device.cancelPair()
            return
        }
        const next = Object.assign({}, pairing)
        next[device.address] = true
        pairing = next
        device.pair()
    }

    function settle(device) {
        if (!pairing[device.address] || !device.paired)
            return
        const next = Object.assign({}, pairing)
        delete next[device.address]
        pairing = next
        device.trusted = true
        device.connect()
    }

    Binding {
        target: page.adapter
        property: "discovering"
        value: page.active && page.powered
        when: !!page.adapter
    }

    // A non-pairable adapter still pairs but keeps no link key, so open the window while the page is up.
    Binding {
        target: page.adapter
        property: "pairable"
        value: page.active && page.powered
        when: !!page.adapter
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.tileGap

        // The switch row, then the devices, ruled apart.
        ToggleTile {
            width: parent.width
            motion: page.motion
            opens: false
            icon: page.powered ? "bluetooth" : "bluetooth-off"
            on: page.powered
            title: I18n.tr("Bluetooth")
            subtitle: !page.powered ? I18n.tr("Off")
                : page.adapter.discovering ? I18n.tr("Searching for devices") : ""
            onToggled: page.adapter.enabled = !page.adapter.enabled
        }

        Rule {
            width: parent.width
            visible: page.powered
        }

        ListGroup {
            width: parent.width
            maxHeight: page.maxListHeight
            visible: page.powered && page.devices.length > 0

            Repeater {
                model: page.devices

                ListRow {
                    id: entry
                    required property var modelData
                    width: parent.width
                    motion: page.motion
                    icon: page.kind(modelData)
                    title: modelData.name
                    subtitle: page.status(modelData)
                    current: modelData.connected && !page.unsaved(modelData)
                    busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting
                        || modelData.state === BluetoothDeviceState.Disconnecting
                    trailing: current ? "check" : busy ? "bluetooth" : ""
                    actions: page.actions(modelData)
                    onActionTriggered: id => {
                        if (id === "lights")
                            page.lightsRequested(modelData)
                        else
                            modelData.forget()
                    }
                    onActivated: page.activate(modelData)

                    Connections {
                        target: entry.modelData
                        function onPairedChanged() {
                            page.settle(entry.modelData)
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: page.powered && page.devices.length === 0
            horizontalAlignment: Text.AlignHCenter
            topPadding: 8
            bottomPadding: 10
            text: I18n.tr("No devices found")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textLabel
        }
    }
}
