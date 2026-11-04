import QtQuick
import "../Clock"
import "../Common"
import "../Status"

// A setpoint: the lane drags it, the digits roll with it, a click on the knob mutes it. The knob's
// ring is the signal actually flowing (`meter`, NaN for none), as a mixer's meter beside its fader.
Tile {
    id: tile

    property string icon: ""
    property string title: ""
    property real value: 0
    property bool muted: false
    property bool toggleable: true
    property bool opens: false
    property real meter: NaN
    // The signal is being consumed (someone is listening to the microphone): ring in the accent.
    property bool meterActive: false
    signal moved(real next)
    signal toggled()
    signal opened()

    readonly property real shown: muted ? 0 : Math.max(0, Math.min(1, value))

    activeFocusOnTab: visible
    Accessible.role: Accessible.Slider
    Accessible.name: title
    Accessible.description: Math.round(shown * 100) + "%"
    Keys.onLeftPressed: moved(Math.max(0, value - 0.05))
    Keys.onRightPressed: moved(Math.min(1, value + 0.05))
    Keys.onSpacePressed: if (toggleable) toggled()
    Keys.onReturnPressed: if (opens) opened()
    Keys.onEnterPressed: if (opens) opened()

    Knob {
        id: knob
        anchors.left: parent.left
        anchors.leftMargin: Theme.knobInset
        anchors.verticalCenter: parent.verticalCenter
        motion: tile.motion
        icon: tile.icon
        level: tile.meter
        live: true
        glyphLevel: tile.shown
        ringColor: tile.meterActive ? Theme.today : Theme.textPrimary
        interactive: tile.toggleable
        onClicked: tile.toggled()
    }

    Item {
        id: lane
        anchors.left: knob.right
        anchors.leftMargin: Theme.knobGap + 3
        anchors.right: readout.left
        anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 3
            radius: 1.5
            color: Theme.statusTrack
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 3
            radius: 1.5
            width: Math.max(height, track.width * tile.shown)
            visible: tile.shown > 0.002
            color: Theme.textPrimary

            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation {
                    duration: tile.motionDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.leftMargin: -4
            anchors.rightMargin: -4
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            function pick(px) {
                tile.moved(Math.max(0, Math.min(1, (px - 4) / track.width)))
            }
            onPressed: mouse => pick(mouse.x)
            onPositionChanged: mouse => { if (pressed) pick(mouse.x) }
        }
    }

    Item {
        id: readout
        anchors.right: tile.opens ? chevron.left : parent.right
        anchors.rightMargin: tile.opens ? 6 : 12
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: digits.implicitHeight

        TickerNumber {
            id: digits
            anchors.right: parent.right
            value: Math.round(tile.shown * 100)
            motion: drag.pressed ? "none" : tile.motion
            color: Theme.textSecondary
            fontPixelSize: Theme.textLabel
            fontWeight: Font.Normal
        }
    }

    StatusGlyph {
        id: chevron
        visible: tile.opens
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        icon: "chevron-right"
        ink: pageHit.containsMouse ? Theme.textPrimary : Theme.textSecondary
    }

    // The readout and chevron open the device page; the lane stays for dragging.
    MouseArea {
        id: pageHit
        visible: tile.opens
        anchors.left: readout.left
        anchors.leftMargin: -4
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.opened()
    }
}
