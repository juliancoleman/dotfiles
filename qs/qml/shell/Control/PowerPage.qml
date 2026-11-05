import QtQuick
import Quickshell
import "../Common"
import "../Status"

// Lock and Sleep act at once; Sleep locks the screen first. Restart and Shut Down, set apart below them,
// ask for a second click since open work goes with them; until then the armed action fills danger.
Item {
    id: page

    property bool active: false
    property string motion: "easeOut"
    property string armed: ""

    signal acted()

    implicitHeight: content.implicitHeight

    onActiveChanged: armed = ""

    readonly property string lockCommand: "pidof hyprlock >/dev/null || exec hyprlock"

    readonly property var gentle: [
        { id: "lock", icon: "lock", title: I18n.tr("Lock") },
        { id: "sleep", icon: "sleep", title: I18n.tr("Sleep") }
    ]
    readonly property var drastic: [
        { id: "restart", icon: "restart", title: I18n.tr("Restart"), confirm: I18n.tr("Confirm Restart") },
        { id: "shutdown", icon: "power-off", title: I18n.tr("Shut Down"), confirm: I18n.tr("Confirm Shut Down") }
    ]

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

    component Action: Tile {
        id: action
        required property var modelData
        readonly property bool isArmed: page.armed === modelData.id

        width: parent ? parent.width : 0
        motion: page.motion
        lifted: hit.containsMouse
        pressed: hit.pressed
        activeFocusOnTab: page.active && visible
        Accessible.role: Accessible.Button
        Accessible.name: isArmed ? modelData.confirm : modelData.title
        Keys.onReturnPressed: page.run(modelData)
        Keys.onEnterPressed: page.run(modelData)
        Keys.onSpacePressed: page.run(modelData)

        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.run(action.modelData)
        }

        Knob {
            id: knob
            anchors.left: parent.left
            anchors.leftMargin: Theme.knobInset
            anchors.verticalCenter: parent.verticalCenter
            motion: page.motion
            icon: action.modelData.icon
            interactive: false
        }

        // The whole row acts, so the knob is only its head; armed, a danger disc covers it.
        Rectangle {
            anchors.fill: knob
            radius: width / 2
            color: Theme.danger
            opacity: action.isArmed ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durationFor(page.motion)
                    easing.type: Easing.OutCubic
                }
            }

            StatusGlyph {
                anchors.centerIn: parent
                width: Theme.buttonIconSize
                height: width
                icon: action.modelData.icon
                ink: Theme.dangerInk
            }
        }

        Text {
            anchors.left: knob.right
            anchors.leftMargin: Theme.knobGap
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(12)
            anchors.verticalCenter: parent.verticalCenter
            text: action.isArmed ? action.modelData.confirm : action.modelData.title
            color: Theme.textPrimary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
            font.weight: action.isArmed ? Font.DemiBold : Theme.fontWeightStrong
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.tileGap

        Column {
            width: parent.width
            spacing: Theme.tileGap

            Repeater {
                model: page.gentle
                Action {}
            }
        }

        Rule { width: parent.width }

        Column {
            width: parent.width
            spacing: Theme.tileGap

            Repeater {
                model: page.drastic
                Action {}
            }
        }
    }
}
