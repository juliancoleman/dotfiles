import QtQuick
import "../Common"
import "../Status"

Rectangle {
    id: tile

    property string motion: "easeOut"
    property string icon: ""
    property string title: ""
    property real value: 0
    property bool muted: false
    property bool toggleable: true
    property bool opens: false
    signal moved(real next)
    signal toggled()
    signal opened()

    readonly property int motionDuration: Theme.durationFor(motion)
    readonly property real shown: muted ? 0 : Math.max(0, Math.min(1, value))

    implicitHeight: 44
    radius: 12
    color: Theme.track
    border.width: activeFocus ? 1 : 0
    border.color: Theme.today
    activeFocusOnTab: visible
    Accessible.role: Accessible.Slider
    Accessible.name: title
    Accessible.description: Math.round(shown * 100) + "%"
    Keys.onLeftPressed: moved(Math.max(0, value - 0.05))
    Keys.onRightPressed: moved(Math.min(1, value + 0.05))
    Keys.onSpacePressed: if (toggleable) toggled()
    Keys.onReturnPressed: if (opens) opened()
    Keys.onEnterPressed: if (opens) opened()

    Rectangle {
        id: knob
        width: 30
        height: 30
        radius: 15
        anchors.left: parent.left
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        color: knobHit.containsMouse && tile.toggleable ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)

        StatusGlyph {
            anchors.centerIn: parent
            width: 16
            height: 16
            icon: tile.icon
            level: tile.shown
            cutColor: knob.color
        }

        MouseArea {
            id: knobHit
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            enabled: tile.toggleable
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }
    }

    Item {
        id: lane
        anchors.left: knob.right
        anchors.leftMargin: 12
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

    Text {
        id: readout
        anchors.right: tile.opens ? chevron.left : parent.right
        anchors.rightMargin: tile.opens ? 6 : 12
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        horizontalAlignment: Text.AlignRight
        text: Math.round(tile.shown * 100)
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.features: { "tnum": 1 }
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
