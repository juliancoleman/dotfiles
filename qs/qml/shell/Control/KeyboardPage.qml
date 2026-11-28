import QtQuick
import "../Common"
import "../Settings"
import "../Status"

// The keys' backlight: its level, whether it waits for low light, and how long it outlasts the last input.
Item {
    id: page

    property string motion: "easeOut"

    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: Theme.tileGap

        SliderTile {
            width: parent.width
            motion: page.motion
            title: I18n.tr("Keyboard brightness")
            icon: "keyboard"
            toggleable: false
            value: KeyboardBacklight.level
            onMoved: next => KeyboardBacklight.set(next)
        }

        // Defined with the other settings, so the launcher finds them; this page is the one place they show.
        SettingControl {
            width: parent.width
            motion: page.motion
            control: SettingsModel.controls.keyboardAdaptive
        }

        SettingControl {
            width: parent.width
            motion: page.motion
            control: SettingsModel.controls.keyboardOffAfter
        }
    }
}
