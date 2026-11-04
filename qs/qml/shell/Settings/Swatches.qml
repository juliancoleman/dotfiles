import QtQuick
import "../Common"

// The palette as a row of circles, each named on hover. For reference only; nothing here is picked.
Item {
    id: swatchRow

    property string title: ""
    property var swatches: []
    property int hovered: -1

    implicitHeight: Theme.px(58)

    Text {
        text: swatchRow.title
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textLabel
        font.letterSpacing: 1.15
        font.capitalization: Font.AllUppercase
    }

    Text {
        anchors.right: parent.right
        text: swatchRow.hovered >= 0 ? swatchRow.swatches[swatchRow.hovered].name : ""
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textLabel
    }

    Row {
        id: circles
        anchors.bottom: parent.bottom
        width: parent.width
        height: Theme.px(36)
        readonly property int size: Theme.px(28)
        spacing: swatchRow.swatches.length > 1
            ? (width - swatchRow.swatches.length * size) / (swatchRow.swatches.length - 1) : 0

        Repeater {
            model: swatchRow.swatches

            Rectangle {
                required property var modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: circles.size
                height: circles.size
                radius: width / 2
                color: modelData.color
                border.width: 1
                border.color: swatchRow.hovered === index ? Theme.textSecondary : Theme.edge
                Accessible.role: Accessible.StaticText
                Accessible.name: modelData.name

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: swatchRow.hovered = parent.index
                    onExited: {
                        if (swatchRow.hovered === parent.index)
                            swatchRow.hovered = -1
                    }
                }
            }
        }
    }
}
