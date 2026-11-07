import QtQuick

// One page of a panel that swaps pages in place: the home page leaves to the left and a subpage arrives
// from the right, so going in and coming back read as one direction of travel. A subpage that opens a
// deeper page of its own is `behind` it and leaves to the left too.
Item {
    id: layer

    property bool shown: false
    property bool home: false
    property bool behind: false
    property string motion: "easeOut"
    readonly property real travel: 24
    property real shift: shown ? 0 : home || behind ? -travel : travel

    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    enabled: shown
    transform: Translate { x: layer.shift }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durationFor(layer.motion)
            easing.type: Easing.OutCubic
        }
    }
    Behavior on shift {
        NumberAnimation {
            duration: Theme.durationFor(layer.motion)
            easing.type: Theme.easingFor(layer.motion)
            easing.overshoot: Theme.springOvershoot
        }
    }
}
