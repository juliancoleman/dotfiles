import QtQuick

// The line a text input is written on: the pen's underline, heavier ink while focused. Put it behind the
// input, filling the field's box; the line sits on its bottom edge.
Item {
    id: field

    property bool focused: false
    property string motion: "easeOut"

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: field.focused ? Theme.lineStrong : Theme.line
        color: field.focused ? Theme.today : Theme.rule

        Behavior on color {
            Settle {
                motion: field.motion
                factor: Theme.hoverFade
            }
        }
    }
}
