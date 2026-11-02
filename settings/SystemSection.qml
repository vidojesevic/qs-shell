import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// Read-only facts from system.sh, refreshed every 2 s while the modal shows
// this section. Ctrl+C copies them as plain text (the modal calls copy()).
ColumnLayout {
    id: section

    required property var form

    // Read by the modal: note in the pane header, hint in the footer.
    readonly property Component header: note
    readonly property string hint: "Values are live; nothing here is saved"

    // Fixed layout. Values come from rows, so the 2 s refresh does not
    // rebuild the rows or move the scroll.
    readonly property var groups: [
        { label: "Device", keys: ["Hostname", "OS", "Kernel", "Uptime"] },
        { label: "Shell", keys: ["Hyprland", "Quickshell", "Config"] },
        { label: "Hardware", keys: ["CPU", "Memory", "GPU", "Disk /", "Battery"] }
    ]

    property var facts: ({})
    property var values: ({})

    // CPU load from the change in /proc/stat since the last refresh.
    property var cpuLast: ({ idle: 0, total: 0 })
    property int cpuUsage: 0

    // Row key: { value, details, percent }. percent < 0 shows no bar.
    readonly property var rows: {
        const f = section.facts
        const v = section.values
        const rows = {}

        // Before both scripts answer, show nothing rather than undefined.
        if (f.host === undefined || v.uptime === undefined)
            return rows

        rows["Hostname"] = { value: f.host }
        rows["OS"] = { value: f.os, details: [f.arch, f.init].join(" · ") }
        rows["Kernel"] = { value: f.kernel }
        rows["Uptime"] = { value: section.duration(parseFloat(v.uptime) / 3600) }

        rows["Hyprland"] = { value: f.hyprland }
        rows["Quickshell"] = { value: f.quickshell, details: "Qt " + f.qt }
        rows["Config"] = { value: (Quickshell.shellDir + "/config.js").replace(Quickshell.env("HOME"), "~") }

        rows["CPU"] = {
            details: [f.cpu, f.cores + "c/" + f.threads + "t", section.temperature(v.cputemp)].join(" · "),
            percent: section.cpuUsage
        }

        const memoryUsed = v.memtotal - v.memavailable
        rows["Memory"] = {
            details: section.gib(memoryUsed) + " / " + section.gib(v.memtotal) + " GB",
            percent: Math.round(100 * memoryUsed / v.memtotal)
        }

        if (f.gpu)
            rows["GPU"] = {
                details: [f.gpu, v.gpustate ?? section.temperature(v.gputemp)].join(" · "),
                percent: v.gpuusage === undefined ? -1 : parseInt(v.gpuusage)
            }

        rows["Disk /"] = {
            details: Math.round(v.diskused / 1e9) + " / " + Math.round(v.disksize / 1e9) + " GB · " + v.diskfs,
            percent: Math.round(100 * v.diskused / v.disksize)
        }

        if (v.battery !== undefined)
            rows["Battery"] = {
                details: [v.batterystatus.toLowerCase(), section.batteryTime(v)].join(" · "),
                percent: parseInt(v.battery)
            }

        return rows
    }

    spacing: 0

    function parse(text) {
        const result = {}
        for (const line of text.trim().split("\n")) {
            const split = line.indexOf("=")
            const value = line.slice(split + 1)
            if (split > 0 && value !== "")
                result[line.slice(0, split)] = value
        }
        return result
    }

    function duration(hours) {
        const minutes = Math.round(hours * 60)
        const days = Math.floor(minutes / 1440)
        const text = Math.floor(minutes % 1440 / 60) + " h " + minutes % 60 + " m"
        return days > 0 ? days + " d " + text : text
    }

    function gib(kb) {
        return (kb / 1048576).toFixed(1)
    }

    function temperature(milli) {
        return milli === undefined ? "" : Math.round(milli / 1000) + " °C"
    }

    function batteryTime(v) {
        const rate = parseFloat(v.batteryrate)
        if (!(rate > 0))
            return ""
        if (v.batterystatus === "Discharging")
            return section.duration(v.batterynow / rate) + " left"
        if (v.batterystatus === "Charging")
            return section.duration((v.batteryfull - v.batterynow) / rate) + " to full"
        return ""
    }

    function line(key) {
        const row = section.rows[key]
        const parts = [row.value, row.details, row.percent >= 0 ? row.percent + " %" : ""]
        return key + ": " + parts.filter(part => part).join(" · ")
    }

    function copy() {
        const lines = []
        for (const group of section.groups) {
            lines.push(group.label)
            for (const key of group.keys)
                if (section.rows[key])
                    lines.push("  " + section.line(key))
        }

        copyProc.command = ["wl-copy", lines.join("\n")]
        copyProc.running = true
    }

    Process {
        running: true
        command: [Quickshell.shellDir + "/settings/system.sh", "static"]

        stdout: StdioCollector {
            onStreamFinished: section.facts = section.parse(text)
        }
    }

    Process {
        id: liveProc

        command: [Quickshell.shellDir + "/settings/system.sh", "live"]

        stdout: StdioCollector {
            onStreamFinished: {
                const values = section.parse(text)

                const fields = values.cpustat.split(/\s+/).slice(1).map(Number)
                const idle = fields[3] + fields[4]
                const total = fields.reduce((sum, value) => sum + value, 0)
                const last = section.cpuLast
                section.cpuUsage = Math.round(100 * (1 - (idle - last.idle) / (total - last.total)))
                section.cpuLast = { idle: idle, total: total }

                section.values = values
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: section.form.visible
        triggeredOnStart: true
        onTriggered: liveProc.running = true
    }

    Process {
        id: copyProc

        onExited: code => {
            if (code === 0)
                section.form.showStatus("✓ Copied", section.form.colors.green)
            else
                section.form.showStatus("Copy failed: wl-copy exit " + code, section.form.colors.red)
        }
    }

    Component {
        id: note

        Text {
            text: "read-only · refreshes every 2 s"
            color: section.form.text.dim

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }
    }

    Repeater {
        model: section.groups

        ColumnLayout {
            id: group

            required property var modelData

            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.topMargin: 8
                Layout.preferredHeight: 28
                verticalAlignment: Text.AlignVCenter

                text: group.modelData.label
                color: section.form.text.dim

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Repeater {
                model: group.modelData.keys

                Item {
                    id: row

                    required property string modelData
                    readonly property var info: section.rows[row.modelData] ?? null

                    visible: row.info !== null
                    Layout.fillWidth: true
                    implicitHeight: 32

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        text: row.modelData
                        color: section.form.colors.foregroundAlt

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            visible: text !== ""
                            text: row.info?.value ?? ""
                            color: section.form.colors.foreground

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 2
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            visible: text !== ""
                            text: row.info?.details ?? ""
                            color: section.form.text.dim

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 2
                            }
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter

                            visible: (row.info?.percent ?? -1) >= 0
                            width: 96
                            height: 6

                            radius: 3
                            color: section.form.colors.border

                            Rectangle {
                                width: 96 * Math.min(100, row.info?.percent ?? 0) / 100
                                height: 6

                                radius: 3
                                color: section.form.colors.accent
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter

                            visible: (row.info?.percent ?? -1) >= 0
                            width: 40
                            horizontalAlignment: Text.AlignRight

                            text: (row.info?.percent ?? 0) + " %"
                            color: section.form.colors.foreground

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
                }
            }
        }
    }
}
