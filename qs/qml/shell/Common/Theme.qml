pragma Singleton

import QtQuick

QtObject {
    property color surface: "#000000"
    property color surfaceRaised: "#000000"
    property color ink: "#252A2E"
    property color textPrimary: "#F2F0EA"
    property color textSecondary: "#AEB5B9"
    property color bordeaux: "#4C1722"
    property color greenBlack: "#4C6455"
    property color greenBlackLight: "#7E9C88"
    property color blueBlack: "#3D566E"
    property color purple: "#B7C1FF"
    property color today: purple
    property color todayInk: "#1B1E2B"
    property color outline: Qt.rgba(0.82, 0.86, 0.88, 0.32)
    property color track: "#14181B"
    property color danger: bordeaux
    property color charging: greenBlackLight
    property color statusTrack: Qt.rgba(0.95, 0.94, 0.92, 0.2)
    property color statusDim: Qt.rgba(0.95, 0.94, 0.92, 0.3)

    readonly property var palette: [
        { name: "Black", color: surface },
        { name: "Graphite", color: ink },
        { name: "Pencil", color: textSecondary },
        { name: "Paper", color: textPrimary },
        { name: "Bordeaux", color: bordeaux },
        { name: "Green-black", color: greenBlack },
        { name: "Green-black light", color: greenBlackLight },
        { name: "Blue-black", color: blueBlack },
        { name: "Purple", color: purple }
    ]

    property string latinFontFamily: "IBM Plex Sans"
    property string jaFontFamily: "IBM Plex Sans JP"
    // UI text follows the locale so kana and kanji don't fall back to a mismatched font; the JP face carries
    // the same Plex Latin, so mixed strings stay consistent.
    readonly property string fontFamily: I18n.japanese ? jaFontFamily : latinFontFamily

    property int verticalDigit: 13
    property int horizontalDigit: 15
    property int periodSize: 10
    property int notchDigit: 13
    property int notchPeriod: 13
    // Pill line the top and bottom notch keeps, so the smaller notch clock stays centered in it.
    property int notchLine: 15
    property int dateSize: 10
    property int clockFontWeight: Font.Medium
    property int padX: 7
    property int padY: 10
    property int notchOuterPad: 3
    property int notchInnerPad: 4
    property int floatMargin: 8
    // Gutter between an open panel's edge and its content, shared by the launcher, notch, and pill panels.
    readonly property int panelPad: 12
    // A panel's header row sits this far inside its content's gutter; a back button reaches back out by the
    // same amount so its hover box starts at the content's edge.
    readonly property int panelHeaderInset: 4
    // Between a panel's header row and its content.
    readonly property int panelHeaderGap: 2
    property int periodGap: 4
    readonly property int buttonIconSize: 16
    property int stackGap: 3
    property int statusGap: 8
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
