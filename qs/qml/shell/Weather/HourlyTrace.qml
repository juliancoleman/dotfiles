import QtQuick
import QtQuick.Shapes
import ".."
import "../Common"
import "../Status"

// The notebook's day ahead as one line on graph paper: temperature over faint gridlines at round degrees,
// readings above every few hours, the chance of rain as short bars standing on the baseline, sunrise and
// sunset as rules through the plot, and an ink tick where now falls. The trace is the pen's heavier line.
Item {
    id: root

    property bool clock24: ClockConfig.use24Hour

    // Room at either end so the first and last labels are not cut by the page edge.
    readonly property real inset: Theme.px(12)
    readonly property real readingRoom: Theme.px(16)
    readonly property real plotHeight: Theme.px(56)
    readonly property real rainHeight: Theme.px(14)
    readonly property real labelGap: Theme.px(4)
    readonly property real plotTop: readingRoom
    readonly property real floorY: plotTop + plotHeight
    readonly property real plotWidth: Math.max(1, width - inset * 2)

    readonly property var hours: {
        const list = WeatherService.hourly.slice(0, 24)
        return list.map((h, i) => ({
            time: h.start,
            // The first hour reads what is observed now, as the hero above it does.
            value: i === 0 && !isNaN(WeatherService.degrees) ? WeatherService.degrees
                : h.celsius === null ? NaN : WeatherService.toUnits(h.celsius),
            chance: h.chance,
            label: i === 0 ? I18n.tr("Now") : timeLabel(h.start, h.offset)
        }))
    }
    readonly property real first: hours.length > 0 ? hours[0].time : 0
    readonly property real last: hours.length > 1 ? hours[hours.length - 1].time : first + 1
    // Every third hour where it fits, every fourth on a narrow page, so labels never touch.
    readonly property int every: hours.length > 0 && plotWidth / hours.length * 3 >= Theme.px(40) ? 3 : 4

    // Gridlines at every 5° over a calm day, every 10° over a wide one; the plot spans whole steps.
    readonly property var axis: {
        let low = Infinity
        let high = -Infinity
        for (const h of hours) {
            if (isNaN(h.value))
                continue
            low = Math.min(low, h.value)
            high = Math.max(high, h.value)
        }
        if (low === Infinity)
            return { low: 0, high: 10, step: 10 }
        const step = high - low <= 15 ? 5 : 10
        const bottom = Math.floor(low / step) * step
        return { low: bottom, high: Math.max(bottom + step, Math.ceil(high / step) * step), step: step }
    }

    readonly property var gridlines: {
        const out = []
        for (let v = axis.low; v <= axis.high; v += axis.step)
            out.push(v)
        return out
    }

    readonly property var suns: WeatherService.sunTimes.filter(s => s.time > Math.max(first, WeatherService.now) && s.time < last)

    implicitHeight: floorY + labelGap + Theme.textCaption * 1.4 + (suns.length > 0 ? Theme.px(6) + Theme.textCaption * 1.4 : 0)

    // Hourly entries carry their own offset; sun events look theirs up.
    function timeLabel(epoch, offset, minutes) {
        const local = WeatherService.wallClock(epoch, offset === undefined ? WeatherService.offsetAt(epoch) : offset)
        return I18n.timeOfDay(local.getUTCHours(), local.getUTCMinutes(), clock24, !!minutes)
    }

    function xAt(time) {
        return inset + (time - first) / Math.max(1, last - first) * plotWidth
    }

    function yAt(value) {
        return plotTop + (axis.high - value) / Math.max(1, axis.high - axis.low) * plotHeight
    }

    Repeater {
        model: root.gridlines

        Rule {
            required property real modelData
            x: root.inset
            y: Math.round(root.yAt(modelData))
            width: root.plotWidth
        }
    }

    Repeater {
        model: root.suns

        Rule {
            required property var modelData
            vertical: true
            x: Math.round(root.xAt(modelData.time))
            y: root.plotTop
            height: root.plotHeight
        }
    }

    // Rain stands on the baseline in the track tone, under the line so the temperature stays legible. Slim
    // chances are left out; a row of 1px stubs would only read as a dashed baseline.
    Repeater {
        model: root.hours

        Rectangle {
            required property var modelData
            readonly property real step: root.plotWidth / Math.max(1, root.hours.length - 1)
            visible: modelData.chance >= 10
            width: Math.max(Theme.px(2), step * 0.5)
            height: Math.max(1, modelData.chance / 100 * root.rainHeight)
            x: root.xAt(modelData.time) - width / 2
            y: root.floorY - height
            color: Theme.statusTrack
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.textPrimary
            strokeWidth: Theme.lineStrong
            fillColor: Theme.clear
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root.hours.filter(h => !isNaN(h.value)).map(h => Qt.point(root.xAt(h.time), root.yAt(h.value)))
            }
        }
    }

    // Now, in ink, crossing the baseline.
    Rectangle {
        visible: root.hours.length > 0
        width: Theme.lineStrong
        height: Theme.px(8)
        x: Math.round(root.xAt(Math.max(root.first, Math.min(root.last, WeatherService.now)))) - width / 2
        y: root.floorY - height / 2
        color: Theme.today
    }

    Repeater {
        model: root.hours

        Item {
            id: hour
            required property var modelData
            required property int index
            readonly property real at: root.xAt(modelData.time)
            visible: index % root.every === 0

            Text {
                x: hour.at - width / 2
                y: root.yAt(hour.modelData.value) - height - Theme.px(1)
                visible: !isNaN(hour.modelData.value)
                text: hour.modelData.value + "°"
                color: Theme.textPrimary
                font.family: Theme.latinFontFamily
                font.pixelSize: Theme.textLabel
                font.weight: Theme.fontWeightStrong
                font.features: { "tnum": 1 }
            }

            Text {
                x: hour.at - width / 2
                y: root.floorY + root.labelGap
                text: hour.modelData.label
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textCaption
                font.features: { "tnum": 1 }
            }
        }
    }

    // The rules through the plot are named underneath, in the order they come.
    Row {
        visible: root.suns.length > 0
        y: root.floorY + root.labelGap + Theme.textCaption * 1.4 + Theme.px(6)
        x: root.inset
        spacing: Theme.px(12)

        Repeater {
            model: root.suns

            Row {
                required property var modelData
                spacing: Theme.px(4)

                StatusGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.px(12)
                    height: Theme.px(12)
                    icon: modelData.rise ? "sunrise" : "sunset"
                    ink: Theme.textSecondary
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (modelData.rise ? I18n.tr("Sunrise") : I18n.tr("Sunset")) + " " + root.timeLabel(modelData.time, undefined, true)
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textCaption
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
}
