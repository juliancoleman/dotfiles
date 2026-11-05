pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Color roles generated from the wallpaper by matugen, for the "matugen" palette. Regenerated each time
// that palette is chosen; the last result is cached so the shell opens in its own colors rather than the
// pens' while matugen runs. Until anything has been generated, `roles` is null and Theme keeps the pens.
Singleton {
    id: root

    readonly property string wallpaper: Quickshell.env("QS_WALLPAPER") || "/etc/qs/wallpaper"
    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") || "") + "/.cache")
        + "/qs-matugen.json"
    // The roles Theme fills its slots from; a scheme missing any is refused.
    readonly property var required: ["surface", "surface_container_high", "on_surface", "on_surface_variant",
        "primary", "on_primary", "error", "on_error", "tertiary"]
    // { role: { dark: "#rrggbb", light: "#rrggbb" } }, or null before the first generation.
    property var roles: null

    function role(name, dark) {
        const entry = roles[name]
        return dark ? entry.dark : entry.light
    }

    function regenerate() {
        if (!generator.running)
            generator.running = true
    }

    function accept(json, persist) {
        try {
            const parsed = JSON.parse(json)
            const source = parsed.colors || parsed
            const next = {}
            for (const name in source) {
                const entry = source[name]
                if (entry && entry.dark && entry.light)
                    next[name] = { dark: entry.dark.color || entry.dark, light: entry.light.color || entry.light }
            }
            const missing = required.filter(name => !next[name])
            if (missing.length > 0)
                throw new Error("missing " + missing.join(", "))
            roles = next
            if (persist)
                cache.setText(JSON.stringify(next) + "\n")
        } catch (error) {
            console.warn("qs matugen: unreadable scheme:", error)
        }
    }

    Process {
        id: generator
        command: ["matugen", "image", root.wallpaper, "--dry-run", "-j", "hex", "--prefer", "saturation"]
        stdout: StdioCollector {
            onStreamFinished: root.accept(text, true)
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim() !== "") console.warn("qs matugen:", text.trim())
        }
    }

    FileView {
        id: cache
        path: root.cachePath
        printErrors: false
        atomicWrites: true
        onLoaded: if (!root.roles) root.accept(text(), false)
    }
}
