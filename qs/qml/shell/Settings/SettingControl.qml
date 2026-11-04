import QtQuick
import "../Common"
import "../Weather"

// One SettingsModel control, drawn by its kind. Hidden while it doesn't apply, so a page's column closes up.
Loader {
    id: row

    required property var control
    readonly property string key: control.key

    visible: SettingsModel.shown(key)
    sourceComponent: {
        switch (SettingsModel.kindOf(control)) {
        case "stepper":
            return stepperRow
        case "palette":
            return paletteRow
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
            title: row.control.title
            choices: row.control.choices
            value: SettingsModel.value(row.key)
            onPicked: next => SettingsModel.apply(row.key, next)
        }
    }

    Component {
        id: stepperRow

        Stepper {
            title: row.control.title
            readout: SettingsModel.valueLabel(row.control)
            value: SettingsModel.value(row.key)
            minimum: row.control.minimum
            maximum: row.control.maximum
            step: row.control.step
            decimals: row.control.decimals
            onEdited: next => SettingsModel.apply(row.key, next)
        }
    }

    Component {
        id: paletteRow

        Swatches {
            title: row.control.title
            swatches: Theme.palette
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
            font.pixelSize: 12
        }
    }
}
