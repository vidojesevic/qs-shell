import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// Settings modal. Toggle with: qs ipc call settings toggle
// Keys: Ctrl+J / Ctrl+K (or Ctrl+Tab / Ctrl+Shift+Tab) change section,
// Escape closes.
PanelWindow {
    id: settings

    // Sections above the divider act at once (live). Sections below it edit
    // config.js (persistent).
    readonly property var sections: [
        "Network", "Bluetooth", "Sound", "Displays",
        "Appearance", "Bar", "Notifications", "Screensaver", "System"
    ]
    readonly property int liveCount: 4

    property int current: 0

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
    WlrLayershell.namespace: "quickshell-settings"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: {
        if (visible)
            keys.forceActiveFocus()
    }

    IpcHandler {
        target: "settings"

        function toggle(): void {
            if (!settings.visible) {
                // Open on the focused monitor.
                const focused = Hyprland.focusedMonitor
                const match = Quickshell.screens.find(s => focused && s.name === focused.name)
                settings.screen = match ?? Quickshell.screens[0]
            }
            settings.visible = !settings.visible
        }

        // For testing: qs ipc call settings set notifications.timeout 3000
        // The value is read as JSON (3000, true, "x"); anything else is a string.
        function set(key: string, value: string): string {
            let parsed = value
            try {
                parsed = JSON.parse(value)
            } catch (e) {}

            return configFile.save({ [key]: parsed }) || "ok"
        }
    }

    ConfigFile {
        id: configFile
    }

    function step(delta) {
        const count = settings.sections.length
        settings.current = (settings.current + delta + count) % count
    }

    function close() {
        settings.visible = false
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Config.colors.background, 0.7)

        MouseArea {
            anchors.fill: parent
            onClicked: settings.close()
        }

        Rectangle {
            anchors.centerIn: parent

            implicitWidth: 820
            implicitHeight: 560

            radius: 8
            color: Config.colors.background
            border.color: Config.colors.border
            border.width: 1
            clip: true

            // Clicks inside must not fall through to the dimmer.
            MouseArea {
                anchors.fill: parent
            }

            Item {
                id: keys

                anchors.fill: parent

                Keys.onEscapePressed: settings.close()

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Backtab) {
                        settings.step(-1)
                        event.accepted = true
                    } else if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
                            settings.step(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_K) {
                            settings.step(-1)
                            event.accepted = true
                        }
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0

                // Sidebar
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true

                    color: Config.colors.backgroundAlt

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 16
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.bottomMargin: 12
                        spacing: 2

                        Text {
                            Layout.leftMargin: 12
                            Layout.bottomMargin: 12

                            text: "Settings"
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize
                                bold: true
                            }
                        }

                        Repeater {
                            model: settings.sections

                            ColumnLayout {
                                id: entry

                                required property int index
                                required property string modelData

                                readonly property bool selected: settings.current === entry.index

                                Layout.fillWidth: true
                                spacing: 2

                                // Divider between live and persistent sections.
                                Rectangle {
                                    visible: entry.index === settings.liveCount

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    Layout.topMargin: 4
                                    Layout.bottomMargin: 4
                                    Layout.leftMargin: 12
                                    Layout.rightMargin: 12

                                    color: Config.colors.border
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32

                                    radius: 6
                                    color: entry.selected ? Config.colors.background : "transparent"

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12

                                        text: entry.modelData
                                        color: entry.selected ? Config.text.active : Config.colors.foregroundAlt

                                        font {
                                            family: Config.bar.fontFamily
                                            pixelSize: Config.bar.fontSize - 2
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settings.current = entry.index
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        Text {
                            Layout.leftMargin: 12

                            text: "^J ^K sections"
                            color: Config.text.dim

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 2
                            }
                        }
                    }

                    // Right border of the sidebar.
                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 1
                        color: Config.colors.border
                    }
                }

                // Pane
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 24

                            text: settings.sections[settings.current]
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize
                                bold: true
                            }
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Config.colors.border
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }
}
