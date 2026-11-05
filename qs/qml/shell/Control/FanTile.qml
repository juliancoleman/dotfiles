import QtQuick
import "../Clock"
import "../Common"
import "../Status"

// One fan: the knob flips Auto/Manual and its ring is the duty the chip reports right now, in either
// mode. Manual reveals a lane whose fill is the setpoint; the ring catches up as the readback lands.
Tile {
    id: tile

    property string title: ""
    property string rpmText: ""
    property bool manual: false
    property bool controllable: true
    // Duty the driver reports (0–100); negative when unknown, which draws no ring.
    property real percent: 0
    property real minimum: 0
    signal autoRequested()
    signal percentRequested(real next)

    property real dragPercent: -1
    readonly property real shownPercent: dragPercent >= 0 ? dragPercent : Math.max(0, percent)
    readonly property real reading: percent < 0 ? NaN : Math.max(0, Math.min(1, percent / 100))
    readonly property real fraction: Math.max(0, Math.min(1, shownPercent / 100))

    implicitHeight: Theme.rowHeight + lane.height
    clip: true
    lifted: body.containsMouse && tile.controllable
    activeFocusOnTab: visible
    Accessible.role: manual ? Accessible.Slider : Accessible.Button
    Accessible.name: title
    Accessible.description: manual ? Math.round(shownPercent) + "%" : I18n.tr("Auto")
    Keys.onSpacePressed: toggle()
    Keys.onReturnPressed: toggle()
    Keys.onLeftPressed: if (manual && controllable) percentRequested(Math.max(minimum, percent - 5))
    Keys.onRightPressed: if (manual && controllable) percentRequested(Math.min(100, percent + 5))

    function toggle() {
        if (!controllable)
            return
        if (manual)
            autoRequested()
        else
            percentRequested(Math.max(minimum, percent))
    }

    // Hold the dragged value briefly so the knob doesn't jump back before the helper replies.
    Timer {
        id: settle
        interval: 600
        onTriggered: tile.dragPercent = -1
    }

    // The whole header row flips Auto/Manual, like a ToggleTile's body; the knob above it does the same.
    MouseArea {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Theme.rowHeight
        hoverEnabled: true
        enabled: tile.controllable
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.toggle()
    }

    Knob {
        id: knob
        x: Theme.knobInset
        y: Theme.knobInset
        motion: tile.motion
        icon: "fan"
        on: tile.manual
        level: tile.reading
        interactive: tile.controllable
        onClicked: tile.toggle()
    }

    Column {
        anchors.left: knob.right
        anchors.leftMargin: Theme.knobGap
        anchors.right: mode.left
        anchors.rightMargin: 6
        anchors.verticalCenter: knob.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: tile.title
            color: Theme.textPrimary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
            font.weight: Theme.fontWeightStrong
        }

        Text {
            width: parent.width
            text: tile.rpmText
            color: Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textLabel
            font.features: { "tnum": 1 }
        }
    }

    Item {
        id: mode
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: knob.verticalCenter
        width: tile.manual ? duty.implicitWidth : auto.implicitWidth
        height: tile.manual ? duty.implicitHeight : auto.implicitHeight

        TickerNumber {
            id: duty
            anchors.right: parent.right
            visible: tile.manual
            value: Math.round(tile.shownPercent)
            suffix: "%"
            motion: drag.pressed ? "none" : tile.motion
            color: Theme.textPrimary
            fontPixelSize: Theme.textLabel
            fontWeight: Font.Normal
        }

        Text {
            id: auto
            anchors.right: parent.right
            visible: !tile.manual
            text: I18n.tr("Auto")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textLabel
        }
    }

    Item {
        id: lane
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: knob.bottom
        height: tile.manual ? 22 : 0
        opacity: tile.manual ? 1 : 0

        // The setpoint as drawn: follows a drag at once, eases to anything else.
        property real shown: tile.fraction
        Behavior on shown {
            enabled: !drag.pressed
            NumberAnimation {
                duration: tile.motionDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: tile.motionDuration
                easing.type: Theme.easingFor(tile.motion)
                easing.overshoot: Theme.springOvershoot
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: tile.motionDuration
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: track
            x: 16
            width: parent.width - 32
            y: 8
            height: Theme.lineStrong
        }

        // The same ruler as a SliderTile's fader: quarter ticks, the set part inked, no thumb.
        Rectangle {
            anchors.fill: track
            radius: height / 2
            color: Theme.statusTrack
        }

        Repeater {
            model: 3

            Rectangle {
                required property int index
                x: track.x + Math.round(track.width * (index + 1) / 4)
                y: track.y + track.height + 2
                width: Theme.line
                height: 3
                color: Theme.statusTrack
            }
        }

        Rectangle {
            x: track.x
            y: track.y
            height: track.height
            radius: height / 2
            width: Math.max(height, track.width * lane.shown)
            color: Theme.textPrimary
        }

        MouseArea {
            id: drag
            anchors.fill: parent
            anchors.leftMargin: track.x - 4
            anchors.rightMargin: track.x - 4
            enabled: tile.manual && tile.controllable
            cursorShape: Qt.PointingHandCursor
            preventStealing: true
            function pick(px) {
                const f = Math.max(0, Math.min(1, (px - 4) / track.width))
                tile.dragPercent = Math.max(tile.minimum, f * 100)
                settle.restart()
                tile.percentRequested(tile.dragPercent)
            }
            onPressed: mouse => pick(mouse.x)
            onPositionChanged: mouse => { if (pressed) pick(mouse.x) }
        }
    }
}
