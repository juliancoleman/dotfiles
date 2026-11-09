import QtQuick
import "../Common"
import "../Weather"

// One SettingsModel control, drawn by its kind. Hidden while it doesn't apply, so a page's column closes up.
// The model's English sources are translated here, on their way into the generic rows.
Loader {
    id: row

    required property var control
    readonly property string key: control.key
    property string motion: "easeOut"

    visible: SettingsModel.shown(key)
    sourceComponent: {
        switch (SettingsModel.kindOf(control)) {
        case "toggle":
            return toggleRow
        case "stepper":
            return stepperRow
        case "location":
            return placeRow
        case "note":
            return noteRow
        default:
            return choiceRow
        }
    }

    Component {
        id: choiceRow

        Options {
            title: I18n.tr(row.control.title)
            choices: row.control.choices.map(choice => ({ label: I18n.tr(choice.label), value: choice.value }))
            motion: row.motion
            value: SettingsModel.value(row.key)
            onPicked: next => SettingsModel.apply(row.key, next)
        }
    }

    Component {
        id: toggleRow

        Toggle {
            title: I18n.tr(row.control.title)
            motion: row.motion
            on: SettingsModel.value(row.key)
            onToggled: SettingsModel.apply(row.key, !on)
        }
    }

    Component {
        id: stepperRow

        Stepper {
            title: I18n.tr(row.control.title)
            readout: SettingsModel.valueLabel(row.control)
            suffix: row.control.suffix
            motion: row.motion
            value: SettingsModel.value(row.key)
            minimum: row.control.minimum
            maximum: row.control.maximum
            step: row.control.step
            decimals: row.control.decimals
            onEdited: next => SettingsModel.apply(row.key, next)
        }
    }

    Component {
        id: placeRow

        LocationPicker {}
    }

    Component {
        id: noteRow

        Text {
            wrapMode: Text.WordWrap
            text: SettingsModel.note(row.key)
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
        }
    }
}
