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

    implicitHeight: content.implicitHeight

    function rank(device) {
        return device.connected ? 3 : device.state === BluetoothDeviceState.Connecting ? 2 : device.paired ? 1 : 0
    }

    readonly property var devices: {
        const list = adapter && adapter.devices ? adapter.devices.values : []
        return list.filter(d => d && (d.paired || d.connected || d.deviceName !== ""))
            .sort((a, b) => rank(b) - rank(a) || a.name.localeCompare(b.name))
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
                    icon: "bluetooth"
                    title: modelData.name
                    subtitle: page.status(modelData)
                    current: modelData.connected
                    busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting
                        || modelData.state === BluetoothDeviceState.Disconnecting
                    trailing: modelData.connected ? "check" : busy ? "bluetooth" : ""
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
