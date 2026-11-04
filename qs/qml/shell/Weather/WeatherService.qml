pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Common"

// Weather from the US National Weather Service: the nearest station's measured conditions, the hourly and
// daily forecasts, and official alerts. Open-Meteo fills what the NWS doesn't publish: days past its seven,
// sunrise and sunset, and air quality. Requests go through curl so they carry the User-Agent the NWS asks for.
Singleton {
    id: root

    readonly property string userAgent: "qs-desktop-shell/1.0 (personal weather widget)"
    readonly property int refreshInterval: 15 * 60 * 1000
    // After a failed load the next try comes after retryFloor, doubling per miss back up to refreshInterval.
    readonly property int retryFloor: 60 * 1000
    property int retryDelay: refreshInterval
    readonly property int staleAfter: 30 * 60 * 1000
    // Polling checks wall-clock time on this beat, so a refresh missed while suspended runs soon after waking.
    readonly property int tickInterval: 30 * 1000
    readonly property int requestTimeout: 20
    // The longest a load can take: points, then stations, then the readings, each up to requestTimeout.
    readonly property int loadDeadline: 3 * requestTimeout * 1000

    readonly property bool imperial: ClockConfig.weatherUnits !== "metric"
    readonly property bool automatic: ClockConfig.weatherLocationMode === "automatic"
    readonly property bool locating: ClockConfig.weatherEnabled && automatic && LocationServices.enabled
    property var automaticFix: null
    // Like `error`, the English source; it reaches views through errorText.
    property string automaticError: ""
    readonly property var location: !ClockConfig.weatherEnabled ? null
        : automatic ? (LocationServices.enabled ? automaticFix : null) : ClockConfig.weatherLocation

    property var point: null
    property var current: null
    property var hourly: []
    property var alerts: []
    // NWS day and night halves folded into days; Open-Meteo days keyed the same way by local date.
    property var forecastDays: []
    property var outlookDays: []
    readonly property var daily: mergeDays(forecastDays, outlookDays)
    // Sunrise and sunset over the coming days, each { time, rise }.
    property var sunTimes: []
    property int outlookOffset: 0
    property var airQuality: null
    // A round that couldn't refresh a best-effort source leaves its last data showing; the panel marks it.
    property bool outlookMissed: false
    property bool airQualityMissed: false
    readonly property bool outlookStale: outlookMissed && daily.length > 0
    readonly property bool airQualityStale: airQualityMissed && !!airQuality
    property var wind: null
    // Wind only matters to the panel when the NWS is warning about it.
    readonly property var windEvents: ["Red Flag Warning", "High Wind Warning", "High Wind Watch",
                                       "Extreme Wind Warning", "Tornado Warning"]
    readonly property bool windWarned: alerts.some(a => windEvents.indexOf(a.event) >= 0)
    property double updatedAt: 0
    property double now: Date.now()
    // The English source, kept so a locale switch retranslates it; views show errorText.
    property string error: ""
    readonly property string errorText: I18n.tr(error)
    property bool loading: false
    property double loadStartedAt: 0
    // When the poller last tried, even if there was no place to load yet.
    property double polledAt: 0
    // Bumped when the location changes, or a load is abandoned, so late replies are dropped.
    property int generation: 0

    readonly property bool stale: updatedAt > 0 && now - updatedAt > staleAfter
    readonly property bool available: !!current && !stale
    readonly property string icon: current ? current.icon : "cloud"
    readonly property string condition: current ? describe(current) : ""
    readonly property real degrees: current && current.celsius !== null ? Math.round(imperial ? current.celsius * 9 / 5 + 32 : current.celsius) : NaN
    readonly property string temperature: isNaN(degrees) ? "–" : degrees + "°"
    readonly property string place: !point ? "" : point.state ? point.city + ", " + point.state : point.city

    // NWS icon URLs name the condition (…/land/day/rain_showers,40?size=medium); map them to bundled glyphs.
    function glyphFor(url) {
        const match = /\/icons\/land\/(day|night)\/([a-z_]+)/.exec(String(url || ""))
        if (!match)
            return "cloud"
        const night = match[1] === "night"
        switch (match[2]) {
        case "skc":
        case "few":
        case "hot":
        case "cold":
            return night ? "clear-night" : "clear-day"
        case "sct":
        case "bkn":
            return night ? "partly-night" : "partly-day"
        case "ovc":
            return "cloud"
        case "wind_skc":
        case "wind_few":
        case "wind_sct":
        case "wind_bkn":
        case "wind_ovc":
            return "wind"
        case "snow":
        case "blizzard":
        case "rain_snow":
        case "snow_sleet":
            return "snow"
        case "sleet":
        case "fzra":
        case "rain_sleet":
        case "rain_fzra":
        case "snow_fzra":
            return "hail"
        case "rain":
        case "rain_showers":
        case "rain_showers_hi":
            return "rain"
        case "tsra":
        case "tsra_sct":
        case "tsra_hi":
            return "thunder"
        case "tornado":
        case "hurricane":
        case "tropical_storm":
            return "alert"
        case "fog":
        case "dust":
        case "smoke":
        case "haze":
            return "fog"
        default:
            return "cloud"
        }
    }

    // Open-Meteo reports WMO weather codes; daily values only, so always the daytime glyph.
    function glyphForCode(code) {
        if (code <= 1)
            return "clear-day"
        if (code === 2)
            return "partly-day"
        if (code === 3)
            return "cloud"
        if (code === 45 || code === 48)
            return "fog"
        if (code === 56 || code === 57 || code === 66 || code === 67)
            return "hail"
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "snow"
        if (code >= 95)
            return "thunder"
        return "rain"
    }

    function toUnits(celsius) {
        return Math.round(imperial ? celsius * 9 / 5 + 32 : celsius)
    }

    // NWS times carry the place's offset (…T15:00:00-06:00), which changes across daylight saving.
    function offsetOf(iso) {
        const match = /([+-])(\d\d):(\d\d)$/.exec(String(iso))
        return match ? (match[1] === "-" ? -1 : 1) * (Number(match[2]) * 60 + Number(match[3])) * 60 : 0
    }

    // A Date whose UTC fields read as the place's wall clock.
    function wallClock(epoch, offset) {
        return new Date(epoch + offset * 1000)
    }

    // The place's offset at a moment, taken from the hourly forecast that covers it. The hours are in
    // order, so the first one ending after the moment is found by bisection.
    function offsetAt(epoch) {
        let low = 0
        let high = hourly.length
        while (low < high) {
            const mid = (low + high) >> 1
            if (hourly[mid].end <= epoch)
                low = mid + 1
            else
                high = mid
        }
        if (low < hourly.length)
            return hourly[low].offset
        return hourly.length > 0 ? hourly[hourly.length - 1].offset : outlookOffset
    }

    function mergeDays(nws, outlook) {
        const byDate = {}
        for (const day of nws)
            byDate[day.date] = day
        const out = []
        for (const extra of outlook) {
            const official = byDate[extra.date]
            out.push({
                date: extra.date,
                weekday: extra.weekday,
                high: official && official.high !== null ? official.high : extra.high,
                low: official && official.low !== null ? official.low : extra.low,
                icon: official ? official.icon : extra.icon,
                chance: official ? official.chance : extra.chance
            })
            if (out.length === 10)
                break
        }
        // Without Open-Meteo, the NWS week still stands on its own.
        return out.length > 0 ? out : nws.filter(d => d.high !== null && d.low !== null)
    }

    function airCategory(aqi) {
        if (aqi <= 50)
            return I18n.tr("Good")
        if (aqi <= 100)
            return I18n.tr("Moderate")
        if (aqi <= 150)
            return I18n.tr("Unhealthy for Sensitive Groups")
        if (aqi <= 200)
            return I18n.tr("Unhealthy")
        if (aqi <= 300)
            return I18n.tr("Very Unhealthy")
        return I18n.tr("Hazardous")
    }

    // The NWS only speaks English, so other locales name the sky by its glyph instead of its words.
    function describe(reading) {
        if (!I18n.japanese)
            return reading.text
        switch (reading.icon) {
        case "clear-day":
        case "clear-night":
            return I18n.tr("Clear")
        case "partly-day":
        case "partly-night":
            return I18n.tr("Partly Cloudy")
        case "wind":
            return I18n.tr("Windy")
        case "snow":
            return I18n.tr("Snow")
        case "hail":
            return I18n.tr("Sleet")
        case "rain":
            return I18n.tr("Rain")
        case "thunder":
            return I18n.tr("Thunderstorms")
        case "alert":
            return I18n.tr("Severe Storm")
        case "fog":
            return I18n.tr("Fog")
        default:
            return I18n.tr("Cloudy")
        }
    }

    function cardinal(degrees) {
        const names = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return names[Math.round(((degrees % 360) + 360) % 360 / 45) % 8]
    }

    function wet(glyph) {
        return glyph === "rain" || glyph === "snow" || glyph === "hail" || glyph === "thunder"
    }

    function noun(glyph) {
        switch (glyph) {
        case "snow":
            return I18n.tr("Snow")
        case "hail":
            return I18n.tr("Sleet")
        case "thunder":
            return I18n.tr("Thunderstorms")
        default:
            return I18n.tr("Rain")
        }
    }

    // `done` gets the parsed body, or null when the request or its JSON failed.
    function fetch(url, done) {
        const asked = generation
        const request = curl.createObject(root, { url: url })
        request.finished.connect(function (ok, body) {
            request.destroy()
            if (asked !== generation)
                return
            let parsed = null
            if (ok) {
                try {
                    parsed = JSON.parse(body)
                } catch (problem) {
                    parsed = null
                }
            }
            done(parsed)
        })
        request.running = true
    }

    function refresh() {
        if (!ClockConfig.weatherEnabled)
            return
        const spot = location
        if (!spot) {
            if (!automatic)
                error = "Choose a location in Settings"
            else if (!LocationServices.enabled)
                error = LocationServices.installed ? "Location services are off"
                                                   : "Location services aren't set up on this system"
            else
                error = automaticError || "Finding your location…"
            return
        }
        if (loading && Date.now() - loadStartedAt < loadDeadline)
            return
        // A load past its deadline never finished (a request that couldn't start, say); drop it and go again.
        if (loading)
            generation += 1
        loading = true
        loadStartedAt = Date.now()
        const key = spot.latitude.toFixed(4) + "," + spot.longitude.toFixed(4)
        if (point && point.key === key) {
            update(point)
            return
        }
        fetch("https://api.weather.gov/points/" + key, function (body) {
            if (body === null) {
                fail("Couldn't reach the National Weather Service")
                return
            }
            const props = body.properties
            if (!props || !props.forecastHourly) {
                fail("Weather is only available for US locations")
                return
            }
            const near = props.relativeLocation && props.relativeLocation.properties
            const next = {
                key: key,
                hourlyUrl: props.forecastHourly,
                forecastUrl: props.forecast,
                stationsUrl: props.observationStations,
                station: "",
                city: spot.name || (near ? near.city : ""),
                // The point's two-letter state, the same whether the place was chosen or found.
                state: near ? near.state || "" : "",
                timeZone: props.timeZone
            }
            fetch(next.stationsUrl, function (stations) {
                const first = stations && stations.features && stations.features[0]
                next.station = first ? first.properties.stationIdentifier : ""
                point = next
                update(next)
            })
        })
    }

    // Every request is launched here and the round settles when the last one answers, so loading ends
    // and updatedAt moves exactly once. The station reading and hourly forecast make a round; the rest
    // keep whatever they last had.
    function update(spot) {
        let pending = 0
        let observed = null
        let periods = null
        let forecastMissed = false
        let outlookMissedNow = false
        let airMissedNow = false
        const settle = function () {
            loading = false
            outlookMissed = outlookMissedNow || forecastMissed
            airQualityMissed = airMissedNow
            if (!periods && !observed) {
                if (current && current.key !== spot.key)
                    current = null
                fail("Couldn't reach the National Weather Service")
                return
            }
            if (periods)
                hourly = periods
            const reading = observed || fromForecast(hourly[0])
            current = reading ? Object.assign({ key: spot.key }, reading) : null
            updatedAt = Date.now()
            retryDelay = refreshInterval
            error = ""
            WeatherAlerts.review()
        }
        const launch = function (url, onReply) {
            ++pending
            fetch(url, function (body) {
                onReply(body)
                if (--pending === 0)
                    settle()
            })
        }

        if (spot.station) {
            launch("https://api.weather.gov/stations/" + spot.station + "/observations/latest", function (body) {
                const props = body && body.properties
                const fresh = props && Date.now() - Date.parse(props.timestamp) < 2 * 60 * 60 * 1000
                if (fresh && props.temperature && props.temperature.value !== null)
                    observed = { celsius: props.temperature.value, text: props.textDescription, icon: glyphFor(props.icon) }
                const speed = fresh && props.windSpeed ? props.windSpeed.value : null
                wind = speed === null ? null : {
                    kmh: speed,
                    gustKmh: props.windGust ? props.windGust.value : null,
                    from: props.windDirection && props.windDirection.value !== null ? cardinal(props.windDirection.value) : ""
                }
            })
        }

        launch(spot.hourlyUrl, function (body) {
            const list = body && body.properties && body.properties.periods
            if (list) {
                periods = list.slice(0, 24).map(p => {
                    // "10 to 15 mph": the top of the range is what a warning cares about.
                    const speeds = String(p.windSpeed || "").match(/\d+/g)
                    return {
                        start: Date.parse(p.startTime),
                        end: Date.parse(p.endTime),
                        offset: offsetOf(p.startTime),
                        celsius: celsiusOf(p),
                        text: p.shortForecast,
                        icon: glyphFor(p.icon),
                        chance: p.probabilityOfPrecipitation ? p.probabilityOfPrecipitation.value || 0 : 0,
                        windKmh: speeds ? Number(speeds[speeds.length - 1]) * 1.609344 : null,
                        windFrom: p.windDirection || ""
                    }
                })
            }
        })

        if (spot.forecastUrl) {
            launch(spot.forecastUrl, function (body) {
                const list = body && body.properties && body.properties.periods
                if (list)
                    forecastDays = foldPeriods(list)
                else
                    forecastMissed = true
            })
        }

        const coords = "latitude=" + spot.key.split(",")[0] + "&longitude=" + spot.key.split(",")[1]
        launch("https://api.open-meteo.com/v1/forecast?" + coords
               + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
               + "&timezone=auto&timeformat=unixtime&forecast_days=11", function (body) {
            const days = body && body.daily
            if (!days || !days.time) {
                outlookMissedNow = true
                return
            }
            outlookOffset = body.utc_offset_seconds || 0
            const outlook = []
            const sun = []
            for (let i = 0; i < days.time.length; ++i) {
                // Midday, so a daylight-saving change can't push local midnight into the day before.
                const noon = wallClock((days.time[i] + 12 * 3600) * 1000, outlookOffset)
                outlook.push({
                    date: noon.toISOString().slice(0, 10),
                    weekday: noon.getUTCDay(),
                    high: days.temperature_2m_max[i],
                    low: days.temperature_2m_min[i],
                    icon: glyphForCode(days.weather_code[i]),
                    chance: days.precipitation_probability_max[i] || 0
                })
                if (days.sunrise[i])
                    sun.push({ time: days.sunrise[i] * 1000, rise: true })
                if (days.sunset[i])
                    sun.push({ time: days.sunset[i] * 1000, rise: false })
            }
            outlookDays = outlook
            sunTimes = sun
        })

        launch("https://air-quality-api.open-meteo.com/v1/air-quality?" + coords + "&current=us_aqi&timeformat=unixtime",
               function (body) {
            if (body === null) {
                airMissedNow = true
                return
            }
            const reading = body.current
            airQuality = reading && reading.us_aqi !== null && reading.us_aqi !== undefined
                ? { aqi: Math.round(reading.us_aqi) } : null
        })

        launch("https://api.weather.gov/alerts/active?point=" + spot.key, function (body) {
            if (body && body.features) {
                alerts = body.features.map(f => ({
                    id: f.properties.id,
                    event: f.properties.event,
                    headline: f.properties.headline || "",
                    severity: f.properties.severity,
                    onset: Date.parse(f.properties.onset || f.properties.effective),
                    ends: Date.parse(f.properties.ends || f.properties.expires)
                }))
            }
        })
    }

    function celsiusOf(period) {
        return period.temperatureUnit === "F" ? (period.temperature - 32) * 5 / 9 : period.temperature
    }

    // Each day pairs its daytime high with the night that follows, the way the NWS reads its forecast.
    function foldPeriods(periods) {
        const days = []
        const byDate = {}
        for (const p of periods) {
            const date = String(p.startTime).slice(0, 10)
            let day = byDate[date]
            if (!day) {
                day = { date: date, weekday: new Date(date + "T12:00:00Z").getUTCDay(), high: null, low: null,
                        icon: glyphFor(p.icon), chance: 0 }
                byDate[date] = day
                days.push(day)
            }
            const chance = p.probabilityOfPrecipitation ? p.probabilityOfPrecipitation.value || 0 : 0
            day.chance = Math.max(day.chance, chance)
            if (p.isDaytime) {
                day.high = celsiusOf(p)
                day.icon = glyphFor(p.icon)
            } else {
                day.low = celsiusOf(p)
            }
        }
        return days
    }

    function fromForecast(period) {
        return period ? { celsius: period.celsius, text: period.text, icon: period.icon } : null
    }

    function fail(message) {
        loading = false
        error = message
        retryDelay = Math.min(refreshInterval, retryDelay >= refreshInterval ? retryFloor : retryDelay * 2)
        if (!point) {
            current = null
            updatedAt = 0
        }
    }

    onLocationChanged: {
        generation += 1
        loading = false
        point = null
        // The old place's reading stays up until the new one arrives, so the circle rolls over rather
        // than disappearing; its forecast and alerts go now so nothing warns about the place left behind.
        hourly = []
        alerts = []
        forecastDays = []
        outlookDays = []
        sunTimes = []
        airQuality = null
        wind = null
        outlookMissed = false
        airQualityMissed = false
        if (!location) {
            current = null
            updatedAt = 0
        }
        Qt.callLater(refresh)
    }

    onAutomaticChanged: {
        if (automatic)
            LocationServices.check()
    }

    onLocatingChanged: {
        if (locating)
            locate.running = true
        else
            automaticFix = null
    }

    Component.onCompleted: {
        if (locating)
            locate.running = true
        Qt.callLater(refresh)
    }

    // Qt timers stop counting while the machine sleeps, so compare wall-clock time on a short beat instead
    // of waiting out one long interval.
    Timer {
        interval: root.tickInterval
        running: true
        repeat: true
        onTriggered: {
            root.now = Date.now()
            WeatherAlerts.tick()
            if (root.now - Math.max(root.polledAt, root.loadStartedAt) < root.retryDelay)
                return
            root.polledAt = root.now
            if (root.automatic && !LocationServices.enabled)
                LocationServices.check()
            root.refresh()
        }
    }

    // Automatic location asks GeoClue through its where-am-i helper, which services.qs.locationServices provides.
    Process {
        id: locate
        command: ["sh", "-c", "command -v where-am-i >/dev/null || exit 127; exec where-am-i -t 20 -a 8"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lat = /Latitude:\s*(-?[\d.]+)/.exec(text)
                const lon = /Longitude:\s*(-?[\d.]+)/.exec(text)
                if (lat && lon) {
                    root.automaticError = ""
                    const next = { name: "", latitude: Number(lat[1]), longitude: Number(lon[1]) }
                    const last = root.automaticFix
                    if (!last || Math.abs(last.latitude - next.latitude) > 0.005 || Math.abs(last.longitude - next.longitude) > 0.005)
                        root.automaticFix = next
                } else {
                    root.automaticError = "Automatic location needs location services"
                    root.refresh()
                }
            }
        }
        onExited: code => {
            if (code !== 0 && !root.automaticFix) {
                root.automaticError = "Automatic location needs location services"
                root.refresh()
            }
        }
    }

    Timer {
        interval: root.refreshInterval
        running: root.locating
        repeat: true
        onTriggered: locate.running = true
    }

    Component {
        id: curl

        Process {
            id: request
            property string url: ""
            signal finished(bool ok, string body)
            command: ["curl", "-sfL", "--max-time", String(root.requestTimeout), "-A", root.userAgent,
                      "-H", "Accept: application/geo+json", url]
            // curl -f prints nothing on failure, so an empty body is the failure signal.
            stdout: StdioCollector {
                onStreamFinished: request.finished(text.length > 0, text)
            }
        }
    }
}
