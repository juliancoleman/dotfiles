import QtQuick
import Quickshell
import Quickshell.Wayland
import "."
import "Common"
import "Weather"

PanelWindow {
    id: window

    visible: ClockConfig.settingsOpen
    implicitWidth: 608
    // Grows for pages taller than the sidebar, like Weather with its search results.
    implicitHeight: Math.max(384, contentColumn.implicitHeight + 44)
    color: "transparent"
    exclusiveZone: 0
    focusable: true
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        left: true
    }

    margins {
        top: 16
        left: 16
    }

    property string query: ""
    property string pageId: "clock"

    readonly property var catalog: [
        {
            id: "theme",
            title: qsTr("Theme"),
            controls: [
                {
                    key: "locale",
                    title: qsTr("Locale"),
                    choices: [
                        { label: qsTr("English"), value: "en" },
                        { label: "日本語", value: "jp" }
                    ]
                },
                {
                    key: "presentation",
                    title: qsTr("Housing"),
                    choices: [
                        { label: qsTr("Pill"), value: "pill" },
                        { label: qsTr("Notch"), value: "notch" }
                    ]
                },
                {
                    key: "placement",
                    title: qsTr("Edge"),
                    choices: [
                        { label: qsTr("Top"), value: "top" },
                        { label: qsTr("Right"), value: "right" },
                        { label: qsTr("Bottom"), value: "bottom" },
                        { label: qsTr("Left"), value: "left" }
                    ]
                },
                {
                    key: "shadow",
                    title: qsTr("Shadow"),
                    keywords: "drop shadow float floating depth elevation",
                    choices: [
                        { label: qsTr("On"), value: "on" },
                        { label: qsTr("Off"), value: "off" }
                    ]
                },
                { key: "palette", title: qsTr("Palette"), keywords: "color colour ink pen bordeaux green blue black purple" }
            ]
        },
        {
            id: "motion",
            title: qsTr("Motion"),
            controls: [
                {
                    key: "motion",
                    title: qsTr("Motion"),
                    choices: [
                        { label: qsTr("Spring"), value: "spring" },
                        { label: qsTr("Ease out"), value: "easeOut" },
                        { label: qsTr("Ease in"), value: "easeIn" },
                        { label: qsTr("Linear"), value: "linear" },
                        { label: qsTr("None"), value: "none" }
                    ]
                },
                { key: "duration", title: qsTr("Duration"), keywords: "ms millisecond" },
                { key: "spring", title: qsTr("Spring factor"), keywords: "overshoot bounce" }
            ]
        },
        {
            id: "clock",
            title: qsTr("Clock"),
            controls: [
                {
                    key: "hourCycle",
                    title: qsTr("Format"),
                    choices: [
                        { label: qsTr("12 hour"), value: "12" },
                        { label: qsTr("24 hour"), value: "24" }
                    ]
                },
                {
                    key: "meridiem",
                    title: qsTr("AM / PM"),
                    keywords: "meridiem period am pm 午前 午後",
                    choices: [
                        { label: qsTr("Show"), value: "shown" },
                        { label: qsTr("Hide"), value: "hidden" }
                    ]
                }
            ]
        },
        {
            id: "status",
            title: qsTr("Status"),
            controls: [
                {
                    key: "batteryPercentage",
                    title: qsTr("Battery percentage"),
                    keywords: "battery percent low power",
                    choices: [
                        { label: qsTr("Always"), value: "always" },
                        { label: qsTr("20% and below"), value: "low" }
                    ]
                }
            ]
        },
        {
            id: "launcher",
            title: qsTr("Launcher"),
            controls: [
                {
                    key: "launcherView",
                    title: qsTr("Default view"),
                    keywords: "applications apps search list grid icons super space",
                    choices: [
                        { label: qsTr("List"), value: "list" },
                        { label: qsTr("Large icons"), value: "large" },
                        { label: qsTr("Small icons"), value: "small" }
                    ]
                }
            ]
        },
        {
            id: "weather",
            title: qsTr("Weather"),
            controls: [
                {
                    key: "weatherEnabled",
                    title: qsTr("Show weather"),
                    keywords: "show hide forecast temperature",
                    choices: [
                        { label: qsTr("On"), value: "on" },
                        { label: qsTr("Off"), value: "off" }
                    ]
                },
                {
                    key: "weatherUnits",
                    title: qsTr("Units"),
                    keywords: "temperature celsius fahrenheit degrees",
                    choices: [
                        { label: "°F", value: "imperial" },
                        { label: "°C", value: "metric" }
                    ]
                },
                {
                    key: "weatherAlerts",
                    title: qsTr("Alerts"),
                    keywords: "notify notification warning rain snow storm wind tornado",
                    choices: [
                        { label: qsTr("On"), value: "on" },
                        { label: qsTr("Off"), value: "off" }
                    ]
                },
                {
                    key: "weatherLocationMode",
                    title: qsTr("Location"),
                    keywords: "city search place automatic location services gps",
                    choices: [
                        { label: qsTr("Exact"), value: "exact" },
                        { label: qsTr("Automatic"), value: "automatic" }
                    ]
                }
            ]
        },
        {
            id: "privacy",
            title: qsTr("Privacy"),
            controls: [
                {
                    key: "locationServices",
                    title: qsTr("Location services"),
                    keywords: "location gps geoclue where privacy time zone",
                    choices: [
                        { label: qsTr("On"), value: "on" },
                        { label: qsTr("Off"), value: "off" }
                    ]
                }
            ]
        }
    ]

    readonly property string pageTitle: {
        const section = sectionById(pageId)
        return section ? section.title : ""
    }

    readonly property var sidebarEntries: {
        const q = normalizedQuery()
        const next = []
        for (var i = 0; i < catalog.length; ++i) {
            if (sectionHit(catalog[i], q))
                next.push({ id: catalog[i].id, title: catalog[i].title })
        }
        return next
    }

    readonly property var contentEntries: {
        const q = normalizedQuery()
        const section = sectionById(pageId)
        if (!section)
            return []
        if (!q || includes(section.title, q))
            return section.controls
        const next = []
        for (var i = 0; i < section.controls.length; ++i) {
            if (controlHit(section.controls[i], q))
                next.push(section.controls[i])
        }
        return next
    }

    function normalizedQuery() {
        return query.trim().toLowerCase()
    }

    function includes(text, q) {
        return String(text || "").toLowerCase().indexOf(q) >= 0
    }

    function sectionById(id) {
        for (var i = 0; i < catalog.length; ++i) {
            if (catalog[i].id === id)
                return catalog[i]
        }
        return null
    }

    function controlByKey(key) {
        for (var s = 0; s < catalog.length; ++s) {
            const controls = catalog[s].controls
            for (var i = 0; i < controls.length; ++i) {
                if (controls[i].key === key)
                    return controls[i]
            }
        }
        return null
    }

    function controlHit(control, q) {
        if (includes(control.title, q))
            return true
        if (control.keywords && includes(control.keywords, q))
            return true
        const choices = control.choices || []
        for (var i = 0; i < choices.length; ++i) {
            if (includes(choices[i].label, q) || includes(choices[i].value, q))
                return true
        }
        return false
    }

    function sectionHit(section, q) {
        if (!q)
            return true
        if (includes(section.title, q))
            return true
        for (var i = 0; i < section.controls.length; ++i) {
            if (controlHit(section.controls[i], q))
                return true
        }
        return false
    }

    function sidebarHas(id) {
        for (var i = 0; i < sidebarEntries.length; ++i) {
            if (sidebarEntries[i].id === id)
                return true
        }
        return false
    }

    function shows(key) {
        for (var i = 0; i < contentEntries.length; ++i) {
            if (contentEntries[i].key === key)
                return true
        }
        return false
    }

    function valueFor(key) {
        switch (key) {
        case "motion":
            return ClockConfig.motion
        case "hourCycle":
            return ClockConfig.use24Hour ? "24" : "12"
        case "meridiem":
            return ClockConfig.showPeriod ? "shown" : "hidden"
        case "locale":
            return ClockConfig.locale
        case "presentation":
            return ClockConfig.presentation
        case "placement":
            return ClockConfig.placement
        case "shadow":
            return ClockConfig.shadow ? "on" : "off"
        case "batteryPercentage":
            return ClockConfig.batteryPercentage
        case "weatherEnabled":
            return ClockConfig.weatherEnabled ? "on" : "off"
        case "launcherView":
            return ClockConfig.launcherView
        case "locationServices":
            return LocationServices.enabled ? "on" : "off"
        case "weatherUnits":
            return ClockConfig.weatherUnits
        case "weatherAlerts":
            return ClockConfig.weatherAlerts ? "on" : "off"
        case "weatherLocationMode":
            return ClockConfig.weatherLocationMode
        default:
            return ""
        }
    }

    function applyPick(key, next) {
        switch (key) {
        case "motion":
            ClockConfig.motion = next
            break
        case "hourCycle":
            ClockConfig.use24Hour = next === "24"
            break
        case "meridiem":
            ClockConfig.showPeriod = next === "shown"
            break
        case "locale":
            ClockConfig.locale = next
            break
        case "presentation":
            ClockConfig.presentation = next
            break
        case "placement":
            ClockConfig.placement = next
            break
        case "shadow":
            ClockConfig.shadow = next === "on"
            break
        case "batteryPercentage":
            ClockConfig.batteryPercentage = next
            break
        case "launcherView":
            ClockConfig.launcherView = next
            break
        case "locationServices":
            LocationServices.setEnabled(next === "on")
            return
        case "weatherEnabled":
            ClockConfig.weatherEnabled = next === "on"
            break
        case "weatherUnits":
            ClockConfig.weatherUnits = next
            break
        case "weatherAlerts":
            ClockConfig.weatherAlerts = next === "on"
            break
        case "weatherLocationMode":
            ClockConfig.weatherLocationMode = next
            break
        default:
            return
        }
        ClockConfig.save()
    }

    function choiceList(key) {
        const control = controlByKey(key)
        return control && control.choices ? control.choices : []
    }

    function controlTitle(key) {
        const control = controlByKey(key)
        return control ? control.title : ""
    }

    function reconcilePage() {
        const q = normalizedQuery()
        const current = sectionById(pageId)
        if (current && sectionHit(current, q))
            return
        for (var i = 0; i < catalog.length; ++i) {
            if (sectionHit(catalog[i], q)) {
                pageId = catalog[i].id
                return
            }
        }
        pageId = ""
    }

    function focusFirstNav() {
        const rows = [themeNav, motionNav, clockNav, statusNav, launcherNav, weatherNav, privacyNav]
        for (var i = 0; i < rows.length; ++i) {
            if (rows[i].visible) {
                rows[i].forceActiveFocus()
                return
            }
        }
        searchField.forceActiveFocus()
    }

    function focusNav(fromRow, direction) {
        const rows = [themeNav, motionNav, clockNav, statusNav, launcherNav, weatherNav, privacyNav]
        var index = 0
        for (var i = 0; i < rows.length; ++i) {
            if (rows[i] === fromRow)
                index = i
        }
        const step = direction < 0 ? -1 : 1
        for (var j = index + step; j >= 0 && j < rows.length; j += step) {
            if (rows[j].visible) {
                rows[j].forceActiveFocus()
                return
            }
        }
        if (direction < 0)
            searchField.forceActiveFocus()
    }

    function recoverFocus() {
        if ((motionNav.activeFocus && !motionNav.visible)
                || (clockNav.activeFocus && !clockNav.visible)
                || (themeNav.activeFocus && !themeNav.visible)
                || (statusNav.activeFocus && !statusNav.visible)
                || (weatherNav.activeFocus && !weatherNav.visible)
                || (privacyNav.activeFocus && !privacyNav.visible))
            focusFirstNav()
    }

    function dismissSearchOrClose() {
        if (searchField.text.length > 0) {
            searchField.text = ""
            searchField.forceActiveFocus()
            return
        }
        ClockConfig.settingsOpen = false
    }

    onVisibleChanged: {
        if (visible)
            LocationServices.check()
    }

    onQueryChanged: {
        reconcilePage()
        Qt.callLater(recoverFocus)
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: window.visible
        onActivated: window.dismissSearchOrClose()
    }

    Shortcut {
        sequence: "Ctrl+F"
        context: Qt.WindowShortcut
        enabled: window.visible
        onActivated: searchField.forceActiveFocus()
    }

    Rectangle {
        id: chrome
        anchors.fill: parent
        radius: 22
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
        Rectangle {
            x: 1
            y: 1
            width: sidebar.width - 1
            height: parent.height - 2
            color: Theme.track
            topLeftRadius: 21
            bottomLeftRadius: 21
        }

        Item {
            id: sidebar
            width: 196
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Rectangle {
                    id: searchBox
                    width: parent.width
                    height: 34
                    radius: 10
                    color: Theme.surface
                    border.width: 1
                    border.color: searchField.activeFocus ? Theme.today : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.left: searchField.left
                        anchors.right: searchField.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchField.text.length === 0
                        text: qsTr("Search")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }

                    TextInput {
                        id: searchField
                        anchors.left: parent.left
                        anchors.right: clearSearch.left
                        anchors.leftMargin: 12
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height - 8
                        clip: true
                        color: Theme.textPrimary
                        selectionColor: Theme.today
                        selectedTextColor: Theme.todayInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        selectByMouse: true
                        verticalAlignment: TextInput.AlignVCenter
                        Accessible.role: Accessible.EditableText
                        Accessible.name: qsTr("Search settings")
                        onTextChanged: window.query = text
                        Keys.onDownPressed: event => {
                            window.focusFirstNav()
                            event.accepted = true
                        }
                    }

                    Item {
                        id: clearSearch
                        anchors.right: parent.right
                        width: searchField.text.length > 0 ? 22 : 0
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            visible: parent.width > 0
                            text: "×"
                            color: clearHit.containsMouse ? Theme.textPrimary : Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: clearHit
                            anchors.fill: parent
                            enabled: parent.width > 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: qsTr("Clear search")
                            onClicked: {
                                searchField.text = ""
                                searchField.forceActiveFocus()
                            }
                        }
                    }
                }

                Column {
                    id: navColumn
                    width: parent.width
                    spacing: 4

                    NavRow {
                        id: themeNav
                        width: navColumn.width
                        visible: window.sidebarHas("theme")
                        label: qsTr("Theme")
                        selected: window.pageId === "theme"
                        onActivated: window.pageId = "theme"
                        Keys.onUpPressed: window.focusNav(themeNav, -1)
                        Keys.onDownPressed: window.focusNav(themeNav, 1)
                    }

                    NavRow {
                        id: motionNav
                        width: navColumn.width
                        visible: window.sidebarHas("motion")
                        label: qsTr("Motion")
                        selected: window.pageId === "motion"
                        onActivated: window.pageId = "motion"
                        Keys.onUpPressed: window.focusNav(motionNav, -1)
                        Keys.onDownPressed: window.focusNav(motionNav, 1)
                    }

                    NavRow {
                        id: clockNav
                        width: navColumn.width
                        visible: window.sidebarHas("clock")
                        label: qsTr("Clock")
                        selected: window.pageId === "clock"
                        onActivated: window.pageId = "clock"
                        Keys.onUpPressed: window.focusNav(clockNav, -1)
                        Keys.onDownPressed: window.focusNav(clockNav, 1)
                    }

                    NavRow {
                        id: statusNav
                        width: navColumn.width
                        visible: window.sidebarHas("status")
                        label: qsTr("Status")
                        selected: window.pageId === "status"
                        onActivated: window.pageId = "status"
                        Keys.onUpPressed: window.focusNav(statusNav, -1)
                        Keys.onDownPressed: window.focusNav(statusNav, 1)
                    }

                    NavRow {
                        id: launcherNav
                        width: navColumn.width
                        visible: window.sidebarHas("launcher")
                        label: qsTr("Launcher")
                        selected: window.pageId === "launcher"
                        onActivated: window.pageId = "launcher"
                        Keys.onUpPressed: window.focusNav(launcherNav, -1)
                        Keys.onDownPressed: window.focusNav(launcherNav, 1)
                    }

                    NavRow {
                        id: weatherNav
                        width: navColumn.width
                        visible: window.sidebarHas("weather")
                        label: qsTr("Weather")
                        selected: window.pageId === "weather"
                        onActivated: window.pageId = "weather"
                        Keys.onUpPressed: window.focusNav(weatherNav, -1)
                        Keys.onDownPressed: window.focusNav(weatherNav, 1)
                    }

                    NavRow {
                        id: privacyNav
                        width: navColumn.width
                        visible: window.sidebarHas("privacy")
                        label: qsTr("Privacy")
                        selected: window.pageId === "privacy"
                        onActivated: window.pageId = "privacy"
                        Keys.onUpPressed: window.focusNav(privacyNav, -1)
                        Keys.onDownPressed: window.focusNav(privacyNav, 1)
                    }
                }
            }
        }

        Rectangle {
            anchors.left: sidebar.right
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            width: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        Item {
            id: detail
            anchors.left: sidebar.right
            anchors.leftMargin: 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Text {
                anchors.centerIn: parent
                visible: window.pageId === ""
                text: qsTr("No matching settings")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }

            Column {
                id: contentColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 22
                spacing: 16
                visible: window.pageId !== ""

                Column {
                    width: parent.width
                    spacing: 4

                    Text {
                        text: window.pageTitle
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Medium
                    }

                    Rectangle {
                        width: 28
                        height: 2
                        radius: 1
                        color: Theme.today
                    }
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("motion")
                    title: window.controlTitle("motion")
                    choices: window.choiceList("motion")
                    value: window.valueFor("motion")
                    onPicked: next => window.applyPick("motion", next)
                }

                Stepper {
                    width: contentColumn.width
                    visible: window.shows("duration")
                    title: window.controlTitle("duration")
                    value: ClockConfig.duration
                    minimum: 50
                    maximum: 1000
                    step: 25
                    suffix: " ms"
                    onEdited: next => {
                        ClockConfig.duration = next
                        ClockConfig.save()
                    }
                }

                Stepper {
                    width: contentColumn.width
                    visible: window.shows("spring")
                    title: window.controlTitle("spring")
                    value: ClockConfig.springOvershoot
                    minimum: 0
                    maximum: 4
                    step: 0.1
                    decimals: 1
                    onEdited: next => {
                        ClockConfig.springOvershoot = next
                        ClockConfig.save()
                    }
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("hourCycle")
                    title: window.controlTitle("hourCycle")
                    choices: window.choiceList("hourCycle")
                    value: window.valueFor("hourCycle")
                    onPicked: next => window.applyPick("hourCycle", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("meridiem") && !ClockConfig.use24Hour
                    title: window.controlTitle("meridiem")
                    choices: window.choiceList("meridiem")
                    value: window.valueFor("meridiem")
                    onPicked: next => window.applyPick("meridiem", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("locale")
                    title: window.controlTitle("locale")
                    choices: window.choiceList("locale")
                    value: window.valueFor("locale")
                    onPicked: next => window.applyPick("locale", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("presentation")
                    title: window.controlTitle("presentation")
                    choices: window.choiceList("presentation")
                    value: window.valueFor("presentation")
                    onPicked: next => window.applyPick("presentation", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("placement")
                    title: window.controlTitle("placement")
                    choices: window.choiceList("placement")
                    value: window.valueFor("placement")
                    onPicked: next => window.applyPick("placement", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("shadow")
                    title: window.controlTitle("shadow")
                    choices: window.choiceList("shadow")
                    value: window.valueFor("shadow")
                    onPicked: next => window.applyPick("shadow", next)
                }

                Swatches {
                    width: contentColumn.width
                    visible: window.shows("palette")
                    title: window.controlTitle("palette")
                    swatches: Theme.palette
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("batteryPercentage")
                    title: window.controlTitle("batteryPercentage")
                    choices: window.choiceList("batteryPercentage")
                    value: window.valueFor("batteryPercentage")
                    onPicked: next => window.applyPick("batteryPercentage", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("launcherView")
                    title: window.controlTitle("launcherView")
                    choices: window.choiceList("launcherView")
                    value: window.valueFor("launcherView")
                    onPicked: next => window.applyPick("launcherView", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("weatherEnabled")
                    title: window.controlTitle("weatherEnabled")
                    choices: window.choiceList("weatherEnabled")
                    value: window.valueFor("weatherEnabled")
                    onPicked: next => window.applyPick("weatherEnabled", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("weatherUnits") && ClockConfig.weatherEnabled
                    title: window.controlTitle("weatherUnits")
                    choices: window.choiceList("weatherUnits")
                    value: window.valueFor("weatherUnits")
                    onPicked: next => window.applyPick("weatherUnits", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("weatherAlerts") && ClockConfig.weatherEnabled
                    title: window.controlTitle("weatherAlerts")
                    choices: window.choiceList("weatherAlerts")
                    value: window.valueFor("weatherAlerts")
                    onPicked: next => window.applyPick("weatherAlerts", next)
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("weatherLocationMode") && ClockConfig.weatherEnabled
                    title: window.controlTitle("weatherLocationMode")
                    choices: window.choiceList("weatherLocationMode")
                    value: window.valueFor("weatherLocationMode")
                    onPicked: next => window.applyPick("weatherLocationMode", next)
                }

                LocationPicker {
                    width: contentColumn.width
                    visible: window.shows("weatherLocationMode") && ClockConfig.weatherEnabled
                }

                Options {
                    width: contentColumn.width
                    visible: window.shows("locationServices") && LocationServices.installed
                    title: window.controlTitle("locationServices")
                    choices: window.choiceList("locationServices")
                    value: window.valueFor("locationServices")
                    onPicked: next => window.applyPick("locationServices", next)
                }

                Text {
                    width: contentColumn.width
                    visible: window.shows("locationServices")
                    wrapMode: Text.WordWrap
                    text: !LocationServices.installed
                        ? qsTr("Location services aren't set up on this system. Enable services.qs.locationServices in your NixOS configuration.")
                        : LocationServices.error || (LocationServices.enabled
                            ? qsTr("Apps and the shell can find this device's approximate location from nearby Wi-Fi networks.")
                            : qsTr("Nothing on this device can look up its location."))
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
            }
        }
    }

    component NavRow: Rectangle {
        id: row

        property string label: ""
        property bool selected: false
        signal activated()

        height: visible ? 34 : 0
        radius: 8
        color: selected ? Theme.today
             : hit.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
        border.width: activeFocus ? 1 : 0
        border.color: selected ? Theme.todayInk : Theme.today

        Behavior on color {
            ColorAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: row.selected ? Theme.todayInk : Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: row.selected ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }

        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                row.forceActiveFocus()
                row.activated()
            }
        }

        activeFocusOnTab: visible
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.checkable: true
        Accessible.checked: selected
        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()
        Keys.onSpacePressed: activated()
    }

    component Options: Item {
        id: options

        property string title: ""
        property string value: ""
        property var choices: []
        signal picked(string next)

        height: visible ? 58 : 0
        activeFocusOnTab: visible
        Accessible.name: title
        Accessible.description: labelFor(value)

        function indexFor(selected) {
            for (var i = 0; i < choices.length; ++i) {
                if (choices[i].value === selected)
                    return i
            }
            return 0
        }

        function labelFor(selected) {
            for (var i = 0; i < choices.length; ++i) {
                if (choices[i].value === selected)
                    return choices[i].label
            }
            return selected
        }

        function step(delta) {
            if (!choices || choices.length === 0)
                return
            const next = indexFor(value) + delta
            if (next < 0 || next >= choices.length)
                return
            picked(choices[next].value)
        }

        Keys.onLeftPressed: step(-1)
        Keys.onRightPressed: step(1)

        Text {
            text: options.title
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1.15
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            id: track
            anchors.bottom: parent.bottom
            width: parent.width
            height: 36
            radius: 12
            color: Theme.track
            border.width: 1
            border.color: options.activeFocus ? Theme.today : Qt.rgba(1, 1, 1, 0.05)

            readonly property real cell: choices.length > 0
                ? (width - 6 - (choices.length - 1) * 2) / choices.length : 0

            Rectangle {
                radius: 9
                x: 3 + options.indexFor(options.value) * (track.cell + 2)
                y: 3
                width: track.cell
                height: track.height - 6
                color: Theme.today

                Behavior on x {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 2

                Repeater {
                    model: options.choices

                    Item {
                        id: cell
                        required property var modelData
                        width: track.cell
                        height: 30

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            text: cell.modelData.label
                            color: cell.modelData.value === options.value ? Theme.todayInk : Theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: cell.modelData.value === options.value ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: options.picked(cell.modelData.value)
                        }
                    }
                }
            }
        }
    }

    component Swatches: Item {
        id: swatchRow

        property string title: ""
        property var swatches: []
        property int hovered: -1

        height: visible ? 58 : 0

        Text {
            text: swatchRow.title
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1.15
            font.capitalization: Font.AllUppercase
        }

        Text {
            anchors.right: parent.right
            text: swatchRow.hovered >= 0 ? swatchRow.swatches[swatchRow.hovered].name : ""
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }

        Row {
            id: circles
            anchors.bottom: parent.bottom
            width: parent.width
            height: 36
            readonly property real size: 28
            spacing: swatchRow.swatches.length > 1
                ? (width - swatchRow.swatches.length * size) / (swatchRow.swatches.length - 1) : 0

            Repeater {
                model: swatchRow.swatches

                Rectangle {
                    required property var modelData
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: circles.size
                    height: circles.size
                    radius: width / 2
                    color: modelData.color
                    border.width: 1
                    border.color: swatchRow.hovered === index ? Theme.textSecondary : Qt.rgba(1, 1, 1, 0.12)
                    Accessible.role: Accessible.StaticText
                    Accessible.name: modelData.name

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: swatchRow.hovered = parent.index
                        onExited: {
                            if (swatchRow.hovered === parent.index)
                                swatchRow.hovered = -1
                        }
                    }
                }
            }
        }
    }

    component Stepper: Item {
        id: field

        property string title: ""
        property real value: 0
        property real minimum: 0
        property real maximum: 1
        property real step: 1
        property int decimals: 0
        property string suffix: ""
        signal edited(real next)

        readonly property string readout: (decimals > 0 ? value.toFixed(decimals) : Math.round(value)) + suffix

        height: visible ? 58 : 0
        activeFocusOnTab: visible
        Accessible.role: Accessible.Slider
        Accessible.name: title
        Accessible.description: readout

        function nudge(direction) {
            const places = Math.pow(10, decimals)
            const raw = Math.round((value + direction * step) * places) / places
            const next = Math.max(minimum, Math.min(maximum, raw))
            if (next !== value)
                edited(next)
        }

        Keys.onLeftPressed: nudge(-1)
        Keys.onRightPressed: nudge(1)

        Text {
            text: field.title
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.letterSpacing: 1.15
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 36
            radius: 12
            color: Theme.track
            border.width: 1
            border.color: field.activeFocus ? Theme.today : Qt.rgba(1, 1, 1, 0.05)

            Text {
                anchors.centerIn: parent
                text: field.readout
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            Repeater {
                model: [
                    { label: "−", direction: -1, side: "left" },
                    { label: "+", direction: 1, side: "right" }
                ]

                Rectangle {
                    required property var modelData
                    width: 36
                    height: 30
                    radius: 9
                    x: modelData.side === "left" ? 3 : parent.width - width - 3
                    y: 3
                    color: pressed.pressed ? Qt.rgba(1, 1, 1, 0.08)
                         : pressed.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: pressed
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: field.nudge(parent.modelData.direction)
                    }
                }
            }
        }
    }
}
