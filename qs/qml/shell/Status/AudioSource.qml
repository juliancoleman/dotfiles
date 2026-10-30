import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Scope {
    id: root

    // false follows the default output (sink); true follows the default input (source).
    property bool input: false
    readonly property var sink: input ? Pipewire.defaultAudioSource : Pipewire.defaultAudioSink
    readonly property bool available: !!sink && sink.ready && !!sink.audio
    readonly property real level: available ? Math.max(0, Math.min(1, sink.audio.volume)) : 0
    readonly property bool muted: available && sink.audio.muted

    signal adjusted()

    property var _node: null
    property real _level: 0
    property bool _muted: false
    property bool _pending: false

    PwObjectTracker {
        objects: [root.sink]
    }

    onSinkChanged: queue()
    onAvailableChanged: queue()
    onLevelChanged: queue()
    onMutedChanged: queue()

    // Coalesce the burst of property updates PipeWire emits per change, and
    // treat a new default sink as a fresh baseline rather than an adjustment.
    function queue() {
        if (_pending)
            return
        _pending = true
        Qt.callLater(flush)
    }

    function flush() {
        _pending = false
        if (!available) {
            _node = null
            return
        }
        if (sink !== _node) {
            _node = sink
            _level = level
            _muted = muted
            return
        }
        if (Math.abs(level - _level) < 0.0001 && muted === _muted)
            return
        _level = level
        _muted = muted
        adjusted()
    }
}
