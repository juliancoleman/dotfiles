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
    // Alone in the pop-up the panel is the card, so the row drops its own; stacked in the list it keeps one.
    property bool bare: false
    readonly property real inset: Theme.px(10)

    readonly property bool critical: !!handle && handle.urgency === NotificationUrgency.Critical
    readonly property var namedActions: handle ? handle.actions.filter(a => a.identifier !== "default") : []
    readonly property bool hasDefault: !!handle && handle.actions.some(a => a.identifier === "default")
    readonly property bool hovered: hit.containsMouse || close.hovered || actionHover.hovered
    readonly property string media: NotificationService.mediaFor(handle)

    implicitHeight: content.implicitHeight + inset * 2
    radius: Theme.radius
    color: bare ? "transparent" : hovered || activeFocus ? Qt.tint(Theme.track, Theme.lift) : Theme.track
    // Critical rows keep a lightened danger hairline: it is a warning state, not a hover tint.
    border.width: activeFocus || !bare ? 1 : 0
    border.color: activeFocus ? Theme.today : critical ? Qt.lighter(Theme.danger, 1.6) : Theme.edge
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
            duration: Theme.durationFor(row.motion) * 0.56
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
        x: Theme.knobInset
        y: Theme.knobInset
        width: Theme.knobSize
        height: Theme.knobSize
        radius: width / 2
        color: Theme.ink
        clip: true

        Image {
            id: picture
            anchors.fill: parent
            source: row.media
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Theme.knobSize * 2, Theme.knobSize * 2)
            asynchronous: true
            visible: status === Image.Ready
        }

        StatusGlyph {
            anchors.centerIn: parent
            width: Theme.buttonIconSize
            height: Theme.buttonIconSize
            visible: !picture.visible
            icon: "bell"
        }
    }

    Column {
        id: content
        x: badge.x + badge.width + Theme.knobGap
        y: row.inset
        width: row.width - x - Theme.px(34)
        spacing: Theme.px(2)

        Text {
            width: parent.width
            text: row.handle ? row.handle.appName : ""
            visible: text !== ""
            color: Theme.textSecondary
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textCaption
        }

        Text {
            width: parent.width
            text: row.handle ? row.handle.summary : ""
            color: Theme.textPrimary
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
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
            font.pixelSize: Theme.textLabel
            lineHeight: 1.1
        }

        Text {
            id: more
            visible: body.truncated || row.expanded
            text: row.expanded ? I18n.tr("Show less") : I18n.tr("Show more")
            color: moreHit.containsMouse ? Theme.textPrimary : Theme.today
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textCaption
            font.weight: Font.Medium

            MouseArea {
                id: moreHit
                anchors.fill: parent
                anchors.margins: -Theme.px(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: row.expanded = !row.expanded
            }
        }

        Flow {
            width: parent.width
            visible: row.namedActions.length > 0
            topPadding: Theme.px(4)
            spacing: Theme.tileGap

            HoverHandler { id: actionHover }

            Repeater {
                model: row.namedActions

                Rectangle {
                    id: action
                    required property var modelData
                    width: label.implicitWidth + Theme.px(20)
                    height: Theme.px(24)
                    radius: Theme.radiusInput
                    color: actionHit.containsMouse || activeFocus ? Theme.knobLift : Theme.lift
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
                        font.pixelSize: Theme.textLabel
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
        anchors.margins: Theme.tileGap
        width: Theme.px(22)
        height: Theme.px(22)
        radius: width / 2
        color: hovered || activeFocus ? Theme.knobLift : "transparent"
        opacity: row.hovered || activeFocus || row.activeFocus ? 1 : 0.55
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: I18n.tr("Dismiss")
        Keys.onReturnPressed: NotificationService.dismiss(row.notificationId)
        Keys.onSpacePressed: NotificationService.dismiss(row.notificationId)

        StatusGlyph {
            anchors.centerIn: parent
            width: Theme.px(12)
            height: Theme.px(12)
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
