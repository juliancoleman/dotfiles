import QtQuick
import "Common"

// The strip of surface holding one bar circle to the next along the bar. It runs from `start` for `span`
// along the bar and sits centred on the circle lane at `lane` across it. Its thickness across the bar is
// the circle diameter, thinning away over the second half of `release` (the water-drop neck letting go of a
// circle as it opens) and widening back as `join` fuses the circles into the notch.
Rectangle {
    id: neck

    property bool vertical: false
    property real diameter: 0
    // Opening progress of the circle this neck lets go of; 1 (the default) contributes no thickness.
    property real release: 1
    // Pill-to-notch progress; the neck forms only once the gap is nearly closed, never as a hairline.
    property real join: 0
    property real start: 0
    property real span: 0
    property real lane: 0

    readonly property real drop: 1 - smoothstep(Math.max(0, Math.min(1, (release - 0.5) / 0.5)))
    readonly property real fuse: Math.max(0, (join - 0.6) / 0.4)
    readonly property real cross: diameter * Math.max(drop, fuse)

    function smoothstep(t) {
        return t * t * (3 - 2 * t)
    }

    color: Theme.surface
    x: vertical ? lane + (diameter - cross) / 2 : start
    y: vertical ? start : lane + (diameter - cross) / 2
    width: vertical ? cross : span
    height: vertical ? span : cross
}
