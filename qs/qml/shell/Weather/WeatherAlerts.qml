pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."
import "../Common"
import "../Notifications"

// Turns weather data into a few shell notifications: one when an official alert is issued or rain/snow
// is forecast to start soon, and one reminder just before it begins. Sent keys persist so a restart
// doesn't repeat them.
Singleton {
    id: root

    readonly property int precipHorizon: 3 * 60 * 60 * 1000
    readonly property int precipReminder: 15 * 60 * 1000
    readonly property int alertReminder: 10 * 60 * 1000
    readonly property int minimumChance: 40

    property var sent: ({})
    // Keys sent before the store has been read stay in memory until it has, so merging can't lose either side.
    property bool storeLoaded: false
    // The next forecast dry-to-wet change, kept so tick() can remind as it approaches.
    property var upcoming: null

    function enabled() {
        return ClockConfig.weatherAlerts && WeatherService.available
    }

    function timeText(ms) {
        const when = WeatherService.wallClock(ms, WeatherService.offsetAt(ms))
        return I18n.timeOfDay(when.getUTCHours(), when.getUTCMinutes(), ClockConfig.use24Hour, true)
    }

    function once(key, summary, body, critical) {
        if (sent[key])
            return
        const next = Object.assign({}, sent)
        next[key] = Date.now()
        sent = next
        if (storeLoaded)
            persist()
        NotificationService.postLocal(I18n.tr("Weather"), summary, body,
                                      critical ? NotificationUrgency.Critical : NotificationUrgency.Normal)
    }

    function review() {
        if (!enabled())
            return
        const now = Date.now()
        for (const alert of WeatherService.alerts) {
            if (alert.ends && alert.ends < now)
                continue
            const severe = alert.severity === "Extreme" || /Tornado Warning/.test(alert.event)
            once("alert:" + alert.id, I18n.tr(alert.event), alert.headline, severe)
        }

        const hours = WeatherService.hourly
        upcoming = null
        if (hours.length === 0 || (WeatherService.wet(hours[0].icon) && hours[0].chance >= minimumChance))
            return
        for (let i = 1; i < hours.length; ++i) {
            const hour = hours[i]
            if (hour.start - now > precipHorizon)
                break
            if (!WeatherService.wet(hour.icon) || hour.chance < minimumChance)
                continue
            upcoming = { icon: hour.icon, start: hour.start }
            once("precip:" + hour.icon + "@" + hour.start,
                 I18n.tr("%1 expected around %2").arg(WeatherService.noun(hour.icon)).arg(timeText(hour.start)),
                 I18n.tr("%1, %2% chance").arg(WeatherService.describe(hour)).arg(hour.chance), false)
            break
        }
    }

    // A reminder only adds something if the first notice went out before the reminder window opened.
    function announcedEarly(key, start, window) {
        return !!sent[key] && sent[key] < start - window
    }

    function tick() {
        if (!enabled())
            return
        const now = Date.now()
        for (const alert of WeatherService.alerts) {
            const lead = alert.onset - now
            if (lead > 0 && lead <= alertReminder && announcedEarly("alert:" + alert.id, alert.onset, alertReminder))
                once("soon:" + alert.id, I18n.tr("%1 starts in %2 minutes").arg(I18n.tr(alert.event)).arg(Math.max(1, Math.round(lead / 60000))),
                     alert.headline, false)
        }
        if (upcoming) {
            const lead = upcoming.start - now
            if (lead > -5 * 60 * 1000 && lead <= precipReminder
                    && announcedEarly("precip:" + upcoming.icon + "@" + upcoming.start, upcoming.start, precipReminder))
                once("soon:precip:" + upcoming.icon + "@" + upcoming.start,
                     I18n.tr("%1 starting soon").arg(WeatherService.noun(upcoming.icon)),
                     I18n.tr("Expected around %1").arg(timeText(upcoming.start)), false)
        }
    }

    // The read is still FileView's live operation while onLoaded runs, so the write-back waits a turn.
    function persist() {
        store.setText(JSON.stringify(sent))
    }

    FileView {
        id: store
        path: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/qs-weather-alerts.json"
        printErrors: false
        atomicWrites: true
        onLoaded: {
            let kept = {}
            try {
                const parsed = JSON.parse(text())
                const cutoff = Date.now() - 3 * 24 * 60 * 60 * 1000
                for (const key in parsed) {
                    if (parsed[key] > cutoff)
                        kept[key] = parsed[key]
                }
            } catch (problem) {
                kept = {}
            }
            root.sent = Object.assign(kept, root.sent)
            root.storeLoaded = true
            Qt.callLater(root.persist)
        }
        onLoadFailed: {
            root.storeLoaded = true
            if (Object.keys(root.sent).length > 0)
                Qt.callLater(root.persist)
        }
    }
}
