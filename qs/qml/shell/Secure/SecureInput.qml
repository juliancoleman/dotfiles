pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import "../Common"

// The one place the shell asks for a secret. Polkit (pkexec, run0, system dialogs), the shell's own
// requests (Wi-Fi passwords), and qs-askpass / pinentry-qs over the socket share it; polkit wins
// while several are pending, and socket requests wait their turn.
Singleton {
    id: root

    // { icon, image, title, kind, placeholder, echo, minLength, busyText, owner, submit(text), cancel() }
    property var local: null
    property string localError: ""
    property bool localBusy: false
    property var queue: []
    // The last socket requester we answered; asking again soon means the secret was rejected.
    property var answered: ({ pid: 0, at: 0 })
    property string polkitError: ""
    property var lineage: ({ program: "", requester: "", apps: [] })
    // Bumped on every rejected secret so the prompt can shake.
    property int rejections: 0
    // Bumped whenever a different request takes the prompt, so typed text never carries over.
    property int serial: 0

    readonly property var flow: agent.flow
    readonly property bool polkitActive: agent.isActive && !!flow && !flow.isCompleted
    readonly property bool active: polkitActive || local !== null
    readonly property bool busy: polkitActive ? !flow.isResponseRequired : localBusy
    readonly property bool echo: polkitActive ? flow.responseVisible : !!(local && local.echo)
    readonly property string error: polkitActive ? polkitError : localError
    readonly property int minLength: polkitActive ? 1 : (local && local.minLength) || 1
    readonly property string placeholder: {
        const prompt = polkitActive ? (flow.inputPrompt || "").trim().replace(/:$/, "")
            : local ? local.placeholder || "" : ""
        // Polkit's prompt is usually a bare "Password", which the dictionary can still translate.
        return I18n.tr(prompt || "Password")
    }

    // Bindings can see a cleared flow before polkitActive updates.
    readonly property var request: polkitActive && flow ? SecureCopy.polkit(flow, lineage) : local || ({})
    readonly property string glyph: request.icon || "lock"
    readonly property string image: request.image || ""
    readonly property string title: request.title || ""
    readonly property string kind: request.kind || ""

    function ask(next, error) {
        if (local !== next)
            ++serial
        local = next
        localError = error || ""
        localBusy = false
        if (localError !== "")
            ++rejections
    }

    function fail(message) {
        if (!local)
            return
        localBusy = false
        localError = message
        ++rejections
    }

    function finish(owner) {
        if (!local || (owner !== undefined && local.owner !== owner))
            return
        local = null
        localError = ""
        localBusy = false
        if (queue.length > 0) {
            const next = queue[0]
            queue = queue.slice(1)
            ask(next.request, next.error)
        }
    }

    function enqueue(request, error) {
        if (local === null)
            ask(request, error)
        else
            queue = queue.concat([{ request: request, error: error }])
    }

    function drop(owner) {
        queue = queue.filter(entry => entry.request.owner !== owner)
        finish(owner)
    }

    function submit(text) {
        if (polkitActive) {
            polkitError = ""
            flow.submit(text)
            return
        }
        if (!local)
            return
        localBusy = true
        localError = ""
        local.submit(text)
    }

    function cancel() {
        if (polkitActive) {
            flow.cancelAuthenticationRequest()
            return
        }
        const pending = local
        finish()
        if (pending && pending.cancel)
            pending.cancel()
    }

    function reply(client, message) {
        client.write(JSON.stringify(message) + "\n")
        client.flush()
    }

    function receive(client, line) {
        let message
        try {
            message = JSON.parse(line)
        } catch (error) {
            client.connected = false
            return
        }
        const request = SecureCopy.socket(message, SecureCopy.parseLineage(message.lineage || ""))
        request.owner = client
        request.submit = secret => {
            answered = { pid: message.pid || 0, at: Date.now() }
            reply(client, { secret: secret })
            finish(client)
        }
        request.cancel = () => reply(client, { cancelled: true })
        const retried = message.pid && message.pid === answered.pid && Date.now() - answered.at < 15000
        enqueue(request, SecureCopy.socketError(message.error) || (retried ? I18n.tr("Wrong password") : ""))
    }

    SocketServer {
        active: true
        path: Quickshell.env("QS_SECURE_SOCKET") || Quickshell.env("XDG_RUNTIME_DIR") + "/qs-secure.sock"
        handler: Socket {
            id: client
            parser: SplitParser {
                onRead: line => root.receive(client, line)
            }
            onConnectedChanged: {
                if (!connected)
                    root.drop(client)
            }
        }
    }

    PolkitAgent {
        id: agent
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            root.polkitError = I18n.tr("Wrong password")
            ++root.rejections
        }
    }

    onFlowChanged: {
        polkitError = ""
        lineage = SecureCopy.parseLineage("")
        ++serial
        const pid = flow ? SecureCopy.run0Pid(flow.message || "") : ""
        if (pid === "")
            return
        lineageReader.command = ["sh", "-c",
            "p=$1; tr '\\0' ' ' < /proc/$p/cmdline; echo; "
            + "while [ \"$p\" -gt 1 ] 2>/dev/null; do cat /proc/$p/comm; p=$(cut -d' ' -f4 /proc/$p/stat); done",
            "sh", pid]
        lineageReader.running = true
    }

    Process {
        id: lineageReader
        stdout: StdioCollector {
            onStreamFinished: root.lineage = SecureCopy.parseLineage(text)
        }
    }
}
