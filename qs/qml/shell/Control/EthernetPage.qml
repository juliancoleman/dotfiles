import QtQuick
import "../Clock"
import "../Common"
import "../Status"

// The wired link: live throughput on the knobs, then the facts about the route and interface.
Item {
    id: page

    property bool active: false
    property string motion: "easeOut"

    implicitHeight: content.implicitHeight

    readonly property var down: WiredSource.rateParts(WiredSource.downRate)
    readonly property var up: WiredSource.rateParts(WiredSource.upRate)
    // Link speed is the ceiling the rings fill toward; without one, 1 Gbit/s so they still mean something.
    readonly property real capacity: (WiredSource.linkSpeed > 0 ? WiredSource.linkSpeed : 1000) * 125000

    onActiveChanged: WiredSource.meterWatchers += active ? 1 : -1
    Component.onDestruction: if (active) WiredSource.meterWatchers -= 1

    function share(rate) {
        return Math.max(0, Math.min(1, rate / capacity))
    }

    component Detail: Item {
        property string label: ""
        property string value: ""
        width: parent.width
        height: Theme.px(28)
        visible: value !== ""

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: parent.value
            color: Theme.textPrimary
            elide: Text.ElideLeft
            width: Math.min(implicitWidth, parent.width * 0.6)
            font.family: Theme.latinFontFamily
            font.pixelSize: Theme.textBody
            font.features: { "tnum": 1 }
        }
    }

    component Throughput: Tile {
        property string icon: ""
        property string title: ""
        property var parts: ({ value: 0, unit: "B/s" })
        property real level: 0

        motion: page.motion
        Accessible.role: Accessible.StaticText
        Accessible.name: title + " " + parts.value + " " + parts.unit

        Knob {
            id: knob
            anchors.left: parent.left
            anchors.leftMargin: Theme.knobInset
            anchors.verticalCenter: parent.verticalCenter
            motion: parent.motion
            icon: parent.icon
            level: parent.level
            live: true
            interactive: false
        }

        Text {
            anchors.left: knob.right
            anchors.leftMargin: Theme.knobGap
            anchors.verticalCenter: parent.verticalCenter
            text: parent.title
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
            font.weight: Theme.fontWeightStrong
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.px(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.px(4)

            TickerNumber {
                anchors.baseline: unit.baseline
                value: parent.parent.parts.value
                motion: page.motion
                color: Theme.textPrimary
                fontPixelSize: Theme.textStrong
                fontWeight: Font.Medium
            }

            Text {
                id: unit
                text: parent.parent.parts.unit
                color: Theme.textSecondary
                font.family: Theme.latinFontFamily
                font.pixelSize: Theme.textLabel
            }
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.tileGap

        // Throughput, then the facts, ruled apart.
        Column {
            width: parent.width
            spacing: Theme.tileGap

            Throughput {
                width: parent.width
                icon: "arrow-down"
                title: I18n.tr("Download")
                parts: page.down
                level: page.share(WiredSource.downRate)
            }

            Throughput {
                width: parent.width
                icon: "arrow-up"
                title: I18n.tr("Upload")
                parts: page.up
                level: page.share(WiredSource.upRate)
            }
        }

        Rule { width: parent.width }

        Column {
            width: parent.width
            spacing: Theme.tileGap

            Detail { label: I18n.tr("Connection"); value: WiredSource.connection }
            Detail { label: I18n.tr("Interface"); value: WiredSource.device }
            Detail { label: I18n.tr("Address"); value: WiredSource.address + WiredSource.prefix }
            Detail { label: I18n.tr("Router"); value: WiredSource.gateway }
            Detail { label: I18n.tr("DNS"); value: WiredSource.dns.join(", ") }
            Detail {
                label: I18n.tr("Link")
                value: WiredSource.linkSpeed >= 1000 ? I18n.tr("%1 Gbit/s").arg(WiredSource.linkSpeed / 1000)
                    : WiredSource.linkSpeed > 0 ? I18n.tr("%1 Mbit/s").arg(WiredSource.linkSpeed) : ""
            }
            Detail { label: I18n.tr("Hardware"); value: WiredSource.hardwareAddress }
        }

        Text {
            width: parent.width
            visible: !WiredSource.on || WiredSource.address === ""
            horizontalAlignment: Text.AlignHCenter
            topPadding: Theme.px(8)
            bottomPadding: Theme.px(10)
            text: !WiredSource.on ? I18n.tr("Networking is off") : I18n.tr("No cable or no lease")
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textLabel
        }
    }
}
