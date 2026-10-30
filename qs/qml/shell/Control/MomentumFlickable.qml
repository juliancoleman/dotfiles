import QtQuick

// Wayland touchpads report no kinetic phase, so Qt stops dead when the fingers lift.
// Track the scroll speed and hand it to flick() once the deltas stop arriving.
Flickable {
    id: root

    // A sideways scroller takes a touchpad's horizontal swipe, and a mouse wheel since it has no other
    // axis; a vertical touchpad swipe passes through to whatever scrolls around it.
    property bool horizontal: false
    property real velocity: 0
    property real lastWheel: 0

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: horizontal ? Flickable.HorizontalFlick : Flickable.VerticalFlick
    flickDeceleration: 1800
    maximumFlickVelocity: 5000

    function scrollBy(delta) {
        if (horizontal)
            contentX = Math.max(0, Math.min(Math.max(0, contentWidth - width), contentX + delta))
        else
            contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), contentY + delta))
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const sideways = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y)
            const touchpad = event.device.type === PointerDevice.TouchPad
            const mine = root.horizontal ? sideways || !touchpad : !sideways
            if (!mine || (root.horizontal ? root.contentWidth <= root.width : root.contentHeight <= root.height)) {
                event.accepted = false
                return
            }
            root.cancelFlick()
            const now = Date.now()
            const dt = now - root.lastWheel
            root.lastWheel = now
            const pixels = sideways ? event.pixelDelta.x : event.pixelDelta.y
            const angle = sideways ? event.angleDelta.x : event.angleDelta.y
            const delta = pixels !== 0 ? -pixels : -angle / 2
            root.scrollBy(delta)
            const instant = delta / Math.max(4, dt) * 1000
            root.velocity = dt > 120 ? 0 : 0.5 * root.velocity + 0.5 * instant
            release.restart()
        }
    }

    Timer {
        id: release
        interval: 50
        onTriggered: {
            if (Math.abs(root.velocity) > 150)
                root.horizontal ? root.flick(-root.velocity, 0) : root.flick(0, -root.velocity)
            root.velocity = 0
        }
    }
}
