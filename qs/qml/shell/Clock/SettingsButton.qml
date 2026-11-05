import QtQuick
import "../Common"
import "../Status"

// A bare glyph in a header. Hover lays a small box behind it, press deepens it. A toggle that is `on`
// becomes the filled accent disc a Knob uses.
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
        : hit.pressed ? Theme.press : hit.containsMouse ? Theme.lift : Theme.clear

    implicitWidth: Theme.px(24)
    implicitHeight: implicitWidth
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
        radius: button.on ? width / 2 : Theme.radiusInput
        color: button.fill
        border.width: button.activeFocus ? Theme.line : 0
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
        height: width
        icon: button.icon
        ink: button.on ? Theme.todayInk : Theme.textPrimary
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        // Reaches into the gap between neighboring header buttons, so the target outgrows the glyph.
        anchors.margins: -3
        enabled: button.opened > 0.45
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}
