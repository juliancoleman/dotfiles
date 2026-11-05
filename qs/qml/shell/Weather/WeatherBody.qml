import QtQuick
import ".."
import "../Clock"
import "../Common"
import "../Status"

// The weather as a page in the notebook: the temperature written large with the sky beside it, warnings as
// rows, the next day as a trace on graph paper, air quality on a ruler, and ten days of highs and lows on
// one graph-paper axis. Every line is the pen's.
Column {
    id: root

    required property Item panel

    spacing: Theme.px(8)

    // The ten days share one axis so each span reads against the whole stretch. Gridlines fall every 10°,
    // or every 5° over a calm stretch, and the axis runs whole steps so its ends are gridlines too.
    readonly property var range: {
        const week = panel.weekRange
        if (WeatherService.daily.length === 0)
            return { low: 0, high: 10, step: 10 }
        const step = week.high - week.low <= 20 ? 5 : 10
        const bottom = Math.floor(week.low / step) * step
        return { low: bottom, high: Math.max(bottom + step, Math.ceil(week.high / step) * step), step: step }
    }
    readonly property real rangeLow: range.low
    readonly property real rangeHigh: range.high
    readonly property var rangeLines: {
        const out = []
        for (let v = range.low; v <= range.high; v += range.step)
            out.push(v)
        return out
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

    // A section opens with its caption written just above its rule.
    component Caption: Column {
        id: caption
        property alias text: captionText.text
        property alias note: noteText.text
        // Where the caption's baseline sits in its row, for readings written on the same line.
        readonly property real textBaseline: captionText.baselineOffset
        default property alias extra: captionRow.data
        width: root.width
        topPadding: Theme.px(6)
        spacing: Theme.px(4)

        Item {
            id: captionRow
            width: parent.width
            height: captionText.implicitHeight

            Label {
                id: captionText
                font.pixelSize: Theme.textCaption
                color: Theme.textSecondary
            }

            Label {
                id: noteText
                anchors.left: captionText.right
                anchors.leftMargin: Theme.px(6)
                anchors.baseline: captionText.baseline
                visible: text.length > 0
                font.pixelSize: Theme.textCaption
                color: Theme.textSecondary
                opacity: 0.7
            }
        }

        Rule {
            width: parent.width
        }
    }

    // The one reading: the temperature, with the sky and the day's range written beside it on its baseline
    // rather than stacked under an icon.
    Item {
        width: parent.width
        height: now.height

        TickerNumber {
            id: now
            value: WeatherService.degrees
            suffix: "°"
            motion: root.panel.motion
            fontPixelSize: Theme.textHero
            fontWeight: Font.Light
        }

        Row {
            id: sky
            anchors.left: now.right
            anchors.leftMargin: Theme.px(14)
            anchors.bottom: dayRange.top
            anchors.bottomMargin: Theme.px(3)
            spacing: Theme.px(5)

            StatusGlyph {
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.px(14)
                height: Theme.px(14)
                icon: WeatherService.icon
            }

            Label {
                width: Math.min(implicitWidth, root.width - sky.x - Theme.px(19))
                text: WeatherService.condition
                elide: Text.ElideRight
            }
        }

        Reading {
            id: dayRange
            anchors.left: sky.left
            anchors.baseline: now.baseline
            visible: !!root.panel.today
            text: root.panel.today ? I18n.tr("High %1 · Low %2").arg(root.panel.degrees(root.panel.today.high))
                                                                .arg(root.panel.degrees(root.panel.today.low)) : ""
            font.family: Theme.fontFamily
            color: Theme.textSecondary
        }
    }

    // Warnings are rows on the page: a danger tick at the margin when the alert is severe.
    Repeater {
        model: WeatherService.alerts

        Item {
            required property var modelData
            readonly property bool severe: root.panel.severe(modelData)
            width: root.width
            height: alertText.implicitHeight

            Rectangle {
                visible: parent.severe
                width: Theme.lineStrong
                height: parent.height
                color: Theme.dangerMark
            }

            StatusGlyph {
                x: Theme.px(8)
                y: Theme.px(1)
                width: Theme.px(14)
                height: Theme.px(14)
                icon: "alert"
                ink: Theme.dangerMark
            }

            Column {
                id: alertText
                x: Theme.px(30)
                width: parent.width - x
                spacing: Theme.px(1)

                Label {
                    width: parent.width
                    text: I18n.tr(modelData.event)
                    font.weight: Theme.fontWeightStrong
                    elide: Text.ElideRight
                }

                Label {
                    visible: !isNaN(modelData.ends)
                    text: I18n.tr("Until %1").arg(root.panel.timeLabel(modelData.ends, true))
                    font.pixelSize: Theme.textCaption
                    color: Theme.textSecondary
                }
            }
        }
    }

    Row {
        visible: WeatherService.windWarned && !!root.panel.windNow
        spacing: Theme.px(8)
        leftPadding: Theme.px(8)

        StatusGlyph {
            width: Theme.px(14)
            height: Theme.px(14)
            icon: "wind"
        }

        Label {
            text: root.panel.windText
        }
    }

    Caption {
        visible: WeatherService.hourly.length > 0
        text: I18n.tr("Next 24 hours")
    }

    HourlyTrace {
        visible: WeatherService.hourly.length > 0
        width: parent.width
        clock24: root.panel.clock24
    }

    Caption {
        id: aqiCaption
        visible: !!WeatherService.airQuality
        text: I18n.tr("Air quality")
        note: WeatherService.airQualityStale ? I18n.tr("Not updated") : ""

        Row {
            anchors.right: parent.right
            y: aqiCaption.textBaseline - aqiBand.baselineOffset
            spacing: Theme.px(5)

            TickerNumber {
                anchors.baseline: aqiBand.baseline
                value: WeatherService.airQuality ? WeatherService.airQuality.aqi : NaN
                motion: root.panel.motion
                fontPixelSize: Theme.textBody
                fontWeight: Theme.fontWeightStrong
            }

            Label {
                id: aqiBand
                text: WeatherService.airQuality ? WeatherService.airCategory(WeatherService.airQuality.aqi) : ""
            }
        }
    }

    // A ruler from 0 to 300 with ticks at the band edges; the reading is a short mark in its band's color,
    // the only color on the page.
    Item {
        id: aqiScale
        visible: !!WeatherService.airQuality
        readonly property real reach: Math.max(1, width - Theme.px(16))
        width: parent.width
        height: Theme.px(28)

        function xAt(aqi) {
            return Theme.px(8) + Math.min(300, Math.max(0, aqi)) / 300 * reach
        }

        Rectangle {
            x: aqiScale.xAt(0)
            y: Theme.px(8)
            width: aqiScale.reach
            height: Theme.line
            color: Theme.statusTrack
        }

        Repeater {
            model: [0].concat(root.panel.aqiBands)

            Item {
                required property int modelData

                Rectangle {
                    x: Math.round(aqiScale.xAt(modelData))
                    y: Theme.px(5)
                    width: Theme.line
                    height: Theme.px(4)
                    color: Theme.statusTrack
                }

                Reading {
                    x: aqiScale.xAt(modelData) - width / 2
                    y: Theme.px(12)
                    text: modelData
                    font.pixelSize: Theme.textMicro
                    color: Theme.textSecondary
                }
            }
        }

        Rectangle {
            x: Math.round(aqiScale.xAt(root.panel.aqi)) - width / 2
            y: Theme.px(2)
            width: Theme.lineStrong
            height: Theme.px(10)
            color: root.panel.aqiColor(root.panel.aqi)
        }
    }

    Caption {
        visible: WeatherService.daily.length > 0
        text: I18n.tr("10-day forecast")
        note: WeatherService.outlookStale ? I18n.tr("Not updated") : ""

        // The axis is labeled once, over the gridlines it names.
        Repeater {
            model: root.rangeLines

            Reading {
                required property real modelData
                x: days.xAt(modelData) - width / 2
                anchors.bottom: parent.bottom
                text: modelData + "°"
                font.pixelSize: Theme.textMicro
                color: Theme.textSecondary
            }
        }
    }

    Item {
        id: days
        visible: WeatherService.daily.length > 0
        readonly property real spanX: Theme.px(124)
        readonly property real spanWidth: width - spanX - Theme.px(44)
        width: parent.width
        height: dayRows.height

        function xAt(value) {
            return spanX + (value - root.rangeLow) / Math.max(1, root.rangeHigh - root.rangeLow) * spanWidth
        }

        // Graph paper behind every row.
        Repeater {
            model: root.rangeLines

            Rule {
                required property real modelData
                vertical: true
                x: Math.round(days.xAt(modelData))
                height: days.height
            }
        }

        Column {
            id: dayRows
            width: parent.width

            Repeater {
                model: WeatherService.daily

                Item {
                    id: day
                    required property var modelData
                    required property int index
                    readonly property real low: WeatherService.toUnits(modelData.low)
                    readonly property real high: WeatherService.toUnits(modelData.high)
                    width: days.width
                    height: Theme.px(26)

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(44)
                        text: root.panel.dayName(day.modelData, day.index)
                        font.weight: Theme.fontWeightStrong
                    }

                    StatusGlyph {
                        x: Theme.px(48)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: day.modelData.chance >= 20 ? -Theme.px(4) : 0
                        width: Theme.px(14)
                        height: Theme.px(14)
                        icon: day.modelData.icon
                    }

                    Reading {
                        x: Theme.px(55) - implicitWidth / 2
                        anchors.bottom: parent.bottom
                        visible: day.modelData.chance >= 20
                        text: day.modelData.chance + "%"
                        font.pixelSize: Theme.textMicro
                        font.weight: Theme.fontWeightStrong
                        color: Theme.today
                    }

                    Reading {
                        x: Theme.px(76)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(34)
                        horizontalAlignment: Text.AlignRight
                        text: day.low + "°"
                        color: Theme.textSecondary
                    }

                    // The day's range: a span in the pen's heavier line with an end tick at each extreme.
                    Rectangle {
                        x: days.xAt(day.low)
                        width: Math.max(Theme.line, days.xAt(day.high) - x)
                        height: Theme.lineStrong
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textPrimary
                    }

                    Rectangle {
                        x: Math.round(days.xAt(day.low))
                        width: Theme.line
                        height: Theme.px(8)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textPrimary
                    }

                    Rectangle {
                        x: Math.round(days.xAt(day.high)) - width
                        width: Theme.line
                        height: Theme.px(8)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.textPrimary
                    }

                    // Today's row carries where it is now, a short ink tick.
                    Rectangle {
                        visible: day.index === 0 && !isNaN(WeatherService.degrees)
                        x: Math.round(days.xAt(Math.max(root.rangeLow, Math.min(root.rangeHigh, WeatherService.degrees)))) - width / 2
                        width: Theme.lineStrong
                        height: Theme.px(12)
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.today
                    }

                    Reading {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.px(34)
                        horizontalAlignment: Text.AlignRight
                        text: day.high + "°"
                    }
                }
            }
        }
    }
}
