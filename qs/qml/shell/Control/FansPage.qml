import QtQuick
import "../Common"

Item {
    id: page

    property string motion: "easeOut"

    readonly property bool controllable: FanControl.ready && !FanControl.busy
    readonly property string note: {
        if (FanControl.busy)
            return I18n.tr("Another session is controlling the fans.")
        if (FanControl.error !== "")
            return FanControl.error
        if (FanControl.connected && !FanControl.available)
            return FanControl.reason
        if (!FanControl.ready)
            return I18n.tr("Manual control isn't enabled on this machine.")
        return ""
    }

    implicitHeight: content.implicitHeight

    Column {
        id: content
        width: parent.width
        spacing: 6

        Repeater {
            model: FanControl.ready ? FanControl.fans : []

            FanTile {
                required property var modelData
                width: content.width
                motion: page.motion
                controllable: page.controllable
                title: modelData.label
                rpmText: FanSource.rpmText(modelData.rpm)
                manual: modelData.mode === "manual"
                percent: modelData.percent
                minimum: modelData.minimumPercent
                onAutoRequested: FanControl.setAuto(modelData.id)
                onPercentRequested: next => FanControl.setPercent(modelData.id, next)
            }
        }

        Repeater {
            model: FanControl.ready ? [] : FanSource.fans

            ToggleTile {
                required property var modelData
                width: content.width
                motion: page.motion
                opens: false
                toggleable: false
                icon: "fan"
                title: modelData.label
                subtitle: I18n.tr("Auto") + " · " + FanSource.rpmText(modelData.rpm)
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
