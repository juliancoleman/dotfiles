import QtQuick
import "../Common"

// A slot that opens along one axis to `target`, used to make room for the AM/PM mark beside the digits.
Item {
    id: reveal

    property bool across: false
    property real cross: 0
    property real span: 0
    readonly property real shown: Math.max(0, span)
    property real target: 0
    property string motion: "easeOut"

    implicitWidth: across ? span : childrenRect.width
    implicitHeight: across ? cross : span
    width: implicitWidth
    height: implicitHeight
    clip: true

    function go(next, slotMotion, instant) {
        if (instant || Math.abs(next - target) < 0.4 && Math.abs(next - span) < 0.4) {
            ease.stop()
            target = next
            span = next
            return
        }
        target = next
        ease.stop()
        motion = slotMotion
        ease.from = span
        ease.to = next
        ease.start()
    }

    NumberAnimation {
        id: ease
        target: reveal
        property: "span"
        duration: Theme.durationFor(reveal.motion)
        easing.type: Theme.easingFor(reveal.motion)
        easing.overshoot: Theme.springOvershoot
    }
}
