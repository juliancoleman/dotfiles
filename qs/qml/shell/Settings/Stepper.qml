import QtQuick
import "../Common"

// A titled number nudged by fixed steps between bounds; `readout` is how the caller writes the value.
Item {
    id: field

    property string title: ""
    property string readout: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 1
    property int decimals: 0
    signal edited(real next)

    implicitHeight: 58
    activeFocusOnTab: visible
    Accessible.role: Accessible.Slider
    Accessible.name: title
    Accessible.description: readout

    function nudge(direction) {
        const places = Math.pow(10, decimals)
        const raw = Math.round((value + direction * step) * places) / places
        const next = Math.max(minimum, Math.min(maximum, raw))
        if (next !== value)
            edited(next)
    }

    Keys.onLeftPressed: nudge(-1)
    Keys.onRightPressed: nudge(1)

    Text {
        text: field.title
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 1.15
        font.capitalization: Font.AllUppercase
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 36
        radius: 12
        color: Theme.track
        border.width: 1
        border.color: field.activeFocus ? Theme.today : Qt.rgba(1, 1, 1, 0.05)

        Text {
            anchors.centerIn: parent
            text: field.readout
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        Repeater {
            model: [
                { label: "−", direction: -1, side: "left" },
                { label: "+", direction: 1, side: "right" }
            ]

            Rectangle {
                required property var modelData
                width: 36
                height: 30
                radius: 9
                x: modelData.side === "left" ? 3 : parent.width - width - 3
                y: 3
                color: pressed.pressed ? Qt.rgba(1, 1, 1, 0.08)
                     : pressed.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 18
                }

                MouseArea {
                    id: pressed
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: field.nudge(parent.modelData.direction)
                }
            }
        }
    }
}
