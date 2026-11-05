import QtQuick
import Quickshell.Io
import ".."
import "../Common"

// The chosen place (or what location services found) and, for an exact place, a city search whose results
// sit on the page.
Column {
    id: root

    property var results: []
    property bool searching: false
    readonly property bool exact: !WeatherService.automatic
    // Where text starts inside the field: on its line, just off the margin.
    readonly property real fieldInset: Theme.px(2)
    readonly property real rowInset: Theme.px(12)

    spacing: Theme.px(8)

    function describe(spot) {
        return spot.region ? spot.name + ", " + spot.region : spot.name
    }

    function choose(spot) {
        ClockConfig.weatherLocation = spot
        ClockConfig.save()
        field.text = ""
        results = []
    }

    function chooseFirst() {
        if (results.length > 0)
            choose(results[0])
    }

    function search() {
        const name = field.text.trim()
        if (name.length < 2) {
            results = []
            return
        }
        // The National Weather Service only covers the United States.
        lookup.command = ["curl", "-sfL", "--max-time", "10",
                          "https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&format=json&countryCode=US&name="
                          + encodeURIComponent(name)]
        searching = true
        lookup.running = true
    }

    Text {
        width: parent.width
        text: {
            if (!root.exact) {
                const fix = WeatherService.automaticFix
                return fix ? I18n.tr("Near %1").arg(WeatherService.place || fix.latitude.toFixed(2) + ", " + fix.longitude.toFixed(2))
                           : WeatherService.errorText || I18n.tr("Finding your location…")
            }
            const spot = ClockConfig.weatherLocation
            return spot ? root.describe(spot) : I18n.tr("Search for a city to show its weather")
        }
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textStrong
        elide: Text.ElideRight
    }

    Text {
        width: parent.width
        visible: text.length > 0
        text: root.exact || WeatherService.automaticFix ? WeatherService.errorText : ""
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
        elide: Text.ElideRight
    }

    Item {
        visible: root.exact
        width: parent.width
        height: visible ? Theme.px(34) : 0

        Field {
            anchors.fill: parent
            focused: field.activeFocus
        }

        Text {
            anchors.fill: field
            verticalAlignment: Text.AlignVCenter
            visible: field.text.length === 0
            text: root.searching ? I18n.tr("Searching…") : I18n.tr("Search for a city")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
        }

        TextInput {
            id: field
            anchors.fill: parent
            anchors.leftMargin: root.fieldInset
            anchors.rightMargin: root.fieldInset
            clip: true
            color: Theme.textPrimary
            selectionColor: Theme.today
            selectedTextColor: Theme.todayInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter
            Accessible.role: Accessible.EditableText
            Accessible.name: I18n.tr("Search for a city")
            onTextChanged: debounce.restart()
            Keys.onReturnPressed: root.chooseFirst()
            Keys.onEnterPressed: root.chooseFirst()
        }
    }

    Column {
        id: resultColumn
        visible: rows.count > 0
        width: root.width

        Repeater {
            id: rows
            model: root.exact ? root.results : []

            Rectangle {
                id: row
                required property var modelData
                width: resultColumn.width
                height: Theme.px(32)
                radius: Theme.radiusInput
                color: rowHit.pressed ? Theme.press : rowHit.containsMouse ? Theme.lift : Theme.clear

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: root.rowInset
                    anchors.rightMargin: root.rowInset
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.describe(row.modelData)
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textBody
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: rowHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: root.describe(row.modelData)
                    onClicked: root.choose(row.modelData)
                }
            }
        }
    }

    Timer {
        id: debounce
        interval: 350
        onTriggered: root.search()
    }

    Process {
        id: lookup
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false
                if (field.text.trim().length < 2)
                    return
                try {
                    const found = JSON.parse(text).results || []
                    root.results = found.map(place => ({
                        name: place.name,
                        region: place.admin1 || place.country || "",
                        latitude: place.latitude,
                        longitude: place.longitude
                    }))
                } catch (problem) {
                    root.results = []
                }
            }
        }
    }
}
