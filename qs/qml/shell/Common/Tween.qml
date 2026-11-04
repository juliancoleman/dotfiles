import QtQuick

// One animated real on `target`, driven by `aim(next)`. Replaces the per-panel `run(ease, property, next)`
// copies: with motion "none" the property snaps, an aim at the value it already rests on is ignored, and a
// new aim restarts from wherever the animation currently is.
NumberAnimation {
    id: ease

    // Which of the five motion settings to follow; see Theme.normalizeMotion.
    property string motion: "spring"
    // Easing overshoot for "spring"; panels that fuse into the notch pass a smaller one.
    property real overshoot: Theme.springOvershoot

    duration: Theme.durationFor(motion)
    easing.type: Theme.easingFor(motion)
    easing.overshoot: overshoot

    function aim(next) {
        if (Theme.normalizeMotion(motion) === "none") {
            stop()
            target[property] = next
            return
        }
        if (!running && Math.abs(target[property] - next) < 0.001)
            return
        stop()
        from = target[property]
        to = next
        start()
    }
}
