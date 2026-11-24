pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Common"

// Photos from an Immich library, asked for in plain words: "at the beach", or "Cambria at the beach" once a
// person carries that name there. A named person narrows the search to their photos and the rest of the words
// describe the picture; a name alone lists their latest. Off unless `launcher.photos` names the server.
// curl reads the API key from `photos.key` beside the config file, so it is never in this process or on a
// command line. Thumbnails land in `$XDG_RUNTIME_DIR/qs-photos` and are gone at logout.
Singleton {
    id: root

    readonly property string server: ClockConfig.photosUrl
    readonly property bool enabled: server !== ""
    readonly property string keyFile: ClockConfig.path.slice(0, ClockConfig.path.lastIndexOf("/") + 1) + "photos.key"
    readonly property string cacheDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-photos"
    readonly property int shown: 24
    readonly property int requestTimeout: 10
    // Named people change rarely; asked again once the list is this old, in ms.
    readonly property int peopleFor: 600000
    // Words that join names without describing anything: "Cambria and Lindsay".
    readonly property var joiners: ["and", "with", "&", "+", "of", "the"]

    property string query: ""
    property string ranFor: ""
    property var results: []
    // [{ id, forms }]: each named person with the ways they can be written, longest name first.
    property var people: []
    property real peopleAt: 0
    property int generation: 0
    // Renditions fetched since the shell started, by file path.
    property var cached: ({})

    onEnabledChanged: {
        people = []
        peopleAt = 0
        search("")
    }

    function search(text) {
        query = text
        if (!enabled || text.length < 3) {
            pending.stop()
            generation += 1
            results = []
            ranFor = ""
            return
        }
        pending.restart()
    }

    // Called as the launcher opens, so a name typed alone is recognized before anything was searched.
    function warm() {
        if (!enabled || peopleAt > 0 && Date.now() - peopleAt < peopleFor)
            return
        ask("/people?size=1000", null, function (answer) {
            if (!answer || !answer.people)
                return
            root.people = root.named(answer.people)
            root.peopleAt = Date.now()
        })
    }

    // Whether a query without a prefix reads as a description: several words, or someone's name.
    function describes(text) {
        const words = text.trim().split(/\s+/).filter(word => word !== "")
        return words.length >= 2 || split(text).ids.length > 0
    }

    // The people a query names, and the words left over to describe the picture.
    function split(text) {
        let rest = " " + text.toLowerCase().replace(/[\s,]+/g, " ").trim() + " "
        const ids = []
        for (const person of people) {
            for (const form of person.forms) {
                const at = rest.indexOf(" " + form + " ")
                if (at < 0)
                    continue
                ids.push(person.id)
                rest = rest.slice(0, at) + rest.slice(at + form.length + 1)
                break
            }
        }
        const words = rest.trim().split(" ").filter(word => word !== "")
        return { ids: ids, rest: words.every(word => joiners.includes(word)) ? "" : words.join(" ") }
    }

    // A person answers to their full name, and to their first name when nobody else shares it.
    function named(list) {
        const firsts = {}
        const known = list.filter(person => person.name && person.name.trim() !== "")
            .map(person => ({ id: person.id, name: person.name.trim().toLowerCase().replace(/\s+/g, " ") }))
        for (const person of known) {
            const first = person.name.split(" ")[0]
            firsts[first] = (firsts[first] || 0) + 1
        }
        return known.map(person => {
            const first = person.name.split(" ")[0]
            const forms = [person.name]
            if (first !== person.name && first.length >= 3 && firsts[first] === 1)
                forms.push(first)
            return { id: person.id, forms: forms }
        }).sort((a, b) => b.forms[0].length - a.forms[0].length)
    }

    function describe(asset) {
        const exif = asset.exifInfo || {}
        const thumbPath = cacheDir + "/" + asset.id + ".webp"
        return {
            id: asset.id,
            name: asset.originalFileName || "",
            when: asset.localDateTime || asset.fileCreatedAt || "",
            place: [exif.city, exif.state].filter(part => !!part).join(", ") || exif.country || "",
            video: asset.type === "VIDEO",
            thumbPath: thumbPath,
            thumb: "file://" + thumbPath
        }
    }

    // "2015-06-14T10:22:33.000Z" is the camera's local time; only its date is read.
    function dayText(photo, format) {
        const parts = photo.when.slice(0, 10).split("-").map(Number)
        if (parts.length !== 3 || parts.some(part => !isFinite(part)))
            return ""
        return new Date(parts[0], parts[1] - 1, parts[2])
            .toLocaleDateString(Qt.locale(I18n.qtLocale), format === undefined ? Locale.ShortFormat : format)
    }

    function open(photo) {
        Quickshell.execDetached(["xdg-open", server + "/photos/" + photo.id])
    }

    // curl up to the request itself: quiet, failing on HTTP errors, with the key read from its file.
    function curlArgs() {
        return ["curl", "-sf", "--max-time", String(requestTimeout), "--variable", "key@" + keyFile,
            "--expand-header", "x-api-key: {{key:trim}}"]
    }

    // `done` gets the parsed answer, or null when the request or its JSON failed.
    function ask(path, body, done) {
        const args = curlArgs()
        if (body !== null)
            args.push("-H", "Content-Type: application/json", "-d", JSON.stringify(body))
        args.push(server + "/api" + path)
        const request = fetcher.createObject(root, { command: args })
        request.finished.connect(function (text) {
            request.destroy()
            let parsed = null
            try {
                parsed = JSON.parse(text)
            } catch (problem) {
                parsed = null
            }
            done(parsed)
        })
        request.running = true
    }

    // Fetches every { url, path } not yet on disk with one curl; `done` gets whether all of them arrived.
    function download(files, done) {
        const wanted = files.filter(file => !cached[file.path])
        if (wanted.length === 0) {
            done(true)
            return
        }
        const args = curlArgs().concat(["--parallel", "--parallel-max", "8", "--create-dirs"])
        for (const file of wanted)
            args.push("-o", file.path, file.url)
        const request = fetcher.createObject(root, { command: args })
        request.exited.connect(function (code) {
            request.destroy()
            if (code === 0) {
                for (const file of wanted)
                    root.cached[file.path] = true
            }
            done(code === 0)
        })
        request.running = true
    }

    function run() {
        generation += 1
        const asked = generation
        const text = query
        const parts = split(text)
        const body = { size: shown, withExif: true }
        if (parts.ids.length > 0)
            body.personIds = parts.ids
        if (parts.rest !== "")
            body.query = parts.rest
        // A name alone has nothing to describe: that person's photos, newest first.
        ask(parts.rest !== "" ? "/search/smart" : "/search/metadata", body, function (answer) {
            if (asked !== root.generation)
                return
            const items = answer && answer.assets && answer.assets.items ? answer.assets.items : []
            const found = items.map(root.describe)
            const thumbs = found.map(photo => ({
                url: root.server + "/api/assets/" + photo.id + "/thumbnail?size=thumbnail",
                path: photo.thumbPath
            }))
            root.download(thumbs, function () {
                if (asked !== root.generation)
                    return
                root.results = found
                root.ranFor = text
            })
        })
    }

    // The larger rendition for the preview pane; `done` gets its file URL, or "" when it couldn't be fetched.
    function preview(photo, done) {
        const path = cacheDir + "/" + photo.id + ".jpg"
        download([{ url: server + "/api/assets/" + photo.id + "/thumbnail?size=preview", path: path }],
                 ok => done(ok ? "file://" + path : ""))
    }

    // Longer than the file search's wait: each ask is a request to the library, not a local scan.
    Timer {
        id: pending
        interval: 250
        onTriggered: root.run()
    }

    Component {
        id: fetcher

        Process {
            id: request
            // The whole of standard output once it closes; empty when curl failed (-f prints nothing).
            signal finished(string text)
            stdout: StdioCollector {
                onStreamFinished: request.finished(text)
            }
        }
    }
}
