import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../Common"
import "../Status"

// What the launcher's selection is: an image, a PDF's first page, the start of a text file, or an app's icon.
Item {
    id: root

    // { kind: "app", entry } or { kind: "file", file }, or null.
    property var item: null

    readonly property var file: item && item.kind === "file" ? item.file : null
    readonly property var entry: item && item.kind === "app" ? item.entry : null
    readonly property string kind: file ? FileSearch.kindOf(file) : ""
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-preview"

    property string textBody: ""
    property string pageImage: ""
    property string meta: ""

    onFileChanged: settle.restart()

    function sizeText(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"]
        let value = bytes
        let unit = 0
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000
            unit += 1
        }
        return (unit === 0 ? value : value.toFixed(value < 10 ? 1 : 0)) + " " + units[unit]
    }

    function run(process, command) {
        process.running = false
        process.command = command
        Qt.callLater(() => process.running = true)
    }

    // Arrowing through results shouldn't start a render per row passed.
    Timer {
        id: settle
        interval: 90
        onTriggered: {
            root.textBody = ""
            root.pageImage = ""
            root.meta = ""
            if (!root.file)
                return
            if (!root.file.isDir)
                root.run(stat, ["stat", "-c", "%s %Y", root.file.path])
            if (root.kind === "text")
                root.run(head, ["head", "-c", "2400", root.file.path])
            else if (root.kind === "pdf")
                root.run(render, ["sh", "-c", 'mkdir -p "$1" && pdftoppm -png -f 1 -l 1 -singlefile -scale-to 520 "$2" "$1/$3"',
                    "sh", root.cacheDir, root.file.path, Qt.md5(root.file.path)])
        }
    }

    Process {
        id: stat
        stdout: StdioCollector {
            onStreamFinished: {
                const [bytes, epoch] = text.trim().split(" ").map(Number)
                if (!isFinite(bytes))
                    return
                const when = new Date(epoch * 1000)
                root.meta = root.sizeText(bytes) + " · " + when.toLocaleDateString(Qt.locale(I18n.qtLocale), Locale.ShortFormat)
            }
        }
    }

    Process {
        id: head
        stdout: StdioCollector {
            onStreamFinished: root.textBody = text.includes("\u0000") ? "" : text
        }
    }

    Process {
        id: render
        property string path: ""
        onStarted: path = root.file ? root.cacheDir + "/" + Qt.md5(root.file.path) + ".png" : ""
        onExited: code => {
            if (code === 0 && root.file && path.endsWith(Qt.md5(root.file.path) + ".png"))
                root.pageImage = "file://" + path + "?" + Date.now()
        }
    }

    Rectangle {
        id: stage
        x: 0
        y: 0
        width: parent.width
        height: Math.min(parent.height - details.height - Theme.px(12), width * 1.05)
        readonly property bool boxed: root.kind === "image" || root.kind === "pdf"
        // Only an image is boxed, in a ruled frame. Text and icons sit straight on the panel.
        radius: Theme.radiusInput
        color: Theme.clear
        border.width: boxed ? 1 : 0
        border.color: Theme.edge
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: Theme.px(10)
            visible: root.kind === "image" || root.kind === "pdf"
            source: root.kind === "image" ? FileSearch.url(root.file.path) : root.kind === "pdf" ? root.pageImage : ""
            sourceSize: Qt.size(520, 520)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
        }

        Text {
            anchors.fill: parent
            anchors.margins: Theme.panelPad
            visible: root.kind === "text" && root.textBody !== ""
            text: root.textBody
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            clip: true
            color: Theme.textSecondary
            // Source text previews stay monospace on purpose.
            font.family: "monospace"
            font.pixelSize: Theme.textCaption
            lineHeight: 1.15
        }

        IconImage {
            readonly property bool fallback: root.entry !== null || root.kind === "folder" || root.kind === "other"
                || (root.kind === "text" && root.textBody === "")
            anchors.centerIn: parent
            visible: fallback && source != ""
            implicitSize: Theme.px(72)
            asynchronous: true
            source: root.entry ? AppSearch.icon(root.entry) : root.file ? FileSearch.icon(root.file) : ""
        }
    }

    Column {
        id: details
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        y: stage.height + Theme.px(10)
        spacing: 2

        Text {
            width: parent.width
            text: root.entry ? root.entry.name : root.file ? root.file.name : ""
            elide: Text.ElideMiddle
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textBody
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            text: root.entry ? (root.entry.comment || root.entry.genericName || "")
                : root.file ? root.file.dir : ""
            visible: text !== ""
            elide: root.entry ? Text.ElideRight : Text.ElideMiddle
            maximumLineCount: 2
            wrapMode: root.entry ? Text.Wrap : Text.NoWrap
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textLabel
        }

        Text {
            width: parent.width
            text: root.file ? (root.file.isDir ? I18n.tr("Folder") : root.meta) : ""
            visible: text !== ""
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textLabel
            font.features: { "tnum": 1 }
        }
    }
}
