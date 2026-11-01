import Quickshell
import Quickshell.Io
import QtQuick

import "notifications"
import "perun-launcher"
import "qsbar"
import "recording"
import "screensaver"
import "settings"
import "theme"

ShellRoot {
    id: root

    readonly property string notifyIcon:
        Quickshell.env("HOME") + "/Pictures/Logos/quickshell.svg"

    Process {
        id: reloadNotify
    }

    // Manual reload, for when the file watcher misses a change:
    // qs ipc call shell reload
    IpcHandler {
        target: "shell"

        function reload(): void { Quickshell.reload(true) }
    }

    // Quickshell only watches .qml files, not JS imports, so saving
    // config.js would not reload without this.
    FileView {
        path: Quickshell.shellDir + "/config.js"
        watchChanges: true
        onFileChanged: Quickshell.reload(false)
    }

    // Replace the built in reload toast with notify-send, so reload messages
    // look like every other notification on the machine. The inhibit only
    // works from inside the reload handlers.
    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup()

            reloadNotify.command = [
                "notify-send",
                "-a", "Quickshell",
                "-i", root.notifyIcon,
                "-t", "3000",
                "Quickshell", "Config reloaded"
            ]

            reloadNotify.running = true
        }

        function onReloadFailed(errorString) {
            Quickshell.inhibitReloadPopup()

            reloadNotify.command = [
                "notify-send",
                "-u", "critical",
                "-a", "Quickshell",
                "-i", root.notifyIcon,
                "Quickshell reload failed", errorString
            ]

            reloadNotify.running = true
        }
    }

    Bar {}

    Notifications {}

    ThemeSwitcher {}

    Launcher {}

    RecordingHud {}

    Screensaver {}

    Settings {}
}
