import QtQuick
import "../Common"

Item {
    id: grid

    property int year: 1970
    property int month: 0
    property date today: new Date()
    property string localeName: "en"
    property int motionDuration: 250
    property int motionCurve: Easing.OutCubic
    property bool motionNone: false

    readonly property real cell: 24
    readonly property real gap: 2
    readonly property real weekHeight: 16
    readonly property int columns: 7
    property int rows: 6
    property real rowSpan: 6
    readonly property var weekdayLabels: localeName === "jp"
        ? ["日", "月", "火", "水", "木", "金", "土"]
        : ["S", "M", "T", "W", "T", "F", "S"]

    implicitWidth: columns * cell + (columns - 1) * gap
    implicitHeight: weekHeight + 6 + rowSpan * cell + Math.max(0, rowSpan - 1) * gap
    clip: true

    property var days: []
    property string todayKey: ""
    property real slideX: 0
    property real slideFade: 1

    function weekRows(nextYear, nextMonth) {
        const firstDow = new Date(nextYear, nextMonth, 1).getDay()
        const length = new Date(nextYear, nextMonth + 1, 0).getDate()
        return Math.ceil((firstDow + length) / 7)
    }

    function rebuild(nextYear, nextMonth) {
        const count = weekRows(nextYear, nextMonth)
        rows = count
        const first = new Date(nextYear, nextMonth, 1)
        const start = new Date(nextYear, nextMonth, 1 - first.getDay())
        const next = []
        for (var i = 0; i < count * columns; ++i) {
            const cellDate = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            next.push({
                day: cellDate.getDate(),
                inMonth: cellDate.getFullYear() === nextYear && cellDate.getMonth() === nextMonth,
                today: cellDate.getFullYear() === today.getFullYear()
                    && cellDate.getMonth() === today.getMonth()
                    && cellDate.getDate() === today.getDate()
            })
        }
        days = next
    }

    function show(nextYear, nextMonth, animate) {
        const had = days.length > 0
        const forward = nextYear > year || (nextYear === year && nextMonth > month)
        const backward = nextYear < year || (nextYear === year && nextMonth < month)
        const same = nextYear === year && nextMonth === month
        year = nextYear
        month = nextMonth
        rebuild(nextYear, nextMonth)
        if (!animate || motionNone) {
            rowEase.stop()
            rowSpan = rows
        } else if (Math.abs(rowSpan - rows) > 0.05) {
            rowEase.stop()
            rowEase.from = rowSpan
            rowEase.to = rows
            rowEase.start()
        }
        if (!animate || motionNone || !had || same || (!forward && !backward)) {
            slideEase.stop()
            fadeEase.stop()
            slideX = 0
            slideFade = 1
            return
        }
        const kick = (forward ? 1 : -1) * 18
        slideEase.stop()
        fadeEase.stop()
        slideX += kick
        slideFade = Math.min(slideFade, 0.45)
        slideEase.from = slideX
        slideEase.to = 0
        fadeEase.from = slideFade
        fadeEase.to = 1
        slideEase.start()
        fadeEase.start()
    }

    onTodayChanged: {
        if (!today || isNaN(today.getTime()))
            return
        const key = today.getFullYear() + "-" + today.getMonth() + "-" + today.getDate()
        if (key === todayKey)
            return
        todayKey = key
        if (days.length)
            rebuild(year, month)
    }

    Row {
        spacing: grid.gap

        Repeater {
            model: grid.weekdayLabels

            Text {
                required property string modelData
                width: grid.cell
                height: grid.weekHeight
                text: modelData
                color: Theme.textSecondary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.fontFamily
                font.pixelSize: 10
                font.weight: Theme.clockFontWeight
            }
        }
    }

    Item {
        y: grid.weekHeight + 6
        width: grid.implicitWidth
        height: grid.rows * grid.cell + (grid.rows - 1) * grid.gap
        clip: true

        Item {
            x: grid.slideX
            width: parent.width
            height: parent.height
            opacity: grid.slideFade

            Repeater {
                model: grid.days

                Item {
                    required property var modelData
                    required property int index
                    x: (index % grid.columns) * (grid.cell + grid.gap)
                    y: Math.floor(index / grid.columns) * (grid.cell + grid.gap)
                    width: grid.cell
                    height: grid.cell

                    Text {
                        anchors.centerIn: parent
                        text: modelData.day
                        color: modelData.today ? Theme.today
                             : modelData.inMonth ? Theme.textPrimary : Theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: modelData.today ? Font.DemiBold : Theme.clockFontWeight
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: rowEase
        target: grid
        property: "rowSpan"
        duration: grid.motionNone ? 0 : grid.motionDuration
        easing.type: grid.motionCurve
        easing.overshoot: Theme.springOvershoot
    }

    NumberAnimation {
        id: slideEase
        target: grid
        property: "slideX"
        duration: grid.motionNone ? 0 : grid.motionDuration
        easing.type: grid.motionCurve
        easing.overshoot: Theme.springOvershoot
    }

    NumberAnimation {
        id: fadeEase
        target: grid
        property: "slideFade"
        duration: grid.motionNone ? 0 : Math.round(grid.motionDuration * 0.72)
        easing.type: grid.motionCurve
        easing.overshoot: Theme.springOvershoot
    }
}
