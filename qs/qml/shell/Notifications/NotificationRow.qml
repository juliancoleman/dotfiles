import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../Common"
import "../Status"

Rectangle {
    id: row

    required property var handle
    required property int notificationId
    property string motion: "easeOut"
    property bool expanded: false

    readonly property bool critical: !!handle && handle.urgency === NotificationUrgency.Critical
    readonly property var namedActions: handle ? handle.actions.filter(a => a.identifier !== "default") : []
    readonly property bool hasDefault: !!handle && handle.actions.some(a => a.identifier === "default")
    readonly property bool hovered: hit.containsMouse || close.hovered || actionHover.hovered
    readonly property string media: NotificationService.mediaFor(handle)

    implicitHeight: content.implicitHeight + 20
    radius: 12
    color: hovered || activeFocus ? Qt.tint(Theme.track, Qt.rgba(1, 1, 1, 0.04)) : Theme.track
    border.width: activeFocus ? 1 : critical ? 1 : 0
    border.color: activeFocus ? Theme.today : Qt.lighter(Theme.danger, 1.6)
    activeFocusOnTab: visible
    Accessible.role: Accessible.Button
    Accessible.name: handle ? handle.summary : ""
    Accessible.description: handle ? handle.body : ""
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: activate()
    Keys.onDeletePressed: NotificationService.dismiss(notificationId)

    onHoveredChanged: NotificationService.setPaused(notificationId, hovered || activeFocus)
    onActiveFocusChanged: NotificationService.setPaused(notificationId, hovered || activeFocus)

    function activate() {
        if (hasDefault)
            NotificationService.invoke(notificationId, "default")
    }

    Behavior on color {
        ColorAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.hasDefault ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.activate()
    }

    Rectangle {
        id: badge
        x: 10
        y: 10
        width: 28
        height: 28
        radius: width / 2
        color: Theme.ink
        clip: true

        Image {
            id: picture
            anchors.fill: parent
            source: row.media
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(56, 56)
            asynchronous: true
            visible: status === Image.Ready
        }

        StatusGlyph {
            anchors.centerIn: parent
            width: 15
            height: 15
            visible: !picture.visible
            icon: "bell"
        }
    }

    Column {
        id: content
        x: badge.x + badge.width + 10
        y: 10
        width: row.width - x - 34
        spacing: 2

        Text {
            width: parent.width
            text: row.handle ? row.handle.appName : ""
            visible: text !== ""
            color: Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }

        Text {
            width: parent.width
            text: row.handle ? row.handle.summary : ""
            color: Theme.textPrimary
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.Medium
        }

        Text {
            id: body
            width: parent.width
            text: row.handle ? row.handle.body : ""
            visible: text !== ""
            color: Theme.textSecondary
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            maximumLineCount: row.expanded ? 100 : 3
            textFormat: Text.PlainText
            font.family: Theme.fontFamily
            font.pixelSize: 11
            lineHeight: 1.1
        }

        Text {
            id: more
            visible: body.truncated || row.expanded
            text: row.expanded ? qsTr("Show less") : qsTr("Show more")
            color: moreHit.containsMouse ? Theme.textPrimary : Theme.today
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.Medium

            MouseArea {
                id: moreHit
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.expanded = !row.expanded
            }
        }

        Flow {
            width: parent.width
            visible: row.namedActions.length > 0
            topPadding: 4
            spacing: 6

            HoverHandler { id: actionHover }

            Repeater {
                model: row.namedActions

                Rectangle {
                    id: action
                    required property var modelData
                    width: label.implicitWidth + 20
                    height: 24
                    radius: 8
                    color: actionHit.containsMouse || activeFocus ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: activeFocus ? 1 : 0
                    border.color: Theme.today
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.text
                    Keys.onReturnPressed: modelData.invoke()
                    Keys.onSpacePressed: modelData.invoke()

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: action.modelData.text
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: actionHit
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: action.modelData.invoke()
                    }
                }
            }
        }
    }

    Rectangle {
        id: close
        readonly property bool hovered: closeHit.containsMouse
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: 22
        height: 22
        radius: width / 2
        color: hovered || activeFocus ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
        opacity: row.hovered || activeFocus || row.activeFocus ? 1 : 0.55
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Dismiss")
        Keys.onReturnPressed: NotificationService.dismiss(row.notificationId)
        Keys.onSpacePressed: NotificationService.dismiss(row.notificationId)

        StatusGlyph {
            anchors.centerIn: parent
            width: 12
            height: 12
            icon: "close"
        }

        MouseArea {
            id: closeHit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationService.dismiss(row.notificationId)
        }
    }
}
