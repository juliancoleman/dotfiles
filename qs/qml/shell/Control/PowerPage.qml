import QtQuick
import Quickshell
import "../Common"
import "../Status"

// Lock and Sleep act at once; Sleep locks the screen first. Restart and Shut Down ask for a second click,
// since open work goes with them.
Item {
    id: page

    property bool active: false
    property string motion: "easeOut"
    property string armed: ""

    signal acted()

    implicitHeight: row.implicitHeight

    onActiveChanged: armed = ""

    readonly property string lockCommand: "pidof hyprlock >/dev/null || exec hyprlock"

    function run(action) {
        if (action.confirm && armed !== action.id) {
            armed = action.id
            return
        }
        armed = ""
        acted()
        switch (action.id) {
        case "lock":
            Quickshell.execDetached(["sh", "-c", lockCommand])
            break
        case "sleep":
            Quickshell.execDetached(["sh", "-c", "(" + lockCommand + ") & sleep 1; exec systemctl suspend"])
            break
        case "restart":
            Quickshell.execDetached(["systemctl", "reboot"])
            break
        case "shutdown":
            Quickshell.execDetached(["systemctl", "poweroff"])
            break
        }
    }

    // A tile asking for confirmation takes the whole row; the others fold away beside it.
    Item {
        id: row
        readonly property real spacing: 6
        readonly property real unit: width + spacing
        width: parent.width
        implicitHeight: 64

        Repeater {
            id: tiles
            model: [
                { id: "lock", icon: "lock", title: I18n.tr("Lock") },
                { id: "sleep", icon: "sleep", title: I18n.tr("Sleep") },
                { id: "restart", icon: "restart", title: I18n.tr("Restart"), confirm: I18n.tr("Confirm Restart") },
                { id: "shutdown", icon: "power-off", title: I18n.tr("Shut Down"), confirm: I18n.tr("Confirm Shut Down") }
            ]

            Rectangle {
                id: tile
                required property var modelData
                required property int index
                readonly property bool isArmed: page.armed === modelData.id
                property real share: page.armed === "" ? 1 / tiles.model.length : isArmed ? 1 : 0
                Behavior on share {
                    NumberAnimation {
                        duration: Theme.durationFor(page.motion)
                        easing.type: Theme.easingFor(page.motion)
                        easing.overshoot: Theme.springOvershoot
                    }
                }
                readonly property Item previous: index > 0 && tiles.count > index ? tiles.itemAt(index - 1) : null
                x: previous ? previous.x + Math.max(0, previous.share) * row.unit : 0
                width: Math.max(0, share * row.unit - row.spacing)
                height: row.height
                visible: width > 0.5
                opacity: Math.min(1, share * tiles.model.length)
                clip: true
                radius: 12
                color: Qt.lighter(Theme.track, hit.containsMouse || activeFocus ? 1.35 : 1)
                border.width: isArmed || activeFocus ? 1 : 0
                border.color: Theme.today
                activeFocusOnTab: page.active
                Accessible.role: Accessible.Button
                Accessible.name: modelData.title
                Keys.onReturnPressed: page.run(modelData)
                Keys.onSpacePressed: page.run(modelData)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFor(page.motion) * 0.56
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 6

                    StatusGlyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 18
                        height: 18
                        icon: tile.modelData.icon
                        ink: tile.isArmed ? Theme.today : Theme.textPrimary
                        cutColor: tile.color
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.isArmed ? tile.modelData.confirm : tile.modelData.title
                        color: tile.isArmed ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: hit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.run(tile.modelData)
                }
            }
        }
    }
}
