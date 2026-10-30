import QtQuick
import "../Common"
import "../Status"

// Secure input card. It starts as the clock housing (`from`) and grows out of it along the edge.
Item {
    id: root

    property string edge: "right"
    property rect from: Qt.rect(0, 0, 0, 0)
    property real notch: 0
    property string motion: "easeOut"
    property bool shown: false

    readonly property real openW: 288
    readonly property real openH: 98
    readonly property real pad: 12
    property real openProgress: 0
    readonly property real p: Math.max(0, openProgress)
    readonly property real pc: Math.min(1, p)
    property real shake: 0
    property alias housingItem: card

    x: edge === "right" ? from.x + from.width - width
        : edge === "left" ? from.x
        : from.x + (from.width - width) / 2
    y: edge === "bottom" ? from.y + from.height - height
        : edge === "top" ? from.y
        : from.y + (from.height - height) / 2
    width: from.width + (openW - from.width) * p
    height: from.height + (openH - from.height) * p
    visible: p > 0.001

    function corner(outer) {
        const radius = Math.min(from.width, from.height) / 2 * (1 - pc) + 14 * pc
        return outer ? radius * (1 - notch) : radius
    }

    function submit() {
        if (SecureInput.busy || input.text.length < SecureInput.minLength)
            return
        const secret = input.text
        input.text = ""
        SecureInput.submit(secret)
    }

    function refocus() {
        Qt.callLater(function () {
            if (root.shown)
                input.forceActiveFocus()
        })
    }

    onShownChanged: {
        input.text = ""
        openEase.stop()
        if (Theme.durationFor(motion) === 0) {
            openProgress = shown ? 1 : 0
        } else {
            openEase.from = openProgress
            openEase.to = shown ? 1 : 0
            openEase.start()
        }
        if (shown)
            refocus()
    }

    Connections {
        target: SecureInput
        function onRejectionsChanged() {
            input.text = ""
            shakeAnim.restart()
            root.refocus()
        }
        function onSerialChanged() {
            input.text = ""
            root.refocus()
        }
    }

    NumberAnimation {
        id: openEase
        target: root
        property: "openProgress"
        duration: Theme.durationFor(root.motion)
        easing.type: Theme.easingFor(root.motion)
        easing.overshoot: Theme.springOvershoot
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: root; property: "shake"; to: -8; duration: 45; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shake"; to: 7; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shake"; to: -4; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 55; easing.type: Easing.OutQuad }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.surface
        clip: true
        topLeftRadius: root.corner(root.edge === "top" || root.edge === "left")
        topRightRadius: root.corner(root.edge === "top" || root.edge === "right")
        bottomLeftRadius: root.corner(root.edge === "bottom" || root.edge === "left")
        bottomRightRadius: root.corner(root.edge === "bottom" || root.edge === "right")

        MouseArea {
            anchors.fill: parent
            onPressed: root.refocus()
        }

        Item {
            id: body
            width: root.openW
            height: root.openH
            x: (root.edge === "right" ? parent.width - width
                : root.edge === "left" ? 0
                : (parent.width - width) / 2) + root.shake
            y: root.edge === "bottom" ? parent.height - height
                : root.edge === "top" ? 0
                : (parent.height - height) / 2
            opacity: Math.max(0, (root.pc - 0.35) / 0.65)

            Rectangle {
                id: knob
                x: root.pad
                y: root.pad
                width: 30
                height: 30
                radius: 15
                color: SecureInput.error !== "" ? Theme.danger : Qt.rgba(1, 1, 1, 0.07)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.durationFor(root.motion)
                        easing.type: Easing.OutCubic
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    sourceSize: Qt.size(36, 36)
                    visible: SecureInput.image !== "" && status === Image.Ready
                    source: SecureInput.image
                    smooth: true
                }

                StatusGlyph {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    visible: SecureInput.image === ""
                    icon: SecureInput.glyph
                    cutColor: knob.color
                }
            }

            Column {
                anchors.left: knob.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: root.pad
                anchors.verticalCenter: knob.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: SecureInput.title
                    color: Theme.textPrimary
                    elide: Text.ElideMiddle
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }

                Text {
                    width: parent.width
                    text: SecureInput.error !== "" ? SecureInput.error
                        : SecureInput.busy ? (SecureInput.request.busyText || qsTr("Checking…"))
                        : SecureInput.kind
                    color: SecureInput.error !== "" ? Theme.textPrimary : Theme.textSecondary
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }

            Rectangle {
                id: field
                x: root.pad
                y: knob.y + knob.height + 10
                width: parent.width - root.pad * 2
                height: 34
                radius: 10
                color: Theme.track
                border.width: 1
                border.color: input.activeFocus ? Theme.today : Qt.rgba(1, 1, 1, 0.08)

                StatusGlyph {
                    id: leader
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: visible ? 13 : 0
                    height: 13
                    visible: !SecureInput.echo
                    icon: "lock"
                    ink: Theme.textSecondary
                    cutColor: field.color
                }

                Text {
                    anchors.fill: input
                    visible: input.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                    text: SecureInput.placeholder
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }

                TextInput {
                    id: input
                    anchors.left: leader.right
                    anchors.right: go.left
                    anchors.leftMargin: leader.visible ? 7 : 2
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 8
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: SecureInput.echo ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    readOnly: SecureInput.busy
                    clip: true
                    color: Theme.textPrimary
                    selectionColor: Theme.today
                    selectedTextColor: Theme.todayInk
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    Accessible.role: Accessible.EditableText
                    Accessible.name: SecureInput.placeholder
                    Accessible.passwordEdit: !SecureInput.echo
                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onEscapePressed: event => {
                        SecureInput.cancel()
                        event.accepted = true
                    }
                }

                Rectangle {
                    id: go
                    readonly property bool ready: !SecureInput.busy && input.text.length >= SecureInput.minLength
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    radius: 13
                    color: ready ? Theme.today : Qt.rgba(1, 1, 1, 0.06)
                    opacity: SecureInput.busy ? 0.45 + 0.55 * pulse.value : 1

                    QtObject {
                        id: pulse
                        property real value: 1
                    }

                    SequentialAnimation {
                        running: SecureInput.busy && root.shown
                        loops: Animation.Infinite
                        onStopped: pulse.value = 1
                        NumberAnimation { target: pulse; property: "value"; from: 1; to: 0; duration: 500; easing.type: Easing.InOutSine }
                        NumberAnimation { target: pulse; property: "value"; from: 0; to: 1; duration: 500; easing.type: Easing.InOutSine }
                    }

                    StatusGlyph {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        icon: "chevron-right"
                        ink: go.ready ? Theme.todayInk : Theme.textSecondary
                        cutColor: go.color
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: go.ready
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.submit()
                    }
                }
            }
        }
    }
}
