import QtQuick
import "."
import "../Common"

// The close mark a panel's trigger turns into while that panel is open.
// Shared so weather, notifications and the control center draw it the same size and fade it the same way.
Item {
    id: root

    property bool shown: false
    property string motion: "easeOut"

    width: Theme.buttonIconSize
    height: Theme.buttonIconSize
    opacity: shown ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durationFor(root.motion)
            easing.type: Easing.OutCubic
        }
    }

    StatusGlyph {
        anchors.fill: parent
        icon: "close"
    }
}
