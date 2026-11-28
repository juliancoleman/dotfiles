import QtQuick
import "../Common"

// One page of the control center. Declaring it is all a page needs: it shows while the panel's `page` is
// its `name`, sits where every page sits, and while it shows the panel takes its title and height from it.
// Its one child is the page's content, whose implicitHeight is the page's height.
PageLayer {
    id: layer

    // The ControlCenter this page belongs to.
    required property var panel
    required property string name
    property string title: ""
    // Showing now. A page that answers to more than its own name (settings and its sections) overrides it.
    property bool current: panel.page === name
    // For content that should only work while it is seen.
    readonly property bool active: panel.opened && current
    readonly property Item pageItem: children.length > 0 ? children[0] : null

    motion: panel.motion
    shown: current
    x: panel.pad
    y: panel.contentY
    width: panel.gridWidth
    height: pageItem ? pageItem.implicitHeight : 0
}
