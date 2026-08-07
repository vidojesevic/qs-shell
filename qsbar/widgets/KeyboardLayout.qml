import Quickshell.Io
import QtQuick

import "../themes" as Themes

Text {
    id: root

    property string keyLayout: "Eng"

    text: "󰌌 " + root.keyLayout
    color: Themes.Theme.blue

    font {
        family: Themes.Theme.fontFamily
        pixelSize: Themes.Theme.fontSize
        bold: true
    }

    Process {
        id: keyboardProc

        command: [
            "sh",
            "-c",
            "hyprctl -j devices | jq -r '.keyboards[] | select(.main == true) | .active_keymap'"
        ]

        stdout: SplitParser {
            onRead: data => {
                if (!data || data.trim() === "")
                    return

                const layout = data.trim()

                const names = {
                    "English (US)": "Eng",
                    "Serbian (Latin)": "Srp",
                    "Serbian": "Срп"
                }

                root.keyLayout = names[layout] ?? layout
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            if (!keyboardProc.running)
                keyboardProc.running = true
        }

        Component.onCompleted: {
            keyboardProc.running = true
        }
    }
}
