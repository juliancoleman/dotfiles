import QtQuick

// A hairline on the page: between groups across the content width, or between side-by-side cells when
// `vertical`. Its weight is the pen's line (`Theme.line`).
Rectangle {
    property bool vertical: false

    implicitWidth: vertical ? Theme.line : 0
    implicitHeight: vertical ? 0 : Theme.line
    color: Theme.rule
}
