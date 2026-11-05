import QtQuick
import "../Common"

// The round control at the head of a row. Clicking it acts at once (mute, disable, switch to manual);
// the row beside it goes deeper. It is an unfilled circle in the pen's line that `on` fills with ink. A
// `level` in 0..1 draws the bar's ring around the glyph. Rings mean something live: a meter, a reading,
// never the setpoint the row's own fader already shows. `live` makes the ring follow at meter speed.
Item {
    id: root

    property string motion: "easeOut"
    property string icon: ""
    property int wifiBars: 0
    property bool on: false
    // NaN draws no ring.
    property real level: NaN
    property bool live: false
    // What the glyph itself fills to (the speaker's waves); defaults to the ring.
    property real glyphLevel: ringed ? level : 0
    property bool interactive: true
    property color ringColor: Theme.textPrimary
    signal clicked()

    readonly property bool hovered: hit.containsMouse && interactive
    readonly property bool pressed: hit.pressed && interactive
    readonly property bool ringed: !isNaN(level)
    readonly property color fill: on ? Theme.today : Theme.clear
    readonly property color ink: on ? Theme.todayInk : Theme.textPrimary

    implicitWidth: Theme.knobSize
    implicitHeight: Theme.knobSize
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.fill
        // A ringed knob is already outlined by its ring's track.
        border.width: !root.on && !root.ringed ? Theme.line : 0
        border.color: Theme.stroke

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFor(root.motion)
                easing.type: Easing.OutCubic
            }
        }
    }

    // State layer: the glyph's own color at hover/press strength, so it reads on any fill.
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.pressed ? Qt.alpha(root.ink, 0.12) : root.hovered ? Qt.alpha(root.ink, 0.08) : Qt.alpha(root.ink, 0)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFor(root.motion) * 0.56
                easing.type: Easing.OutCubic
            }
        }
    }

    StatusArc {
        anchors.fill: parent
        anchors.margins: 2
        visible: root.ringed
        lineWidth: Theme.lineStrong
        value: root.ringed ? root.level : 0
        trackColor: root.on ? Theme.todayDim : Theme.statusTrack
        fillColor: root.on ? Theme.todayInk : root.ringColor

        Behavior on value {
            NumberAnimation {
                duration: root.live ? 60 : Theme.durationFor(root.motion)
                easing.type: Easing.OutCubic
            }
        }
    }

    StatusGlyph {
        anchors.centerIn: parent
        width: root.ringed ? Theme.px(13) : Theme.buttonIconSize
        height: width
        icon: root.icon
        wifiBars: root.wifiBars
        level: root.glyphLevel
        ink: root.ink
        dim: root.on ? Theme.todayDim : Theme.statusDim
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
