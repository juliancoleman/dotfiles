import QtQuick
import "../Common"
import "../Status"

Rectangle {
    id: row

    property string icon: ""
    property int wifiBars: 3
    property string title: ""
    property string subtitle: ""
    property string trailing: ""
    property bool current: false
    property bool busy: false
    signal activated()
    property string motion: "spring"

    implicitHeight: 40
    radius: 10
    // Fade white's alpha only; animating from "transparent" (black) passes through grey.
    color: Qt.rgba(1, 1, 1, hit.containsMouse || activeFocus ? 0.05 : 0)
    border.width: activeFocus ? 1 : 0
    border.color: Theme.today
    activeFocusOnTab: visible
    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: subtitle
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()

    Behavior on color {
        ColorAnimation {
            duration: Theme.durationFor(row.motion) * 0.56
            easing.type: Easing.OutCubic
        }
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.activated()
    }

    // Rows without an icon start their text where the icon would.
    StatusGlyph {
        id: glyph
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: row.icon !== ""
        width: row.icon !== "" ? 16 : 0
        height: 16
        icon: row.icon
        wifiBars: row.wifiBars
        ink: row.current ? Theme.today : Theme.textPrimary
        cutColor: Theme.track
    }

    Column {
        anchors.left: glyph.right
        anchors.leftMargin: row.icon !== "" ? 10 : 0
        anchors.right: mark.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.title
            color: Theme.textPrimary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: row.current ? Font.Medium : Font.Normal
        }

        Text {
            width: parent.width
            text: row.subtitle
            visible: text !== ""
            color: Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    StatusGlyph {
        id: mark
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: row.trailing !== "" ? 14 : 0
        height: 14
        visible: row.trailing !== ""
        icon: row.trailing
        ink: row.trailing === "check" ? Theme.today : Theme.textSecondary
        opacity: row.busy ? 0.4 + 0.6 * pulse.value : 1

        QtObject {
            id: pulse
            property real value: 1
        }

        SequentialAnimation {
            running: row.busy
            loops: Animation.Infinite
            onStopped: pulse.value = 1
            NumberAnimation { target: pulse; property: "value"; from: 1; to: 0; duration: 500; easing.type: Easing.InOutSine }
            NumberAnimation { target: pulse; property: "value"; from: 0; to: 1; duration: 500; easing.type: Easing.InOutSine }
        }
    }
}
