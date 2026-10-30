import QtQuick
import Quickshell.Services.Pipewire
import "../Common"

Item {
    id: page

    // false lists outputs (sinks); true lists inputs (sources).
    property bool input: false
    property var source: null
    property string motion: "easeOut"
    readonly property real maxListHeight: 240

    implicitHeight: content.implicitHeight

    readonly property var current: input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    readonly property var devices: {
        const list = Pipewire.nodes ? Pipewire.nodes.values : []
        return list.filter(n => n && n.audio && !n.isStream && n.isSink === !page.input)
            .sort((a, b) => page.label(a).localeCompare(page.label(b)))
    }

    function label(node) {
        return node.description || node.nickname || node.name
    }

    function choose(node) {
        if (input)
            Pipewire.preferredDefaultAudioSource = node
        else
            Pipewire.preferredDefaultAudioSink = node
    }

    Column {
        id: content
        width: parent.width
        spacing: 6

        SliderTile {
            width: parent.width
            motion: page.motion
            visible: !!page.source && page.source.available
            title: page.input ? qsTr("Microphone") : qsTr("Volume")
            icon: !page.source ? "" : page.input
                ? (page.source.muted || page.source.level <= 0.005 ? "microphone-muted" : "microphone")
                : (page.source.muted || page.source.level <= 0.005 ? "volume-muted" : "volume")
            value: page.source ? page.source.level : 0
            muted: !!page.source && page.source.muted
            onMoved: next => {
                const audio = page.source.sink.audio
                audio.muted = false
                audio.volume = next
            }
            onToggled: page.source.sink.audio.muted = !page.source.muted
        }

        MomentumFlickable {
            width: parent.width
            height: Math.min(page.maxListHeight, list.implicitHeight)
            contentHeight: list.implicitHeight

            Column {
                id: list
                width: parent.width

                Repeater {
                    model: page.devices

                    ListRow {
                        required property var modelData
                        width: list.width
                        icon: page.input ? "microphone" : "volume"
                        title: page.label(modelData)
                        current: modelData === page.current
                        trailing: current ? "check" : ""
                        onActivated: page.choose(modelData)
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: page.devices.length === 0
            horizontalAlignment: Text.AlignHCenter
            topPadding: 8
            bottomPadding: 10
            text: page.input ? qsTr("No input devices") : qsTr("No output devices")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 11
        }
    }
}
