import QtQuick
import "../Clock"
import "../Common"
import "../Status"

// Memory, CPU, disk: each a ring around its glyph with the percentage rolling beneath, like the bar.
Tile {
    id: tile

    // [{ icon, name, value }] with value as a 0..1 fraction.
    property var readings: []

    implicitHeight: Theme.knobSize + Theme.textLabel + 20
    Accessible.role: Accessible.StaticText
    Accessible.name: readings.map(r => r.name + " " + Math.round(r.value * 100) + "%").join(", ")

    Row {
        anchors.fill: parent

        Repeater {
            model: tile.readings

            Item {
                required property var modelData
                width: tile.width / Math.max(1, tile.readings.length)
                height: tile.height

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    Knob {
                        anchors.horizontalCenter: parent.horizontalCenter
                        motion: tile.motion
                        icon: modelData.icon
                        level: Math.max(0, Math.min(1, modelData.value))
                        interactive: false
                    }

                    TickerNumber {
                        anchors.horizontalCenter: parent.horizontalCenter
                        value: Math.round(modelData.value * 100)
                        suffix: "%"
                        motion: tile.motion
                        color: Theme.textSecondary
                        fontPixelSize: Theme.textLabel
                        fontWeight: Font.Normal
                    }
                }
            }
        }
    }
}
