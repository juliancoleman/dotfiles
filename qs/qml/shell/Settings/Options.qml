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

    implicitHeight: 58
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
        font.pixelSize: 11
        font.letterSpacing: 1.15
        font.capitalization: Font.AllUppercase
    }

    Rectangle {
        id: track
        anchors.bottom: parent.bottom
        width: parent.width
        height: 36
        radius: 12
        color: Theme.track
        border.width: 1
        border.color: options.activeFocus ? Theme.today : Qt.rgba(1, 1, 1, 0.05)

        readonly property real cell: choices.length > 0
            ? (width - 6 - (choices.length - 1) * 2) / choices.length : 0

        Rectangle {
            radius: 9
            x: 3 + options.indexFor(options.value) * (track.cell + 2)
            y: 3
            width: track.cell
            height: track.height - 6
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
            anchors.margins: 3
            spacing: 2

            Repeater {
                model: options.choices

                Item {
                    id: cell
                    required property var modelData
                    width: track.cell
                    height: 30

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        anchors.rightMargin: 4
                        text: cell.modelData.label
                        color: cell.modelData.value === options.value ? Theme.todayInk : Theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
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
