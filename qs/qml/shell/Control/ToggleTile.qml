import QtQuick
import "../Common"
import "../Status"

Rectangle {
    id: tile

    property string motion: "easeOut"
    property string icon: ""
    property int wifiBars: 3
    property string title: ""
    property string subtitle: ""
    property bool on: false
    property bool toggleable: true
    property bool opens: true
    signal toggled()
    signal opened()

    readonly property int motionDuration: Theme.durationFor(motion)

    implicitHeight: 44
    radius: 12
    color: body.containsMouse && body.enabled ? Qt.tint(Theme.track, Qt.rgba(1, 1, 1, 0.04)) : Theme.track
    border.width: activeFocus ? 1 : 0
    border.color: Theme.today
    activeFocusOnTab: visible && (opens || toggleable)
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: subtitle
    Keys.onReturnPressed: opens ? opened() : toggled()
    Keys.onEnterPressed: opens ? opened() : toggled()
    Keys.onSpacePressed: toggleable ? toggled() : opened()

    Behavior on color {
        ColorAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.opens || tile.toggleable
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.opens ? tile.opened() : tile.toggled()
    }

    Rectangle {
        id: knob
        width: 30
        height: 30
        radius: 15
        anchors.left: parent.left
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        color: tile.on ? Theme.today
             : knobHit.containsMouse && tile.toggleable ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)

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
            icon: tile.icon
            wifiBars: tile.wifiBars
            ink: tile.on ? Theme.todayInk : Theme.textPrimary
            dim: tile.on ? Qt.rgba(0.11, 0.12, 0.17, 0.35) : Theme.statusDim
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

    Column {
        anchors.left: knob.right
        anchors.leftMargin: 9
        anchors.right: chevron.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
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
            text: tile.subtitle
            visible: text !== ""
            color: Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }

    StatusGlyph {
        id: chevron
        visible: tile.opens
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: tile.opens ? 12 : 0
        height: 12
        icon: "chevron-right"
        ink: Theme.textSecondary
    }
}
