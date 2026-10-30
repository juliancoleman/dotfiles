import QtQuick
import "../Common"

Item {
    id: page

    property var source: null
    property var control: null
    property string motion: "easeOut"

    readonly property bool controllable: control !== null && control.ready && !control.busy
    readonly property string note: {
        if (!control)
            return ""
        if (control.busy)
            return qsTr("Another session is controlling the fans.")
        if (control.error !== "")
            return control.error
        if (control.connected && !control.available)
            return control.reason
        if (!control.ready)
            return qsTr("Manual control isn't enabled on this machine.")
        return ""
    }

    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 6

        Repeater {
            model: page.control && page.control.ready ? page.control.fans : []

            FanTile {
                required property var modelData
                width: content.width
                motion: page.motion
                controllable: page.controllable
                title: modelData.label
                rpmText: page.source.rpmText(modelData.rpm)
                manual: modelData.mode === "manual"
                percent: modelData.percent
                minimum: modelData.minimumPercent
                onAutoRequested: page.control.setAuto(modelData.id)
                onPercentRequested: next => page.control.setPercent(modelData.id, next)
            }
        }

        Repeater {
            model: page.control && page.control.ready ? [] : (page.source ? page.source.fans : [])

            ToggleTile {
                required property var modelData
                width: content.width
                motion: page.motion
                opens: false
                toggleable: false
                icon: "fan"
                title: modelData.label
                subtitle: qsTr("Auto") + " · " + page.source.rpmText(modelData.rpm)
            }
        }

        Text {
            width: content.width
            leftPadding: 4
            rightPadding: 4
            visible: page.note !== ""
            text: page.note
            wrapMode: Text.Wrap
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
