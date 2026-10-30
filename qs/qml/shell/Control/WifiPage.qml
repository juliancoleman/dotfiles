import QtQuick
import Quickshell.Networking
import "../Common"
import "../Secure"

Item {
    id: page

    property var device: null
    property bool active: false
    property string motion: "easeOut"
    readonly property real maxListHeight: 240

    // Network this page last tried to join, so only it reacts to that network's result.
    property string joining: ""
    readonly property bool asking: !!SecureInput.local && SecureInput.local.owner === page

    implicitHeight: content.implicitHeight

    function bars(network) {
        const s = Math.max(0, Math.min(1, network.signalStrength))
        return s < 0.25 ? 0 : s < 0.5 ? 1 : s < 0.75 ? 2 : 3
    }

    function rank(network) {
        return network.connected ? 3 : network.state === ConnectionState.Connecting ? 2 : network.known ? 1 : 0
    }

    readonly property var networks: {
        const list = device && device.networks ? device.networks.values : []
        return list.filter(n => n && n.name !== "").sort((a, b) =>
            rank(b) - rank(a) || bars(b) - bars(a) || a.name.localeCompare(b.name))
    }

    function secured(network) {
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe
    }

    function status(network) {
        if (network.connected)
            return qsTr("Connected")
        if (network.state === ConnectionState.Connecting)
            return qsTr("Connecting…")
        if (network.state === ConnectionState.Disconnecting)
            return qsTr("Disconnecting…")
        return network.known ? qsTr("Saved") : ""
    }

    function askPassword(network, error) {
        joining = network.name
        SecureInput.ask({
            owner: page,
            icon: "wifi-lock",
            title: network.name,
            kind: qsTr("Wi-Fi password"),
            busyText: qsTr("Joining…"),
            minLength: 8,
            submit: psk => network.connectWithPsk(psk)
        }, error)
    }

    function activate(network) {
        if (network.connected) {
            network.disconnect()
            return
        }
        if (network.known || !secured(network)) {
            joining = network.name
            network.connect()
            return
        }
        askPassword(network)
    }

    function failureText(reason) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
        case ConnectionFailReason.WifiAuthTimeout:
            return qsTr("Wrong password")
        case ConnectionFailReason.WifiNetworkLost:
            return qsTr("Network out of range")
        default:
            return qsTr("Couldn't connect")
        }
    }

    Binding {
        target: page.device
        property: "scannerEnabled"
        value: page.active && Networking.wifiEnabled
        when: !!page.device
    }

    Column {
        id: content
        width: parent.width
        spacing: 6

        ToggleTile {
            width: parent.width
            motion: page.motion
            opens: false
            icon: Networking.wifiEnabled ? "wifi" : "wifi-off"
            on: Networking.wifiEnabled
            title: qsTr("Wi-Fi")
            subtitle: !Networking.wifiEnabled ? qsTr("Off")
                : page.device && page.device.scannerEnabled ? qsTr("Searching for networks") : ""
            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
        }

        MomentumFlickable {
            width: parent.width
            height: Math.min(page.maxListHeight, list.implicitHeight)
            visible: Networking.wifiEnabled
            contentHeight: list.implicitHeight

            Column {
                id: list
                width: parent.width

                Repeater {
                    model: page.networks

                    ListRow {
                        id: entry
                        required property var modelData
                        width: list.width
                        icon: "wifi"
                        wifiBars: page.bars(modelData)
                        title: modelData.name
                        subtitle: page.status(modelData)
                        current: modelData.connected
                        busy: modelData.stateChanging
                        trailing: modelData.connected ? "check"
                            : page.secured(modelData) && !modelData.known ? "lock" : ""
                        onActivated: page.activate(modelData)

                        Connections {
                            target: entry.modelData
                            function onConnectionFailed(reason) {
                                if (page.joining !== entry.modelData.name || !page.secured(entry.modelData))
                                    return
                                const text = page.failureText(reason)
                                if (page.asking)
                                    SecureInput.fail(text)
                                else if (reason === ConnectionFailReason.NoSecrets
                                         || reason === ConnectionFailReason.WifiAuthTimeout)
                                    page.askPassword(entry.modelData, text)
                            }
                            function onConnectedChanged() {
                                if (entry.modelData.connected && page.joining === entry.modelData.name) {
                                    page.joining = ""
                                    SecureInput.finish(page)
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: Networking.wifiEnabled && page.networks.length === 0
            horizontalAlignment: Text.AlignHCenter
            topPadding: 8
            bottomPadding: 10
            text: qsTr("No networks found")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
}
