import QtQuick
import "../Common"
import "../Status"

Rectangle {
    id: tile

    // [{ icon, name, value }] with value as a 0..1 fraction.
    property var readings: []

    implicitHeight: 56
    radius: 12
    color: Theme.track
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
                    spacing: 5

                    StatusGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 16
                        height: 16
                        icon: modelData.icon
                        cutColor: tile.color
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Math.round(modelData.value * 100) + "%"
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
