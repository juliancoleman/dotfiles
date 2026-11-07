pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// The shell is the session's only notification daemon. It tracks active notifications, newest first,
// and keeps each until it's dismissed, acted on, or closed by its app; the arrival toast is the
// center's own peek and never removes anything.
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

    // Local notifications count down from -2: D-Bus ids are positive, and -1 is the pop-up's "no row" id.
    property int nextLocalId: -2

    // A genuinely new notification arrived, or an existing one was replaced in place.
    signal arrived()

    NotificationServer {
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        // Notifications stay until the user dismisses them.
        persistenceSupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        onNotification: notification => root.accept(notification)
    }

    // The shell's own notices (weather alerts, say) take the same row shape as D-Bus ones: the fields the
    // rows read, the change signals accept() listens for, and a dismiss that ends in `closed`.
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
            signal closed()
            function dismiss() { closed(); destroy() }
        }
    }

    function postLocal(appName, summary, body, urgency) {
        accept(local.createObject(root, { id: nextLocalId--, appName: appName, summary: summary, body: body,
                                          urgency: urgency, time: Date.now() }))
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
        model.insert(0, { handle: notification, notificationId: notification.id })
        const id = notification.id
        notification.closed.connect(function () { root.remove(id) })
        // replaces_id updates this same object, so any content change is a replacement.
        const replaced = function () { Qt.callLater(root.replace, notification) }
        notification.summaryChanged.connect(replaced)
        notification.bodyChanged.connect(replaced)
        notification.imageChanged.connect(replaced)
        notification.appIconChanged.connect(replaced)
        ++revision
        arrived()
    }

    function replace(notification) {
        const index = indexOf(notification.id)
        if (index < 0)
            return
        if (index > 0)
            model.move(index, 0, 1)
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
