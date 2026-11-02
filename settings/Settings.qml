import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "../config.js" as Config
import "../theme/catppuccin.js" as Catppuccin
import "../theme/dracula.js" as Dracula
import "../theme/onedark.js" as Onedark
import "../theme/tokyonight.js" as Tokyonight
import "../theme/ember.js" as Ember

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
    // No Apply cycle: the live sections and the read-only System.
    readonly property bool live: current < liveCount || sections[current] === "System"

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

    // Asks the theme switcher for a theme. Connected in shell.qml.
    signal themeRequested(string name)

    // Theme is not in config.js. Its original value is the name that
    // theme/current.js links to.
    property string currentTheme: ""

    readonly property var themes: ({
        catppuccin: Catppuccin,
        dracula: Dracula,
        onedark: Onedark,
        tokyonight: Tokyonight,
        ember: Ember
    })

    // Modal colors. A pending theme shows here before Apply.
    readonly property var look: settings.themes[settings.pending.theme] ?? Config
    readonly property var colors: settings.look.colors
    readonly property var text: settings.look.text

    // Pane content per section. Sections without a page show an empty pane.
    readonly property var pages: ({
        Network: networkPage,
        Bluetooth: bluetoothPage,
        Appearance: appearancePage,
        Bar: barPage,
        Notifications: notificationsPage,
        Screensaver: screensaverPage,
        System: systemPage
    })

    Component {
        id: networkPage

        NetworkSection {
            form: settings
        }
    }

    Component {
        id: bluetoothPage

        BluetoothSection {
            form: settings
        }
    }

    Component {
        id: appearancePage

        AppearanceSection {
            form: settings
        }
    }

    Component {
        id: barPage

        BarSection {
            form: settings
        }
    }

    Component {
        id: notificationsPage

        NotificationsSection {
            form: settings
        }
    }

    Component {
        id: systemPage

        SystemSection {
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
    property color statusColor: settings.colors.green

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
    onCurrentChanged: {
        keys.forceActiveFocus()
        body.contentY = 0
    }

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
        property string theme: ""

        // Wait until the reload is done. A window made visible during the
        // reload crashes Quickshell (null window in connectWindow).
        onReloaded: Qt.callLater(persist.restore)

        function restore() {
            if (open) {
                settings.current = section
                settings.screen = settings.screenNamed(screenName)
                settings.visible = true
            }

            // config.js was saved; the theme switch goes next. It reloads
            // again, and the values kept here reopen the modal after it.
            if (theme !== "") {
                const name = theme
                theme = ""
                settings.themeRequested(name)
                return
            }

            if (applied)
                settings.showStatus("✓ Applied", settings.colors.green)

            open = false
            applied = false
        }
    }

    Process {
        running: true
        command: ["readlink", Quickshell.shellDir + "/theme/current.js"]

        stdout: StdioCollector {
            onStreamFinished: settings.currentTheme = text.trim().replace(/\.js$/, "")
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
        if (key === "theme")
            return settings.currentTheme

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

        // The theme goes to the theme switcher, the rest to config.js.
        const changes = Object.assign({}, settings.pending)
        const theme = changes.theme ?? ""
        delete changes.theme

        if (Object.keys(changes).length === 0) {
            settings.themeRequested(theme)
            return
        }

        persist.theme = theme

        const reason = configFile.save(changes)
        if (reason)
            settings.failed(reason)
    }

    function failed(reason) {
        persist.open = false
        persist.applied = false
        persist.theme = ""
        settings.visible = true
        settings.showStatus("Reload failed: " + reason, settings.colors.red)
    }

    function showStatus(text, color) {
        settings.status = text
        settings.statusColor = color
        statusTimer.restart()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(settings.colors.background, 0.7)

        MouseArea {
            anchors.fill: parent
            onClicked: settings.leave(-1)
        }

        Rectangle {
            anchors.centerIn: parent

            implicitWidth: 960
            implicitHeight: 560

            radius: 8
            color: settings.colors.background
            border.color: settings.colors.border
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
                    } else if (key === Qt.Key_R && page.item?.rescan) {
                        page.item.rescan()
                    } else if (key === Qt.Key_C && page.item?.copy) {
                        page.item.copy()
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
                    color: settings.colors.backgroundAlt

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
                            color: settings.text.normal

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

                                    color: settings.colors.border
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32

                                    radius: 6
                                    color: entry.selected ? settings.colors.background : "transparent"

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 12

                                        text: entry.modelData
                                        color: entry.selected ? settings.text.active : settings.colors.foregroundAlt

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
                                        color: settings.colors.accent

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
                            color: settings.text.dim

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
                        color: settings.colors.border
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
                            color: settings.text.normal

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
                            color: settings.text.dim

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 2
                            }
                        }

                        // A live section's own control, such as the Wi-Fi
                        // radio switch.
                        Loader {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 24

                            sourceComponent: page.item?.header ?? null
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: settings.colors.border
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 4

                        // Scrolls when the page is taller than the pane. The
                        // page margins sit inside it, so focus rings at the
                        // page edge are not clipped.
                        Flickable {
                            id: body

                            anchors.fill: parent
                            contentHeight: page.height
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            // Keep the focused control in view while Tab
                            // moves through the page.
                            readonly property Item focused: Window.activeFocusItem
                            onFocusedChanged: body.reveal(body.focused)

                            function reveal(item) {
                                let parent = item
                                while (parent && parent !== body.contentItem)
                                    parent = parent.parent
                                if (!parent)
                                    return

                                const margin = settings.rowPadding
                                const top = item.mapToItem(body.contentItem, 0, 0).y - margin
                                const bottom = top + item.height + 2 * margin

                                if (top < body.contentY)
                                    body.contentY = Math.max(0, top)
                                else if (bottom > body.contentY + body.height)
                                    body.contentY = Math.min(body.contentHeight - body.height, bottom - body.height)
                            }

                            // Width only, so the page keeps its own height
                            // and rows stay at the top.
                            Loader {
                                id: page

                                x: 24
                                width: body.width - 24 - 32

                                // Locked while the save/discard prompt is open.
                                enabled: !settings.asking

                                sourceComponent: settings.pages[settings.sections[settings.current]] ?? null
                            }
                        }

                        // Scrollbar, in the right page margin.
                        Rectangle {
                            visible: body.contentHeight > body.height

                            x: parent.width - 16
                            y: 8
                            width: 4
                            height: parent.height - 16

                            radius: 2
                            color: settings.colors.border

                            Rectangle {
                                y: body.visibleArea.yPosition * parent.height
                                width: 4
                                height: body.visibleArea.heightRatio * parent.height

                                radius: 2
                                color: settings.colors.muted
                            }
                        }
                    }

                    // Footer. Sections without an Apply cycle show their
                    // hint and Close (System adds Copy report).
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 52

                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: 1
                            color: settings.colors.border
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 24
                            anchors.rightMargin: 16
                            spacing: 8

                            Text {
                                Layout.fillWidth: true

                                text: settings.asking ? "Unsaved changes"
                                    : settings.status || (page.item?.hint ?? "")
                                color: settings.asking ? settings.colors.yellow
                                    : settings.status ? settings.statusColor
                                    : settings.text.dim
                                elide: Text.ElideRight

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 2
                                }
                            }

                            FooterButton {
                                form: settings
                                visible: !!page.item?.copy
                                label: "Copy report"
                                hint: "^C"
                                onClicked: page.item.copy()
                            }

                            FooterButton {
                                form: settings
                                visible: settings.live
                                label: "Close"
                                hint: "Esc"
                                onClicked: settings.leave(-1)
                            }

                            FooterButton {
                                form: settings
                                visible: !settings.asking && !settings.live
                                label: "Cancel"
                                hint: "Esc"
                                onClicked: settings.leave(-1)
                            }

                            FooterButton {
                                form: settings
                                visible: !settings.asking && !settings.live
                                label: "Apply"
                                hint: "^S"
                                enabled: settings.canApply
                                onClicked: settings.apply(settings.current)
                            }

                            FooterButton {
                                form: settings
                                visible: !settings.asking && !settings.live
                                label: "Save & Close"
                                hint: "^↵"
                                primary: true
                                enabled: settings.canApply
                                onClicked: settings.apply(-1)
                            }

                            // Save/discard prompt. The choice then finishes
                            // the move the user started (switch or close).
                            FooterButton {
                                form: settings
                                visible: settings.asking
                                label: "Back"
                                hint: "Esc"
                                onClicked: settings.asking = false
                            }

                            FooterButton {
                                form: settings
                                visible: settings.asking
                                label: "Discard"
                                hint: "D"
                                onClicked: settings.discard()
                            }

                            FooterButton {
                                form: settings
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
