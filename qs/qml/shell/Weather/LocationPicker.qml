import QtQuick
import Quickshell.Io
import ".."
import "../Common"

// The chosen place (or what location services found) and, for an exact place, a city search.
Column {
    id: root

    property var results: []
    property bool searching: false
    readonly property bool exact: !WeatherService.automatic

    spacing: 8

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
                return fix ? qsTr("Near %1").arg(WeatherService.place || fix.latitude.toFixed(2) + ", " + fix.longitude.toFixed(2))
                           : WeatherService.error || qsTr("Finding your location…")
            }
            const spot = ClockConfig.weatherLocation
            return spot ? root.describe(spot) : qsTr("Search for a city to show its weather")
        }
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
    }

    Text {
        width: parent.width
        visible: text.length > 0
        text: root.exact || WeatherService.automaticFix ? WeatherService.error : ""
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
    }

    Rectangle {
        visible: root.exact
        width: parent.width
        height: visible ? 34 : 0
        radius: 10
        color: Theme.track
        border.width: 1
        border.color: field.activeFocus ? Theme.today : Qt.rgba(1, 1, 1, 0.05)

        Text {
            anchors.fill: field
            verticalAlignment: Text.AlignVCenter
            visible: field.text.length === 0
            text: root.searching ? qsTr("Searching…") : qsTr("Search for a city")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 13
        }

        TextInput {
            id: field
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            clip: true
            color: Theme.textPrimary
            selectionColor: Theme.today
            selectedTextColor: Theme.todayInk
            font.family: Theme.fontFamily
            font.pixelSize: 13
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter
            Accessible.role: Accessible.EditableText
            Accessible.name: qsTr("Search for a city")
            onTextChanged: debounce.restart()
            Keys.onReturnPressed: root.chooseFirst()
            Keys.onEnterPressed: root.chooseFirst()
        }
    }

    Repeater {
        model: root.exact ? root.results : []

        Rectangle {
            id: row
            required property var modelData
            width: root.width
            height: 30
            radius: 8
            color: rowHit.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"

            Text {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.describe(row.modelData)
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 13
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
