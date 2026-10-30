pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The installed applications, ranked against a query: the name counts most, then what the app is
// (generic name, keywords), then its description. Apps launched often rise among equally good matches.
Singleton {
    id: root

    readonly property string usagePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache"))
        + "/qs-launcher.json"
    property var usage: ({})

    readonly property var apps: {
        const seen = {}
        const out = []
        for (const entry of DesktopEntries.applications.values) {
            if (!entry || entry.noDisplay || seen[entry.id])
                continue
            seen[entry.id] = true
            out.push(entry)
        }
        return out.sort((a, b) => a.name.localeCompare(b.name))
    }

    // 0 when nothing matches; exact beats prefix beats a word's start beats anywhere beats scattered letters.
    // Only names match by scattered letters; a description holds nearly any short query's letters somewhere.
    function fieldScore(text, query, scattered) {
        const value = String(text || "").toLowerCase()
        if (!value)
            return 0
        if (value === query)
            return 100
        if (value.startsWith(query))
            return 80
        const at = value.indexOf(query)
        if (at > 0 && /[\s\-_.]/.test(value.charAt(at - 1)))
            return 65
        if (at > 0)
            return 45
        if (!scattered)
            return 0
        let from = 0
        let spread = 0
        for (const ch of query) {
            const next = value.indexOf(ch, from)
            if (next < 0)
                return 0
            spread += next - from
            from = next + 1
        }
        return Math.max(1, 25 - spread)
    }

    function score(entry, query) {
        const best = Math.max(
            fieldScore(entry.name, query, true),
            fieldScore(entry.genericName, query) * 0.7,
            Math.max(0, ...entry.keywords.map(k => fieldScore(k, query))) * 0.6,
            fieldScore(entry.comment, query) * 0.35)
        if (best <= 0)
            return 0
        const used = usage[entry.id]
        return best + (used ? Math.min(15, Math.log(used.count + 1) * 5) : 0)
    }

    function search(text) {
        const query = text.trim().toLowerCase()
        if (!query)
            return apps
        return apps.map(entry => ({ entry: entry, score: score(entry, query) }))
            .filter(hit => hit.score > 0)
            .sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name))
            .map(hit => hit.entry)
    }

    function icon(entry) {
        const name = entry ? entry.icon : ""
        if (name.startsWith("/"))
            return "file://" + name
        return Quickshell.iconPath(name, true) || Quickshell.iconPath("application-x-executable", true)
    }

    function launch(entry) {
        if (!entry)
            return
        const next = Object.assign({}, usage)
        const before = next[entry.id]
        next[entry.id] = { count: (before ? before.count : 0) + 1, last: Date.now() }
        usage = next
        store.setText(JSON.stringify(next))
        // DesktopEntry.execute() ignores Terminal=true, so those open in the terminal explicitly.
        if (entry.runInTerminal)
            Quickshell.execDetached(["ghostty", "-e"].concat(entry.command))
        else
            entry.execute()
    }

    FileView {
        id: store
        path: root.usagePath
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                root.usage = JSON.parse(text()) || {}
            } catch (error) {
                root.usage = {}
            }
        }
    }
}
