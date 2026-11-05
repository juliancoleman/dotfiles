import QtQuick
import "../Common"

// One row on the control page, with no fill of its own: the page shows through, rules or gaps between rows
// are the parent's, hover and press lay a state layer over it, and keyboard focus rings it in the accent.
Rectangle {
    id: tile

    property string motion: "easeOut"
    property bool lifted: false
    property bool pressed: false

    readonly property int motionDuration: Theme.durationFor(motion)

    implicitHeight: Theme.rowHeight
    radius: Theme.radiusInput
    color: Theme.clear
    border.width: activeFocus ? Theme.line : 0
    border.color: Theme.today

    Rectangle {
        anchors.fill: parent
        radius: tile.radius
        color: tile.pressed ? Theme.press : tile.lifted ? Theme.lift : Theme.clear

        Behavior on color {
            ColorAnimation {
                duration: tile.motionDuration * 0.56
                easing.type: Easing.OutCubic
            }
        }
    }
}
