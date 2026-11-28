pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../Secure"

// What the user has running: apps (the processes in the session's scopes, grouped into whole apps) and
// the services someone started by hand. An app is more than a process tree: a front end may exit and
// leave helpers that were re-parented, or moved into a scope of their own, and those block the next
// launch. Processes are tied together by what survives that: the scope they were started in, their
// session id, and parentage. Quitting signals every process of the app. Read from /proc and niri while
// `watchers > 0`.
Singleton {
    id: root

    property int watchers: 0
    readonly property bool active: watchers > 0
    // [{ key, name, icon, pids, units, windows, windowIds }], apps with a window first.
    property var apps: []
    // [{ unit, name, about }]: running services that are not part of the desktop itself.
    property var services: []
    property string signature: ""

    // Every process of this user under the user manager, with its parent, session and cgroup; the shell's
    // own pid; niri's windows; the running services with where each unit file lives.
    readonly property string collector: "printf '@@shell %s\\n' \"$PPID\"\n"
        + "for d in /proc/[0-9]*; do\n"
        + "  [ -O \"$d\" ] || continue\n"
        + "  IFS= read -r cg < \"$d/cgroup\" 2>/dev/null || continue\n"
        + "  case \"$cg\" in */user@*.service/*) ;; *) continue ;; esac\n"
        + "  IFS= read -r st < \"$d/stat\" 2>/dev/null || continue\n"
        + "  IFS= read -r comm < \"$d/comm\" 2>/dev/null || continue\n"
        + "  set -- ${st##*) }\n"
        + "  printf '%s\\t%s\\t%s\\t%s\\t%s\\n' \"${d#/proc/}\" \"$2\" \"$4\" \"${cg#*user@*.service/}\" \"$comm\"\n"
        + "done\n"
        + "printf '@@windows\\n'; niri msg --json windows 2>/dev/null; printf '\\n@@services\\n'\n"
        + "systemctl --user show -p Id -p FragmentPath -p Description $(systemctl --user list-units --type=service"
        + " --state=running --plain --no-legend --no-pager 2>/dev/null | while read -r unit rest; do"
        + " printf '%s ' \"$unit\"; done) 2>/dev/null\n"
        // Unit files the home configuration installed are links into the store; ones written by hand are files.
        + "for f in \"$HOME\"/.config/systemd/user/*.service; do [ -L \"$f\" ] && printf 'Linked=%s\\n' \"$f\"; done\n"

    // "app-niri-qs\x2dshell-1790.scope" -> "app-niri-qs-shell-1790.scope"
    function plainName(unit) {
        return unit.replace(/\\x([0-9a-fA-F]{2})/g, (all, hex) => String.fromCharCode(parseInt(hex, 16)))
    }

    // The unit name the launcher gives an app's scope: "app-qs-<escaped desktop id>-<random>.scope".
    function scopeName(id) {
        const escaped = Array.from(id).map(ch => /[A-Za-z0-9:_.]/.test(ch) ? ch
            : "\\x" + ch.charCodeAt(0).toString(16).padStart(2, "0")).join("")
        return "app-qs-" + escaped + "-" + Math.floor(Math.random() * 0xffffffff).toString(16) + ".scope"
    }

    // What a scope's name says the app is: a desktop id from the launcher or from the app itself, or the
    // command niri spawned (`named`: fit to show when no desktop entry is found). Terminal surfaces and
    // anything unrecognized say nothing.
    function hint(unit) {
        const mine = unit.match(/^app-qs-(.+)-[0-9a-f]+\.scope$/)
        if (mine)
            return { id: plainName(mine[1]), exact: true, named: true }
        const plain = plainName(unit)
        const spawned = plain.match(/^app-niri-(.+)-\d+\.scope$/)
        if (spawned)
            return { id: spawned[1], exact: false, named: true }
        const own = plain.match(/^app-(.+)-\d+\.scope$/)
        return own ? { id: own[1], exact: false, named: false } : null
    }

    // ".ghostty-wrappe" -> "ghostty": a NixOS wrapper runs ".name-wrapped", and comm cuts that at 15.
    function cleanComm(comm) {
        return comm.startsWith(".") ? comm.slice(1).replace(/-w(r(a(p(p(e(d)?)?)?)?)?)?$/, "") : comm
    }

    function parse(text) {
        const procs = []
        let shellPid = 0
        let windows = []
        const about = {}
        const linked = []
        let unit = {}
        let part = "procs"
        let windowJson = ""
        for (const line of text.split("\n")) {
            if (line.startsWith("@@shell ")) {
                shellPid = Number(line.slice(8))
            } else if (line === "@@windows") {
                part = "windows"
            } else if (line === "@@services") {
                part = "services"
            } else if (part === "windows") {
                windowJson += line
            } else if (part === "services") {
                // Blocks of Key=Value, one per unit, with a blank line between them.
                const at = line.indexOf("=")
                if (line.startsWith("Linked=")) {
                    linked.push(line.slice(7))
                } else if (at > 0) {
                    unit[line.slice(0, at)] = line.slice(at + 1)
                    if (unit.Id !== undefined && unit.FragmentPath !== undefined && unit.Description !== undefined) {
                        about[unit.Id] = { path: unit.FragmentPath, text: unit.Description }
                        unit = {}
                    }
                } else {
                    unit = {}
                }
            } else if (line !== "") {
                const [pid, ppid, sid, cgroup, comm] = line.split("\t")
                const parts = cgroup.split("/")
                procs.push({ pid: Number(pid), ppid: Number(ppid), sid: Number(sid), slice: parts[0],
                             unit: parts[parts.length - 1], comm: comm })
            }
        }
        try {
            windows = JSON.parse(windowJson) || []
        } catch (problem) {
            windows = []
        }
        return { procs: procs, shellPid: shellPid, windows: windows, about: about, linked: linked }
    }

    // Groups the scoped processes into apps. `seen` is parse()'s result. Only scopes inside a slice count:
    // the user manager's own init.scope is the parent every orphan is handed to, not an app.
    function group(seen) {
        const scoped = seen.procs.filter(p => p.unit.endsWith(".scope") && p.slice.endsWith(".slice"))
        const byPid = {}
        for (const p of scoped)
            byPid[p.pid] = p
        const shell = byPid[seen.shellPid]
        // niri does not start a session per spawn, so the shell shares its session with everything niri
        // started; and everything the launcher started before it used scopes shares the shell's scope.
        const sharedSid = shell ? shell.sid : -1
        const sharedUnit = shell ? shell.unit : ""

        const parent = {}
        const find = pid => {
            while (parent[pid] !== pid) {
                parent[pid] = parent[parent[pid]]
                pid = parent[pid]
            }
            return pid
        }
        const join = (a, b) => {
            const ra = find(a)
            const rb = find(b)
            if (ra !== rb)
                parent[Math.max(ra, rb)] = Math.min(ra, rb)
        }
        for (const p of scoped)
            parent[p.pid] = p.pid
        const firstOf = {}
        const tie = (key, pid) => {
            if (firstOf[key] === undefined)
                firstOf[key] = pid
            else
                join(firstOf[key], pid)
        }
        for (const p of scoped) {
            if (p.unit !== sharedUnit && !/^app-niri-qs\\x2dshell-\d+\.scope$/.test(p.unit))
                tie("unit " + p.unit, p.pid)
            if (p.sid !== sharedSid)
                tie("sid " + p.sid, p.pid)
            if (byPid[p.ppid])
                join(p.pid, p.ppid)
        }

        const groups = {}
        for (const p of scoped) {
            const key = find(p.pid)
            if (!groups[key])
                groups[key] = []
            groups[key].push(p)
        }
        const membersOf = {}
        for (const p of scoped)
            (membersOf[p.unit] = membersOf[p.unit] || []).push(p.pid)

        const out = []
        for (const key in groups) {
            const members = groups[key]
            const pids = members.map(p => p.pid)
            // The shell and its helpers are not something to quit from the shell.
            if (shell && pids.includes(shell.pid))
                continue
            const inGroup = {}
            for (const pid of pids)
                inGroup[pid] = true
            const units = [...new Set(members.map(p => p.unit))]
            const mine = seen.windows.filter(w => inGroup[w.pid])
            out.push({ key: Number(key), pids: pids, members: members, units: units, windows: mine,
                       // Units that hold nothing but this app can be signaled whole, which also reaches
                       // processes started after this reading.
                       whole: units.filter(u => membersOf[u].every(pid => inGroup[pid])) })
        }
        return out
    }

    // Names each group and gives X11 windows, which niri reports under Xwayland's pid, to their app.
    function describe(groups, windows) {
        const claimed = {}
        for (const app of groups)
            for (const w of app.windows)
                claimed[w.id] = true
        const loose = windows.filter(w => !claimed[w.id])
        return groups.map(app => {
            // Only scopes that are this app's alone say what it is; a shared one names somebody else.
            const hints = app.whole.map(root.hint).filter(h => h !== null)
            let entry = null
            const exact = hints.find(h => h.exact)
            if (exact)
                entry = DesktopEntries.byId(exact.id)
            for (const w of app.windows)
                entry = entry || SecureRequest.entryFor(w.app_id || "")
            for (const h of hints)
                entry = entry || SecureRequest.entryFor(h.id)
            const main = app.members.reduce((a, b) => a.pid < b.pid ? a : b)
            entry = entry || SecureRequest.entryFor(root.cleanComm(main.comm))
            const ids = hints.map(h => h.id.toLowerCase())
            if (entry) {
                ids.push(entry.id.toLowerCase())
                if (entry.startupClass)
                    ids.push(entry.startupClass.toLowerCase())
            }
            const found = app.windows.concat(loose.filter(w => ids.includes((w.app_id || "").toLowerCase())))
            return {
                key: app.key,
                name: entry ? entry.name : (hints.find(h => h.named) || { id: root.cleanComm(main.comm) }).id,
                icon: entry && entry.icon ? (entry.icon.startsWith("/") ? "file://" + entry.icon
                    : Quickshell.iconPath(entry.icon, true)) : "",
                pids: app.pids,
                units: app.whole,
                windows: found.length,
                windowIds: found.map(w => w.id)
            }
        }).sort((a, b) => (b.windows > 0) - (a.windows > 0) || a.name.localeCompare(b.name))
    }

    // The desktop's own services (the compositor, audio, portals, the wallpaper, the idle daemon) come
    // from the system's or the home's configuration and return at the next login; stopping one only breaks
    // the session. What is left is what was started by hand: a transient unit, or one the user wrote.
    function configured(path, linked) {
        return path.startsWith("/etc/") || path.startsWith("/nix/store/") || path.startsWith("/run/current-system/")
            || linked.includes(path)
    }

    function serviceList(seen) {
        return Object.keys(seen.about).filter(unit => !configured(seen.about[unit].path, seen.linked)).map(unit => ({
            unit: unit,
            name: root.plainName(unit.replace(/\.service$/, "")),
            about: seen.about[unit].text
        })).sort((a, b) => a.name.localeCompare(b.name))
    }

    function take(text) {
        const seen = parse(text)
        const nextApps = describe(group(seen), seen.windows)
        const nextServices = serviceList(seen)
        // Rows are rebuilt when the lists change, so they only change when what they show does.
        const next = JSON.stringify([nextApps, nextServices])
        if (next === signature)
            return
        signature = next
        apps = nextApps
        services = nextServices
    }

    function send(app, name) {
        if (app.pids.length > 0)
            Quickshell.execDetached(["kill", "-s", name].concat(app.pids.map(String)))
        for (const unit of app.units)
            Quickshell.execDetached(["systemctl", "--user", "kill", "--signal=" + name, unit])
        soon.restart()
    }

    function quit(app) {
        send(app, "TERM")
    }

    function forceQuit(app) {
        send(app, "KILL")
    }

    function focus(app) {
        if (app.windowIds.length > 0)
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(app.windowIds[0])])
    }

    function stopService(service) {
        Quickshell.execDetached(["systemctl", "--user", "stop", "--no-block", service.unit])
        soon.restart()
    }

    function killService(service) {
        Quickshell.execDetached(["systemctl", "--user", "kill", "--signal=KILL", service.unit])
        soon.restart()
    }

    Process {
        id: reader
        command: ["sh", "-c", root.collector]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: if (!reader.running) reader.running = true
    }

    // After an action, look again once the signal has had time to land.
    Timer {
        id: soon
        interval: 500
        onTriggered: if (!reader.running) reader.running = true
    }
}
