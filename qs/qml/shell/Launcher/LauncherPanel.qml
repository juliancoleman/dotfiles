import QtQuick
import Quickshell
import Quickshell.Widgets
import ".."
import "../Common"
import "../Settings"
import "../Status"

// Super+Space: the bar's housing (`from`) grows into a search over applications, the home folder's files,
// and settings, shown as a list, large icons, or small icons. "@" narrows to applications, "/" to files, and
// ">" to settings; choosing a setting opens the control center at its section. Without a prefix, apps come
// first, then files, then settings. Math answers above them all, and Enter copies it. While files are among
// the results, a pane beside them previews the selection.
Item {
    id: root

    property string edge: "top"
    property rect from: Qt.rect(0, 0, 0, 0)
    property real notch: 0
    property string motion: "easeOut"
    property bool shown: false

    // A settings result was chosen; the bar opens its control center on this section, on the same screen.
    signal settingChosen(string section)

    readonly property real listW: 400
    readonly property real previewW: 270
    // The preview opens away from a side edge so the list stays where it was.
    readonly property bool previewLeft: edge === "right"
    readonly property bool showPreview: fileResults.length > 0
    readonly property real maxW: listW + previewW
    property real openW: listW + (showPreview ? previewW : 0)
    Behavior on openW {
        enabled: root.shown && root.pc > 0.999
        NumberAnimation {
            duration: Theme.durationFor(root.motion)
            easing.type: Easing.OutCubic
        }
    }
    // Fits what's showing, so a lone answer opens short; past this the results scroll.
    readonly property real maxH: 450
    readonly property real fitH: Math.min(maxH, Math.max(showPreview ? 340 : 0, grid.y + Theme.panelPad - 2
        + (results.length > 0 ? grid.contentHeight : calc ? 0 : 60)))
    property real openH: fitH
    Behavior on openH {
        enabled: root.shown && root.pc > 0.999
        NumberAnimation {
            duration: Theme.durationFor(root.motion)
            easing.type: Easing.OutCubic
        }
    }
    property real openProgress: 0
    readonly property real p: Math.max(0, openProgress)
    readonly property real pc: Math.min(1, p)
    property alias housingItem: card

    property string query: ""
    readonly property string mode: query.startsWith("@") ? "apps" : query.startsWith("/") ? "files"
        : query.startsWith(">") ? "settings" : "all"
    readonly property string term: mode === "all" ? query : query.slice(1)
    readonly property var calc: mode === "all" ? Calculator.evaluate(query) : null
    readonly property var appResults: mode === "apps" || mode === "all" ? AppSearch.search(term) : []
    // Mixed in once the query says something; one letter would match most of the home folder.
    readonly property string fileTerm: mode === "files" ? term.trim()
        : mode === "all" && !calc && term.trim().length >= 2 ? term.trim() : ""
    readonly property var fileResults: fileTerm === "" ? [] : FileSearch.results
    // Mixed in once something is typed; an empty search would list every setting.
    readonly property var settingResults: mode === "settings" || mode === "all" && !calc && term.trim() !== ""
        ? SettingsModel.search(term) : []
    readonly property var results: appResults.map(entry => ({ kind: "app", entry: entry }))
        .concat(fileResults.map(file => ({ kind: "file", file: file })))
        .concat(settingResults.map(hit => ({ kind: "setting", section: hit.section, control: hit.control })))
    readonly property var selected: calcSelected ? null : results[grid.currentIndex] || null
    // A result is selected when it appears, so Enter copies it; arrowing down moves into the apps.
    property bool calcFocused: true
    readonly property bool calcSelected: calc !== null && calcFocused
    // Opens in the default from settings; the toggles switch it for this time only.
    property string view: ClockConfig.launcherView
    readonly property bool listView: view === "list"

    x: edge === "right" ? from.x + from.width - width
        : edge === "left" ? from.x
        : from.x + (from.width - width) / 2
    y: edge === "bottom" ? from.y + from.height - height
        : edge === "top" ? from.y
        : from.y + (from.height - height) / 2
    width: from.width + (openW - from.width) * p
    height: from.height + (openH - from.height) * p
    visible: p > 0.001

    function corner(outer) {
        const radius = Math.min(from.width, from.height) / 2 * (1 - pc) + 18 * pc
        return outer ? radius * (1 - notch) : radius
    }

    function refocus() {
        Qt.callLater(function () {
            if (root.shown)
                input.forceActiveFocus()
        })
    }

    function launch(item) {
        if (!item)
            return
        LauncherState.close()
        if (item.kind === "app")
            AppSearch.launch(item.entry)
        else if (item.kind === "file")
            Quickshell.execDetached(["xdg-open", item.file.path])
        else
            settingChosen(item.section.id)
    }

    function setView(next) {
        if (view === next)
            return
        view = next
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
    }

    function copyResult() {
        Quickshell.execDetached(["wl-copy", "--", calc.copy])
        LauncherState.close()
    }

    onQueryChanged: calcFocused = true
    onFileTermChanged: FileSearch.search(fileTerm)
    onResultsChanged: grid.currentIndex = 0

    onShownChanged: {
        openEase.stop()
        if (Theme.durationFor(motion) === 0) {
            openProgress = shown ? 1 : 0
        } else {
            openEase.from = openProgress
            openEase.to = shown ? 1 : 0
            openEase.start()
        }
        if (shown) {
            view = ClockConfig.launcherView
            input.text = ""
            grid.currentIndex = 0
            grid.positionViewAtBeginning()
            refocus()
        } else {
            input.focus = false
        }
    }

    NumberAnimation {
        id: openEase
        target: root
        property: "openProgress"
        duration: Theme.durationFor(root.motion)
        easing.type: Theme.easingFor(root.motion)
        easing.overshoot: Theme.springOvershoot
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Theme.surface
        clip: true
        topLeftRadius: root.corner(root.edge === "top" || root.edge === "left")
        topRightRadius: root.corner(root.edge === "top" || root.edge === "right")
        bottomLeftRadius: root.corner(root.edge === "bottom" || root.edge === "left")
        bottomRightRadius: root.corner(root.edge === "bottom" || root.edge === "right")

        MouseArea {
            anchors.fill: parent
            onPressed: root.refocus()
        }

        Item {
            id: body
            width: root.openW
            height: root.openH
            x: root.edge === "right" ? parent.width - width
                : root.edge === "left" ? 0
                : (parent.width - width) / 2
            y: root.edge === "bottom" ? parent.height - height
                : root.edge === "top" ? 0
                : (parent.height - height) / 2
            opacity: Math.max(0, (root.pc - 0.35) / 0.65)

            FilePreview {
                x: root.previewLeft ? Theme.panelPad : root.listW - 4
                y: Theme.panelPad
                width: root.previewW - Theme.panelPad - 4
                height: parent.height - Theme.panelPad * 2
                visible: root.showPreview || body.width > root.listW + 1
                opacity: Math.max(0, (body.width - root.listW) / root.previewW)
                item: root.selected
            }

            Item {
                id: listArea
                x: root.previewLeft ? parent.width - width : 0
                width: root.listW
                height: parent.height

                Rectangle {
                    id: field
                    x: Theme.panelPad
                    y: Theme.panelPad
                    width: parent.width - Theme.panelPad * 2
                    height: 34
                    radius: 10
                    color: Theme.track
                    border.width: 1
                    border.color: input.activeFocus ? Theme.today : Qt.rgba(1, 1, 1, 0.08)

                    StatusGlyph {
                        id: leader
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13
                        height: 13
                        icon: "search"
                        ink: Theme.textSecondary
                        cutColor: field.color
                    }

                    Text {
                        anchors.fill: input
                        visible: input.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                        text: qsTr("Search  ·  @ apps  ·  / files  ·  > settings")
                        color: Theme.textSecondary
                        font: input.font
                    }

                    TextInput {
                        id: input
                        anchors.left: leader.right
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: parent.height - 8
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Theme.textPrimary
                        selectionColor: Theme.today
                        selectedTextColor: Theme.todayInk
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        Accessible.role: Accessible.EditableText
                        Accessible.name: qsTr("Search")
                        onTextChanged: root.query = text

                        Keys.onPressed: event => {
                            const atEnd = input.cursorPosition === input.text.length
                            if (event.key === Qt.Key_Escape) {
                                LauncherState.close()
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (root.calcSelected)
                                    root.copyResult()
                                else
                                    root.launch(root.selected)
                            } else if (event.key === Qt.Key_Down) {
                                if (root.calcSelected)
                                    root.calcFocused = false
                                else
                                    grid.moveCurrentIndexDown()
                            } else if (event.key === Qt.Key_Up) {
                                if (root.calc && grid.currentIndex < grid.columns)
                                    root.calcFocused = true
                                else
                                    grid.moveCurrentIndexUp()
                            } else if (root.calcSelected && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
                                return
                            } else if (!root.listView && atEnd && event.key === Qt.Key_Right) {
                                grid.moveCurrentIndexRight()
                            } else if (!root.listView && atEnd && event.key === Qt.Key_Left) {
                                grid.moveCurrentIndexLeft()
                            } else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
                                root.setView(["list", "large", "small"][event.key - Qt.Key_1])
                            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                const order = ["list", "large", "small"]
                                const step = event.key === Qt.Key_Tab ? 1 : order.length - 1
                                root.setView(order[(order.indexOf(root.view) + step) % order.length])
                            } else {
                                return
                            }
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    id: answer
                    x: Theme.panelPad
                    y: field.y + field.height + (visible ? 8 : 0)
                    width: parent.width - Theme.panelPad * 2
                    height: visible ? 60 : 0
                    visible: root.calc !== null
                    radius: 12
                    color: root.calcSelected ? Theme.ink : Theme.track
                    border.width: root.calcSelected ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    Accessible.role: Accessible.Button
                    Accessible.name: root.calc ? qsTr("Copy %1").arg(root.calc.text) : ""

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: hint.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            width: parent.width
                            text: root.query.trim()
                            elide: Text.ElideRight
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        Text {
                            width: parent.width
                            text: root.calc ? root.calc.text : ""
                            elide: Text.ElideRight
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: 22
                            font.weight: Font.Light
                            font.features: { "tnum": 1 }
                        }
                    }

                    Text {
                        id: hint
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.calcSelected
                        text: qsTr("Enter to copy")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.calcFocused = true
                        onClicked: root.copyResult()
                    }
                }

                Item {
                    id: header
                    x: 16
                    y: answer.y + answer.height + 6
                    visible: !root.calc || root.results.length > 0
                    height: visible ? 36 : 0
                    width: parent.width - 28

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14

                        Repeater {
                            model: [
                                { title: qsTr("Applications"), count: root.appResults.length,
                                  shown: root.mode === "apps" || (root.mode === "all"
                                      && (root.appResults.length > 0
                                          || root.fileResults.length === 0 && root.settingResults.length === 0)) },
                                { title: qsTr("Files"), count: root.fileResults.length,
                                  shown: root.mode === "files" || root.fileResults.length > 0 },
                                { title: qsTr("Settings"), count: root.settingResults.length,
                                  shown: root.mode === "settings" || root.settingResults.length > 0 }
                            ].filter(section => section.shown)

                            Row {
                                required property var modelData
                                spacing: 6

                                Text {
                                    id: title
                                    text: modelData.title
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    anchors.baseline: title.baseline
                                    text: modelData.count
                                    color: Theme.textSecondary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Repeater {
                            model: [
                                { view: "list", icon: "view-list", name: qsTr("List") },
                                { view: "large", icon: "view-large", name: qsTr("Large icons") },
                                { view: "small", icon: "view-small", name: qsTr("Small icons") }
                            ]

                            Rectangle {
                                required property var modelData
                                readonly property bool chosen: root.view === modelData.view
                                width: 26
                                height: 24
                                radius: 7
                                color: chosen ? Theme.ink : toggleHit.containsMouse ? Theme.track : "transparent"
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.name

                                StatusGlyph {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    icon: modelData.icon
                                    ink: chosen ? Theme.textPrimary : Theme.textSecondary
                                }

                                MouseArea {
                                    id: toggleHit
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setView(modelData.view)
                                }
                            }
                        }
                    }
                }

                GridView {
                    id: grid
                    readonly property int columns: root.listView ? 1
                        : Math.max(1, Math.floor(width / (root.view === "small" ? 76 : 96)))
                    // Cells inset their highlight by 2, so the grid sits 2 short of the gutter.
                    x: Theme.panelPad - 2
                    y: header.y + header.height
                    width: parent.width - (Theme.panelPad - 2) * 2
                    height: parent.height - y - (Theme.panelPad - 2)
                    clip: true
                    model: root.results
                    cellWidth: Math.floor(width / columns)
                    cellHeight: root.listView ? 40 : root.view === "small" ? 70 : 88
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    currentIndex: 0
                    keyNavigationEnabled: false

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool current: GridView.isCurrentItem
                        readonly property bool isApp: modelData.kind === "app"
                        readonly property bool isSetting: modelData.kind === "setting"
                        readonly property var file: modelData.kind === "file" ? modelData.file : null
                        readonly property string label: isApp ? modelData.entry.name
                            : isSetting ? modelData.control.title : file.name
                        // A setting reads where it lives and what it's set to: "Theme · Pill".
                        readonly property string comment: isApp
                            ? (modelData.entry.genericName || modelData.entry.comment)
                            : isSetting ? [modelData.section.title, SettingsModel.valueLabel(modelData.control)]
                                .filter(part => part !== "").join(" · ")
                            : file.dir
                        readonly property bool thumbnail: !!file && FileSearch.kindOf(file) === "image"
                        width: grid.cellWidth
                        height: grid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 10
                            color: cell.current && !root.calcSelected ? Theme.ink : "transparent"
                        }

                        IconImage {
                            id: icon
                            readonly property int size: root.listView ? 24 : root.view === "small" ? 26 : 38
                            implicitSize: size
                            asynchronous: true
                            source: cell.thumbnail || cell.isSetting ? ""
                                : cell.isApp ? AppSearch.icon(cell.modelData.entry) : FileSearch.icon(cell.file)
                            x: root.listView ? 10 : (cell.width - size) / 2
                            y: root.listView ? (cell.height - size) / 2 : root.view === "small" ? 11 : 13

                            Image {
                                anchors.fill: parent
                                visible: cell.thumbnail
                                source: cell.thumbnail ? FileSearch.url(cell.file.path) : ""
                                sourceSize: Qt.size(icon.size * 2, icon.size * 2)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }

                            // Whatever the icon theme can't find gets the app's initial or the file's extension;
                            // settings, which have no icon of their own, get the gear.
                            Rectangle {
                                anchors.fill: parent
                                visible: !cell.thumbnail && (icon.source == "" || icon.status === Image.Error)
                                radius: width * 0.24
                                color: Theme.ink

                                StatusGlyph {
                                    anchors.centerIn: parent
                                    visible: cell.isSetting
                                    width: parent.width * 0.6
                                    height: width
                                    icon: cell.isSetting ? cell.modelData.control.icon || cell.modelData.section.icon : ""
                                    cutColor: Theme.ink
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !cell.isSetting
                                    width: parent.width - 4
                                    horizontalAlignment: Text.AlignHCenter
                                    fontSizeMode: Text.HorizontalFit
                                    minimumPixelSize: 6
                                    text: cell.isApp ? cell.label.charAt(0).toUpperCase()
                                        : cell.isSetting ? ""
                                        : (cell.file.ext || (cell.file.isDir ? "dir" : "file")).slice(0, 4).toUpperCase()
                                    color: Theme.textPrimary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: parent.width * (cell.isApp ? 0.46 : 0.3)
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Text {
                            id: name
                            x: root.listView ? icon.x + icon.size + 11 : 5
                            width: root.listView ? cell.width - x - 10 : cell.width - 10
                            y: root.listView
                                ? (cell.comment ? cell.height / 2 - implicitHeight + 1 : (cell.height - implicitHeight) / 2)
                                : icon.y + icon.size + 6
                            text: cell.label
                            color: Theme.textPrimary
                            horizontalAlignment: root.listView ? Text.AlignLeft : Text.AlignHCenter
                            elide: cell.file ? Text.ElideMiddle : Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: root.listView ? 12 : 11
                            font.weight: Font.Medium
                        }

                        Text {
                            visible: root.listView && !!cell.comment
                            x: name.x
                            width: name.width
                            y: cell.height / 2 + 1
                            text: cell.comment
                            color: Theme.textSecondary
                            elide: cell.file ? Text.ElideMiddle : Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPositionChanged: {
                                grid.currentIndex = cell.index
                                root.calcFocused = false
                            }
                            onClicked: root.launch(cell.modelData)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.results.length === 0 && !root.calc
                        text: root.mode === "files" && root.fileTerm === ""
                            ? qsTr("Type to search your home folder") : qsTr("No matches")
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
