pragma Singleton

import QtQuick
import Quickshell
import ".."
import "../Common"

// Every setting, for both the control center's settings pages and the launcher's ">" search: what each
// control is, when it applies, and how it reads and writes ClockConfig. A control is a row of choices unless
// its `kind` says otherwise. A control shows its section's `icon` in the launcher unless it names its own.
// Each control carries its own `get`/`set` (and `shown` when it doesn't always apply), so a key is defined
// in exactly one place; `set` writes a preference that the model then saves, unless the control is a
// `system` switch that lives outside the config file. Titles and labels stay English sources that the views
// pass through I18n.tr, so search can match either language and a locale switch doesn't rebuild every page.
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
                    ],
                    get: () => ClockConfig.locale,
                    set: next => ClockConfig.locale = next
                },
                {
                    key: "presentation",
                    title: "Housing",
                    choices: [
                        { label: "Pill", value: "pill" },
                        { label: "Notch", value: "notch" }
                    ],
                    get: () => ClockConfig.presentation,
                    set: next => ClockConfig.presentation = next
                },
                {
                    key: "placement",
                    title: "Edge",
                    choices: [
                        { label: "Top", value: "top" },
                        { label: "Right", value: "right" },
                        { label: "Bottom", value: "bottom" },
                        { label: "Left", value: "left" }
                    ],
                    get: () => ClockConfig.placement,
                    set: next => ClockConfig.placement = next
                },
                {
                    key: "shadow",
                    title: "Shadow",
                    keywords: "drop shadow float floating depth elevation",
                    choices: onOff,
                    get: () => ClockConfig.shadow ? "on" : "off",
                    set: next => ClockConfig.shadow = next === "on"
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
                    ],
                    get: () => ClockConfig.motion,
                    set: next => ClockConfig.motion = next
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
                    suffix: " ms",
                    get: () => ClockConfig.duration,
                    set: next => ClockConfig.duration = next
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
                    suffix: "",
                    get: () => ClockConfig.springOvershoot,
                    set: next => ClockConfig.springOvershoot = next
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
                    ],
                    get: () => ClockConfig.use24Hour ? "24" : "12",
                    set: next => ClockConfig.use24Hour = next === "24"
                },
                {
                    key: "meridiem",
                    title: "AM / PM",
                    keywords: "meridiem period am pm 午前 午後",
                    choices: [
                        { label: "Show", value: "shown" },
                        { label: "Hide", value: "hidden" }
                    ],
                    shown: () => !ClockConfig.use24Hour,
                    get: () => ClockConfig.showPeriod ? "shown" : "hidden",
                    set: next => ClockConfig.showPeriod = next === "shown"
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
                    ],
                    get: () => ClockConfig.batteryPercentage,
                    set: next => ClockConfig.batteryPercentage = next
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
                    ],
                    get: () => ClockConfig.launcherView,
                    set: next => ClockConfig.launcherView = next
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
                    choices: onOff,
                    get: () => ClockConfig.weatherEnabled ? "on" : "off",
                    set: next => ClockConfig.weatherEnabled = next === "on"
                },
                {
                    key: "weatherUnits",
                    title: "Units",
                    keywords: "temperature celsius fahrenheit degrees",
                    choices: [
                        { label: "°F", value: "imperial" },
                        { label: "°C", value: "metric" }
                    ],
                    shown: () => ClockConfig.weatherEnabled,
                    get: () => ClockConfig.weatherUnits,
                    set: next => ClockConfig.weatherUnits = next
                },
                {
                    key: "weatherAlerts",
                    icon: "alert",
                    title: "Alerts",
                    keywords: "notify notification warning rain snow storm wind tornado",
                    choices: onOff,
                    shown: () => ClockConfig.weatherEnabled,
                    get: () => ClockConfig.weatherAlerts ? "on" : "off",
                    set: next => ClockConfig.weatherAlerts = next === "on"
                },
                {
                    key: "weatherLocationMode",
                    icon: "navigation",
                    title: "Location",
                    keywords: "city search place automatic location services gps",
                    choices: [
                        { label: "Exact", value: "exact" },
                        { label: "Automatic", value: "automatic" }
                    ],
                    shown: () => ClockConfig.weatherEnabled,
                    get: () => ClockConfig.weatherLocationMode,
                    set: next => ClockConfig.weatherLocationMode = next
                },
                // The place itself, found by name; searching finds it through Location above.
                { key: "weatherLocation", kind: "location", shown: () => ClockConfig.weatherEnabled }
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
                    choices: onOff,
                    system: true,
                    shown: () => LocationServices.installed,
                    get: () => LocationServices.enabled ? "on" : "off",
                    set: next => LocationServices.setEnabled(next === "on")
                },
                // What the switch means, or why it's missing.
                { key: "locationNote", kind: "note" }
            ]
        }
    ]

    readonly property var controls: {
        const byKey = {}
        for (let s = 0; s < sections.length; ++s) {
            for (let i = 0; i < sections[s].controls.length; ++i)
                byKey[sections[s].controls[i].key] = sections[s].controls[i]
        }
        return byKey
    }

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
        const control = controls[key]
        return !control || !control.shown || control.shown()
    }

    function value(key) {
        const control = controls[key]
        return control && control.get ? control.get() : ""
    }

    function apply(key, next) {
        const control = controls[key]
        if (!control || !control.set)
            return
        control.set(next)
        if (!control.system)
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
