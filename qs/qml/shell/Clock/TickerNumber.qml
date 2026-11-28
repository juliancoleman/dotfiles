import QtQuick
import "../Common"

// A whole number on the clock's digit tickers, so readings like the temperature and battery change the way
// the time does. Columns are fixed and aligned from the right, keeping the ones digit on the same ticker;
// a leading column folds away while unused rather than rolling through a blank. Without a reading the ones
// ticker rests on the placeholder, a step before 0, so a reading that turns up late rolls in over it.
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
    // What the number is created with simply appears; changes after that roll.
    property bool settled: false

    baselineOffset: ones.y + ones.baselineOffset

    // Digits are pushed imperatively so each ticker knows, as its digit changes, whether to roll. A column a
    // growing number unfolds simply appears; over the placeholder, every column the reading needs rolls open.
    function sync() {
        const previous = shown
        const next = isNaN(value) ? NaN : Math.max(-999, Math.min(999, Math.round(value)))
        const rolling = settled && motion !== "none"
        const arriving = isNaN(previous)
        const before = arriving ? 0 : Math.abs(previous)
        const size = isNaN(next) ? 0 : Math.abs(next)
        place(hundredsColumn, hundreds, Math.floor(size / 100) % 10, rolling && (arriving || before >= 100))
        place(tensColumn, tens, Math.floor(size / 10) % 10, rolling && (arriving || before >= 10))
        place(onesColumn, ones, isNaN(next) ? placeholder : size % 10, rolling)
        shown = next
    }

    function place(column, ticker, digit, rolling) {
        column.snapping = !rolling
        ticker.animateChange = rolling
        ticker.digit = String(digit)
    }

    onValueChanged: sync()
    Component.onCompleted: {
        sync()
        settled = true
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
            samples: [root.placeholder].concat(defaultSamples)
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

        width: used && ticker ? ticker.implicitWidth : 0
        height: ticker ? ticker.implicitHeight : 0
        clip: true

        Behavior on width {
            enabled: root.motion !== "none" && !column.snapping
            Settle {
                motion: root.motion
            }
        }
    }
}
