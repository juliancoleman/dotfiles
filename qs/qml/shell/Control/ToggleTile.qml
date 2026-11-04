import QtQuick
import "../Common"
import "../Status"

// Knob kills or revives the whole function in one click; the row opens its page.
Tile {
    id: tile

    property string icon: ""
    property int wifiBars: 3
    property string title: ""
    property string subtitle: ""
    property bool on: false
    property bool toggleable: true
    property bool opens: true
    signal toggled()
    signal opened()

    lifted: body.containsMouse && body.enabled
    activeFocusOnTab: visible && (opens || toggleable)
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: subtitle
    Keys.onReturnPressed: opens ? opened() : toggled()
    Keys.onEnterPressed: opens ? opened() : toggled()
    Keys.onSpacePressed: toggleable ? toggled() : opened()

    MouseArea {
        id: body
        anchors.fill: parent
        hoverEnabled: true
        enabled: tile.opens || tile.toggleable
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.opens ? tile.opened() : tile.toggled()
    }

    Knob {
        id: knob
        anchors.left: parent.left
        anchors.leftMargin: Theme.knobInset
        anchors.verticalCenter: parent.verticalCenter
        motion: tile.motion
        icon: tile.icon
        wifiBars: tile.wifiBars
        on: tile.on
        interactive: tile.toggleable
        onClicked: tile.toggled()
    }

    Column {
        anchors.left: knob.right
        anchors.leftMargin: Theme.knobGap
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
            font.pixelSize: Theme.textBody
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            text: tile.subtitle
            visible: text !== ""
            color: Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textLabel
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
