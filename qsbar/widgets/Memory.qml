import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: memoryRoot

    // All values in kB, as reported by /proc/meminfo.
    property int total: 0
    property int available: 0
    property int cached: 0
    property int buffers: 0
    property int swapTotal: 0
    property int swapFree: 0

    readonly property int used: total - available

    readonly property int usage: total > 0
        ? Math.round(100 * used / total)
        : 0

    text: " " + usage + "%"
    color: memoryPopup.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    function gib(kb) {
        return (kb / 1048576).toFixed(1)
    }

    ListModel {
        id: processes
    }

    Process {
        id: memProc

        command: ["cat", "/proc/meminfo"]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(/\s+/)
                    const value = parseInt(parts[1]) || 0

                    switch (parts[0]) {
                    case "MemTotal:":
                        memoryRoot.total = value
                        break
                    case "MemAvailable:":
                        memoryRoot.available = value
                        break
                    case "Cached:":
                        memoryRoot.cached = value
                        break
                    case "Buffers:":
                        memoryRoot.buffers = value
                        break
                    case "SwapTotal:":
                        memoryRoot.swapTotal = value
                        break
                    case "SwapFree:":
                        memoryRoot.swapFree = value
                        break
                    }
                }
            }
        }
    }

    // Top memory consumers, only polled while the popup is open.
    Process {
        id: processProc

        command: [
            "sh",
            "-c",
            "ps -eo comm,rss --sort=-rss | sed -n '2,6p'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                processes.clear()

                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].trim().split(/\s+/)

                    if (parts.length < 2)
                        continue

                    processes.append({
                        name: parts[0],
                        rss: parseInt(parts[1]) || 0
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
            memProc.running = true

            if (memoryPopup.visible)
                processProc.running = true
        }

        Component.onCompleted: memProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!memoryPopup.visible)
                processProc.running = true

            memoryPopup.visible = !memoryPopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            memoryPopup.visible = false
        }
    }

    PopupWindow {
        id: memoryPopup

        anchor {
            item: memoryRoot

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
                        text: "Memory"
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
                        text: memoryRoot.gib(memoryRoot.total) + " GiB total"
                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: " " + memoryRoot.usage + "%"

                        color: memoryRoot.usage >= 85
                            ? Config.text.critical
                            : Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 4
                            bold: true
                        }
                    }

                    Text {
                        text: memoryRoot.gib(memoryRoot.used)
                            + " / " + memoryRoot.gib(memoryRoot.total) + " GiB"

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
                    Layout.fillWidth: true

                    implicitHeight: 8
                    radius: 4
                    color: Config.colors.muted

                    Rectangle {
                        width: parent.width * Math.min(memoryRoot.usage, 100) / 100
                        height: parent.height

                        radius: 4

                        color: memoryRoot.usage >= 85
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
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                GridLayout {
                    Layout.fillWidth: true

                    columns: 4
                    columnSpacing: 12
                    rowSpacing: 4

                    Repeater {
                        model: [
                            { label: "Used", value: memoryRoot.used },
                            { label: "Available", value: memoryRoot.available },
                            { label: "Cached", value: memoryRoot.cached },
                            { label: "Buffers", value: memoryRoot.buffers }
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
                                text: memoryRoot.gib(modelData.value) + " GiB"
                                color: Config.text.normal

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Swap"
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
                        text: memoryRoot.swapTotal > 0
                            ? memoryRoot.gib(memoryRoot.swapTotal - memoryRoot.swapFree)
                                + " / " + memoryRoot.gib(memoryRoot.swapTotal) + " GiB"
                            : "none"

                        color: Config.text.normal

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
                        required property int rss

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
                            text: (rss / 1024).toFixed(0) + " MiB"
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
