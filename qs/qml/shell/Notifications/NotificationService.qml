pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The shell is the session's only notification daemon. It tracks active notifications, newest
// first, and expires them itself so expiry can pause while the panel is open or a row is hovered.
Singleton {
    id: root

    readonly property ListModel model: ListModel {
        dynamicRoles: true
    }
    readonly property int count: model.count
    property int revision: 0
    readonly property var newest: {
        root.revision
        return model.count > 0 ? model.get(0).handle : null
    }
    readonly property bool newestCritical: !!newest && newest.urgency === NotificationUrgency.Critical

    property int lowTimeout: 6000
    property int normalTimeout: 12000
    property bool panelOpen: false
    property double lastTick: 0
    // Local notifications count down from -2: D-Bus ids are positive, and -1 is the pop-up's "no row" id.
    property int nextLocalId: -2

    // A genuinely new notification arrived, or an existing one was replaced in place.
    signal arrived()

    NotificationServer {
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        persistenceSupported: false
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        onNotification: notification => root.accept(notification)
    }

    // The shell's own notices (weather alerts, say) take the same row shape as D-Bus ones: the fields the
    // rows read, the change signals accept() listens for, and close methods that end in `closed`.
    Component {
        id: local

        QtObject {
            property int id
            property bool tracked: false
            property string appName
            property string summary
            property string body
            property int urgency
            property double time
            readonly property var actions: []
            readonly property string image: ""
            readonly property string appIcon: ""
            readonly property int expireTimeout: -1
            signal closed()
            function dismiss() { closed(); destroy() }
            function expire() { closed(); destroy() }
        }
    }

    function postLocal(appName, summary, body, urgency) {
        accept(local.createObject(root, { id: nextLocalId--, appName: appName, summary: summary, body: body,
                                          urgency: urgency, time: Date.now() }))
    }

    Timer {
        interval: 100
        repeat: true
        running: root.count > 0
        onTriggered: root.settle(Date.now())
    }

    function timeoutFor(notification) {
        // Quickshell 0.3.1 forwards the D-Bus timeout in milliseconds, though its docs say seconds.
        if (notification.expireTimeout > 0)
            return Math.round(notification.expireTimeout)
        if (notification.expireTimeout === 0 || notification.urgency === NotificationUrgency.Critical)
            return -1
        return notification.urgency === NotificationUrgency.Low ? lowTimeout : normalTimeout
    }

    // Image data or path first, then the app's themed icon. Missing theme icons resolve to "" so callers
    // show the generic symbol rather than the icon provider's placeholder.
    function mediaFor(notification) {
        if (!notification)
            return ""
        const image = String(notification.image || "")
        const themed = "image://icon/"
        if (image !== "" && (!image.startsWith(themed) || Quickshell.hasThemeIcon(image.slice(themed.length))))
            return image
        const icon = String(notification.appIcon || "")
        if (icon.startsWith("/") || icon.startsWith("file:"))
            return icon
        return icon !== "" && Quickshell.hasThemeIcon(icon) ? Quickshell.iconPath(icon) : ""
    }

    function indexOf(id) {
        for (let i = 0; i < model.count; ++i) {
            if (model.get(i).notificationId === id)
                return i
        }
        return -1
    }

    function accept(notification) {
        notification.tracked = true
        settle(Date.now())
        model.insert(0, { handle: notification, notificationId: notification.id,
                          remaining: timeoutFor(notification), paused: false })
        const id = notification.id
        notification.closed.connect(function () { root.remove(id) })
        // replaces_id updates this same object, so any content change is a replacement.
        const replaced = function () { Qt.callLater(root.replace, notification) }
        notification.summaryChanged.connect(replaced)
        notification.bodyChanged.connect(replaced)
        notification.imageChanged.connect(replaced)
        notification.appIconChanged.connect(replaced)
        notification.expireTimeoutChanged.connect(replaced)
        ++revision
        arrived()
    }

    function replace(notification) {
        const index = indexOf(notification.id)
        if (index < 0)
            return
        settle(Date.now())
        if (index > 0)
            model.move(index, 0, 1)
        model.setProperty(0, "remaining", timeoutFor(notification))
        ++revision
        arrived()
    }

    function remove(id) {
        const index = indexOf(id)
        if (index < 0)
            return
        model.remove(index, 1)
        ++revision
    }

    function settle(now) {
        const elapsed = lastTick > 0 ? Math.max(0, now - lastTick) : 0
        lastTick = now
        if (elapsed === 0 || panelOpen)
            return
        for (let i = model.count - 1; i >= 0; --i) {
            const entry = model.get(i)
            if (entry.remaining < 0 || entry.paused)
                continue
            const left = entry.remaining - elapsed
            model.setProperty(i, "remaining", Math.max(0, left))
            if (left <= 0)
                entry.handle.expire()
        }
    }

    function setPanelOpen(open) {
        settle(Date.now())
        panelOpen = open
        if (!open) {
            for (let i = 0; i < model.count; ++i)
                model.setProperty(i, "paused", false)
        }
    }

    function setPaused(id, paused) {
        const index = indexOf(id)
        if (index < 0)
            return
        settle(Date.now())
        model.setProperty(index, "paused", paused)
    }

    function dismiss(id) {
        const index = indexOf(id)
        if (index >= 0)
            model.get(index).handle.dismiss()
    }

    function invoke(id, identifier) {
        const index = indexOf(id)
        if (index < 0)
            return
        const actions = model.get(index).handle.actions
        for (let i = 0; i < actions.length; ++i) {
            if (actions[i].identifier === identifier) {
                actions[i].invoke()
                return
            }
        }
    }

    // Critical and persistent notifications are dismissed too; any that refuse stay listed.
    function clearAll() {
        const handles = []
        for (let i = 0; i < model.count; ++i)
            handles.push(model.get(i).handle)
        for (const notification of handles)
            notification.dismiss()
    }
}
