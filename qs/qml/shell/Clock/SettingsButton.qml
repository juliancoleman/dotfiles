import QtQuick
import "../Common"
import "../Status"

Item {
    id: button

    property real opened: 1
    property string icon: "settings"
    property string label: I18n.tr("Settings")
    property bool toggle: false
    property bool on: false
    signal activated()
    property string motion: "spring"

    readonly property color fill: on ? Theme.today
        : hit.containsMouse || activeFocus ? Theme.track : Theme.surface

    implicitWidth: Theme.px(24)
    implicitHeight: Theme.px(24)
    opacity: Math.max(opened, activeFocus ? 1 : 0)
    activeFocusOnTab: opened > 0.85
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.checkable: toggle
    Accessible.checked: on
    Accessible.onPressAction: activated()
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: button.fill
        border.width: button.activeFocus ? 1 : 0
        border.color: button.on ? Theme.textPrimary : Theme.today

        Behavior on color {
            ColorAnimation {
                duration: Theme.durationFor(button.motion) * 0.56
                easing.type: Easing.OutCubic
            }
        }
    }

    StatusGlyph {
        anchors.centerIn: parent
        width: Theme.buttonIconSize
        height: Theme.buttonIconSize
        icon: button.icon
        ink: button.on ? Theme.todayInk : Theme.textPrimary
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        enabled: button.opened > 0.45
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}
