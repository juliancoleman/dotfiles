import QtQuick
import "../Common"

// One flat container in the control grid: a single fill, a hairline edge, and the accent edge on focus.
Rectangle {
    id: tile

    property string motion: "easeOut"
    property bool lifted: false

    readonly property int motionDuration: Theme.durationFor(motion)

    implicitHeight: Theme.rowHeight
    radius: Theme.radius
    color: lifted ? Qt.tint(Theme.track, Theme.lift) : Theme.track
    border.width: 1
    border.color: activeFocus ? Theme.today : Theme.edge

    Behavior on color {
        ColorAnimation {
            duration: tile.motionDuration * 0.56
            easing.type: Easing.OutCubic
        }
    }
}
