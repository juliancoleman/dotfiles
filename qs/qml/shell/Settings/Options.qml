import QtQuick
import "../Common"

// A titled row of mutually exclusive choices written on a ruled line: cells split by hairlines, the
// picked one set in primary text and underlined in ink, the underline sliding to the next pick.
Item {
    id: options

    property string title: ""
    property string value: ""
    property var choices: []
    signal picked(string next)
    property string motion: "spring"

    readonly property int fade: Theme.durationFor(motion) * 0.56

    implicitHeight: Theme.px(58)
    activeFocusOnTab: visible
    Accessible.role: Accessible.PageTabList
    Accessible.name: title
    Accessible.description: labelFor(value)

    function indexOf(selected) {
        for (var i = 0; i < choices.length; ++i) {
            if (choices[i].value === selected)
                return i
        }
        return -1
    }

    function indexFor(selected) {
        return Math.max(0, indexOf(selected))
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
        anchors.left: parent.left
        anchors.right: parent.right
        text: options.title
        elide: Text.ElideRight
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
        font.weight: Font.Normal
    }

    // The ruled line.
    Item {
        id: line
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.px(36)

        // One hairline between cells; the cells share what is left.
        readonly property real cell: choices.length > 0 ? (width - (choices.length - 1) * Theme.line) / choices.length : 0
        readonly property real chosenX: options.indexFor(options.value) * (cell + Theme.line)

        Rule {
            anchors.bottom: parent.bottom
            width: parent.width
        }

        Row {
            anchors.fill: parent

            Repeater {
                model: options.choices

                Row {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property bool chosen: modelData.value === options.value

                    Rule {
                        vertical: true
                        visible: slot.index > 0
                        height: Theme.px(16)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: line.cell
                        height: line.height
                        radius: Theme.radiusInput
                        // Fade the layer's alpha only; animating from "transparent" (black) passes through gray.
                        color: hit.pressed ? Theme.press : hit.containsMouse ? Theme.lift : Theme.clear
                        border.width: slot.chosen && options.activeFocus ? Theme.line : 0
                        border.color: Theme.today

                        Behavior on color {
                            ColorAnimation {
                                duration: options.fade
                                easing.type: Easing.OutCubic
                            }
                        }

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(4)
                            anchors.rightMargin: Theme.px(4)
                            text: slot.modelData.label
                            color: slot.chosen ? Theme.textPrimary : Theme.textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textBody
                            font.weight: slot.chosen ? Font.Medium : Font.Normal
                        }

                        MouseArea {
                            id: hit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: options.picked(slot.modelData.value)
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            x: line.chosenX
            width: line.cell
            height: Theme.lineStrong
            visible: options.choices.length > 0
            color: Theme.today

            Behavior on x {
                NumberAnimation {
                    duration: Theme.durationFor(options.motion) * 0.88
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
