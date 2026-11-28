import QtQuick

// How a size or a position animates, for use in a Behavior: the chosen curve, duration and overshoot.
// (A value driven by `aim()` rather than by a binding uses Tween, which follows the same setting.)
NumberAnimation {
    // Which of the five motion settings to follow; see Theme.normalizeMotion.
    property string motion: "spring"
    // Share of the configured duration.
    property real factor: 1

    duration: Theme.durationFor(motion) * factor
    easing.type: Theme.easingFor(motion)
    easing.overshoot: Theme.springOvershoot
}
