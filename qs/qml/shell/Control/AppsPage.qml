import QtQuick
import "../Common"

// What is running, as a "Force Quit" list: the apps, then any service started by hand. An app with no
// window says so, since that is the leftover that keeps a relaunch from showing anything. Quitting asks
// every process of the app to end; force quitting ends them, and takes a second click on the same row.
// The desktop's own services are not listed: stopping the wallpaper or the compositor is nobody's wish.
Item {
    id: page

    property bool active: false
    property string motion: "easeOut"
    property real maxHeight: Infinity
    // The row whose force action is waiting for its second click: "app <key>" or "service <unit>".
    property string armed: ""
    // A window was brought forward; the panel in front of it closes.
    signal acted()

    implicitHeight: list.implicitHeight

    onActiveChanged: armed = ""

    function counted(n, one, many) {
        return n === 1 ? I18n.tr(one) : I18n.tr(many).arg(n)
    }

    function appStatus(app) {
        const processes = counted(app.pids.length, "1 process", "%1 processes")
        return (app.windows > 0 ? counted(app.windows, "1 window", "%1 windows") : I18n.tr("No window"))
            + " · " + processes
    }

    // The first click on a force action arms it; the second, on the same row, carries it out.
    function force(id, act) {
        if (armed !== id) {
            armed = id
            disarm.restart()
            return
        }
        armed = ""
        act()
    }

    Timer {
        id: disarm
        interval: 4000
        onTriggered: page.armed = ""
    }

    ListGroup {
        id: list
        width: parent.width
        maxHeight: page.maxHeight
        spacing: 2

        SectionHeader {
            width: parent.width
            text: I18n.tr("Apps")
        }

        Repeater {
            model: RunningApps.apps

            ListRow {
                id: app
                required property var modelData
                readonly property string id: "app " + modelData.key
                readonly property bool isArmed: page.armed === id
                // Not parent.width: a row outlives its place in the list for a moment when the list changes.
                width: list.width
                motion: page.motion
                image: modelData.icon
                title: modelData.name
                subtitle: isArmed ? I18n.tr("Click again to force quit") : page.appStatus(modelData)
                current: isArmed
                actions: [
                    { id: "quit", icon: "close", label: I18n.tr("Quit") },
                    { id: "force", icon: "power-off", label: I18n.tr("Force quit") }
                ]
                onActivated: {
                    if (modelData.windows === 0)
                        return
                    RunningApps.focus(modelData)
                    page.acted()
                }
                onActionTriggered: action => {
                    if (action === "force") {
                        page.force(id, () => RunningApps.forceQuit(modelData))
                    } else {
                        page.armed = ""
                        RunningApps.quit(modelData)
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: RunningApps.apps.length === 0
            topPadding: 8
            bottomPadding: 8
            horizontalAlignment: Text.AlignHCenter
            text: I18n.tr("Nothing open")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textLabel
        }

        Item {
            width: parent.width
            height: Theme.tileGap
            visible: RunningApps.services.length > 0
        }

        SectionHeader {
            width: parent.width
            visible: RunningApps.services.length > 0
            text: I18n.tr("Services")
        }

        Repeater {
            model: RunningApps.services

            ListRow {
                id: service
                required property var modelData
                readonly property string id: "service " + modelData.unit
                readonly property bool isArmed: page.armed === id
                width: list.width
                motion: page.motion
                title: modelData.about || modelData.name
                subtitle: isArmed ? I18n.tr("Click again to force stop") : modelData.name
                current: isArmed
                actions: [
                    { id: "stop", icon: "close", label: I18n.tr("Stop") },
                    { id: "force", icon: "power-off", label: I18n.tr("Force stop") }
                ]
                onActionTriggered: action => {
                    if (action === "force") {
                        page.force(id, () => RunningApps.killService(modelData))
                    } else {
                        page.armed = ""
                        RunningApps.stopService(modelData)
                    }
                }
            }
        }
    }
}
