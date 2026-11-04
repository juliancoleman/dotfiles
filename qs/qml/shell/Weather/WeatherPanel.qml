import QtQuick
import ".."
import "../Clock"
import "../Common"
import "../Control"
import "../Status"

// What the weather capsule opens into: where and how it is now, any warnings, the next day by the hour with
// sunrise and sunset in place, air quality, and ten days of highs and lows.
Item {
    id: root

    signal closeRequested()

    // The place row shares the capsule's height in a top bar pill; its close action takes the capsule's place,
    // like the control center's ring, so it sits where the pointer already is.
    property real rowHeight: 26
    property real faceRoom: 0
    // Below a bottom or side bar's pill the capsule holds the panel's bottom corner instead.
    property real footRoom: 0
    // Where the screen runs out first, everything but the place row scrolls.
    property real maxHeight: Infinity
    // The notched weather trigger becomes the close action while this panel is open.
    property bool closeActionInFace: false
    property string motion: "easeOut"
    // Hero reading. The type ramp tops out at textDisplay (22); the current temperature is the one reading
    // meant to be seen from across the room, so it keeps its own size until Theme grows a hero step.
    readonly property int heroDigit: 40

    property real pad: Theme.panelPad
    readonly property real innerWidth: width - pad * 2
    readonly property bool clock24: ClockConfig.use24Hour
    readonly property var today: WeatherService.daily.length > 0 ? WeatherService.daily[0] : null

    implicitHeight: placeRow.height + scroller.height + Math.max(pad, footRoom)

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

    // The hours ahead, with sunrise and sunset slotted in where they fall. Rebuilt when the data behind it
    // changes, not on the clock; a sun event that passes between refreshes stays until the next one.
    readonly property var hours: {
        const list = WeatherService.hourly
        if (list.length === 0)
            return []
        const out = list.map((h, i) => ({
            time: h.start,
            label: i === 0 ? I18n.tr("Now") : timeLabel(h.start, false, h.offset),
            icon: h.icon,
            reading: i === 0 && !isNaN(WeatherService.degrees) ? WeatherService.temperature : degrees(h.celsius),
            chance: h.chance
        }))
        const first = Math.max(list[0].start, Date.now())
        const last = list[list.length - 1].end
        for (const sun of WeatherService.sunTimes) {
            if (sun.time <= first || sun.time >= last)
                continue
            out.push({
                time: sun.time,
                label: timeLabel(sun.time, true),
                icon: sun.rise ? "sunrise" : "sunset",
                reading: sun.rise ? I18n.tr("Sunrise") : I18n.tr("Sunset"),
                chance: 0
            })
        }
        return out.sort((a, b) => a.time - b.time)
    }

    readonly property var windNow: {
        const observed = WeatherService.wind
        if (observed)
            return observed
        const next = WeatherService.hourly[0]
        return next && next.windKmh !== null ? { kmh: next.windKmh, gustKmh: null, from: next.windFrom } : null
    }

    // The ten days share one scale so each bar reads against the whole stretch.
    readonly property var range: {
        let low = Infinity
        let high = -Infinity
        for (const d of WeatherService.daily) {
            low = Math.min(low, WeatherService.toUnits(d.low))
            high = Math.max(high, WeatherService.toUnits(d.high))
        }
        return { low: low, high: high }
    }
    readonly property real rangeLow: range.low
    readonly property real rangeHigh: range.high

    component Divider: Rectangle {
        width: root.innerWidth
        height: 1
        color: Theme.statusTrack
    }

    component Label: Text {
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textBody
        font.features: { "tnum": 1 }
    }

    // Latin-only readings (temperatures, percentages) keep the Latin face so digits don't change size with the
    // UI locale.
    component Reading: Label {
        font.family: Theme.latinFontFamily
    }

    Item {
        id: placeRow
        x: root.pad
        width: root.innerWidth
        height: root.rowHeight

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Label {
                id: placeName
                text: WeatherService.place || I18n.tr("Weather")
                font.pixelSize: Theme.textStrong
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Math.max(0, root.innerWidth
                    - (root.closeActionInFace ? 0 : closeButton.width) - 20))
            }

            StatusGlyph {
                anchors.verticalCenter: placeName.verticalCenter
                visible: WeatherService.automatic
                width: 10
                height: 10
                icon: "navigation"
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
            x: root.faceRoom > 0 ? parent.width + root.pad - (root.faceRoom + width) / 2 : parent.width - width
            onActivated: root.closeRequested()
        }
    }

    MomentumFlickable {
        id: scroller
        x: root.pad
        y: placeRow.height
        width: root.innerWidth
        height: Math.max(0, Math.min(content.implicitHeight,
                                     root.maxHeight - placeRow.height - Math.max(root.pad, root.footRoom)))
        contentHeight: content.implicitHeight

        Column {
            id: content
            width: root.innerWidth
            spacing: 8

            Item {
                width: parent.width
                height: Math.max(now.implicitHeight, summary.implicitHeight)

                TickerNumber {
                    id: now
                    value: WeatherService.degrees
                    suffix: "°"
                    motion: root.motion
                    fontPixelSize: root.heroDigit
                    fontWeight: Font.Light
                }

                Column {
                    id: summary
                    anchors.right: parent.right
                    anchors.verticalCenter: now.verticalCenter
                    spacing: 2

                    StatusGlyph {
                        anchors.right: parent.right
                        width: 18
                        height: 18
                        icon: WeatherService.icon
                    }

                    Label {
                        anchors.right: parent.right
                        text: WeatherService.condition
                        font.pixelSize: Theme.textBody
                        font.weight: Font.Medium
                    }

                    Reading {
                        anchors.right: parent.right
                        visible: !!root.today
                        text: root.today ? I18n.tr("H:%1 L:%2").arg(root.degrees(root.today.high)).arg(root.degrees(root.today.low)) : ""
                        font.pixelSize: Theme.textBody
                        color: Theme.textSecondary
                    }
                }
            }

            Repeater {
                model: WeatherService.alerts

                Row {
                    required property var modelData
                    spacing: 8
                    width: content.width

                    StatusGlyph {
                        y: 1
                        width: 14
                        height: 14
                        icon: "alert"
                        ink: Qt.lighter(Theme.danger, 2.2)
                    }

                    Column {
                        width: parent.width - 22
                        spacing: 1

                        Label {
                            width: parent.width
                            text: I18n.tr(modelData.event)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Label {
                            visible: !isNaN(modelData.ends)
                            text: I18n.tr("Until %1").arg(root.timeLabel(modelData.ends, true))
                            font.pixelSize: Theme.textLabel
                            color: Theme.textSecondary
                        }
                    }
                }
            }

            Row {
                visible: WeatherService.windWarned && !!root.windNow
                spacing: 8

                StatusGlyph {
                    width: 14
                    height: 14
                    icon: "wind"
                }

                Label {
                    text: !root.windNow ? ""
                        : I18n.tr("Wind %1%2").arg(root.speed(root.windNow.kmh)).arg(root.windNow.from ? " " + I18n.tr(root.windNow.from) : "")
                          + (root.windNow.gustKmh ? I18n.tr(", gusts %1").arg(root.speed(root.windNow.gustKmh)) : "")
                }
            }

            Divider {}

            MomentumFlickable {
                id: hourStrip
                horizontal: true
                width: parent.width
                height: hourRow.implicitHeight
                contentWidth: hourRow.implicitWidth
                contentHeight: height

                // The strip fades out at whichever end has more hours past it.
                Rectangle {
                    parent: hourStrip
                    z: 1
                    width: 18
                    height: hourStrip.height
                    visible: hourStrip.contentX > 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.surface }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                Rectangle {
                    parent: hourStrip
                    z: 1
                    x: hourStrip.width - width
                    width: 18
                    height: hourStrip.height
                    visible: hourStrip.contentX < hourStrip.contentWidth - hourStrip.width - 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Theme.surface }
                    }
                }

                Row {
                    id: hourRow

                    Repeater {
                        model: root.hours

                        Column {
                            required property var modelData
                            width: Math.max(44, stamp.implicitWidth + 10)
                            spacing: 5

                            Label {
                                id: stamp
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.label
                                font.pixelSize: Theme.textLabel
                                font.weight: Font.Medium
                                color: Theme.textSecondary
                            }

                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 20
                                height: 30

                                StatusGlyph {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 18
                                    height: 18
                                    icon: modelData.icon
                                }

                                Reading {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    visible: modelData.chance >= 20
                                    text: modelData.chance + "%"
                                    // Below the ramp: the chance sits under an 18px glyph in a 30px cell and
                                    // textCaption (10) collides with it.
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    color: Theme.purple
                                }
                            }

                            // Sunrise and sunset carry a translated word in place of a reading.
                            Reading {
                                readonly property bool sun: modelData.icon === "sunrise" || modelData.icon === "sunset"
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.reading
                                font.family: sun ? Theme.fontFamily : Theme.latinFontFamily
                                font.pixelSize: sun ? Theme.textLabel : Theme.textStrong
                                font.weight: Font.Medium
                            }
                        }
                    }
                }
            }

            Divider {
                visible: !!WeatherService.airQuality
            }

            Column {
                visible: !!WeatherService.airQuality
                width: parent.width
                spacing: 6

                Item {
                    width: parent.width
                    height: aqiTitle.implicitHeight

                    Label {
                        id: aqiTitle
                        text: I18n.tr("Air Quality")
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }

                    Label {
                        anchors.left: aqiTitle.right
                        anchors.leftMargin: 6
                        anchors.baseline: aqiTitle.baseline
                        visible: WeatherService.airQualityStale
                        text: I18n.tr("Not updated")
                        font.pixelSize: Theme.textLabel
                        color: Theme.textSecondary
                    }

                    Label {
                        anchors.right: parent.right
                        text: WeatherService.airQuality ? WeatherService.airQuality.aqi + " · "
                            + WeatherService.airCategory(WeatherService.airQuality.aqi) : ""
                        font.weight: Font.Medium
                    }
                }

                // US AQI bands, 0 to 300+, toned to the theme.
                Rectangle {
                    id: aqiScale
                    width: parent.width
                    height: 4
                    radius: 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.aqiGood }
                        GradientStop { position: 0.17; color: Theme.aqiGood }
                        GradientStop { position: 0.33; color: Theme.aqiModerate }
                        GradientStop { position: 0.5; color: Theme.aqiSensitive }
                        GradientStop { position: 0.67; color: Theme.aqiUnhealthy }
                        GradientStop { position: 0.85; color: Theme.aqiVeryUnhealthy }
                        GradientStop { position: 1.0; color: Theme.aqiHazardous }
                    }

                    Rectangle {
                        readonly property real at: WeatherService.airQuality ? Math.min(300, WeatherService.airQuality.aqi) / 300 : 0
                        width: 8
                        height: 8
                        radius: 4
                        x: at * (aqiScale.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textPrimary
                        border.width: 2
                        border.color: Theme.surface
                    }
                }
            }

            Divider {
                visible: WeatherService.daily.length > 0
            }

            Column {
                width: parent.width
                visible: WeatherService.daily.length > 0

                Label {
                    anchors.right: parent.right
                    visible: WeatherService.outlookStale
                    text: I18n.tr("Not updated")
                    font.pixelSize: Theme.textLabel
                    color: Theme.textSecondary
                }

                Repeater {
                    model: WeatherService.daily

                    Item {
                        id: day
                        required property var modelData
                        required property int index
                        readonly property real low: WeatherService.toUnits(modelData.low)
                        readonly property real high: WeatherService.toUnits(modelData.high)
                        width: content.width
                        height: 26

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 44
                            text: day.index === 0 ? I18n.tr("Today")
                                : Qt.locale(I18n.qtLocale).dayName(day.modelData.weekday, Locale.ShortFormat)
                            font.weight: Font.Medium
                        }

                        StatusGlyph {
                            x: 48
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: day.modelData.chance >= 20 ? -4 : 0
                            width: 16
                            height: 16
                            icon: day.modelData.icon
                        }

                        Reading {
                            x: 48 + 8 - implicitWidth / 2
                            anchors.bottom: parent.bottom
                            visible: day.modelData.chance >= 20
                            text: day.modelData.chance + "%"
                            // Below the ramp: tucked under a 16px glyph in a 26px row; textCaption (10) overlaps it.
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
                            color: Theme.purple
                        }

                        Reading {
                            id: lowLabel
                            x: 78
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: day.low + "°"
                            font.weight: Font.Medium
                            color: Theme.textSecondary
                        }

                        Rectangle {
                            id: track
                            readonly property real span: Math.max(1, root.rangeHigh - root.rangeLow)
                            x: lowLabel.x + lowLabel.width + 10
                            width: highLabel.x - 10 - x
                            anchors.verticalCenter: parent.verticalCenter
                            height: 4
                            radius: 2
                            color: Theme.track

                            Rectangle {
                                x: (day.low - root.rangeLow) / track.span * track.width
                                width: Math.max(height, (day.high - day.low) / track.span * track.width)
                                height: parent.height
                                radius: 2
                                color: Theme.textSecondary
                            }

                            // Today's bar carries where it is now.
                            Rectangle {
                                visible: day.index === 0 && !isNaN(WeatherService.degrees)
                                readonly property real at: Math.max(root.rangeLow, Math.min(root.rangeHigh, WeatherService.degrees))
                                width: 8
                                height: 8
                                radius: 4
                                x: (at - root.rangeLow) / track.span * track.width - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.textPrimary
                                border.width: 2
                                border.color: Theme.surface
                            }
                        }

                        Reading {
                            id: highLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            horizontalAlignment: Text.AlignRight
                            text: day.high + "°"
                            font.weight: Font.Medium
                        }
                    }
                }
            }
        }
    }
}
