import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: cpuRoot

    property int usage: 0
    property string model: ""
    property int coreCount: 0
    property real frequency: 0
    property string loadAverage: ""
    property int temperature: 0

    property var lastIdle: []
    property var lastTotal: []

    text: "󰍛 " + usage + "%"
    color: cpuPopup.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    ListModel {
        id: cores
    }

    ListModel {
        id: processes
    }

    // Per-core and total usage from /proc/stat.
    Process {
        id: statProc

        command: ["cat", "/proc/stat"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const idle = []
                const total = []

                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("cpu") !== 0)
                        break

                    const parts = lines[i].trim().split(/\s+/)

                    idle.push(parseInt(parts[4]) + parseInt(parts[5]))

                    total.push(parts.slice(1, 8).reduce(
                        (sum, value) => sum + parseInt(value), 0))
                }

                if (cpuRoot.lastTotal.length === total.length) {
                    for (let i = 0; i < total.length; i++) {
                        const totalDelta = total[i] - cpuRoot.lastTotal[i]

                        const percent = totalDelta > 0
                            ? Math.round(100 * (1 - (idle[i] - cpuRoot.lastIdle[i]) / totalDelta))
                            : 0

                        if (i === 0) {
                            cpuRoot.usage = percent
                            continue
                        }

                        if (cores.count >= i)
                            cores.setProperty(i - 1, "usage", percent)
                        else
                            cores.append({ core: i - 1, usage: percent })
                    }
                }

                cpuRoot.lastIdle = idle
                cpuRoot.lastTotal = total
            }
        }
    }

    // Model name and core count, read once.
    Process {
        id: modelProc

        command: [
            "sh",
            "-c",
            "grep -m1 'model name' /proc/cpuinfo | cut -d: -f2; nproc"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                cpuRoot.model = lines[0] ? lines[0].trim() : "Unknown"
                cpuRoot.coreCount = parseInt(lines[1]) || 0
            }
        }
    }

    // Frequency, load average, temperature and top processes.
    Process {
        id: detailProc

        command: [
            "sh",
            "-c",
            "awk '{ sum += $1; n++ } END { printf \"%.2f\\n\", n ? sum / n / 1000000 : 0 }' "
            + "/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; "
            + "cut -d' ' -f1-3 /proc/loadavg; "
            + "for hwmon in /sys/class/hwmon/hwmon*; do "
            + "case \"$(cat $hwmon/name 2>/dev/null)\" in "
            + "coretemp|k10temp|zenpower) cat $hwmon/temp1_input 2>/dev/null; break;; "
            + "esac; done; "
            + "ps -eo comm,%cpu --sort=-%cpu | sed -n '2,6p'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                cpuRoot.frequency = parseFloat(lines[0]) || 0
                cpuRoot.loadAverage = lines[1] || ""
                cpuRoot.temperature = Math.round((parseInt(lines[2]) || 0) / 1000)

                processes.clear()

                for (let i = 3; i < lines.length; i++) {
                    const parts = lines[i].trim().split(/\s+/)

                    if (parts.length < 2)
                        continue

                    processes.append({
                        name: parts[0],
                        share: parts[1]
                    })
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true

        onTriggered: {
            statProc.running = true

            if (cpuPopup.visible)
                detailProc.running = true
        }

        Component.onCompleted: {
            statProc.running = true
            modelProc.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!cpuPopup.visible)
                detailProc.running = true

            cpuPopup.visible = !cpuPopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            cpuPopup.visible = false
        }
    }

    PopupWindow {
        id: cpuPopup

        anchor {
            item: cpuRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 460
        implicitHeight: 450

        visible: false
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible)
                popupCloseTimer.restart()
            else
                popupCloseTimer.stop()
        }

        Rectangle {
            anchors.fill: parent

            radius: 8
            color: Config.colors.background

            border {
                width: 1
                color: Config.colors.muted
            }

            // Keep popup open while pointer is over it.
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        popupCloseTimer.stop()
                    else
                        popupCloseTimer.restart()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "CPU"
                        color: Config.text.active

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                            bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: cpuRoot.temperature > 0

                        text: "󰔏 " + cpuRoot.temperature + "°C"

                        color: cpuRoot.temperature >= 80
                            ? Config.text.critical
                            : Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true

                    text: cpuRoot.model
                    color: Config.text.dim
                    elide: Text.ElideRight

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: "󰍛 " + cpuRoot.usage + "%"
                        color: Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 4
                            bold: true
                        }
                    }

                    Text {
                        text: cpuRoot.frequency.toFixed(2) + " GHz"
                        color: Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "load " + cpuRoot.loadAverage
                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Text {
                    text: cpuRoot.coreCount + " threads"
                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                GridLayout {
                    Layout.fillWidth: true

                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4

                    Repeater {
                        model: cores

                        delegate: RowLayout {
                            required property int core
                            required property int usage

                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                Layout.preferredWidth: 26

                                text: "C" + core
                                color: Config.text.dim

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 4
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true

                                implicitHeight: 6
                                radius: 3
                                color: Config.colors.muted

                                Rectangle {
                                    width: parent.width * Math.min(usage, 100) / 100
                                    height: parent.height

                                    radius: 3

                                    color: usage >= 80
                                        ? Config.colors.red
                                        : Config.colors.yellow

                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 300
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignRight

                                text: usage + "%"
                                color: Config.text.normal

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 4
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Text {
                    text: "Top processes"
                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                Repeater {
                    model: processes

                    delegate: RowLayout {
                        required property string name
                        required property string share

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true

                            text: name
                            color: Config.text.normal
                            elide: Text.ElideRight

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }

                        Text {
                            text: share + "%"
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                                bold: true
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }
}
