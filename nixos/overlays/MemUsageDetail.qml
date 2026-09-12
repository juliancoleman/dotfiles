import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    LayoutMirroring.enabled: I18n.isRtl
    LayoutMirroring.childrenInherit: true

    readonly property real usage: DgopService.memoryUsage || 0
    readonly property var topProcesses: {
        const procs = DgopService.processes || [];
        return procs.slice(0, 4);
    }

    implicitHeight: contentColumn.implicitHeight + Theme.spacingL * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHigh, Theme.popupTransparency)
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.08)
    border.width: 0

    Component.onCompleted: {
        DgopService.addRef(["memory", "processes"]);
        DgopService.setSortBy("memory");
    }
    Component.onDestruction: {
        DgopService.removeRef(["memory", "processes"]);
    }

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingL * 2
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        Row {
            width: parent.width
            spacing: Theme.spacingM

            DankIcon {
                name: "developer_board"
                size: Theme.iconSizeLarge
                color: root.usage > 90 ? Theme.error : (root.usage > 75 ? Theme.warning : Theme.primary)
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                width: parent.width - Theme.iconSizeLarge - parent.spacing

                StyledText {
                    text: I18n.tr("Memory")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                StyledText {
                    text: DgopService.totalMemoryKB > 0 ? `${DgopService.formatSystemMemory(DgopService.usedMemoryKB)} / ${DgopService.formatSystemMemory(DgopService.totalMemoryKB)}` : "--"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 10
            radius: 5
            color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

            Rectangle {
                width: parent.width * Math.min(root.usage / 100, 1)
                height: parent.height
                radius: parent.radius
                color: root.usage > 90 ? Theme.error : (root.usage > 75 ? Theme.warning : Theme.primary)
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.shortDuration
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: Theme.spacingM

            Repeater {
                model: [
                    {
                        label: I18n.tr("Usage"),
                        value: root.usage > 0 ? `${root.usage.toFixed(0)}%` : "--"
                    },
                    {
                        label: I18n.tr("Available"),
                        value: DgopService.formatSystemMemory(DgopService.availableMemoryMB > 0 ? DgopService.availableMemoryMB * 1024 : DgopService.freeMemoryMB * 1024)
                    },
                    {
                        label: I18n.tr("Swap"),
                        value: DgopService.totalSwapKB > 0 ? DgopService.formatSystemMemory(DgopService.usedSwapKB) : I18n.tr("None")
                    }
                ]

                StyledRect {
                    required property var modelData
                    width: (parent.width - Theme.spacingM * 2) / 3
                    height: 56
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.primary
                            font.weight: Font.Medium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: modelData.value
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingXS

            StyledText {
                text: I18n.tr("Top processes")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
            }

            Repeater {
                model: root.topProcesses

                Row {
                    required property var modelData
                    width: parent.width
                    spacing: Theme.spacingS
                    height: 22

                    StyledText {
                        text: DgopService.formatSystemMemory(modelData.memoryKB || 0)
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                        width: 56
                        horizontalAlignment: Text.AlignRight
                    }

                    StyledText {
                        text: modelData.command || modelData.name || "?"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        elide: Text.ElideRight
                        width: parent.width - 56 - parent.spacing
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: Theme.cornerRadius
            z: 20
            color: Theme.withAlpha(Theme.primary, monitorMouse.containsMouse ? 0.18 : 0.10)

            StyledText {
                anchors.centerIn: parent
                text: I18n.tr("Open system monitor")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.primary
            }

            MouseArea {
                id: monitorMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    DgopService.setSortBy("memory");
                    if (PopoutService.processListModalLoader)
                        PopoutService.processListModalLoader.active = true;
                    Qt.callLater(() => {
                        const modal = PopoutService.processListModal;
                        if (!modal)
                            return;
                        modal.currentTab = 1;
                        modal.show();
                    });
                }
            }
        }
    }
}
