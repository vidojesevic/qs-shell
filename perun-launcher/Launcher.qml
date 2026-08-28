import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// App launcher. Toggle with: qs ipc call launcher toggle
PanelWindow {
    id: launcher

    property string query: ""

    readonly property var entries: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)

    // Entries matching `query`, best match first.
    readonly property var results: {
        const q = launcher.query.trim().toLowerCase()

        if (q === "") {
            return launcher.entries
                .slice()
                .sort((a, b) => a.name.localeCompare(b.name))
        }

        return launcher.entries
            .map(e => ({ entry: e, rank: launcher.rank(e, q) }))
            .filter(m => m.rank >= 0)
            .sort((a, b) => a.rank - b.rank || a.entry.name.localeCompare(b.entry.name))
            .map(m => m.entry)
    }

    // Match position decides rank; -1 means no match.
    function rank(entry, q) {
        const name = entry.name.toLowerCase()

        if (name === q) return 0
        if (name.startsWith(q)) return 1
        if (name.includes(q)) return 2

        if ((entry.genericName ?? "").toLowerCase().includes(q)) return 3
        if ((entry.keywords ?? []).some(k => k.toLowerCase().includes(q))) return 4
        if ((entry.comment ?? "").toLowerCase().includes(q)) return 5
        if ((entry.execString ?? "").toLowerCase().includes(q)) return 6

        return -1
    }

    function launch(entry) {
        if (!entry) return

        launcher.visible = false
        entry.execute()
    }

    function close() {
        launcher.visible = false
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
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Fresh search every time it opens.
    onVisibleChanged: {
        if (visible) {
            launcher.query = ""
            search.text = ""
            list.currentIndex = 0
            search.forceActiveFocus()
        }
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (!launcher.visible) {
                // Open on the focused monitor.
                const focused = Hyprland.focusedMonitor
                const match = Quickshell.screens.find(s => focused && s.name === focused.name)
                launcher.screen = match ?? Quickshell.screens[0]
            }
            launcher.visible = !launcher.visible
        }

        function open(): void {
            if (!launcher.visible) toggle()
        }

        function close(): void {
            launcher.visible = false
        }
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
            onClicked: launcher.close()
        }

        Rectangle {
            id: panel

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.18)

            width: 640
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
                        color: Config.colors.cyan

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                        }
                    }

                    TextInput {
                        id: search

                        Layout.fillWidth: true

                        color: Config.colors.foreground
                        selectionColor: Config.colors.accent
                        selectedTextColor: Config.colors.background
                        clip: true

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                        }

                        onTextChanged: {
                            launcher.query = text
                            list.currentIndex = 0
                        }

                        onAccepted: launcher.launch(list.currentEntry)

                        Keys.onEscapePressed: launcher.close()
                        Keys.onUpPressed: list.step(-1)
                        Keys.onDownPressed: list.step(1)

                        Keys.onPressed: event => {
                            // Emacs-style nav, same as rofi.
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

                            text: "Search applications"
                            color: Config.colors.muted

                            font: search.font
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Text {
                        text: launcher.results.length
                        color: Config.colors.muted

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

                    readonly property var currentEntry: currentIndex >= 0
                        ? (launcher.results[currentIndex] ?? null)
                        : null

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 440)

                    model: launcher.results
                    clip: true
                    currentIndex: 0
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        id: row

                        required property int index
                        required property var modelData

                        width: list.width
                        height: 44

                        radius: 4
                        color: list.currentIndex === row.index
                            ? Config.colors.muted
                            : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12

                            Item {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28

                                Image {
                                    id: icon

                                    anchors.fill: parent

                                    // `true` checks the icon theme first, so a
                                    // missing icon yields "" instead of a warning.
                                    source: Quickshell.iconPath(row.modelData.icon, true)
                                    sourceSize.width: 28
                                    sourceSize.height: 28
                                    asynchronous: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !icon.visible

                                    text: "\uf1b2"
                                    color: Config.colors.muted

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: 20
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name
                                    color: Config.colors.foreground
                                    elide: Text.ElideRight

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""

                                    text: row.modelData.genericName || row.modelData.comment || ""
                                    color: Config.colors.foregroundAlt
                                    elide: Text.ElideRight

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 4
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onPositionChanged: list.currentIndex = row.index
                            onClicked: launcher.launch(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
