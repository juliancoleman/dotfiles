pragma Singleton

import QtQuick
import Quickshell
import ".."
import "../Common"

// Every setting, for both the control center's settings pages and the launcher's ">" search: what each
// control is, when it applies, and how it reads and writes ClockConfig. A control is a row of choices unless
// its `kind` says otherwise. A control shows its section's `icon` in the launcher unless it names its own.
// Titles and labels stay English sources that the views pass through I18n.tr, so search can match either
// language and a locale switch doesn't rebuild every page.
Singleton {
    id: root

    readonly property var onOff: [
        { label: "On", value: "on" },
        { label: "Off", value: "off" }
    ]

    readonly property var sections: [
        {
            id: "theme",
            icon: "palette",
            title: "Theme",
            controls: [
                {
                    key: "locale",
                    title: "Locale",
                    // Each language names itself, so the dictionary deliberately has no entry for these.
                    choices: [
                        { label: "English", value: "en" },
                        { label: "日本語", value: "jp" }
                    ]
                },
                {
                    key: "presentation",
                    title: "Housing",
                    choices: [
                        { label: "Pill", value: "pill" },
                        { label: "Notch", value: "notch" }
                    ]
                },
                {
                    key: "placement",
                    title: "Edge",
                    choices: [
                        { label: "Top", value: "top" },
                        { label: "Right", value: "right" },
                        { label: "Bottom", value: "bottom" },
                        { label: "Left", value: "left" }
                    ]
                },
                {
                    key: "shadow",
                    title: "Shadow",
                    keywords: "drop shadow float floating depth elevation",
                    choices: onOff
                },
                {
                    key: "palette",
                    kind: "palette",
                    title: "Palette",
                    keywords: "color colour ink pen bordeaux green blue black purple"
                }
            ]
        },
        {
            id: "motion",
            icon: "motion",
            title: "Motion",
            controls: [
                {
                    key: "motion",
                    title: "Motion",
                    choices: [
                        { label: "Spring", value: "spring" },
                        { label: "Ease out", value: "easeOut" },
                        { label: "Ease in", value: "easeIn" },
                        { label: "Linear", value: "linear" },
                        { label: "None", value: "none" }
                    ]
                },
                {
                    key: "duration",
                    kind: "stepper",
                    title: "Duration",
                    keywords: "ms millisecond",
                    minimum: 50,
                    maximum: 1000,
                    step: 25,
                    decimals: 0,
                    suffix: " ms"
                },
                {
                    key: "spring",
                    kind: "stepper",
                    title: "Spring factor",
                    keywords: "overshoot bounce",
                    minimum: 0,
                    maximum: 4,
                    step: 0.1,
                    decimals: 1,
                    suffix: ""
                }
            ]
        },
        {
            id: "clock",
            icon: "clock",
            title: "Clock",
            controls: [
                {
                    key: "hourCycle",
                    title: "Format",
                    choices: [
                        { label: "12 hour", value: "12" },
                        { label: "24 hour", value: "24" }
                    ]
                },
                {
                    key: "meridiem",
                    title: "AM / PM",
                    keywords: "meridiem period am pm 午前 午後",
                    choices: [
                        { label: "Show", value: "shown" },
                        { label: "Hide", value: "hidden" }
                    ]
                }
            ]
        },
        {
            id: "status",
            icon: "power",
            title: "Status",
            controls: [
                {
                    key: "batteryPercentage",
                    title: "Battery percentage",
                    keywords: "battery percent low power",
                    choices: [
                        { label: "Always", value: "always" },
                        { label: "20% and below", value: "low" }
                    ]
                }
            ]
        },
        {
            id: "launcher",
            icon: "search",
            title: "Launcher",
            controls: [
                {
                    key: "launcherView",
                    title: "Default view",
                    keywords: "applications apps search list grid icons super space",
                    choices: [
                        { label: "List", value: "list" },
                        { label: "Large icons", value: "large" },
                        { label: "Small icons", value: "small" }
                    ]
                }
            ]
        },
        {
            id: "weather",
            icon: "partly-day",
            title: "Weather",
            controls: [
                {
                    key: "weatherEnabled",
                    title: "Show weather",
                    keywords: "show hide forecast temperature",
                    choices: onOff
                },
                {
                    key: "weatherUnits",
                    title: "Units",
                    keywords: "temperature celsius fahrenheit degrees",
                    choices: [
                        { label: "°F", value: "imperial" },
                        { label: "°C", value: "metric" }
                    ]
                },
                {
                    key: "weatherAlerts",
                    icon: "alert",
                    title: "Alerts",
                    keywords: "notify notification warning rain snow storm wind tornado",
                    choices: onOff
                },
                {
                    key: "weatherLocationMode",
                    icon: "navigation",
                    title: "Location",
                    keywords: "city search place automatic location services gps",
                    choices: [
                        { label: "Exact", value: "exact" },
                        { label: "Automatic", value: "automatic" }
                    ]
                },
                // The place itself, found by name; searching finds it through Location above.
                { key: "weatherLocation", kind: "location" }
            ]
        },
        {
            id: "privacy",
            icon: "lock",
            title: "Privacy",
            controls: [
                {
                    key: "locationServices",
                    icon: "navigation",
                    title: "Location services",
                    keywords: "location gps geoclue where privacy time zone",
                    choices: onOff
                },
                // What the switch means, or why it's missing.
                { key: "locationNote", kind: "note" }
            ]
        }
    ]

    function kindOf(control) {
        return control.kind || "choice"
    }

    function section(id) {
        for (let i = 0; i < sections.length; ++i) {
            if (sections[i].id === id)
                return sections[i]
        }
        return null
    }

    // Whether a control applies right now; one that doesn't is neither drawn nor found.
    function shown(key) {
        switch (key) {
        case "meridiem":
            return !ClockConfig.use24Hour
        case "weatherUnits":
        case "weatherAlerts":
        case "weatherLocationMode":
        case "weatherLocation":
            return ClockConfig.weatherEnabled
        case "locationServices":
            return LocationServices.installed
        default:
            return true
        }
    }

    function value(key) {
        switch (key) {
        case "locale":
            return ClockConfig.locale
        case "presentation":
            return ClockConfig.presentation
        case "placement":
            return ClockConfig.placement
        case "shadow":
            return ClockConfig.shadow ? "on" : "off"
        case "motion":
            return ClockConfig.motion
        case "duration":
            return ClockConfig.duration
        case "spring":
            return ClockConfig.springOvershoot
        case "hourCycle":
            return ClockConfig.use24Hour ? "24" : "12"
        case "meridiem":
            return ClockConfig.showPeriod ? "shown" : "hidden"
        case "batteryPercentage":
            return ClockConfig.batteryPercentage
        case "launcherView":
            return ClockConfig.launcherView
        case "weatherEnabled":
            return ClockConfig.weatherEnabled ? "on" : "off"
        case "weatherUnits":
            return ClockConfig.weatherUnits
        case "weatherAlerts":
            return ClockConfig.weatherAlerts ? "on" : "off"
        case "weatherLocationMode":
            return ClockConfig.weatherLocationMode
        case "locationServices":
            return LocationServices.enabled ? "on" : "off"
        default:
            return ""
        }
    }

    function apply(key, next) {
        switch (key) {
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
        case "motion":
            ClockConfig.motion = next
            break
        case "duration":
            ClockConfig.duration = next
            break
        case "spring":
            ClockConfig.springOvershoot = next
            break
        case "hourCycle":
            ClockConfig.use24Hour = next === "24"
            break
        case "meridiem":
            ClockConfig.showPeriod = next === "shown"
            break
        case "batteryPercentage":
            ClockConfig.batteryPercentage = next
            break
        case "launcherView":
            ClockConfig.launcherView = next
            break
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
        // A system switch rather than a preference: it lives outside the config file.
        case "locationServices":
            LocationServices.setEnabled(next === "on")
            return
        default:
            return
        }
        ClockConfig.save()
    }

    // A note's text: here, what the location switch means, or why it's missing.
    function note(key) {
        if (key !== "locationNote")
            return ""
        if (!LocationServices.installed)
            return I18n.tr("Location services aren't set up on this system. Enable services.qs.locationServices in your NixOS configuration.")
        return I18n.tr(LocationServices.error) || (LocationServices.enabled
            ? I18n.tr("Apps and the shell can find this device's approximate location from nearby Wi-Fi networks.")
            : I18n.tr("Nothing on this device can look up its location."))
    }

    // The current value as its control shows it, or "" for controls without one.
    function valueLabel(control) {
        const current = value(control.key)
        switch (kindOf(control)) {
        case "stepper":
            return (control.decimals > 0 ? current.toFixed(control.decimals) : Math.round(current)) + control.suffix
        case "choice":
            for (let i = 0; i < control.choices.length; ++i) {
                if (control.choices[i].value === current)
                    return I18n.tr(control.choices[i].label)
            }
            return current
        default:
            return ""
        }
    }

    function includes(text, needle) {
        const source = String(text || "")
        return source.toLowerCase().indexOf(needle) >= 0 || I18n.tr(source).toLowerCase().indexOf(needle) >= 0
    }

    function matches(entry, control, needle) {
        if (!needle || includes(entry.title, needle) || includes(control.title, needle)
                || includes(control.keywords, needle))
            return true
        const choices = control.choices || []
        for (let i = 0; i < choices.length; ++i) {
            if (includes(choices[i].label, needle) || includes(choices[i].value, needle))
                return true
        }
        return false
    }

    // Controls that apply and match by section, title, keywords, or a choice, in page order; all of them
    // for an empty query. Untitled controls belong to the one above them and aren't found on their own.
    function search(query) {
        const needle = query.trim().toLowerCase()
        const hits = []
        for (let s = 0; s < sections.length; ++s) {
            const entry = sections[s]
            for (let i = 0; i < entry.controls.length; ++i) {
                const control = entry.controls[i]
                if (control.title && shown(control.key) && matches(entry, control, needle))
                    hits.push({ section: entry, control: control })
            }
        }
        return hits
    }
}
