import QtQuick
import "../Common"
import "../Settings"

// One DualSense's lightbar: on/off and brightness, the effect, the color it shows, and how fast it moves.
Item {
    id: page

    property var device: null
    property string motion: "easeOut"

    readonly property string address: device ? device.address : ""
    readonly property var setting: DualSenseLights.settings(address)
    readonly property bool tinted: setting.mode === "solid" || setting.mode === "breathe"
    readonly property bool moving: setting.mode !== "solid"
    readonly property bool present: !!device && device.connected && DualSenseLights.available(address)
    readonly property color chosen: setting.color

    function set(change) {
        DualSenseLights.update(address, change)
    }

    function pickHue(fraction) {
        const hue = Math.max(0, Math.min(0.999, fraction))
        set({ color: Qt.hsva(hue, 1, 1, 1).toString(), on: true })
    }

    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: Theme.tileGap

        SliderTile {
            width: parent.width
            motion: page.motion
            enabled: page.present
            icon: "brightness"
            title: I18n.tr("Brightness")
            value: page.setting.brightness
            muted: !page.setting.on
            onMoved: next => page.set({ brightness: next, on: true })
            onToggled: page.set({ on: !page.setting.on })
        }

        Options {
            width: parent.width
            motion: page.motion
            enabled: page.present
            title: I18n.tr("Effect")
            value: page.setting.mode
            choices: [
                { value: "solid", label: I18n.tr("Solid") },
                { value: "breathe", label: I18n.tr("Breathe") },
                { value: "fade", label: I18n.tr("Fade") },
                { value: "rainbow", label: I18n.tr("Rainbow") }
            ]
            onPicked: next => page.set({ mode: next, on: true })
        }

        // The swatches and the spectrum show the light itself, so they're the one place a panel shows raw color.
        Item {
            id: colors
            width: parent.width
            visible: page.tinted
            enabled: page.present
            implicitHeight: spectrumLane.y + spectrumLane.height + Theme.px(4)

            Text {
                id: caption
                width: parent.width
                text: I18n.tr("Color")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textCaption
            }

            Row {
                id: swatches
                y: caption.height + Theme.px(6)
                width: parent.width
                height: Theme.px(26)
                readonly property real cell: width / DualSenseLights.palette.length

                Repeater {
                    model: DualSenseLights.palette

                    Item {
                        id: swatch
                        required property string modelData
                        readonly property bool picked: page.setting.color === modelData
                        width: swatches.cell
                        height: swatches.height
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData

                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.px(26)
                            height: width
                            radius: width / 2
                            color: Theme.clear
                            border.width: Theme.lineStrong
                            border.color: Theme.textPrimary
                            opacity: swatch.picked ? 1 : swatchHit.containsMouse ? 0.35 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durationFor(page.motion) * 0.56
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: Theme.px(18)
                            height: width
                            radius: width / 2
                            color: swatch.modelData
                            border.width: Theme.line
                            border.color: Theme.edge
                        }

                        MouseArea {
                            id: swatchHit
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.set({ color: swatch.modelData, on: true })
                        }
                    }
                }
            }

            // Any hue at full strength; drag along it to sweep the light.
            Item {
                id: spectrumLane
                y: swatches.y + swatches.height + Theme.px(10)
                width: parent.width
                height: Theme.px(16)
                Accessible.role: Accessible.Slider
                Accessible.name: I18n.tr("Hue")

                Rectangle {
                    id: spectrum
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.px(4)
                    width: parent.width - Theme.px(8)
                    height: Theme.px(6)
                    radius: height / 2

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#ff0000" }
                        GradientStop { position: 1 / 6; color: "#ffff00" }
                        GradientStop { position: 2 / 6; color: "#00ff00" }
                        GradientStop { position: 3 / 6; color: "#00ffff" }
                        GradientStop { position: 4 / 6; color: "#0000ff" }
                        GradientStop { position: 5 / 6; color: "#ff00ff" }
                        GradientStop { position: 1; color: "#ff0000" }
                    }
                }

                // Marks the chosen color's hue when it has one (not white).
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: spectrum.x + page.chosen.hsvHue * spectrum.width - width / 2
                    width: Theme.px(4)
                    height: parent.height
                    radius: width / 2
                    visible: page.chosen.hsvSaturation > 0.2 && page.chosen.hsvHue >= 0
                    color: Theme.textPrimary
                    border.width: Theme.line
                    border.color: Theme.surface
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    onPressed: mouse => page.pickHue((mouse.x - spectrum.x) / spectrum.width)
                    onPositionChanged: mouse => {
                        if (pressed)
                            page.pickHue((mouse.x - spectrum.x) / spectrum.width)
                    }
                }
            }
        }

        Options {
            width: parent.width
            motion: page.motion
            visible: page.moving
            enabled: page.present
            title: I18n.tr("Speed")
            value: page.setting.speed
            choices: [
                { value: "slow", label: I18n.tr("Slow") },
                { value: "medium", label: I18n.tr("Medium") },
                { value: "fast", label: I18n.tr("Fast") }
            ]
            onPicked: next => page.set({ speed: next })
        }

        Text {
            width: content.width
            // Footnote under a group, aligned with the text inside it.
            leftPadding: 4
            rightPadding: leftPadding
            visible: !page.present
            text: I18n.tr("Connect the DualSense to change its lights.")
            wrapMode: Text.Wrap
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textCaption
        }
    }
}
