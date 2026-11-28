import QtQuick

// A quiet line on a page: what a list says when it has nothing to list.
Text {
    horizontalAlignment: Text.AlignHCenter
    topPadding: Theme.px(8)
    bottomPadding: Theme.px(10)
    color: Theme.textSecondary
    font.family: Theme.fontFamily
    font.pixelSize: Theme.textLabel
}
