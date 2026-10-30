pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Selects the playing MPRIS player, else the most recently active one, and reports
// playback changes as `mediaEvent(resultingPlaying, direction)` with direction
// "next", "previous", or "neutral".
Singleton {
    id: root

    property var _activity: ({})
    property int _activityCounter: 0
    property int _selectionRevision: 0
    property string _pendingDirection: ""
    property string _pendingPlayerKey: ""
    property double _pendingSince: 0

    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property var selectedPlayer: {
        const revision = _selectionRevision
        let playing = null
        let playingActivity = -1
        let recent = null
        let recentActivity = -1
        for (let i = 0; i < players.length; ++i) {
            const player = players[i]
            if (!player)
                continue
            const activity = _activity[playerKey(player)] || 0
            if (activity > recentActivity) {
                recent = player
                recentActivity = activity
            }
            if (player.playbackState === MprisPlaybackState.Playing && activity > playingActivity) {
                playing = player
                playingActivity = activity
            }
        }
        return playing || recent
    }

    signal mediaEvent(bool resultingPlaying, string direction)

    Instantiator {
        model: Mpris.players

        delegate: QtObject {
            id: observer

            required property var modelData
            property bool initialized: false
            // The player object is already gone by destruction time, so remember its key up front.
            property string key: ""

            Component.onCompleted: {
                key = root.playerKey(modelData)
                root.touch(modelData)
                initialized = true
            }
            Component.onDestruction: root.forget(key)

            property Connections watch: Connections {
                target: observer.modelData
                ignoreUnknownSignals: true

                function onPlaybackStateChanged() {
                    if (!observer.initialized)
                        return
                    root.touch(observer.modelData)
                    if (root.selectedPlayer !== observer.modelData || root.hasPendingDirection(observer.modelData))
                        return
                    root.mediaEvent(observer.modelData.playbackState === MprisPlaybackState.Playing, "neutral")
                }

                function onPostTrackChanged() {
                    if (!observer.initialized)
                        return
                    root.touch(observer.modelData)
                    if (root.selectedPlayer !== observer.modelData)
                        return
                    if (!root.consumePendingDirection(observer.modelData))
                        root.mediaEvent(observer.modelData.playbackState === MprisPlaybackState.Playing, "neutral")
                }
            }
        }
    }

    // Track-change signals that follow our own next/previous are absorbed within this window.
    Timer {
        id: pendingTimer
        interval: 1500
        onTriggered: root.clearPending()
    }

    function playerKey(player) {
        if (!player)
            return ""
        // A player mid-teardown can still be listed, and reading its properties throws.
        try {
            return player.dbusName || player.identity || String(player)
        } catch (error) {
            return ""
        }
    }

    function touch(player) {
        const key = playerKey(player)
        if (!key)
            return
        const updated = Object.assign({}, _activity)
        updated[key] = ++_activityCounter
        _activity = updated
        ++_selectionRevision
    }

    function forget(key) {
        if (!key || _activity[key] === undefined)
            return
        const updated = Object.assign({}, _activity)
        delete updated[key]
        _activity = updated
        ++_selectionRevision
        if (_pendingPlayerKey === key)
            clearPending()
    }

    function setPending(player, direction) {
        _pendingPlayerKey = playerKey(player)
        _pendingDirection = direction
        _pendingSince = Date.now()
        pendingTimer.restart()
    }

    function clearPending() {
        _pendingPlayerKey = ""
        _pendingDirection = ""
        _pendingSince = 0
        pendingTimer.stop()
    }

    function hasPendingDirection(player) {
        return _pendingDirection !== "" && _pendingPlayerKey === playerKey(player)
            && Date.now() - _pendingSince <= pendingTimer.interval
    }

    function consumePendingDirection(player) {
        const matches = hasPendingDirection(player)
        if (matches)
            clearPending()
        return matches
    }

    function next() {
        const player = selectedPlayer
        if (!player || !player.canGoNext)
            return
        setPending(player, "next")
        player.next()
        touch(player)
        mediaEvent(player.playbackState === MprisPlaybackState.Playing, "next")
    }

    function previous() {
        const player = selectedPlayer
        if (!player || !player.canGoPrevious)
            return
        setPending(player, "previous")
        player.previous()
        touch(player)
        mediaEvent(player.playbackState === MprisPlaybackState.Playing, "previous")
    }

    function playPause() {
        const player = selectedPlayer
        if (!player || !player.canTogglePlaying)
            return
        const resultingPlaying = player.playbackState !== MprisPlaybackState.Playing
        player.togglePlaying()
        touch(player)
        mediaEvent(resultingPlaying, "neutral")
    }
}
