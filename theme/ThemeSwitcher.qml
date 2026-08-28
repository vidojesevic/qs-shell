import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// Modal theme picker. Toggle with: qs ipc call theme toggle
PanelWindow {
    id: themeMenu

    readonly property string revealConfig: Quickshell.shellDir + "/theme/reveal.qml"
    property string pendingTheme: ""

    readonly property var themes: [
        { name: "catppuccin", label: "Catppuccin", color: "#cba6f7" },
        { name: "dracula",    label: "Dracula",    color: "#bd93f9" },
        { name: "tokyonight", label: "Tokyo Night", color: "#7aa2f7" },
        { name: "ember",      label: "Ember",      color: "#e6a44c" }
    ]

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: false
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-theme"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    IpcHandler {
        target: "theme"

        function toggle(): void {
            if (!themeMenu.visible) {
                // Open on the focused monitor.
                const focused = Hyprland.focusedMonitor
                const match = Quickshell.screens.find(s => focused && s.name === focused.name)
                themeMenu.screen = match ?? Quickshell.screens[0]
            }
            themeMenu.visible = !themeMenu.visible
        }

        function apply(name: string): void {
            themeMenu.apply(name)
        }

        // Called by the reveal instance once the screen is frozen.
        function covered(): void {
            if (themeMenu.pendingTheme === "") return
            switchProc.command = [Quickshell.shellDir + "/theme/switch.sh", themeMenu.pendingTheme]
            switchProc.running = true
        }

        function reload(): void {
            Quickshell.reload(false)
        }

        function current(): string {
            return Config.colors.background
        }
    }

    Process {
        id: switchProc

        // Script skips its own "qs ipc call theme reload"; we reload below.
        environment: ({ QS_RELOAD_SELF: "1" })

        // Script relinked theme + wallpaper; reload QML in place to pick it up.
        // Screen is frozen by the reveal instance; new tree tells it to start.
        onExited: {
            persist.revealPending = true
            Quickshell.reload(false)
        }
    }

    // Survives Quickshell.reload().
    PersistentProperties {
        id: persist

        reloadableId: "themeSwitcher"

        property bool revealPending: false

        // Fires in the new tree after values are restored from the old one.
        onReloaded: {
            if (revealPending) {
                revealPending = false
                revealStart.running = true
            }
        }
    }

    // Spawned by Hyprland, not by us, so it outlives this tree's reload.
    Process {
        id: revealProc

        command: ["hyprctl", "dispatch", 'hl.dsp.exec_cmd("qs -p ' + themeMenu.revealConfig + '")']
    }

    Process {
        id: revealStart

        command: ["qs", "ipc", "-p", themeMenu.revealConfig, "call", "reveal", "start"]
    }

    function apply(name) {
        themeMenu.visible = false
        themeMenu.pendingTheme = name
        revealProc.running = true
    }

    BackgroundEffect.blurRegion: Region {
        item: dim
    }

    Rectangle {
        id: dim

        anchors.fill: parent
        color: Qt.alpha(Config.colors.background, 0.4)

        focus: true
        Keys.onEscapePressed: themeMenu.visible = false

        MouseArea {
            anchors.fill: parent
            onClicked: themeMenu.visible = false
        }

        Rectangle {
            anchors.centerIn: parent

            implicitWidth: list.implicitWidth + 48
            implicitHeight: list.implicitHeight + 48

            radius: 8
            color: Config.colors.background
            border.color: Config.colors.muted
            border.width: 1

            ColumnLayout {
                id: list

                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: "Theme"
                    color: Config.colors.cyan

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize + 2
                        bold: true
                    }
                }

                Repeater {
                    model: themeMenu.themes

                    Rectangle {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitWidth: 220
                        implicitHeight: 36

                        radius: 4
                        color: hover.containsMouse ? Config.colors.muted : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Rectangle {
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: modelData.color
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.label
                                color: Config.colors.foreground

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize
                                }
                            }
                        }

                        MouseArea {
                            id: hover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: themeMenu.apply(modelData.name)
                        }
                    }
                }
            }
        }
    }
}
