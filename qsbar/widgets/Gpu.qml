import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: gpuRoot

    // False while the dGPU is runtime-suspended. We do not call
    // nvidia-smi then, because it wakes the card and costs battery.
    property bool active: false

    property string name: ""
    property int usage: 0
    property int memoryUsed: 0   // MiB
    property int memoryTotal: 0  // MiB
    property int temperature: 0
    property real power: 0
    property int clock: 0

    readonly property int memoryUsage: memoryTotal > 0
        ? Math.round(100 * memoryUsed / memoryTotal)
        : 0

    text: active ? "󰢮 " + usage + "%" : "󰢮 off"
    color: gpuPopup.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    function gib(mib) {
        return (mib / 1024).toFixed(1)
    }

    ListModel {
        id: processes
    }

    Process {
        id: gpuProc

        command: [
            "sh",
            "-c",
            "[ \"$(cat /sys/bus/pci/drivers/nvidia/*/power/runtime_status)\" = suspended ] && exit; "
            + "nvidia-smi --format=csv,noheader,nounits "
            + "--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,clocks.gr"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/,\s*/)

                gpuRoot.active = parts.length >= 7

                if (!gpuRoot.active)
                    return

                gpuRoot.name = parts[0]
                gpuRoot.usage = parseInt(parts[1]) || 0
                gpuRoot.memoryUsed = parseInt(parts[2]) || 0
                gpuRoot.memoryTotal = parseInt(parts[3]) || 0
                gpuRoot.temperature = parseInt(parts[4]) || 0
                gpuRoot.power = parseFloat(parts[5]) || 0
                gpuRoot.clock = parseInt(parts[6]) || 0
            }
        }
    }

    // Top VRAM consumers, only polled while the popup is open.
    Process {
        id: processProc

        command: [
            "sh",
            "-c",
            "nvidia-smi --format=csv,noheader,nounits "
            + "--query-compute-apps=process_name,used_memory | sort -t, -k2 -rn | head -5"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                processes.clear()

                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(/,\s*/)

                    if (parts.length < 2)
                        continue

                    processes.append({
                        name: parts[0].split("/").pop(),
                        vram: parseInt(parts[1]) || 0
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
            gpuProc.running = true

            if (gpuPopup.visible && gpuRoot.active)
                processProc.running = true
        }

        Component.onCompleted: gpuProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!gpuPopup.visible && gpuRoot.active)
                processProc.running = true

            gpuPopup.visible = !gpuPopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            gpuPopup.visible = false
        }
    }

    PopupWindow {
        id: gpuPopup

        anchor {
            item: gpuRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 460
        implicitHeight: 340

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
                        text: "GPU"
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
                        Layout.maximumWidth: 340

                        text: gpuRoot.name
                        color: Config.text.dim
                        elide: Text.ElideRight

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
                    }
                }

                Text {
                    visible: !gpuRoot.active

                    text: "Sleeping (runtime suspended)"
                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize
                    }
                }

                RowLayout {
                    visible: gpuRoot.active

                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: "󰢮 " + gpuRoot.usage + "%"

                        color: gpuRoot.usage >= 85
                            ? Config.text.critical
                            : Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 4
                            bold: true
                        }
                    }

                    Text {
                        text: gpuRoot.gib(gpuRoot.memoryUsed)
                            + " / " + gpuRoot.gib(gpuRoot.memoryTotal) + " GiB VRAM"

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
                }

                Rectangle {
                    visible: gpuRoot.active

                    Layout.fillWidth: true

                    implicitHeight: 8
                    radius: 4
                    color: Config.colors.muted

                    Rectangle {
                        width: parent.width * Math.min(gpuRoot.usage, 100) / 100
                        height: parent.height

                        radius: 4

                        color: gpuRoot.usage >= 85
                            ? Config.colors.red
                            : Config.colors.cyan

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                            }
                        }
                    }
                }

                Rectangle {
                    visible: gpuRoot.active

                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                GridLayout {
                    visible: gpuRoot.active

                    Layout.fillWidth: true

                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4

                    Repeater {
                        model: [
                            { label: "VRAM", value: gpuRoot.memoryUsage + "%" },
                            { label: "Temperature", value: gpuRoot.temperature + "°C" },
                            { label: "Power", value: gpuRoot.power.toFixed(1) + " W" },
                            { label: "Clock", value: gpuRoot.clock + " MHz" }
                        ]

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.label
                                color: Config.text.dim

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.value
                                color: Config.text.normal

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: gpuRoot.active

                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Text {
                    visible: gpuRoot.active

                    text: processes.count > 0 ? "Top processes" : "No GPU processes"
                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                Repeater {
                    model: gpuRoot.active ? processes : null

                    delegate: RowLayout {
                        required property string name
                        required property int vram

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
                            text: vram + " MiB"
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
