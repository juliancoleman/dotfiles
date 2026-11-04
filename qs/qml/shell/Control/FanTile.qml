import QtQuick
import "../Common"
import "../Status"

// One controllable fan: the knob flips Auto/Manual; Manual reveals a duty slider.
Rectangle {
    id: tile

    property string motion: "easeOut"
    property string title: ""
    property string rpmText: ""
    property bool manual: false
    property bool controllable: true
    property real percent: 0
    property real minimum: 0
    signal autoRequested()
    signal percentRequested(real next)

    readonly property int motionDuration: Theme.durationFor(motion)
    property real dragPercent: -1
    readonly property real shownPercent: dragPercent >= 0 ? dragPercent : percent
    readonly property real fraction: Math.max(0, Math.min(1, shownPercent / 100))

    implicitHeight: 44 + lane.height
    radius: 12
    color: Theme.track
    clip: true
    border.width: activeFocus ? 1 : 0
    border.color: Theme.today
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

    Rectangle {
        id: knob
        x: 7
        y: 7
        width: 30
        height: 30
        radius: 15
        color: tile.manual ? Theme.today
             : knobHit.containsMouse && tile.controllable ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)

        Behavior on color {
            ColorAnimation {
                duration: tile.motionDuration
                easing.type: Easing.OutCubic
            }
        }

        StatusGlyph {
            anchors.centerIn: parent
            width: 16
            height: 16
            icon: "fan"
            ink: tile.manual ? Theme.todayInk : Theme.textPrimary
            cutColor: knob.color
        }

        MouseArea {
            id: knobHit
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            enabled: tile.controllable
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggle()
        }
    }

    Column {
        anchors.left: knob.right
        anchors.leftMargin: 9
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
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            text: tile.rpmText
            color: Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
    }

    Text {
        id: mode
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: knob.verticalCenter
        text: tile.manual ? Math.round(tile.shownPercent) + "%" : I18n.tr("Auto")
        color: tile.manual ? Theme.textPrimary : Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.features: { "tnum": 1 }
    }

    Item {
        id: lane
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: knob.bottom
        height: tile.manual ? 22 : 0
        opacity: tile.manual ? 1 : 0

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

        Rectangle {
            id: track
            x: 16
            width: parent.width - 32
            y: 9
            height: 3
            radius: 1.5
            color: Theme.statusTrack
        }

        Rectangle {
            x: track.x
            y: track.y
            height: 3
            radius: 1.5
            width: Math.max(height, track.width * tile.fraction)
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
