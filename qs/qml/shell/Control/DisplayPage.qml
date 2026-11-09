import QtQuick
import ".."
import "../Common"
import "../Settings"
import "../Status"

// The panel's brightness and whether it follows the room, then the refresh rates each output offers.
Item {
    id: page

    property string motion: "easeOut"
    property bool active: false
    readonly property real maxListHeight: 240
    // Outputs with a choice to make.
    readonly property var outputs: Displays.outputs.filter(output => output.rates.length > 1)

    implicitHeight: content.implicitHeight

    // Asked again each visit, since niri's own config or a hotplug can change modes behind the shell.
    onActiveChanged: if (active) Displays.refresh()

    Column {
        id: content
        width: parent.width
        spacing: Theme.tileGap

        SliderTile {
            width: parent.width
            motion: page.motion
            visible: Brightness.available
            title: I18n.tr("Brightness")
            icon: "brightness"
            toggleable: false
            adjustable: !AutoBrightness.active
            value: Brightness.level
            onMoved: next => Brightness.set(next)
        }

        Toggle {
            width: parent.width
            motion: page.motion
            visible: AutoBrightness.available
            title: I18n.tr("Auto-brightness")
            on: ClockConfig.autoBrightness
            onToggled: {
                ClockConfig.autoBrightness = !ClockConfig.autoBrightness
                ClockConfig.save()
            }
        }

        // Settings → Display's own control, so the key is defined once.
        SettingControl {
            width: parent.width
            motion: page.motion
            control: SettingsModel.controls.screenOff
        }

        Repeater {
            model: page.outputs

            Column {
                id: rates
                required property var modelData
                width: content.width
                spacing: Theme.px(4)

                SectionHeader {
                    width: parent.width
                    text: page.outputs.length > 1 ? I18n.tr("Refresh rate · %1").arg(rates.modelData.name)
                        : I18n.tr("Refresh rate")
                }

                ListGroup {
                    width: parent.width
                    maxHeight: page.maxListHeight

                    Repeater {
                        model: rates.modelData.rates

                        ListRow {
                            required property var modelData
                            width: parent.width
                            motion: page.motion
                            title: I18n.tr("%1 Hz").arg(Displays.hertz(modelData))
                            current: modelData === rates.modelData.current
                            trailing: current ? "check" : ""
                            onActivated: Displays.setRate(rates.modelData.name, modelData)
                        }
                    }
                }
            }
        }
    }
}
