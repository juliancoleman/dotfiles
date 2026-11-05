import QtQuick

// Rows of a control page, straight on the page. Past `maxHeight` the rows scroll.
Item {
    id: group

    default property alias rows: column.data
    property real maxHeight: Infinity
    property alias spacing: column.spacing

    // Nothing shown, no height taken.
    implicitHeight: column.implicitHeight > 0 ? flick.height : 0

    MomentumFlickable {
        id: flick
        width: parent.width
        height: Math.min(group.maxHeight, column.implicitHeight)
        contentHeight: column.implicitHeight
        interactive: contentHeight > height

        Column {
            id: column
            width: flick.width
        }
    }
}
