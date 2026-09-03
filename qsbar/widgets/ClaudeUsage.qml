import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: claudeRoot

    // Threshold for the danger styling and the desktop warning.
    property int dangerLevel: 80

    property int tokens: 0
    property int limit: 0
    property int percent: 0
    property int messages: 0
    property int remainingMinutes: 0
    property int burnPerMinute: 0
    property string blockStart: ""
    property string blockEnd: ""
    property bool blockActive: false

    // [{ name, tokens }]
    property var models: []
    property var projects: []

    // Block already warned about, so one window notifies once.
    property string notifiedBlock: ""

    readonly property bool danger: blockActive && percent >= dangerLevel

    text: "󰚩 " + (blockActive ? percent + "%" : "idle")

    color: claudePopup.visible
        ? Config.text.active
        : (danger ? Config.text.critical : Config.text.normal)

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    function compact(count) {
        if (count >= 1000000)
            return (count / 1000000).toFixed(1) + "M"

        if (count >= 1000)
            return (count / 1000).toFixed(0) + "k"

        return count
    }

    function clock(minutes) {
        const hours = Math.floor(minutes / 60)

        return hours > 0
            ? hours + "h " + (minutes % 60) + "m"
            : minutes + "m"
    }

    // Model ids are long in the bar popup, the family is enough.
    function modelName(id) {
        return id.replace("claude-", "").replace(/-\d{8}$/, "")
    }

    Process {
        id: usageProc

        command: [Quickshell.shellDir + "/qsbar/widgets/claude-usage.py"]

        stdout: StdioCollector {
            onStreamFinished: {
                const data = JSON.parse(text)

                claudeRoot.blockActive = data.active
                claudeRoot.tokens = data.tokens
                claudeRoot.limit = data.limit
                claudeRoot.percent = data.percent
                claudeRoot.messages = data.messages
                claudeRoot.remainingMinutes = data.remainingMinutes
                claudeRoot.burnPerMinute = data.burnPerMinute || 0
                claudeRoot.blockStart = data.blockStart || ""
                claudeRoot.blockEnd = data.blockEnd || ""
                claudeRoot.models = data.models
                claudeRoot.projects = data.projects

                if (claudeRoot.danger && claudeRoot.notifiedBlock !== data.blockStart) {
                    claudeRoot.notifiedBlock = data.blockStart

                    notifyProc.command = [
                        "notify-send",
                        "-u", "critical",
                        "-a", "Claude Code",
                        "Claude usage at " + data.percent + "%",
                        claudeRoot.compact(data.tokens) + " of "
                            + claudeRoot.compact(data.limit)
                            + " tokens, window resets at " + data.blockEnd
                    ]

                    notifyProc.running = true
                }
            }
        }
    }

    Process {
        id: notifyProc
    }

    Timer {
        interval: 60000
        running: true
        repeat: true

        onTriggered: usageProc.running = true
        Component.onCompleted: usageProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            usageProc.running = true
            claudePopup.visible = !claudePopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            claudePopup.visible = false
        }
    }

    PopupWindow {
        id: claudePopup

        anchor {
            item: claudeRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 460
        implicitHeight: 320

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
                        text: "Claude usage"
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
                        text: claudeRoot.blockActive
                            ? claudeRoot.blockStart + " – " + claudeRoot.blockEnd
                            : "no active window"

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
                        text: "󰚩 " + claudeRoot.percent + "%"

                        color: claudeRoot.danger
                            ? Config.text.critical
                            : Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 4
                            bold: true
                        }
                    }

                    Text {
                        text: claudeRoot.compact(claudeRoot.tokens)
                            + " / " + claudeRoot.compact(claudeRoot.limit) + " tokens"

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
                        width: parent.width * Math.min(claudeRoot.percent, 100) / 100
                        height: parent.height

                        radius: 4

                        color: claudeRoot.danger
                            ? Config.colors.red
                            : Config.colors.purple

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

                    columns: 3
                    columnSpacing: 12
                    rowSpacing: 4

                    Repeater {
                        model: [
                            {
                                label: "Resets in",
                                value: claudeRoot.clock(claudeRoot.remainingMinutes)
                            },
                            {
                                label: "Replies",
                                value: "" + claudeRoot.messages
                            },
                            {
                                label: "Burn",
                                value: claudeRoot.compact(claudeRoot.burnPerMinute) + "/min"
                            }
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
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Text {
                    text: "Models"
                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                Repeater {
                    model: claudeRoot.models

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true

                            text: claudeRoot.modelName(modelData.name)
                            color: Config.text.normal
                            elide: Text.ElideRight

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }

                        Text {
                            text: claudeRoot.compact(modelData.tokens)
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                                bold: true
                            }
                        }
                    }
                }

                Text {
                    text: "Projects"
                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                Repeater {
                    model: claudeRoot.projects

                    delegate: RowLayout {
                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true

                            // Project dirs are stored as flattened paths.
                            text: modelData.name.split("-").pop()
                            color: Config.text.normal
                            elide: Text.ElideRight

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }

                        Text {
                            text: claudeRoot.compact(modelData.tokens)
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
