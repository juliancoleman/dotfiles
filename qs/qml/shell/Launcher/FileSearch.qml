pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Files and folders in the home folder whose names contain the query, via fd: hidden and gitignored paths stay out.
// Names that start with the query rank first, then those with it at a word's start; shallower paths break ties.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property int shown: 40
    property string query: ""
    property string ranFor: ""
    property var results: []

    readonly property var images: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif"]
    readonly property var texts: ["txt", "md", "markdown", "json", "nix", "qml", "js", "ts", "tsx", "jsx", "py", "rs",
        "sh", "fish", "toml", "yaml", "yml", "conf", "ini", "cfg", "csv", "log", "c", "h", "cpp", "hpp", "go", "html",
        "css", "kdl", "lua", "xml", "rb", "java", "kt", "swift", "sql", "diff", "patch", "env", "org", "tex"]

    function search(text) {
        query = text
        if (text.length === 0) {
            pending.stop()
            results = []
            ranFor = ""
            return
        }
        pending.restart()
    }

    // What a path is for previewing and picking an icon.
    function kindOf(file) {
        if (file.isDir)
            return "folder"
        if (images.includes(file.ext))
            return "image"
        if (file.ext === "pdf")
            return "pdf"
        if (texts.includes(file.ext) || file.ext === "")
            return "text"
        return "other"
    }

    function icon(file) {
        switch (kindOf(file)) {
        case "folder":
            return Quickshell.iconPath("folder", true)
        case "image":
            return Quickshell.iconPath("image-x-generic", true)
        case "pdf":
            return Quickshell.iconPath("application-pdf", true)
        case "text":
            return Quickshell.iconPath("text-x-generic", true)
        case "other":
            return Quickshell.iconPath("application-x-generic", true)
        default:
            return ""
        }
    }

    // Names may hold spaces, "#", or "?", which a bare "file://" + path would misread.
    function url(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    // "~/Pictures/Screenshots" for showing where a file lives.
    function tilde(path) {
        return path.startsWith(home + "/") ? "~" + path.slice(home.length) : path
    }

    function describe(line) {
        const isDir = line.endsWith("/")
        const path = isDir ? line.slice(0, -1) : line
        const slash = path.lastIndexOf("/")
        const name = path.slice(slash + 1)
        const dot = name.lastIndexOf(".")
        return {
            path: path,
            name: name,
            dir: tilde(path.slice(0, slash) || "/"),
            isDir: isDir,
            ext: !isDir && dot > 0 ? name.slice(dot + 1).toLowerCase() : "",
            depth: path.slice(home.length).split("/").length
        }
    }

    function score(file, needle) {
        const name = file.name.toLowerCase()
        const at = name.indexOf(needle)
        const base = name === needle || name.startsWith(needle + ".") ? 100
            : at === 0 ? 80
            : at > 0 && /[\s\-_.]/.test(name.charAt(at - 1)) ? 65
            : 45
        return base - Math.min(20, file.depth * 2) + (file.isDir ? 4 : 0)
    }

    Timer {
        id: pending
        interval: 60
        onTriggered: {
            finder.running = false
            finder.command = ["fd", "--ignore-case", "--fixed-strings", "--absolute-path", "--type", "f", "--type", "d",
                "--max-results", "400", "--", root.query, root.home]
            finder.searching = root.query
            Qt.callLater(() => finder.running = true)
        }
    }

    Process {
        id: finder
        property string searching: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (finder.searching !== root.query)
                    return
                const needle = root.query.toLowerCase()
                root.results = text.split("\n").filter(line => line.length > 0)
                    .map(root.describe)
                    .map(file => ({ file: file, score: root.score(file, needle) }))
                    .sort((a, b) => b.score - a.score || a.file.path.length - b.file.path.length)
                    .slice(0, root.shown)
                    .map(hit => hit.file)
                root.ranFor = finder.searching
            }
        }
    }
}
