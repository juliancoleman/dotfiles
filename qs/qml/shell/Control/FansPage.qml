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

        // Rows are ListModels updated in place; a fresh array here would rebuild every tile per reply.
        Repeater {
            model: FanControl.ready ? FanControl.rows : null

            FanTile {
                required property var model
                width: content.width
                motion: page.motion
                controllable: page.controllable
                title: model.label
                rpmText: FanSource.rpmText(model.rpm)
                manual: model.mode === "manual"
                percent: model.percent
                minimum: model.minimumPercent
                onAutoRequested: FanControl.setAuto(model.id)
                onPercentRequested: next => FanControl.setPercent(model.id, next)
            }
        }

        // No helper: read-only rows, but the ring still shows the duty sysfs reports.
        Repeater {
            model: FanControl.ready ? null : FanSource.rows

            FanTile {
                required property var model
                width: content.width
                motion: page.motion
                controllable: false
                title: model.label
                rpmText: FanSource.rpmText(model.rpm)
                percent: model.percent
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
            font.pixelSize: Theme.textCaption
        }
    }
}
