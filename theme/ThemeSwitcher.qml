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
    property string query: ""

    readonly property var themes: [
        { name: "catppuccin", label: "Catppuccin", color: "#cba6f7" },
        { name: "dracula",    label: "Dracula",    color: "#bd93f9" },
        { name: "onedark",    label: "One Dark",   color: "#61afef" },
        { name: "tokyonight", label: "Tokyo Night", color: "#7aa2f7" },
        { name: "ember",      label: "Ember",      color: "#e6a44c" }
    ]

    // Themes matching `query`; everything when it is empty.
    readonly property var results: {
        const q = themeMenu.query.trim().toLowerCase()

        if (q === "") return themeMenu.themes

        return themeMenu.themes.filter(t =>
            t.label.toLowerCase().includes(q) || t.name.includes(q))
    }

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
    // Exclusive so the search field gets every keystroke.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Fresh search every time it opens.
    onVisibleChanged: {
        if (visible) {
            themeMenu.query = ""
            search.text = ""
            list.currentIndex = 0
            search.forceActiveFocus()
        }
    }

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
        if (!name) return

        themeMenu.visible = false
        themeMenu.pendingTheme = name
        revealProc.running = true
    }

    function close() {
        themeMenu.visible = false
    }

    BackgroundEffect.blurRegion: Region {
        item: dim
    }

    Rectangle {
        id: dim

        anchors.fill: parent
        color: Qt.alpha(Config.colors.background, 0.4)

        MouseArea {
            anchors.fill: parent
            onClicked: themeMenu.close()
        }

        Rectangle {
            anchors.centerIn: parent

            implicitWidth: 300
            implicitHeight: layout.implicitHeight + 24

            radius: 8
            color: Config.colors.background
            border.color: Config.colors.muted
            border.width: 1

            // Clicks inside must not fall through to the dimmer.
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                id: layout

                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    Layout.topMargin: 4
                    spacing: 10

                    Text {
                        text: "\uf002"
                        color: Config.text.active

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                        }
                    }

                    TextInput {
                        id: search

                        Layout.fillWidth: true

                        color: Config.text.normal
                        selectionColor: Config.text.active
                        selectedTextColor: Config.colors.background
                        clip: true

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                        }

                        onTextChanged: {
                            themeMenu.query = text
                            list.currentIndex = 0
                        }

                        onAccepted: themeMenu.apply(list.currentTheme?.name)

                        Keys.onEscapePressed: themeMenu.close()
                        Keys.onUpPressed: list.step(-1)
                        Keys.onDownPressed: list.step(1)

                        Keys.onPressed: event => {
                            // Emacs-style nav, same as the launcher.
                            if (event.modifiers & Qt.ControlModifier) {
                                if (event.key === Qt.Key_N) {
                                    list.step(1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_P) {
                                    list.step(-1)
                                    event.accepted = true
                                }
                            }
                        }

                        Text {
                            anchors.fill: parent
                            visible: search.text === ""

                            text: "Search themes"
                            color: Config.text.dim

                            font: search.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        text: themeMenu.results.length
                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Config.colors.border
                }

                ListView {
                    id: list

                    // Wraps around, like rofi's cycle.
                    function step(delta) {
                        if (count === 0) return
                        currentIndex = (currentIndex + delta + count) % count
                    }

                    readonly property var currentTheme: currentIndex >= 0
                        ? (themeMenu.results[currentIndex] ?? null)
                        : null

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 300)

                    model: themeMenu.results
                    clip: true
                    currentIndex: 0
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        id: row

                        required property int index
                        required property var modelData

                        width: list.width
                        height: 36

                        radius: 4
                        color: list.currentIndex === row.index
                            ? Config.colors.muted
                            : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Rectangle {
                                implicitWidth: 14
                                implicitHeight: 14
                                radius: 7
                                color: row.modelData.color
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.label

                                color: list.currentIndex === row.index
                                    ? Config.text.active
                                    : Config.text.normal

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPositionChanged: list.currentIndex = row.index
                            onClicked: themeMenu.apply(row.modelData.name)
                        }
                    }
                }
            }
        }
    }
}
