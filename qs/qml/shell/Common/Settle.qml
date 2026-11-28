import QtQuick

// How a color, an opacity or a level animates, for use in a Behavior: the chosen curve and duration, with a
// spring settling instead of overshooting, since these must not pass their target.
PropertyAnimation {
    // Which of the five motion settings to follow; see Theme.normalizeMotion.
    property string motion: "spring"
    // Share of the configured duration; a hover or press layer passes Theme.hoverFade.
    property real factor: 1

    duration: Theme.durationFor(motion) * factor
    easing.type: Theme.settleFor(motion)
}
