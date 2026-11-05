pragma Singleton

import QtQuick

// Every color, face, shape and line in the shell, for the chosen palette and appearance (`dark`).
// Components read the semantic slots below; nothing outside this file names a color.
QtObject {
    id: theme

    // Set from ClockConfig (`theme.colors`, `theme.appearance`).
    // "pens" (the stationery below) or "matugen" (roles generated from the wallpaper, `Matugen`).
    property string palette: "pens"
    property bool dark: true

    // ── The pens ──────────────────────────────────────────────────────────────────────────────────────
    // Paper and the pencil that rules it, and Uni-ball Signo's colored blacks, each with a lightened
    // night ink for the black page. Color is by function: every ink has one job and only that job.
    readonly property color paper: "#F2F0EA"
    readonly property color graphite: "#252A2E"
    readonly property color pencil: "#AEB5B9"
    readonly property color pencilOnPaper: "#646C71"
    // Blue Black: the active or armed state, once per surface.
    readonly property color blueBlack: "#3D566E"
    readonly property color blueBlackLight: "#8AA5C0"
    // Bordeaux: destructive and warning, never decoration.
    readonly property color bordeaux: "#4C1722"
    // Green Black: charging, good air.
    readonly property color greenBlack: "#4C6455"
    readonly property color greenBlackLight: "#7E9C88"

    readonly property var pensSet: dark ? {
        surface: "#000000",
        textPrimary: paper,
        textSecondary: pencil,
        rule: Qt.rgba(0.82, 0.86, 0.88, 0.14),
        stroke: Qt.rgba(0.82, 0.86, 0.88, 0.24),
        edge: Qt.rgba(0.82, 0.86, 0.88, 0.10),
        track: "#14181B",
        statusTrack: Qt.rgba(0.95, 0.94, 0.92, 0.2),
        statusDim: Qt.rgba(0.95, 0.94, 0.92, 0.3),
        lift: Qt.rgba(1, 1, 1, 0.05),
        press: Qt.rgba(1, 1, 1, 0.10),
        today: blueBlackLight,
        todayInk: "#111922",
        danger: bordeaux,
        dangerMark: Qt.lighter(bordeaux, 1.6),
        dangerInk: paper,
        charging: greenBlackLight
    } : {
        surface: paper,
        textPrimary: graphite,
        textSecondary: pencilOnPaper,
        rule: Qt.rgba(0.15, 0.16, 0.18, 0.16),
        stroke: Qt.rgba(0.15, 0.16, 0.18, 0.30),
        edge: Qt.rgba(0.15, 0.16, 0.18, 0.12),
        track: "#E6E3DB",
        statusTrack: Qt.rgba(0.15, 0.16, 0.18, 0.18),
        statusDim: Qt.rgba(0.15, 0.16, 0.18, 0.32),
        lift: Qt.rgba(0.15, 0.16, 0.18, 0.05),
        press: Qt.rgba(0.15, 0.16, 0.18, 0.10),
        today: blueBlack,
        todayInk: paper,
        danger: bordeaux,
        dangerMark: bordeaux,
        dangerInk: paper,
        charging: greenBlack
    }

    // The same functions filled from matugen's roles: the wallpaper's surface and on-surface for the page
    // and its writing, with the pens' rule and overlay strengths; primary for the active state, error for
    // danger, tertiary for charging.
    readonly property var matugenSet: {
        if (!Matugen.roles)
            return null
        const role = name => Matugen.role(name, dark)
        const writing = role("on_surface")
        const primary = role("primary")
        return {
            surface: role("surface"),
            textPrimary: writing,
            textSecondary: role("on_surface_variant"),
            rule: Qt.alpha(writing, dark ? 0.14 : 0.16),
            stroke: Qt.alpha(writing, dark ? 0.24 : 0.30),
            edge: Qt.alpha(writing, dark ? 0.10 : 0.12),
            track: role("surface_container_high"),
            statusTrack: Qt.alpha(writing, dark ? 0.2 : 0.18),
            statusDim: Qt.alpha(writing, dark ? 0.3 : 0.32),
            lift: Qt.alpha(writing, 0.05),
            press: Qt.alpha(writing, 0.10),
            today: primary,
            todayInk: role("on_primary"),
            danger: role("error"),
            dangerMark: role("error"),
            dangerInk: role("on_error"),
            charging: role("tertiary")
        }
    }

    // Until matugen has produced a scheme, the pens stand in.
    readonly property var set: palette === "matugen" && matugenSet ? matugenSet : pensSet

    // ── Semantic color slots ─────────────────────────────────────────────────────────────────────────
    // The page every panel is drawn on.
    readonly property color surface: set.surface
    // Readings in primary; labels, captions and functions in secondary.
    readonly property color textPrimary: set.textPrimary
    readonly property color textSecondary: set.textSecondary
    // Lines: `rule` between groups, `stroke` around an unfilled control, `edge` around a boxed thing.
    readonly property color rule: set.rule
    readonly property color stroke: set.stroke
    readonly property color edge: set.edge
    // The unfilled part of a slider or bar.
    readonly property color track: set.track
    readonly property color statusTrack: set.statusTrack
    readonly property color statusDim: set.statusDim
    // Overlays a row or control takes on hover and press.
    readonly property color lift: set.lift
    readonly property color press: set.press
    // `lift` at zero alpha: animating from "transparent" (black) passes through gray.
    readonly property color clear: Qt.alpha(set.lift, 0)
    // The active/armed state, once per surface, with `todayInk` for content set on it.
    readonly property color today: set.today
    readonly property color todayInk: set.todayInk
    readonly property color todayDim: Qt.alpha(set.todayInk, 0.35)
    // Destructive or warning: `danger` fills, `dangerMark` for thin marks and text that must read on the
    // surface.
    readonly property color danger: set.danger
    readonly property color dangerMark: set.dangerMark
    // Content set on a `danger` fill (a count badge, a destructive button's label).
    readonly property color dangerInk: set.dangerInk
    readonly property color charging: set.charging

    // US AQI bands, good through hazardous, toned rather than the EPA's saturated chart.
    readonly property color aqiGood: set.charging
    readonly property color aqiModerate: "#C9B76A"
    readonly property color aqiSensitive: "#C98E5A"
    readonly property color aqiUnhealthy: "#B0565A"
    readonly property color aqiVeryUnhealthy: "#8E6AA8"
    readonly property color aqiHazardous: "#7A3346"

    // ── Faces ─────────────────────────────────────────────────────────────────────────────────────────
    readonly property string latinFontFamily: "IBM Plex Sans"
    readonly property string jaFontFamily: "IBM Plex Sans JP"
    // UI text follows the locale so kana and kanji don't fall back to a mismatched font.
    readonly property string fontFamily: I18n.japanese ? jaFontFamily : latinFontFamily
    // Emphasis weight for titles and labels.
    readonly property int fontWeightStrong: Font.Medium
    readonly property int clockFontWeight: Font.Medium

    // One multiplier under every size below (`bar.scale`). Sizes stay whole pixels so strokes don't blur.
    property real scale: 1
    function px(base) {
        return Math.max(1, Math.round(base * scale))
    }

    // Type ramp. Readings share the clock's digit size so a panel reads as the same instrument as the bar.
    readonly property int textMicro: px(8)
    readonly property int textCaption: px(10)
    readonly property int textLabel: px(11)
    readonly property int textBody: px(12)
    readonly property int textStrong: px(13)
    readonly property int textTitle: horizontalDigit
    readonly property int textDisplay: px(22)
    // The one reading a panel is about (the weather's current temperature, the launcher's query).
    readonly property int textHero: px(40)

    // ── Shape ─────────────────────────────────────────────────────────────────────────────────────────
    // Panel housings.
    readonly property int radius: px(12)
    // Rows, hover boxes, fields.
    readonly property int radiusInput: px(6)
    // The round control at the head of every row: click it to act, click the row to go deeper.
    readonly property int knobSize: px(30)
    readonly property int knobInset: px(7)
    readonly property int knobGap: px(9)
    readonly property int rowHeight: px(44)
    readonly property int tileGap: px(6)

    // ── Lines ─────────────────────────────────────────────────────────────────────────────────────────
    // Weight of rules and strokes: a 0.38 pen's line.
    readonly property real line: 1
    // Weight of a fader's track or a chart's trace.
    readonly property real lineStrong: 2

    readonly property int verticalDigit: px(13)
    readonly property int horizontalDigit: px(15)
    readonly property int periodSize: px(10)
    readonly property int notchDigit: px(13)
    readonly property int notchPeriod: px(13)
    // Pill line the top and bottom notch keeps, so the smaller notch clock stays centered in it.
    readonly property int notchLine: px(15)
    readonly property int dateSize: px(10)
    readonly property int padX: px(7)
    readonly property int padY: px(10)
    readonly property int notchOuterPad: px(3)
    readonly property int notchInnerPad: px(4)
    readonly property int floatMargin: px(8)
    // Gutter between an open panel's edge and its content, shared by the launcher, notch, and pill panels.
    readonly property int panelPad: px(12)
    // A panel's header row sits this far inside its content's gutter; a back button reaches back out by the
    // same amount so its hover box starts at the content's edge.
    readonly property int panelHeaderInset: px(4)
    // Between a panel's header row and its content.
    readonly property int panelHeaderGap: px(2)
    readonly property int periodGap: px(4)
    readonly property int buttonIconSize: px(16)
    readonly property int stackGap: px(3)
    readonly property int statusGap: px(8)
    property int motionDuration: 250
    property real springOvershoot: 2.0

    function normalizeMotion(name) {
        switch (name) {
        case "spring":
        case "easeIn":
        case "linear":
        case "easeOut":
        case "none":
            return name
        default:
            return "spring"
        }
    }

    function durationFor(name) {
        return normalizeMotion(name) === "none" ? 0 : motionDuration
    }

    function easingFor(name) {
        switch (normalizeMotion(name)) {
        case "none":
        case "linear":
            return Easing.Linear
        case "easeIn":
            return Easing.InCubic
        case "spring":
            return Easing.OutBack
        case "easeOut":
            return Easing.OutCubic
        default:
            return Easing.OutCubic
        }
    }
}
