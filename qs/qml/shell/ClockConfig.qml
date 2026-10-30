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
    property bool settingsOpen: false
    property var document: ({})
    property string placement: "right"
    property bool use24Hour: true
    property bool showPeriod: true
    property string locale: "en"
    property string motion: "easeOut"
    property string presentation: "pill"
    property bool shadow: true
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

    function apply(parsed) {
        const bar = parsed && parsed.bar ? parsed.bar : {}
        const clock = parsed && parsed.clock ? parsed.clock : {}
        const status = parsed && parsed.status ? parsed.status : {}
        const notifications = parsed && parsed.notifications ? parsed.notifications : {}
        document = parsed || {}
        doNotDisturb = notifications.doNotDisturb === true
        const weather = parsed && parsed.weather ? parsed.weather : {}
        weatherEnabled = weather.enabled !== false
        weatherUnits = weather.units === "metric" ? "metric" : "imperial"
        weatherLocationMode = weather.locationMode === "automatic" ? "automatic" : "exact"
        const spot = weather.location
        const valid = !!spot && isFinite(spot.latitude) && isFinite(spot.longitude)
        const same = valid && !!weatherLocation && weatherLocation.latitude === spot.latitude
            && weatherLocation.longitude === spot.longitude && weatherLocation.name === spot.name
        if (!same)
            weatherLocation = valid ? { name: String(spot.name || ""), region: String(spot.region || ""),
                                        latitude: Number(spot.latitude), longitude: Number(spot.longitude) } : null
        weatherAlerts = weather.alerts !== false
        batteryPercentage = status.batteryPercentage === "always" ? "always" : "low"
        placement = ["top", "right", "bottom", "left"].indexOf(bar.placement) >= 0
            ? bar.placement : "right"
        shadow = bar.shadow !== false
        const launcher = parsed && parsed.launcher ? parsed.launcher : {}
        launcherView = ["list", "large", "small"].indexOf(launcher.view) >= 0 ? launcher.view : "large"
        use24Hour = clock.hourCycle !== 12
        showPeriod = clock.meridiem !== "hidden"
        locale = clock.locale === "jp" || clock.locale === "ja" ? "jp" : "en"
        motion = Theme.normalizeMotion(clock.motion)
        presentation = clock.presentation === "notch" ? "notch" : "pill"
        const ms = Number(clock.duration)
        duration = ms >= 50 && ms <= 2000 ? Math.round(ms) : 250
        const factor = Number(clock.springOvershoot)
        springOvershoot = factor >= 0 && factor <= 4 ? Math.round(factor * 10) / 10 : 2
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
