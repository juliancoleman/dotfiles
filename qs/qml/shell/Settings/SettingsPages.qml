import QtQuick
import ".."
import "../Common"
import "../Control"

// Settings as control-center pages: the section list, and one page of controls per section. The control
// center owns navigation and the header; this draws whichever page `section` names ("" for the list),
// sliding between them like the control center's own pages.
Item {
    id: root

    property string section: ""
    property string motion: "easeOut"
    property bool active: false
    // Taller pages, like Weather with its city search, scroll past this.
    property real maxHeight: Infinity
    signal sectionChosen(string id)

    // Asked again each visit, since the switch can change outside the shell.
    onActiveChanged: if (active) LocationServices.check()

    implicitHeight: {
        if (section !== "") {
            for (let i = 0; i < pages.count; ++i) {
                const page = pages.itemAt(i)
                if (page && page.modelData.id === section)
                    return page.height
            }
        }
        return sectionList.height
    }

    PageLayer {
        id: sectionList
        home: true
        motion: root.motion
        shown: root.section === ""
        width: root.width
        height: Math.min(root.maxHeight, list.implicitHeight)

        MomentumFlickable {
            anchors.fill: parent
            contentHeight: list.implicitHeight

            Column {
                id: list
                width: parent.width
                spacing: 2

                Repeater {
                    model: SettingsModel.sections

                    ListRow {
                        required property var modelData
                        width: list.width
                        icon: modelData.icon
                        title: modelData.title
                        trailing: "chevron-right"
                        onActivated: root.sectionChosen(modelData.id)
                    }
                }
            }
        }
    }

    Repeater {
        id: pages
        model: SettingsModel.sections

        PageLayer {
            id: page
            required property var modelData
            motion: root.motion
            shown: root.section === modelData.id
            width: root.width
            height: Math.min(root.maxHeight, controls.implicitHeight)

            MomentumFlickable {
                anchors.fill: parent
                contentHeight: controls.implicitHeight

                Column {
                    id: controls
                    width: parent.width
                    spacing: 12

                    Repeater {
                        model: page.modelData.controls

                        SettingControl {
                            required property var modelData
                            control: modelData
                            width: controls.width
                        }
                    }
                }
            }
        }
    }
}
