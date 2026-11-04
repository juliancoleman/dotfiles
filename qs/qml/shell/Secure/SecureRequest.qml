pragma Singleton

import QtQuick
import Quickshell
import "../Common"

// What the secure prompt says and shows for each kind of request. Requesters describe themselves
// in mechanism terms ("…as the super user", action ids, askpass prompts); this says what is happening.
Singleton {
    id: root

    readonly property var shells: ["sh", "bash", "dash", "fish", "zsh", "nu", "run0", "sudo", "systemd", "niri"]
    // Flags of sudo and run0 that consume the next argument, so it isn't mistaken for the command.
    readonly property var valueFlags: ["-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U", "-T", "--user", "--group",
        "--chdir", "--unit", "--property", "--description", "--slice", "--nice", "--background", "--setenv",
        "--machine", "--prompt", "--close-from", "--host", "--role", "--type", "--other-user", "--command-timeout"]
    readonly property var polkitFamilies: [
        ["org.freedesktop.NetworkManager", "wifi-lock", I18n.tr("Network settings")],
        ["org.freedesktop.udisks2", "disk", I18n.tr("Disks")],
        ["org.freedesktop.systemd1", "settings", I18n.tr("System services")],
        ["org.freedesktop.login1", "lock", I18n.tr("Power")],
        ["org.freedesktop.timedate1", "settings", I18n.tr("Date & time")],
        ["org.freedesktop.hostname1", "settings", I18n.tr("System")],
        ["org.freedesktop.locale1", "settings", I18n.tr("System")]
    ]

    function themed(name) {
        return name ? Quickshell.iconPath(name, true) : ""
    }

    // heuristicLookup misses reverse-DNS ids like com.mitchellh.ghostty for a process named "ghostty".
    function entryFor(name) {
        const direct = DesktopEntries.heuristicLookup(name)
        if (direct)
            return direct
        const lower = name.toLowerCase()
        return DesktopEntries.applications.values.find(entry =>
            entry.id.toLowerCase().split(".").pop() === lower
            || entry.name.toLowerCase() === lower
            || (entry.command.length > 0 && entry.command[0].split("/").pop() === name)) || null
    }

    function appIcon(name) {
        const entry = entryFor(name)
        return entry && entry.icon ? themed(entry.icon) : themed(name)
    }

    function commandOf(args) {
        for (let i = 1; i < args.length; ++i) {
            const arg = args[i]
            if (arg === "--")
                return (args[i + 1] || "").split("/").pop()
            if (!arg.startsWith("-"))
                return arg.split("/").pop()
            if (valueFlags.indexOf(arg) >= 0)
                ++i
        }
        return ""
    }

    // Lineage text is the requester's command line, then process names from the requester up to init.
    function parseLineage(text) {
        const lines = text.split("\n").map(line => line.trim()).filter(line => line !== "")
        const args = (lines.shift() || "").split(" ").filter(arg => arg !== "")
        // Nix wrappers rename binaries to ".name-wrapped", and comm is cut to 15 bytes.
        const names = lines.map(line => line.replace(/^\./, "").replace(/-w(r(a(p(p(ed?)?)?)?)?)?$/, ""))
        return {
            program: commandOf(args),
            requester: names[0] || "",
            apps: names.filter(name => shells.indexOf(name) < 0)
        }
    }

    function lineageImage(lineage) {
        for (const app of lineage.apps) {
            const image = appIcon(app)
            if (image !== "")
                return image
        }
        return ""
    }

    // run0 names its polkit request after a transient unit; the pid in that name leads to the command and the app.
    function run0Pid(message) {
        const match = message.match(/transient unit\s+[`'‘"]?run-p(\d+)-/)
        return match ? match[1] : ""
    }

    function cleanPrompt(prompt) {
        return prompt.trim().replace(/[:：]\s*$/, "")
    }

    function polkit(flow, lineage) {
        const id = flow.actionId || ""
        const message = flow.message || ""
        const run = message.match(/run\s+[`'‘"](.+?)[`'’"]\s+as/)
        if (id === "org.freedesktop.policykit.exec" || run) {
            const program = run ? run[1].split("/").pop() : I18n.tr("Command")
            return { icon: "lock", image: themed(program), title: program, kind: I18n.tr("Run as administrator") }
        }
        if (run0Pid(message) !== "") {
            return {
                icon: "lock",
                image: lineageImage(lineage),
                title: lineage.program || I18n.tr("Command"),
                kind: I18n.tr("Run as administrator")
            }
        }
        const family = polkitFamilies.find(entry => id.startsWith(entry[0])) || ["", "lock", I18n.tr("Administrator")]
        let title = message.trim()
            .replace(/^authentication is (required|needed)\s+(in order\s+)?to\s+/i, "")
            .replace(/[.。]\s*$/, "")
            .replace(/[`'‘’"]/g, "")
        title = title.charAt(0).toUpperCase() + title.slice(1)
        return { icon: family[1], image: themed(flow.iconName), title: title, kind: family[2] }
    }

    // qs-askpass (sudo, ssh, git) and pinentry-qs (gpg) requests.
    function socket(message, lineage) {
        const prompt = message.prompt || ""
        const image = lineageImage(lineage)
        if (message.source === "pinentry") {
            const description = message.description || ""
            const uid = description.match(/"([^"]+)"/)
            const name = uid ? uid[1].replace(/\s*<[^>]*>\s*$/, "") : ""
            return {
                icon: "key",
                image: image,
                title: name || message.title || description.split("\n")[0] || I18n.tr("Passphrase"),
                kind: /openpgp|gpg/i.test(description + message.title) ? I18n.tr("GPG key") : I18n.tr("Passphrase"),
                placeholder: cleanPrompt(prompt).replace(/^passphrase$/i, "") || I18n.tr("Passphrase")
            }
        }
        if (lineage.requester === "sudo") {
            return { icon: "lock", image: image, title: lineage.program || I18n.tr("Command"), kind: I18n.tr("Run as administrator") }
        }
        const key = prompt.match(/passphrase for (?:key )?['"]?([^'"]+?)['"]?\s*:?\s*$/i)
        if (key) {
            return {
                icon: "key",
                image: image,
                title: key[1].split("/").pop(),
                kind: I18n.tr("SSH key"),
                placeholder: I18n.tr("Passphrase")
            }
        }
        const credential = prompt.match(/^(username|password) for ['"]([^'"]+)['"]/i)
        if (credential) {
            const user = credential[1].toLowerCase() === "username"
            const host = credential[2].replace(/^\w+:\/\//, "").replace(/^[^@/]*@/, "").replace(/\/.*$/, "")
            return {
                icon: "lock",
                image: image,
                title: host,
                kind: user ? I18n.tr("Git username") : I18n.tr("Git password"),
                placeholder: user ? I18n.tr("Username") : I18n.tr("Password"),
                echo: user
            }
        }
        const login = prompt.match(/^(\S+?)@(\S+?)'s password/)
        if (login) {
            return { icon: "lock", image: image, title: login[2], kind: I18n.tr("SSH password for %1").arg(login[1]) }
        }
        return {
            icon: "lock",
            image: image,
            title: cleanPrompt(prompt) || lineage.program || I18n.tr("Password"),
            kind: lineage.requester
        }
    }

    function socketError(message) {
        if (!message)
            return ""
        return /bad|invalid|wrong|incorrect/i.test(message) ? I18n.tr("Wrong password") : message
    }

    // Desktop entries are scanned on first use; start early so app icons resolve on the first request.
    Component.onCompleted: DesktopEntries.applications.values
}
