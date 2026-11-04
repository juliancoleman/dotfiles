pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Common"

Singleton {
    id: root

    readonly property string path: Quickshell.env("QS_CONFIG_FILE")
        || (Quickshell.env("HOME") || "") + "/.config/qs/config.json"

    property bool loaded: false
    property var document: ({})
    property string placement: "right"
    property bool use24Hour: true
    property bool showPeriod: true
    property string locale: "en"
    property string motion: "easeOut"
    property string presentation: "pill"
    property bool shadow: true
    // Multiplies every size token in Theme; a 2K panel at scale 1 wants the bar a quarter larger.
    property real scale: 1
    // "list", "large", or "small" grid.
    property string launcherView: "large"
    property int duration: 250
    property real springOvershoot: 2
    property string batteryPercentage: "low"
    property bool doNotDisturb: false
    property bool weatherEnabled: true
    property string weatherUnits: "imperial"
    property string weatherLocationMode: "exact"
    // { name, region, latitude, longitude } chosen in Settings, or null.
    property var weatherLocation: null
    property bool weatherAlerts: true

    onDurationChanged: Theme.motionDuration = duration
    onSpringOvershootChanged: Theme.springOvershoot = springOvershoot
    onScaleChanged: Theme.scale = scale
    onLocaleChanged: I18n.locale = locale

    function oneOf(...allowed) {
        return raw => allowed.indexOf(raw) >= 0
    }

    function within(low, high) {
        return raw => typeof raw === "number" && raw >= low && raw <= high
    }

    // One value from the file: the default when it's absent, the value itself when the shell understands
    // it, and otherwise the value already in memory, with a warning, so a hand-edited typo is neither
    // silently swapped for a default nor rewritten into the file by the next save.
    function pick(key, raw, valid, fallback, current) {
        if (raw === undefined)
            return fallback
        if (valid(raw))
            return raw
        console.warn("qs config: invalid " + key + " '" + raw + "', keeping " + current)
        return current
    }

    function apply(parsed) {
        const bar = parsed && parsed.bar ? parsed.bar : {}
        const clock = parsed && parsed.clock ? parsed.clock : {}
        const status = parsed && parsed.status ? parsed.status : {}
        const notifications = parsed && parsed.notifications ? parsed.notifications : {}
        const launcher = parsed && parsed.launcher ? parsed.launcher : {}
        const weather = parsed && parsed.weather ? parsed.weather : {}
        const flag = oneOf(true, false)
        document = parsed || {}
        doNotDisturb = pick("notifications.doNotDisturb", notifications.doNotDisturb, flag, false, doNotDisturb)
        weatherEnabled = pick("weather.enabled", weather.enabled, flag, true, weatherEnabled)
        weatherUnits = pick("weather.units", weather.units, oneOf("imperial", "metric"), "imperial", weatherUnits)
        weatherLocationMode = pick("weather.locationMode", weather.locationMode, oneOf("exact", "automatic"),
                                   "exact", weatherLocationMode)
        const spot = weather.location
        if (spot === undefined || spot === null) {
            weatherLocation = null
        } else if (!isFinite(spot.latitude) || !isFinite(spot.longitude)) {
            console.warn("qs config: invalid weather.location '" + JSON.stringify(spot) + "', keeping "
                         + (weatherLocation ? weatherLocation.name : "none"))
        } else if (!weatherLocation || weatherLocation.latitude !== spot.latitude
                   || weatherLocation.longitude !== spot.longitude || weatherLocation.name !== spot.name) {
            weatherLocation = { name: String(spot.name || ""), region: String(spot.region || ""),
                                latitude: Number(spot.latitude), longitude: Number(spot.longitude) }
        }
        weatherAlerts = pick("weather.alerts", weather.alerts, flag, true, weatherAlerts)
        batteryPercentage = pick("status.batteryPercentage", status.batteryPercentage, oneOf("always", "low"),
                                 "low", batteryPercentage)
        placement = pick("bar.placement", bar.placement, oneOf("top", "right", "bottom", "left"), "right", placement)
        shadow = pick("bar.shadow", bar.shadow, flag, true, shadow)
        scale = Math.round(pick("bar.scale", bar.scale, within(0.75, 2), 1, scale) * 20) / 20
        launcherView = pick("launcher.view", launcher.view, oneOf("list", "large", "small"), "large", launcherView)
        use24Hour = pick("clock.hourCycle", clock.hourCycle, oneOf(12, 24), 24, use24Hour ? 24 : 12) === 24
        showPeriod = pick("clock.meridiem", clock.meridiem, oneOf("shown", "hidden"), "shown",
                          showPeriod ? "shown" : "hidden") === "shown"
        locale = pick("clock.locale", clock.locale, oneOf("en", "jp", "ja"), "en", locale) === "en" ? "en" : "jp"
        motion = pick("clock.motion", clock.motion, name => Theme.normalizeMotion(name) === name, "spring", motion)
        presentation = pick("clock.presentation", clock.presentation, oneOf("pill", "notch"), "pill", presentation)
        duration = Math.round(pick("clock.duration", clock.duration, within(50, 2000), 250, duration))
        springOvershoot = Math.round(pick("clock.springOvershoot", clock.springOvershoot, within(0, 4), 2,
                                          springOvershoot) * 10) / 10
    }

    function save() {
        if (!loaded)
            return
        const next = document || {}
        if (!next.bar)
            next.bar = {}
        if (!next.clock)
            next.clock = {}
        if (!next.status)
            next.status = {}
        if (!next.notifications)
            next.notifications = {}
        next.status.batteryPercentage = batteryPercentage
        next.notifications.doNotDisturb = doNotDisturb
        next.weather = {
            enabled: weatherEnabled,
            units: weatherUnits,
            locationMode: weatherLocationMode,
            location: weatherLocation,
            alerts: weatherAlerts
        }
        next.bar.placement = placement
        next.bar.shadow = shadow
        next.bar.scale = scale
        next.launcher = Object.assign({}, next.launcher, { view: launcherView })
        next.clock.hourCycle = use24Hour ? 24 : 12
        next.clock.meridiem = showPeriod ? "shown" : "hidden"
        next.clock.locale = locale
        next.clock.motion = motion
        next.clock.presentation = presentation
        next.clock.duration = duration
        next.clock.springOvershoot = springOvershoot
        delete next.clock.presentationMotion
        document = next
        writer.setText(JSON.stringify(next, null, 2) + "\n")
    }

    FileView {
        id: reader
        path: root.path
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                root.apply(JSON.parse(text()))
                root.loaded = true
            } catch (error) {
                console.log("qs config:", error)
            }
        }
        onFileChanged: reload()
    }

    FileView {
        id: writer
        path: root.path
        atomicWrites: true
        printErrors: false
    }
}
