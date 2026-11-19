import QtQuick
import ".."
import "../Clock"
import "../Common"
import "../Control"
import "../Status"

// What the weather capsule opens into: the place row with its close action, and below it the forecast
// (WeatherBody), which reads the shared helpers here through `panel`.
Item {
    id: root

    signal closeRequested()

    // The place row shares the capsule's height in the pill; its close action takes the capsule's place, like
    // the control center's ring, so it sits where the pointer already is. faceWidth is 0 when the capsule isn't
    // in this panel (lent to the notch, where the capsule itself becomes the close action).
    property real rowHeight: 26
    property real faceWidth: 0
    // Which corner the capsule holds: below a bottom or side bar's pill the place row moves to the bottom with
    // it, and along a left bar the close action sits at the left end.
    property bool faceLeft: false
    property bool faceBottom: false
    // Where the screen runs out first, everything but the place row scrolls.
    property real maxHeight: Infinity
    // The notched weather trigger becomes the close action while this panel is open.
    property bool closeActionInFace: false
    property string motion: "easeOut"
    property real pad: Theme.panelPad
    readonly property real innerWidth: width - pad * 2
    readonly property bool clock24: ClockConfig.use24Hour
    readonly property var today: WeatherService.daily.length > 0 ? WeatherService.daily[0] : null

    implicitHeight: placeRow.height + scroller.height + pad

    function degrees(celsius) {
        return celsius === null || celsius === undefined || isNaN(celsius) ? "–" : WeatherService.toUnits(celsius) + "°"
    }

    // Hourly entries carry their own offset; anything else (sun, alert ends) looks its offset up.
    function timeLabel(epoch, minutes, offset) {
        const local = WeatherService.wallClock(epoch, offset === undefined ? WeatherService.offsetAt(epoch) : offset)
        return I18n.timeOfDay(local.getUTCHours(), local.getUTCMinutes(), clock24, minutes)
    }

    function speed(kmh) {
        return WeatherService.imperial ? Math.round(kmh / 1.609344) + " mph" : Math.round(kmh) + " km/h"
    }

    function dayName(day, index) {
        return index === 0 ? I18n.tr("Today") : Qt.locale(I18n.qtLocale).dayName(day.weekday, Locale.ShortFormat)
    }

    readonly property var windNow: {
        const observed = WeatherService.wind
        if (observed)
            return observed
        const next = WeatherService.hourly[0]
        return next && next.windKmh !== null ? { kmh: next.windKmh, gustKmh: null, from: next.windFrom } : null
    }
    readonly property string windText: !windNow ? ""
        : I18n.tr("Wind %1%2").arg(speed(windNow.kmh)).arg(windNow.from ? " " + I18n.tr(windNow.from) : "")
          + (windNow.gustKmh ? I18n.tr(", gusts %1").arg(speed(windNow.gustKmh)) : "")

    // The week's coldest low and warmest high, the scale every day's range bar reads against.
    readonly property var weekRange: {
        let low = Infinity
        let high = -Infinity
        for (const d of WeatherService.daily) {
            low = Math.min(low, WeatherService.toUnits(d.low))
            high = Math.max(high, WeatherService.toUnits(d.high))
        }
        return low === Infinity ? { low: 0, high: 1 } : { low: low, high: Math.max(low + 1, high) }
    }

    // US AQI bands; the axis runs to 300 and everything past it sits at the end.
    readonly property var aqiBands: [50, 100, 150, 200, 300]
    readonly property int aqi: WeatherService.airQuality ? WeatherService.airQuality.aqi : 0
    function aqiColor(aqi) {
        if (aqi <= 50)
            return Theme.aqiGood
        if (aqi <= 100)
            return Theme.aqiModerate
        if (aqi <= 150)
            return Theme.aqiSensitive
        if (aqi <= 200)
            return Theme.aqiUnhealthy
        if (aqi <= 300)
            return Theme.aqiVeryUnhealthy
        return Theme.aqiHazardous
    }

    function severe(alert) {
        return alert.severity === "Extreme" || alert.severity === "Severe"
    }

    Item {
        id: placeRow
        x: root.pad
        y: root.faceBottom ? scroller.y + scroller.height : 0
        width: root.innerWidth
        height: root.rowHeight

        Row {
            readonly property real room: Math.max(0, root.innerWidth
                - (root.closeActionInFace ? 0 : closeButton.width + Theme.px(8)) - Theme.px(14))
            x: root.faceLeft && closeButton.visible ? closeButton.x + closeButton.width + Theme.px(8) : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(4)

            Text {
                id: placeName
                text: WeatherService.place || I18n.tr("Weather")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textBody
                elide: Text.ElideRight
                width: Math.min(implicitWidth, parent.room)
            }

            StatusGlyph {
                anchors.verticalCenter: placeName.verticalCenter
                visible: WeatherService.automatic
                width: Theme.px(10)
                height: Theme.px(10)
                icon: "navigation"
                ink: Theme.textSecondary
            }
        }

        SettingsButton {
            id: closeButton
            opened: 1
            visible: !root.closeActionInFace
            icon: "close"
            label: I18n.tr("Close weather")
            motion: root.motion
            anchors.verticalCenter: parent.verticalCenter
            // Centered on the capsule's corner of the panel, whichever it is.
            x: root.faceWidth > 0
                ? (root.faceLeft ? root.faceWidth / 2 : root.width - root.faceWidth / 2) - root.pad - width / 2
                : parent.width - width
            onActivated: root.closeRequested()
        }
    }

    MomentumFlickable {
        id: scroller
        x: root.pad
        y: root.faceBottom ? root.pad : placeRow.height
        width: root.innerWidth
        height: Math.max(0, Math.min(body.implicitHeight, root.maxHeight - placeRow.height - root.pad))
        contentHeight: body.implicitHeight
        clip: true

        WeatherBody {
            id: body
            width: root.innerWidth
            panel: root
        }
    }
}
