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

    // Gap between a row divider and the control above or below it.
    readonly property int rowPadding: 12

    // Unsaved changes in the current section: { key path: value }. Leaving
    // the section asks to save or discard them first.
    property var pending: ({})
    readonly property int dirtyCount: Object.keys(pending).length

    // Keys whose pending value is not allowed (empty required text). Apply
    // stays off while any is set.
    property var invalid: ({})
    readonly property bool canApply: dirtyCount > 0 && Object.keys(invalid).length === 0

    // The save/discard prompt is open. target is where to go after it: a
    // section index, or -1 to close.
    property bool asking: false
    property int target: -1

    // Pane content per section. Sections without a page show an empty pane.
    readonly property var pages: ({
        Notifications: notificationsPage,
        Screensaver: screensaverPage
    })

    Component {
        id: notificationsPage

        NotificationsSection {
            form: settings
        }
    }

    Component {
        id: screensaverPage

        ScreensaverSection {
            form: settings
        }
    }

    property string status: ""
    property color statusColor: Config.colors.green

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

    // The old section's controls are gone; take focus back from them.
    onCurrentChanged: keys.forceActiveFocus()

    IpcHandler {
        target: "settings"

        function toggle(): void {
            if (settings.visible) {
                settings.leave(-1)
                return
            }

            // Open on the focused monitor.
            const focused = Hyprland.focusedMonitor
            settings.screen = settings.screenNamed(focused?.name)
            settings.visible = true
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

        onFailed: reason => settings.failed(reason)
    }

    // Apply reloads the shell, which rebuilds this window closed. These
    // values reopen it in the new shell.
    PersistentProperties {
        id: persist

        reloadableId: "settings"

        property bool open: false
        property bool applied: false
        property int section: 0
        property string screenName: ""

        onReloaded: {
            if (open) {
                settings.current = section
                settings.screen = settings.screenNamed(screenName)
                settings.visible = true
            }

            if (applied)
                settings.showStatus("✓ Applied", Config.colors.green)

            open = false
            applied = false
        }
    }

    Timer {
        id: statusTimer

        interval: 2000
        onTriggered: settings.status = ""
    }

    function screenNamed(name) {
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0]
    }

    function step(delta) {
        const count = settings.sections.length
        settings.leave((settings.current + delta + count) % count)
    }

    // Go to a section, or close when index is -1. With unsaved changes,
    // ask first; the choice then finishes this move.
    function leave(index) {
        if (index === settings.current)
            return

        if (settings.dirtyCount === 0) {
            settings.go(index)
            return
        }

        settings.target = index
        settings.asking = true
        keys.forceActiveFocus()
    }

    function go(index) {
        settings.asking = false

        if (index < 0) {
            settings.pending = {}
            settings.invalid = {}
            settings.visible = false
        } else {
            settings.current = index
        }
    }

    function discard() {
        settings.pending = {}
        settings.invalid = {}
        settings.go(settings.target)
    }

    function original(key) {
        return key.split(".").reduce((object, name) => object[name], Config)
    }

    function valueOf(key) {
        return key in settings.pending ? settings.pending[key] : settings.original(key)
    }

    // Controls call this on every edit. A value equal to config.js is clean.
    function change(key, value) {
        const next = Object.assign({}, settings.pending)

        if (value === settings.original(key))
            delete next[key]
        else
            next[key] = value

        settings.pending = next
    }

    function validate(key, ok) {
        const next = Object.assign({}, settings.invalid)

        if (ok)
            delete next[key]
        else
            next[key] = true

        settings.invalid = next
    }

    // Writes config.js. On success the shell reloads, and persist reopens
    // the modal on section target, or leaves it closed when target is -1.
    function apply(target) {
        if (!settings.canApply)
            return

        settings.asking = false

        persist.open = target >= 0
        persist.applied = target >= 0
        persist.section = target
        persist.screenName = settings.screen.name

        const reason = configFile.save(settings.pending)
        if (reason)
            settings.failed(reason)
    }

    function failed(reason) {
        persist.open = false
        persist.applied = false
        settings.visible = true
        settings.showStatus("Reload failed: " + reason, Config.colors.red)
    }

    function showStatus(text, color) {
        settings.status = text
        settings.statusColor = color
        statusTimer.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Config.colors.background, 0.7)

        MouseArea {
            anchors.fill: parent
            onClicked: settings.leave(-1)
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

            // Holds focus while no control has it. Keys a control does not
            // use bubble up to here.
            RowLayout {
                id: keys

                anchors.fill: parent
                anchors.margins: 1
                spacing: 0

                Keys.onPressed: event => {
                    const key = event.key
                    const tab = key === Qt.Key_Tab || key === Qt.Key_Backtab

                    if (settings.asking && !tab) {
                        if (key === Qt.Key_D)
                            settings.discard()
                        else if (key === Qt.Key_S)
                            settings.apply(settings.target)
                        else if (key === Qt.Key_Escape)
                            settings.asking = false
                    } else if (key === Qt.Key_Escape) {
                        settings.leave(-1)
                    } else if (!(event.modifiers & Qt.ControlModifier)) {
                        // Controls move focus on Tab themselves. Here focus is
                        // on the modal, so Tab enters the pane.
                        if (!tab)
                            return
                        keys.nextItemInFocusChain(key === Qt.Key_Tab).forceActiveFocus()
                    } else if (key === Qt.Key_J || key === Qt.Key_Tab) {
                        settings.step(1)
                    } else if (key === Qt.Key_K || key === Qt.Key_Backtab) {
                        settings.step(-1)
                    } else if (key === Qt.Key_S) {
                        settings.apply(settings.current)
                    } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
                        settings.apply(-1)
                    } else {
                        return
                    }

                    event.accepted = true
                }

                // Sidebar
                Rectangle {
                    Layout.preferredWidth: 200
                    Layout.fillHeight: true

                    // Modal radius minus its border, so the corners do not
                    // paint over the rounded border (clip is square).
                    topLeftRadius: 7
                    bottomLeftRadius: 7
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

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: 12

                                        visible: entry.selected && settings.dirtyCount > 0
                                        text: "●"
                                        color: Config.colors.accent

                                        font {
                                            family: Config.bar.fontFamily
                                            pixelSize: Config.bar.fontSize - 2
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settings.leave(entry.index)
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

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 24

                            visible: settings.dirtyCount > 0
                            text: settings.dirtyCount + (settings.dirtyCount === 1
                                ? " unsaved change"
                                : " unsaved changes")
                            color: Config.text.dim

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 2
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
                        Layout.topMargin: 4
                        Layout.leftMargin: 24
                        Layout.rightMargin: 32

                        // Width only, so the page keeps its own height and
                        // rows stay at the top.
                        Loader {
                            width: parent.width

                            // Locked while the save/discard prompt is open.
                            enabled: !settings.asking

                            sourceComponent: settings.pages[settings.sections[settings.current]] ?? null
                        }
                    }

                    // Footer, persistent sections only. Live sections get
                    // their own Close footer.
                    Item {
                        visible: settings.current >= settings.liveCount

                        Layout.fillWidth: true
                        Layout.preferredHeight: 52

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: Config.colors.border
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 16
                            spacing: 8

                            Text {
                                Layout.fillWidth: true

                                text: settings.asking ? "Unsaved changes" : settings.status
                                color: settings.asking ? Config.colors.yellow : settings.statusColor
                                elide: Text.ElideRight

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 2
                                }
                            }

                            FooterButton {
                                visible: !settings.asking
                                label: "Cancel"
                                hint: "Esc"
                                onClicked: settings.leave(-1)
                            }

                            FooterButton {
                                visible: !settings.asking
                                label: "Apply"
                                hint: "^S"
                                enabled: settings.canApply
                                onClicked: settings.apply(settings.current)
                            }

                            FooterButton {
                                visible: !settings.asking
                                label: "Save & Close"
                                hint: "^↵"
                                primary: true
                                enabled: settings.canApply
                                onClicked: settings.apply(-1)
                            }

                            // Save/discard prompt. The choice then finishes
                            // the move the user started (switch or close).
                            FooterButton {
                                visible: settings.asking
                                label: "Back"
                                hint: "Esc"
                                onClicked: settings.asking = false
                            }

                            FooterButton {
                                visible: settings.asking
                                label: "Discard"
                                hint: "D"
                                onClicked: settings.discard()
                            }

                            FooterButton {
                                visible: settings.asking
                                label: "Save"
                                hint: "S"
                                primary: true
                                enabled: settings.canApply
                                onClicked: settings.apply(settings.target)
                            }
                        }
                    }
                }
            }
        }
    }
}
