import QtQuick

// The caption over a section: a sentence-case caption written on a rule.
Item {
    id: header

    property string text: ""

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + Theme.px(4) + Theme.line

    Text {
        id: label
        anchors.left: parent.left
        anchors.right: parent.right
        text: header.text
        elide: Text.ElideRight
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textCaption
        font.weight: Font.Normal
    }

    Rule {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: Theme.line
    }
}
