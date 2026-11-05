import QtQuick

// The line a text input is written on: the pen's underline, heavier ink while focused. Put it behind the
// input, filling the field's box; the line sits on its bottom edge.
Item {
    id: field

    property bool focused: false
    property string motion: "easeOut"

    readonly property int fade: Theme.durationFor(motion) * 0.56

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: field.focused ? Theme.lineStrong : Theme.line
        color: field.focused ? Theme.today : Theme.rule

        Behavior on color {
            ColorAnimation {
                duration: field.fade
                easing.type: Easing.OutCubic
            }
        }
    }
}
