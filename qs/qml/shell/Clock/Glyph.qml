import QtQuick
import "../Common"

// One clock digit, rolling with the rest of the time; `compact` is the side bar's smaller stacked face.
DigitTicker {
    required property Item clock
    property bool compact: false

    motion: clock.motion
    animateChange: clock.animateTicker
    fontPixelSize: compact ? Theme.verticalDigit : clock.faceDigit
    fontFamily: Theme.latinFontFamily
    color: Theme.textPrimary
}
