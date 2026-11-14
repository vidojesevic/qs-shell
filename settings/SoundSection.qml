import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// Live section: every change goes to PipeWire at once through pactl. Same
// data as the bar Volume popup, plus one volume row for each playing app.
// Enter picks the focused output. Left / Right change the focused volume
// by 5, M mutes it.
ColumnLayout {
    id: section

    required property var form

    readonly property string hint: "↵ select output · ←/→ volume · M mute"

    property string defaultSink: ""
    property int masterVolume: 0
    property bool masterMuted: false

    // A drag is on: a poll must not move the bars back. A change that is
    // still settling is covered by the guard timer.
    property bool dragging: false

    // Last volume change, sent after a short pause so a drag does not start
    // a process for each pixel. Its third item is the target.
    property var queued: null

    spacing: 0

    function clamp(value) {
        return Math.round(Math.max(0, Math.min(100, value)))
    }

    function percent(volume) {
        return Object.values(volume).reduce(
            (top, channel) => Math.max(top, parseInt(channel.value_percent) || 0), 0)
    }

    function send() {
        if (!section.queued)
            return

        Quickshell.execDetached(section.queued)
        section.queued = null
    }

    function queue(command) {
        if (section.queued && section.queued[2] !== command[2])
            section.send()

        section.queued = command
        guard.restart()
        sendTimer.restart()
    }

    function setMaster(value) {
        if (section.defaultSink === "")
            return

        section.masterVolume = section.clamp(value)
        section.queue(["pactl", "set-sink-volume", section.defaultSink, section.masterVolume + "%"])

        if (section.masterVolume > 0 && section.masterMuted) {
            section.masterMuted = false
            Quickshell.execDetached(["pactl", "set-sink-mute", section.defaultSink, "0"])
        }
    }

    function toggleMaster() {
        if (section.defaultSink === "")
            return

        section.masterMuted = !section.masterMuted
        Quickshell.execDetached(["pactl", "set-sink-mute", section.defaultSink, section.masterMuted ? "1" : "0"])
        guard.restart()
    }

    function setStream(row, value) {
        const level = section.clamp(value)
        streams.setProperty(row, "vol", level)
        section.queue(["pactl", "set-sink-input-volume", String(streams.get(row).stream), level + "%"])
    }

    function toggleStream(row) {
        const item = streams.get(row)
        const mute = !item.mute

        streams.setProperty(row, "mute", mute)
        Quickshell.execDetached(["pactl", "set-sink-input-mute", String(item.stream), mute ? "1" : "0"])
        guard.restart()
    }

    // Make the sink default, then move every playing stream onto it.
    function selectSink(name) {
        Quickshell.execDetached([
            "sh", "-c",
            "pactl set-default-sink \"$1\"; "
            + "for input in $(pactl list short sink-inputs | cut -f1); do "
            + "pactl move-sink-input \"$input\" \"$1\"; "
            + "done",
            "_", name
        ])

        settle.restart()
    }

    // Make model match items, row by row, so delegates (and focus) stay.
    function sync(model, key, items) {
        for (let i = model.count - 1; i >= 0; i--) {
            if (!items.some(item => item[key] === model.get(i)[key]))
                model.remove(i)
        }

        items.forEach((item, i) => {
            let at = -1
            for (let j = 0; j < model.count; j++) {
                if (model.get(j)[key] === item[key])
                    at = j
            }

            if (at < 0) {
                model.insert(i, item)
            } else {
                model.set(at, item)
                if (at !== i)
                    model.move(at, i, 1)
            }
        })
    }

    // A row left and took focus with it. Give focus to the page, so the
    // modal keys still work.
    function restoreFocus() {
        const focused = section.Window.activeFocusItem
        if (!focused || focused === section.Window.contentItem)
            section.forceActiveFocus()
    }

    Timer {
        id: guard

        interval: 600
    }

    Timer {
        id: sendTimer

        interval: 60
        onTriggered: section.send()
    }

    // Give the server a moment to apply a change.
    Timer {
        id: settle

        interval: 250
        onTriggered: pollProc.running = true
    }

    // A queued change must not be lost when the page goes away.
    Component.onDestruction: section.send()

    Timer {
        interval: 2000
        running: section.form.visible
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!pollProc.running)
                pollProc.running = true
        }
    }

    // Three parts split by "---": default sink name, sinks, sink inputs.
    Process {
        id: pollProc

        command: [
            "sh", "-c",
            "pactl get-default-sink; echo; echo ---; pactl -f json list sinks; "
            + "echo; echo ---; pactl -f json list sink-inputs"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n---\n")

                if (parts.length < 3 || guard.running || section.dragging)
                    return

                const name = parts[0].trim()
                const seen = {}
                const outputs = []

                section.defaultSink = name

                // PipeWire can list several nodes under one Pulse name.
                // pactl resolves a name to the first, so keep that one.
                for (const sink of JSON.parse(parts[1])) {
                    if (seen[sink.name])
                        continue

                    seen[sink.name] = true

                    const level = section.percent(sink.volume)

                    outputs.push({
                        name: sink.name,
                        description: sink.description,
                        vol: level,
                        isDefault: sink.name === name
                    })

                    if (sink.name === name) {
                        section.masterVolume = level
                        section.masterMuted = sink.mute
                    }
                }

                section.sync(sinks, "name", outputs)

                section.sync(streams, "stream", JSON.parse(parts[2]).map(input => ({
                    stream: input.index,
                    title: input.properties["application.name"]
                        || input.properties["node.name"] || "Stream",
                    vol: section.percent(input.volume),
                    mute: input.mute
                })))
            }
        }
    }

    ListModel {
        id: sinks

        onCountChanged: Qt.callLater(section.restoreFocus)
    }

    ListModel {
        id: streams

        onCountChanged: Qt.callLater(section.restoreFocus)
    }

    component GroupLabel: Item {
        id: group

        property string label

        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 32

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: group.label
            color: section.form.text.dim

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }
    }

    component Note: Text {
        Layout.preferredHeight: 28 + 2 * section.form.rowPadding
        verticalAlignment: Text.AlignVCenter

        color: section.form.text.dim

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize - 2
        }
    }

    // Name, mute icon, bar, percent. Emits the wanted level, the owner sets it.
    component VolumeRow: Rectangle {
        id: row

        property string label
        property int level
        property bool muted

        signal moved(int value)
        signal muteToggled()

        Layout.fillWidth: true
        implicitHeight: 28 + 2 * section.form.rowPadding

        radius: 6
        color: "transparent"

        activeFocusOnTab: true

        Keys.onLeftPressed: row.moved(row.level - 5)
        Keys.onRightPressed: row.moved(row.level + 5)
        Keys.onPressed: event => {
            if (event.key !== Qt.Key_M)
                return

            row.muteToggled()
            event.accepted = true
        }

        RowLayout {
            anchors.fill: parent
            spacing: 12

            Text {
                Layout.preferredWidth: 160

                text: row.label
                elide: Text.ElideRight
                color: section.form.text.normal

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Text {
                text: row.muted ? "󰖁" : "󰕾"
                color: row.muted ? section.form.text.dim : section.form.text.normal

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        row.forceActiveFocus()
                        row.muteToggled()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6

                radius: 3
                color: section.form.colors.border

                Rectangle {
                    width: parent.width * Math.min(100, row.level) / 100
                    height: parent.height

                    radius: 3
                    color: row.muted ? section.form.colors.muted : section.form.colors.accent
                }

                // Taller than the bar, so it is easy to hit.
                MouseArea {
                    anchors.fill: parent
                    anchors.topMargin: -8
                    anchors.bottomMargin: -8
                    cursorShape: Qt.PointingHandCursor

                    function seek(mouse) {
                        row.moved(Math.round(100 * Math.max(0, Math.min(1, mouse.x / width))))
                    }

                    onPressedChanged: section.dragging = pressed
                    onPressed: mouse => {
                        row.forceActiveFocus()
                        seek(mouse)
                    }
                    onPositionChanged: mouse => seek(mouse)
                }
            }

            Text {
                Layout.preferredWidth: 42

                horizontalAlignment: Text.AlignRight
                text: row.level + "%"
                color: section.form.text.dim

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: section.form.colors.border
        }

        FocusRing {
            form: section.form
            visible: row.activeFocus
        }
    }

    GroupLabel {
        label: "Volume"
    }

    VolumeRow {
        label: "Master"
        level: section.masterVolume
        muted: section.masterMuted

        onMoved: value => section.setMaster(value)
        onMuteToggled: section.toggleMaster()
    }

    GroupLabel {
        label: "Output"
    }

    Note {
        visible: sinks.count === 0
        text: "No output devices"
    }

    Repeater {
        model: sinks

        Rectangle {
            id: sink

            required property string name
            required property string description
            required property int vol
            required property bool isDefault

            Layout.fillWidth: true
            implicitHeight: 28 + 2 * section.form.rowPadding

            radius: 6
            color: "transparent"

            activeFocusOnTab: true

            Keys.onReturnPressed: section.selectSink(sink.name)
            Keys.onEnterPressed: section.selectSink(sink.name)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Text {
                    text: sink.description
                    color: sink.isDefault ? section.form.text.active : section.form.text.normal

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 2
                    }
                }

                Text {
                    visible: sink.isDefault
                    text: "default"
                    color: section.form.colors.green

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 2
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                text: sink.vol + "%"
                color: section.form.text.dim

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: section.form.colors.border
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    sink.forceActiveFocus()
                    section.selectSink(sink.name)
                }
            }

            FocusRing {
                form: section.form
                visible: sink.activeFocus
            }
        }
    }

    GroupLabel {
        label: "Applications"
    }

    Note {
        visible: streams.count === 0
        text: "Nothing is playing"
    }

    Repeater {
        model: streams

        VolumeRow {
            id: stream

            required property int index
            required property string title
            required property int vol
            required property bool mute

            label: stream.title
            level: stream.vol
            muted: stream.mute

            onMoved: value => section.setStream(stream.index, value)
            onMuteToggled: section.toggleStream(stream.index)
        }
    }
}
