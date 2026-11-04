import QtQuick
import "../Common"

// The round control at the head of a row. Clicking it acts at once (mute, disable, switch to manual);
// the row beside it goes deeper. `on` fills it with the accent; a `level` in 0..1 draws the bar's ring
// around the glyph. Rings mean something live: a meter, a reading, never the setpoint the row's own
// slider already shows. `live` makes the ring follow at meter speed instead of the UI's motion.
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
    readonly property bool ringed: !isNaN(level)
    readonly property color fill: on ? Theme.today : hovered ? Theme.knobLift : Theme.knobFill

    implicitWidth: Theme.knobSize
    implicitHeight: Theme.knobSize
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.fill

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFor(root.motion)
                easing.type: Easing.OutCubic
            }
        }
    }

    StatusArc {
        anchors.fill: parent
        anchors.margins: 2
        visible: root.ringed
        lineWidth: 2
        value: root.ringed ? root.level : 0
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
        width: root.ringed ? 13 : Theme.buttonIconSize
        height: width
        icon: root.icon
        wifiBars: root.wifiBars
        level: root.glyphLevel
        ink: root.on ? Theme.todayInk : Theme.textPrimary
        dim: root.on ? Theme.todayDim : Theme.statusDim
        cutColor: root.fill
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
