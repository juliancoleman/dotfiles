import QtQuick
import "../Common"

// A setting that is only on or off: its title written on a ruled line, a switch at the end. The whole row
// flips it. Off is an unfilled track in the pen's line with a graphite thumb; on fills the track in `today`
// with the thumb in `todayInk`, the same pair an "on" knob uses.
Item {
    id: toggle

    property string title: ""
    property bool on: false
    property string motion: "spring"
    signal toggled()

    readonly property real trackWidth: Theme.px(36)
    readonly property real trackHeight: Theme.px(20)
    readonly property real thumbInset: Theme.px(3)

    implicitHeight: Theme.px(40)
    activeFocusOnTab: visible
    Accessible.role: Accessible.CheckBox
    Accessible.name: title
    Accessible.checkable: true
    Accessible.checked: on
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: toggled()
    Keys.onEnterPressed: toggled()

    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: Theme.line
        radius: Theme.radiusInput
        // Fade the layer's alpha only; animating from "transparent" (black) passes through gray.
        color: hit.pressed ? Theme.press : hit.containsMouse ? Theme.lift : Theme.clear
        border.width: toggle.activeFocus ? Theme.line : 0
        border.color: Theme.today

        Behavior on color {
            Settle {
                motion: toggle.motion
                factor: Theme.hoverFade
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: Theme.px(4)
        anchors.right: track.left
        anchors.rightMargin: Theme.px(8)
        anchors.verticalCenter: parent.verticalCenter
        text: toggle.title
        elide: Text.ElideRight
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textBody
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.rightMargin: Theme.px(4)
        anchors.verticalCenter: parent.verticalCenter
        width: toggle.trackWidth
        height: toggle.trackHeight
        radius: height / 2
        color: toggle.on ? Theme.today : Theme.clear
        border.width: toggle.on ? 0 : Theme.line
        border.color: Theme.stroke

        Behavior on color {
            Settle {
                motion: toggle.motion
            }
        }

        Rectangle {
            readonly property real size: track.height - toggle.thumbInset * 2
            width: size
            height: size
            radius: size / 2
            y: toggle.thumbInset
            x: toggle.on ? track.width - size - toggle.thumbInset : toggle.thumbInset
            color: toggle.on ? Theme.todayInk : Theme.textSecondary

            Behavior on x {
                Move {
                    motion: toggle.motion
                }
            }
            Behavior on color {
                Settle {
                    motion: toggle.motion
                }
            }
        }
    }

    Rule {
        anchors.bottom: parent.bottom
        width: parent.width
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
