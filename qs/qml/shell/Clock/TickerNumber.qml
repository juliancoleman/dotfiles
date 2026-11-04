import QtQuick
import "../Common"

// A whole number on the clock's digit tickers, so readings like the temperature and battery change the way
// the time does. Columns are fixed and aligned from the right, keeping the ones digit on the same ticker;
// a leading column folds away while unused rather than rolling through a blank.
Row {
    id: root

    // NaN shows the placeholder.
    property real value: NaN
    property string suffix: ""
    property string placeholder: "–"
    property real fontPixelSize: Theme.horizontalDigit
    property int fontWeight: Theme.clockFontWeight
    property string motion: "easeOut"
    property color color: Theme.textPrimary

    property real shown: NaN
    readonly property bool known: !isNaN(shown)
    readonly property int magnitude: known ? Math.abs(shown) : 0

    baselineOffset: ones.y + ones.baselineOffset

    // Digits are pushed imperatively so each ticker knows, as its digit changes, whether to roll: a column
    // that was folded away, or a first reading, simply appears.
    function sync() {
        const previous = shown
        if (isNaN(value)) {
            shown = NaN
            return
        }
        const next = Math.max(-999, Math.min(999, Math.round(value)))
        const rolling = !isNaN(previous) && motion !== "none"
        const before = Math.abs(previous)
        const size = Math.abs(next)
        place(hundredsColumn, hundreds, Math.floor(size / 100) % 10, rolling && before >= 100)
        place(tensColumn, tens, Math.floor(size / 10) % 10, rolling && before >= 10)
        place(onesColumn, ones, size % 10, rolling)
        shown = next
    }

    function place(column, ticker, digit, rolling) {
        column.snapping = !rolling
        ticker.animateChange = rolling
        ticker.digit = String(digit)
    }

    onValueChanged: sync()
    Component.onCompleted: sync()

    Text {
        visible: !root.known
        text: root.placeholder
        color: root.color
        font.family: Theme.latinFontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
    }

    Text {
        visible: root.known && root.shown < 0
        text: "−"
        color: root.color
        font.family: Theme.latinFontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
    }

    Slot {
        id: hundredsColumn
        used: root.magnitude >= 100
        ticker: hundreds

        DigitTicker {
            id: hundreds
            anchors.right: parent.right
            wraps: false
            motion: root.motion
            color: root.color
            fontPixelSize: root.fontPixelSize
            fontWeight: root.fontWeight
        }
    }

    Slot {
        id: tensColumn
        used: root.magnitude >= 10
        ticker: tens

        DigitTicker {
            id: tens
            anchors.right: parent.right
            wraps: false
            motion: root.motion
            color: root.color
            fontPixelSize: root.fontPixelSize
            fontWeight: root.fontWeight
        }
    }

    Slot {
        id: onesColumn
        used: true
        ticker: ones

        DigitTicker {
            id: ones
            anchors.right: parent.right
            wraps: false
            motion: root.motion
            color: root.color
            fontPixelSize: root.fontPixelSize
            fontWeight: root.fontWeight
        }
    }

    Text {
        visible: root.known && root.suffix !== ""
        text: root.suffix
        color: root.color
        font.family: Theme.latinFontFamily
        font.pixelSize: root.fontPixelSize
        font.weight: root.fontWeight
    }

    component Slot: Item {
        id: column

        property bool used: false
        property Item ticker: null
        property bool snapping: true

        visible: root.known
        width: used && ticker ? ticker.implicitWidth : 0
        height: ticker ? ticker.implicitHeight : 0
        clip: true

        Behavior on width {
            enabled: root.motion !== "none" && !column.snapping
            NumberAnimation {
                duration: Theme.durationFor(root.motion)
                easing.type: Easing.OutCubic
            }
        }
    }
}
