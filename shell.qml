import Quickshell
import Quickshell.Io
import QtQuick

import "notifications"
import "perun-launcher"
import "qsbar"
import "recording"
import "theme"

ShellRoot {
    id: root

    readonly property string notifyIcon:
        Quickshell.env("HOME") + "/Pictures/Logos/quickshell.svg"

    Process {
        id: reloadNotify
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
}
