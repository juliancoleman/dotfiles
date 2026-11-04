import QtQuick
import "../Common"
import "../Clock"

// A titled number nudged by fixed steps between bounds; `readout` is how the caller writes the value.
Item {
    id: field

    property string title: ""
    property string readout: ""
    property string suffix: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 1
    property real step: 1
    property int decimals: 0
    property string motion: "easeOut"
    signal edited(real next)

    readonly property int inset: Theme.px(3)

    implicitHeight: Theme.px(58)
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
        font.pixelSize: Theme.textLabel
        font.letterSpacing: 1.15
        font.capitalization: Font.AllUppercase
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.px(36)
        radius: Theme.radius
        color: Theme.track
        border.width: 1
        border.color: field.activeFocus ? Theme.today : Theme.edge

        // Whole numbers roll on the clock's tickers; the ticker has no fraction column, so decimals stay text.
        TickerNumber {
            anchors.centerIn: parent
            visible: field.decimals === 0
            value: field.decimals === 0 ? field.value : NaN
            suffix: field.suffix
            motion: field.motion
            color: Theme.textPrimary
            fontPixelSize: Theme.textStrong
            fontWeight: Font.Medium
        }

        Text {
            anchors.centerIn: parent
            visible: field.decimals > 0
            text: field.readout
            color: Theme.textPrimary
            font.family: Theme.latinFontFamily
            font.pixelSize: Theme.textStrong
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }

        Repeater {
            model: [
                { label: "−", direction: -1, side: "left" },
                { label: "+", direction: 1, side: "right" }
            ]

            Rectangle {
                required property var modelData
                width: Theme.px(36)
                height: parent.height - 2 * field.inset
                radius: Theme.radiusInput
                x: modelData.side === "left" ? field.inset : parent.width - width - field.inset
                y: field.inset
                color: pressed.pressed ? Theme.knobFill
                     : pressed.containsMouse ? Theme.lift : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textTitle
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
