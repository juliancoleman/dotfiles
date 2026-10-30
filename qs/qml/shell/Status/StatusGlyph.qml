import QtQuick
import QtQuick.Shapes
import "../Common"

// Icon paths are from Lucide v1.64.0 (https://lucide.dev).
// ISC License, Copyright (c) 2026 Lucide Icons and Contributors.
// Permission to use, copy, modify, and/or distribute this software for any purpose with or without
// fee is hereby granted, provided that the above copyright notice and this permission notice appear
// in all copies. THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES.
Item {
    id: root

    property string icon: "ethernet-off"
    property int wifiBars: 0
    property real level: 0
    property color ink: Theme.textPrimary
    property color dim: Theme.statusDim
    property color cutColor: Theme.surface
    property real stroke: 2

    readonly property var spec: build(icon, wifiBars, level)

    readonly property var paths: ({
        wifiDot: "M12 20h0.01",
        wifiArcs: [
            "M8.5 16.429a5 5 0 0 1 7 0",
            "M5 12.859a10 10 0 0 1 14 0",
            "M2 8.82a15 15 0 0 1 20 0"
        ],
        ethernet: "M10 8v1 M14 8v1 M18 8v1 M6 8v1 "
            + "M19 17a2 2 0 0 0 -1.765 1.059l-0.47 0.882A2 2 0 0 1 15 20H9a2 2 0 0 1 -1.765 -1.059"
            + "l-0.47 -0.882A2 2 0 0 0 5 17H4a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2h16a2 2 0 0 1 2 2v9"
            + "a2 2 0 0 1 -2 2z",
        slash: "M2 2 L22 22",
        bluetooth: "M7 7 L17 17 L12 22 V2 L17 7 L7 17",
        sun: "M8 12a4 4 0 1 0 8 0a4 4 0 1 0 -8 0 M12 2v2 M12 20v2 M4.93 4.93l1.41 1.41 "
            + "M17.66 17.66l1.41 1.41 M2 12h2 M20 12h2 M6.34 17.66l-1.41 1.41 M19.07 4.93l-1.41 1.41",
        speaker: "M11 4.702a0.705 0.705 0 0 0 -1.203 -0.498L6.413 7.587A1.4 1.4 0 0 1 5.416 8H3"
            + "a1 1 0 0 0 -1 1v6a1 1 0 0 0 1 1h2.416a1.4 1.4 0 0 1 0.997 0.413l3.383 3.384"
            + "A0.705 0.705 0 0 0 11 19.298z",
        nearWave: "M16 9a5 5 0 0 1 0 6",
        farWave: "M19.364 18.364a9 9 0 0 0 0 -12.728",
        mute: "M16.5 14.5 L21.5 9.5 M16.5 9.5 L21.5 14.5",
        zap: "M15.914 4a1.5 1.5 0 0 0 -2.474 -1.561l-9 9A1.5 1.5 0 0 0 5.5 14h4.002a0.5 0.5 0 0 1 0.471 0.666"
            + "L8.086 20a1.5 1.5 0 0 0 2.475 1.56l9 -9A1.5 1.5 0 0 0 18.5 10h-3.997a0.5 0.5 0 0 1 -0.472 -0.667z",
        mic: "M9 5a3 3 0 0 1 6 0v7a3 3 0 0 1 -6 0z M12 19v3 M19 10v2a7 7 0 0 1 -14 0v-2",
        micOff: "M12 19v3 M15 9.34V5a3 3 0 0 0 -5.68 -1.33 M16.95 16.95A7 7 0 0 1 5 12v-2 "
            + "M18.89 13.23A7 7 0 0 0 19 12v-2 M2 2 L22 22 M9 9v3a3 3 0 0 0 5.12 2.12",
        play: "M5 5a2 2 0 0 1 3.008 -1.728l11.997 6.998a2 2 0 0 1 0.003 3.458l-12 7A2 2 0 0 1 5 19z",
        pause: "M15 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1 -1 1h-3a1 1 0 0 1 -1 -1V4a1 1 0 0 1 1 -1z "
            + "M6 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1 -1 1H6a1 1 0 0 1 -1 -1V4a1 1 0 0 1 1 -1z",
        fan: "M10.827 16.379a6.082 6.082 0 0 1 -8.618 -7.002l5.412 1.45a6.082 6.082 0 0 1 7.002 -8.618"
            + "l-1.45 5.412a6.082 6.082 0 0 1 8.618 7.002l-5.412 -1.45a6.082 6.082 0 0 1 -7.002 8.618"
            + "l1.45 -5.412z M12 12v0.01",
        chevronLeft: "M15 18 L9 12 L15 6",
        chevronRight: "M9 18 L15 12 L9 6",
        lock: "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2v-7a2 2 0 0 1 2 -2z M7 11V7a5 5 0 0 1 10 0v4",
        // Lucide's lock, shrunk to sit where the wifi glyph's dot and inner arc would be.
        wifiLock: "M8.5 17h7a1 1 0 0 1 1 1v2a1 1 0 0 1 -1 1h-7a1 1 0 0 1 -1 -1v-2a1 1 0 0 1 1 -1z M10 17v-1a2 2 0 0 1 4 0v1",
        key: "M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1 -1v-1a1 1 0 0 1 1 -1h1"
            + "a1 1 0 0 0 1 -1v-1a1 1 0 0 1 1 -1h0.172a2 2 0 0 0 1.414 -0.586l0.814 -0.814a6.5 6.5 0 1 0 -4 -4z "
            + "M16.5 7.5a0.5 0.5 0 1 0 1 0a0.5 0.5 0 1 0 -1 0",
        check: "M20 6 L9 17 L4 12",
        close: "M18 6 L6 18 M6 6 L18 18",
        moon: "M12 3a6 6 0 0 0 9 9a9 9 0 1 1 -9 -9z",
        bell: "M10.268 21a2 2 0 0 0 3.464 0 M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 0.74 -1.673"
            + "C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499 -1.411 5.956 -2.738 7.326z",
        cpu: "M12 20v2 M12 2v2 M17 20v2 M17 2v2 M2 12h2 M2 17h2 M2 7h2 M20 12h2 M20 17h2 M20 7h2 M7 20v2 M7 2v2 "
            + "M6 4h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2H6a2 2 0 0 1 -2 -2V6a2 2 0 0 1 2 -2z "
            + "M9 8h6a1 1 0 0 1 1 1v6a1 1 0 0 1 -1 1H9a1 1 0 0 1 -1 -1V9a1 1 0 0 1 1 -1z",
        memory: "M6 19v-3 M10 19v-3 M14 19v-3 M18 19v-3 M8 11V9 M16 11V9 M12 11V9 M2 15h20 "
            + "M2 7a2 2 0 0 1 2 -2h16a2 2 0 0 1 2 2v1.1a2 2 0 0 0 0 3.837V17a2 2 0 0 1 -2 2H4"
            + "a2 2 0 0 1 -2 -2v-5.1a2 2 0 0 0 0 -3.837z",
        disk: "M22 12 L2 12 M5.45 5.11 L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2 -2v-6l-3.45 -6.89"
            + "A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0 -1.79 1.11z M6 16h0.01 M10 16h0.01",
        settings: "M9.671 4.136a2.34 2.34 0 0 1 4.659 0a2.34 2.34 0 0 0 3.319 1.915a2.34 2.34 0 0 1 2.33 4.033"
            + "a2.34 2.34 0 0 0 0 3.831a2.34 2.34 0 0 1 -2.33 4.033a2.34 2.34 0 0 0 -3.319 1.915"
            + "a2.34 2.34 0 0 1 -4.659 0a2.34 2.34 0 0 0 -3.32 -1.915a2.34 2.34 0 0 1 -2.33 -4.033"
            + "a2.34 2.34 0 0 0 0 -3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319 -1.915z "
            + "M9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0"
    })

    implicitWidth: 24
    implicitHeight: 24

    readonly property string cloudTop: "M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242"
    readonly property var weather: ({
        "clear-day": paths.sun,
        "clear-night": "M12 3a6 6 0 0 0 9 9a9 9 0 1 1 -9 -9z",
        "partly-day": "M12 2v2 M4.93 4.93l1.41 1.41 M20 12h2 M19.07 4.93l-1.41 1.41 M15.947 12.65a4 4 0 0 0 -5.925 -4.128 "
            + "M13 22H7a5 5 0 1 1 4.9 -6H13a3 3 0 0 1 0 6z",
        "partly-night": "M13 16a3 3 0 0 1 0 6H7a5 5 0 1 1 4.9 -6z M18.376 14.512a6 6 0 0 0 3.461 -4.127"
            + "c0.148 -0.625 -0.659 -0.97 -1.248 -0.714a4 4 0 0 1 -5.259 -5.26c0.255 -0.589 -0.09 -1.395 -0.716 -1.248"
            + "a6 6 0 0 0 -4.594 5.36",
        "cloud": "M17.5 19H9a7 7 0 1 1 6.71 -9h1.79a4.5 4.5 0 1 1 0 9z",
        "rain": cloudTop + " M16 14v6 M8 14v6 M12 16v6",
        "snow": cloudTop + " M8 15h0.01 M8 19h0.01 M12 17h0.01 M12 21h0.01 M16 15h0.01 M16 19h0.01",
        "hail": cloudTop + " M16 14v2 M8 14v2 M16 20h0.01 M8 20h0.01 M12 16v2 M12 22h0.01",
        "thunder": "M6 16.326A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 0.5 8.973 M13 12l-3 5h4l-3 5",
        "fog": cloudTop + " M16 17H7 M17 21H9",
        "wind": "M12.8 19.6A2 2 0 1 0 14 16H2 M17.5 8a2.5 2.5 0 1 1 2 4H2 M9.8 4.4A2 2 0 1 1 11 8H2",
        "alert": "M21.73 18l-8 -14a2 2 0 0 0 -3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73 -3 M12 9v4 M12 17h0.01",
        "sunrise": "M12 2v8 M4.93 10.93l1.41 1.41 M2 18h2 M20 18h2 M19.07 10.93l-1.41 1.41 M22 22H2 M8 6l4 -4l4 4 "
            + "M16 18a4 4 0 0 0 -8 0",
        "sunset": "M12 10V2 M4.93 10.93l1.41 1.41 M2 18h2 M20 18h2 M19.07 10.93l-1.41 1.41 M22 22H2 M16 6l-4 4l-4 -4 "
            + "M16 18a4 4 0 0 0 -8 0",
        "navigation": "M3 11L22 2L13 21L11 13z"
    })

    function build(name, bars, amount) {
        const out = { lit: "", dim: "", cut: "", over: "" }
        if (weather[name] !== undefined) {
            out.lit = weather[name]
            return out
        }
        switch (name) {
        case "wifi":
            out.lit = paths.wifiDot
            for (let i = 0; i < paths.wifiArcs.length; ++i) {
                if (i < bars)
                    out.lit += " " + paths.wifiArcs[i]
                else
                    out.dim += " " + paths.wifiArcs[i]
            }
            break
        case "wifi-off":
            out.lit = paths.wifiDot
            out.dim = paths.wifiArcs.join(" ")
            out.cut = paths.slash
            out.over = paths.slash
            break
        case "ethernet":
            out.lit = paths.ethernet
            break
        case "bluetooth":
            out.lit = paths.bluetooth
            break
        case "bluetooth-off":
            out.dim = paths.bluetooth
            out.cut = paths.slash
            out.over = paths.slash
            break
        case "fan":
            out.lit = paths.fan
            break
        case "chevron-left":
            out.lit = paths.chevronLeft
            break
        case "chevron-right":
            out.lit = paths.chevronRight
            break
        case "lock":
            out.lit = paths.lock
            break
        case "wifi-lock":
            out.lit = paths.wifiArcs[1] + " " + paths.wifiArcs[2] + " " + paths.wifiLock
            break
        case "key":
            out.lit = paths.key
            break
        case "check":
            out.lit = paths.check
            break
        case "close":
            out.lit = paths.close
            break
        case "bell":
            out.lit = paths.bell
            break
        case "moon":
            out.lit = paths.moon
            break
        case "settings":
            out.lit = paths.settings
            break
        case "cpu":
            out.lit = paths.cpu
            break
        case "memory":
            out.lit = paths.memory
            break
        case "disk":
            out.lit = paths.disk
            break
        case "brightness":
            out.lit = paths.sun
            break
        case "volume":
            out.lit = paths.speaker
            if (amount > 0.005)
                out.lit += " " + paths.nearWave
            else
                out.dim += " " + paths.nearWave
            if (amount >= 0.5)
                out.lit += " " + paths.farWave
            else
                out.dim += " " + paths.farWave
            break
        case "volume-muted":
            out.lit = paths.speaker + " " + paths.mute
            break
        case "power":
            out.lit = paths.zap
            break
        case "power-off":
            out.lit = "M12 2v10 M18.4 6.6a9 9 0 1 1 -12.77 0.04"
            break
        case "restart":
            out.lit = "M21 12a9 9 0 1 1 -9 -9c2.52 0 4.93 1 6.74 2.74L21 8 M21 3v5h-5"
            break
        case "sleep":
            out.lit = "M18 5h4 M20 3v4 M20.985 12.486a9 9 0 1 1 -9.473 -9.472c0.405 -0.022 0.617 0.46 0.402 0.803"
                + "a6 6 0 0 0 8.268 8.268c0.344 -0.215 0.825 -0.004 0.803 0.401"
            break
        case "microphone":
            out.lit = paths.mic
            break
        case "microphone-muted":
            out.lit = paths.micOff
            break
        case "play":
            out.lit = paths.play
            break
        case "pause":
            out.lit = paths.pause
            break
        case "search":
            out.lit = "M21 21l-4.34 -4.34 M3 11a8 8 0 1 0 16 0a8 8 0 1 0 -16 0"
            break
        case "view-list":
            out.lit = "M3 5h0.01 M3 12h0.01 M3 19h0.01 M8 5h13 M8 12h13 M8 19h13"
            break
        case "view-large":
            out.lit = "M4 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1V4a1 1 0 0 1 1 -1z "
                + "M15 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1h-5a1 1 0 0 1 -1 -1V4a1 1 0 0 1 1 -1z "
                + "M15 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1h-5a1 1 0 0 1 -1 -1v-5a1 1 0 0 1 1 -1z "
                + "M4 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1v-5a1 1 0 0 1 1 -1z"
            break
        case "view-small":
            out.lit = "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2V5a2 2 0 0 1 2 -2z "
                + "M3 9h18 M3 15h18 M9 3v18 M15 3v18"
            break
        case "ethernet-off":
        default:
            out.lit = paths.ethernet
            out.cut = paths.slash
            out.over = paths.slash
            break
        }
        return out
    }

    Shape {
        anchors.centerIn: parent
        // Centering normally snaps to whole logical pixels, which pushes the glyph off the middle of a ring
        // whose size isn't whole; the curve renderer antialiases a fractional position cleanly.
        anchors.alignWhenCentered: false
        width: 24
        height: 24
        scale: Math.min(root.width, root.height) / 24
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.dim
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.spec.dim }
        }
        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.spec.lit }
        }
        ShapePath {
            strokeColor: root.cutColor
            strokeWidth: root.stroke * 2.6
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap
            PathSvg { path: root.spec.cut }
        }
        ShapePath {
            strokeColor: root.ink
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: root.spec.over }
        }
    }
}
