import QtQuick
import "../Common"
import "../Status"

// One entry in a list: a glyph, a title over a subtitle, a trailing mark.
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
    // Optional glyph buttons left of the trailing mark, each `{ id, icon, label }`; their own clicks, not the
    // row's.
    property var actions: []
    signal actionTriggered(string id)
    property string motion: "spring"

    implicitHeight: Theme.px(40)
    radius: Theme.radiusInput
    // Fade the layer's alpha only; animating from "transparent" (black) passes through gray.
    color: hit.pressed ? Theme.press : hit.containsMouse || activeFocus ? Theme.lift : Theme.clear
    border.width: activeFocus ? Theme.line : 0
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
        anchors.leftMargin: Theme.px(10)
        anchors.verticalCenter: parent.verticalCenter
        visible: row.icon !== ""
        width: row.icon !== "" ? Theme.px(16) : 0
        height: Theme.px(16)
        icon: row.icon
        wifiBars: row.wifiBars
        ink: row.current ? Theme.today : Theme.textPrimary
    }

    Column {
        anchors.left: glyph.right
        anchors.leftMargin: row.icon !== "" ? Theme.px(10) : 0
        anchors.right: actionRow.visible ? actionRow.left : mark.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: row.title
            color: Theme.textPrimary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
            font.weight: row.current ? Theme.fontWeightStrong : Font.Normal
        }

        Text {
            width: parent.width
            text: row.subtitle
            visible: text !== ""
            color: Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textCaption
        }
    }

    Row {
        id: actionRow
        anchors.right: mark.left
        anchors.rightMargin: row.trailing !== "" ? Theme.px(6) : 0
        anchors.verticalCenter: parent.verticalCenter
        visible: row.actions.length > 0

        Repeater {
            model: row.actions

            Rectangle {
                id: actionButton
                required property var modelData
                width: Theme.px(26)
                height: Theme.px(26)
                radius: Theme.radiusInput
                color: actionHit.pressed ? Theme.press : actionHit.containsMouse ? Theme.lift : Theme.clear
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label

                StatusGlyph {
                    anchors.centerIn: parent
                    width: Theme.px(12)
                    height: Theme.px(12)
                    icon: actionButton.modelData.icon
                    ink: actionHit.containsMouse ? Theme.textPrimary : Theme.textSecondary
                }

                MouseArea {
                    id: actionHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.actionTriggered(actionButton.modelData.id)
                }
            }
        }
    }

    StatusGlyph {
        id: mark
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(10)
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
