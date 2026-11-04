import QtQuick
import "../Common"

Item {
    id: ticker

    property string digit: ""
    property var samples: []
    property bool animateChange: true
    // A clock digit rolls the short way around (9 on to 0); a reading rolls straight along 0–9, so going
    // from 6 down to 1 never passes through 0.
    property bool wraps: true
    property string motion: "easeOut"
    property color color: Theme.textPrimary
    // A digit that changes tone (the 12-hour clock's muted leading zero) fades with its roll.
    Behavior on color {
        ColorAnimation {
            duration: Theme.durationFor(ticker.motion)
            easing.type: Easing.InOutQuad
        }
    }
    // Digits are Latin in every locale; the JP face's taller line box would resize them on locale change.
    property string fontFamily: Theme.latinFontFamily
    property real fontPixelSize: Theme.horizontalDigit
    property int fontWeight: Theme.clockFontWeight
    readonly property var defaultSamples: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
    readonly property var sampleValues: samples && samples.length ? samples : defaultSamples
    readonly property int reelPadding: 2

    property string displayedDigit: digit
    property var reelValues: buildReel()
    property real reelPosition: indexFor(digit) + reelPadding
    property int curve: Easing.OutCubic
    // A spring overshoots in proportion to how far it travels, so a roll across several digits would swing
    // into the neighboring one; scaling by the distance keeps every settle the size of a single step.
    property real overshoot: Theme.springOvershoot

    implicitWidth: Math.ceil(maximumWidth())
    implicitHeight: Math.ceil(fontMetrics.ascent + fontMetrics.descent)
    baselineOffset: fontMetrics.ascent
    clip: true

    function maximumWidth() {
        // Read so the width re-measures when the font size changes; advanceWidth() alone isn't tracked.
        fontMetrics.font
        const list = sampleValues
        var width = 0
        for (var i = 0; i < list.length; ++i)
            width = Math.max(width, fontMetrics.advanceWidth(String(list[i])))
        return Math.max(width, fontMetrics.advanceWidth(displayedDigit))
    }

    function buildReel() {
        return [String(sampleValues[sampleValues.length - 1]),
                String(sampleValues[sampleValues.length - 1])]
            .concat(sampleValues)
            .concat([String(sampleValues[0]), String(sampleValues[0])])
    }

    function indexFor(value) {
        const index = sampleValues.indexOf(value)
        return index >= 0 ? index : 0
    }

    function targetPosition(current, target) {
        if (!wraps)
            return reelPadding + indexFor(target)
        const count = sampleValues.length
        const start = indexFor(current)
        const forward = (indexFor(target) - start + count) % count
        const delta = forward <= count / 2 ? forward : forward - count
        return reelPadding + start + delta
    }

    function play() {
        curve = Theme.easingFor(motion)
        ease.from = reelPadding + indexFor(displayedDigit)
        ease.to = targetPosition(displayedDigit, digit)
        overshoot = Theme.springOvershoot / Math.max(1, Math.abs(ease.to - ease.from))
        reelPosition = ease.from
        ease.restart()
    }

    function finish() {
        displayedDigit = digit
        reelPosition = reelPadding + indexFor(digit)
    }

    function syncDigit() {
        const next = digit
        if (motion === "none") {
            ease.stop()
            displayedDigit = next
            reelPosition = reelPadding + indexFor(next)
            return
        }
        if (next === displayedDigit && !ease.running)
            return
        if (!animateChange) {
            ease.stop()
            displayedDigit = next
            reelPosition = reelPadding + indexFor(next)
            return
        }
        if (ease.running) {
            ease.stop()
            displayedDigit = reelValues[Math.round(reelPosition)]
            reelPosition = reelPadding + indexFor(displayedDigit)
        }
        if (next === displayedDigit) {
            return
        }
        play()
    }

    onDigitChanged: syncDigit()
    onMotionChanged: syncDigit()

    Component.onCompleted: {
        displayedDigit = digit
        reelPosition = reelPadding + indexFor(digit)
    }

    FontMetrics {
        id: fontMetrics
        font.family: ticker.fontFamily
        font.pixelSize: ticker.fontPixelSize
        font.weight: ticker.fontWeight
        font.kerning: false
        font.features: ({ "tnum": 1 })
    }

    Item {
        width: ticker.width
        height: ticker.height
        clip: true

        Column {
            y: -ticker.reelPosition * ticker.height
            width: parent.width
            spacing: 0

            Repeater {
                model: ticker.reelValues

                Text {
                    required property string modelData
                    width: ticker.width
                    height: ticker.height
                    text: modelData
                    color: ticker.color
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: ticker.fontFamily
                    font.pixelSize: ticker.fontPixelSize
                    font.weight: ticker.fontWeight
                    font.kerning: false
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }

    NumberAnimation {
        id: ease
        target: ticker
        property: "reelPosition"
        duration: Theme.durationFor(ticker.motion)
        easing.type: ticker.curve
        easing.overshoot: ticker.overshoot
        onFinished: ticker.finish()
    }
}
