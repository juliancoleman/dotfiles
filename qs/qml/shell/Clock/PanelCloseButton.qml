import QtQuick

// The close action in a panel's header. It stands where the panel's trigger was, so the pointer that
// opened the panel is already on it, and it comes in with the panel (`opened`, the panel's open progress).
SettingsButton {
    // The trigger's centre along the header, in the header's coordinates.
    required property real triggerCenter

    icon: "close"
    anchors.verticalCenter: parent.verticalCenter
    x: triggerCenter - width / 2
}
