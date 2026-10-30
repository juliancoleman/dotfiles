import QtQuick
import Quickshell
import Quickshell.Services.UPower

Scope {
    id: root

    function designCapacity(device) {
        if (!device)
            return 0
        const capacity = Number(device.energyCapacity)
        if (!isFinite(capacity) || capacity <= 0)
            return 0
        const health = Number(device.healthPercentage)
        if (device.healthSupported && isFinite(health) && health > 0)
            return capacity / (health / 100)
        return capacity
    }

    function usable(device) {
        return !!device && device.ready && device.isLaptopBattery && device.isPresent
    }

    readonly property var fallbackDevice: {
        const devices = UPower.devices ? UPower.devices.values : []
        let best = null
        let bestCapacity = -1
        for (let i = 0; i < devices.length; ++i) {
            const candidate = devices[i]
            if (!usable(candidate))
                continue
            const capacity = designCapacity(candidate)
            if (!best || capacity > bestCapacity) {
                best = candidate
                bestCapacity = capacity
            }
        }
        return best
    }
    readonly property var device: usable(UPower.displayDevice) ? UPower.displayDevice : fallbackDevice
    readonly property bool available: usable(device)
    readonly property real percentage: {
        if (!available)
            return 0
        const reported = Number(device.percentage)
        if (!isFinite(reported))
            return 0
        return Math.max(0, Math.min(1, reported > 1 ? reported / 100 : reported))
    }
    readonly property bool charging: available && (device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool externalPower: available && (!UPower.onBattery
        || device.state === UPowerDeviceState.Charging
        || device.state === UPowerDeviceState.PendingCharge
        || device.state === UPowerDeviceState.FullyCharged)

    signal powerConnected()
    signal powerDisconnected()

    property bool _settled: false
    property bool _announced: false

    onExternalPowerChanged: {
        if (_settled)
            powerSettle.restart()
    }

    // UPower reports line power and battery state separately, so a plug event can flicker before it lands.
    Timer {
        id: powerSettle
        interval: 600
        onTriggered: {
            if (root.externalPower === root._announced)
                return
            root._announced = root.externalPower
            if (root.externalPower)
                root.powerConnected()
            else
                root.powerDisconnected()
        }
    }

    // UPower fills in device state asynchronously at startup; don't announce the initial state.
    Timer {
        running: true
        interval: 3000
        onTriggered: {
            root._announced = root.externalPower
            root._settled = true
        }
    }
}
