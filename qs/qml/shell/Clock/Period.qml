import QtQuick
import "../Common"

// The 12-hour mark: "AM"/"PM" or "午前"/"午後". Only one half changes, so only that half is a ticker; it
// trails in English (A|M) and leads in Japanese (午|前). The leading half sits at `shift` so the taller
// trailing half still fits, and the trailing half hangs from the leading one's baseline.
Item {
    id: period

    required property Item clock
    property bool kana: false
    property real fontPixelSize: Theme.periodSize
    readonly property string family: kana ? Theme.jaFontFamily : Theme.latinFontFamily
    readonly property Item lead: kana ? fixed : mark
    readonly property Item trail: kana ? mark : fixed
    readonly property real shift: Math.max(0, trail.baselineOffset - lead.baselineOffset)

    implicitWidth: trail.x + trail.implicitWidth
    implicitHeight: Math.max(lead.y + lead.implicitHeight, trail.y + trail.implicitHeight)
    baselineOffset: lead.y + lead.baselineOffset

    DigitTicker {
        id: mark
        x: period.kana ? fixed.implicitWidth : 0
        y: period.kana ? fixed.y + fixed.baselineOffset - baselineOffset : period.shift
        digit: period.kana ? period.clock.kanaMark : period.clock.latinMark
        samples: period.kana ? ["前", "後"] : ["A", "P"]
        motion: period.clock.motion
        animateChange: period.kana ? period.clock.animateKana : period.clock.animateLatin
        fontPixelSize: period.fontPixelSize
        fontFamily: period.family
        color: Theme.textSecondary
    }

    Text {
        id: fixed
        x: period.kana ? 0 : mark.implicitWidth
        y: period.kana ? period.shift : mark.y + mark.baselineOffset - baselineOffset
        text: period.kana ? "午" : "M"
        color: Theme.textSecondary
        font.family: period.family
        font.pixelSize: period.fontPixelSize
        font.weight: Theme.clockFontWeight
        font.letterSpacing: period.kana ? 0 : 0.3
    }
}
