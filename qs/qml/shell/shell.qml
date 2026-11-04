import QtQuick
import Quickshell
import Quickshell.Io
import "."
import "Launcher"
import "Settings"
import "Status"

ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: ClockBar {
            modelData: modelData
        }
    }

    // Niri binds Super+Space to `qs-shell ipc call launcher toggle`.
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            LauncherState.toggle()
        }

        function open(): void {
            LauncherState.open()
        }

        function close(): void {
            LauncherState.close()
        }
    }

    // Niri binds Super+Comma to `qs-shell ipc call settings toggle`.
    IpcHandler {
        target: "settings"

        function toggle(): void {
            SettingsState.toggle()
        }
    }

    // Niri binds the brightness and media keys to `qs-shell ipc call status <function>`.
    IpcHandler {
        target: "status"

        function next(): void {
            Media.next()
        }

        function previous(): void {
            Media.previous()
        }

        function playPause(): void {
            Media.playPause()
        }

        function brightnessUp(): void {
            Brightness.step(1)
        }

        function brightnessDown(): void {
            Brightness.step(-1)
        }
    }
}
