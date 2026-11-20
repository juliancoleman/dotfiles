import QtQuick
import QtQuick.Effects

// What a notification shows in its round badge. A picture it carries fills the circle and is cut to it; an
// item's clip is always its bounding box, so it's masked instead. An app's logo is already shaped, so it sits
// whole within the circle's inscribed square rather than losing its corners.
Item {
    id: root

    property alias source: image.source
    property alias sourceSize: image.sourceSize
    property bool logo: false

    visible: image.status === Image.Ready

    Image {
        id: image
        anchors.centerIn: parent
        width: root.logo ? Math.round(root.width * Math.SQRT1_2) : root.width
        height: root.logo ? Math.round(root.height * Math.SQRT1_2) : root.height
        fillMode: root.logo ? Image.PreserveAspectFit : Image.PreserveAspectCrop
        asynchronous: true
        layer.enabled: root.visible && !root.logo
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            // Thresholded at the mask's antialiased edge and spread across it, so the rim stays smooth.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }
    }

    Item {
        id: mask
        anchors.fill: parent
        visible: false
        layer.enabled: root.visible && !root.logo
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            radius: width / 2
        }
    }
}
