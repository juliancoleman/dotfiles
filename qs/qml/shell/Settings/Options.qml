import QtQuick
import "../Common"

// A titled row of mutually exclusive choices; the highlight slides to the picked one.
Item {
    id: options

    property string title: ""
    property string value: ""
    property var choices: []
    signal picked(string next)
    property string motion: "spring"

    implicitHeight: Theme.px(58)
    activeFocusOnTab: visible
    Accessible.name: title
    Accessible.description: labelFor(value)

    function indexFor(selected) {
        for (var i = 0; i < choices.length; ++i) {
            if (choices[i].value === selected)
                return i
        }
        return 0
    }

    function labelFor(selected) {
        for (var i = 0; i < choices.length; ++i) {
            if (choices[i].value === selected)
                return choices[i].label
        }
        return selected
    }

    function step(delta) {
        if (!choices || choices.length === 0)
            return
        const next = indexFor(value) + delta
        if (next < 0 || next >= choices.length)
            return
        picked(choices[next].value)
    }

    Keys.onLeftPressed: step(-1)
    Keys.onRightPressed: step(1)

    Text {
        text: options.title
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textLabel
        font.letterSpacing: 1.15
        font.capitalization: Font.AllUppercase
    }

    Rectangle {
        id: track
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.px(36)
        radius: Theme.radius
        color: Theme.track
        border.width: 1
        border.color: options.activeFocus ? Theme.today : Theme.edge

        readonly property int inset: Theme.px(3)
        // Hairline between cells.
        readonly property int gap: 2
        readonly property real cell: choices.length > 0
            ? (width - 2 * inset - (choices.length - 1) * gap) / choices.length : 0

        Rectangle {
            radius: Theme.radiusInput
            x: track.inset + options.indexFor(options.value) * (track.cell + track.gap)
            y: track.inset
            width: track.cell
            height: track.height - 2 * track.inset
            color: Theme.today

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durationFor(options.motion) * 0.88
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: track.inset
            spacing: track.gap

            Repeater {
                model: options.choices

                Item {
                    id: cell
                    required property var modelData
                    width: track.cell
                    height: track.height - 2 * track.inset

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(4)
                        anchors.rightMargin: Theme.px(4)
                        text: cell.modelData.label
                        color: cell.modelData.value === options.value ? Theme.todayInk : Theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textBody
                        font.weight: cell.modelData.value === options.value ? Font.DemiBold : Font.Normal
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: options.picked(cell.modelData.value)
                    }
                }
            }
        }
    }
}
