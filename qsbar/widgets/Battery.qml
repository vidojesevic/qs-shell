import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: batteryRoot

    property int percent: 0
    property string status: ""
    property int cycles: 0
    property string technology: ""
    property string model: ""
    property bool acOnline: false

    // Microwatt / microwatt-hour / microvolt, straight from sysfs.
    property real powerNow: 0
    property real energyNow: 0
    property real energyFull: 0
    property real energyDesign: 0
    property real voltageNow: 0

    readonly property bool charging: status === "Charging"

    readonly property int health: energyDesign > 0
        ? Math.round(100 * energyFull / energyDesign)
        : 0

    // Hours left until empty, or until full while charging.
    readonly property real hoursLeft: {
        if (powerNow <= 0)
            return 0

        return charging
            ? (energyFull - energyNow) / powerNow
            : energyNow / powerNow
    }

    function levelIcon() {
        if (charging)
            return "󰂄"

        const icons = [
            "󰂎", "󰁺", "󰁻", "󰁼", "󰁽",
            "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"
        ]

        return icons[Math.min(10, Math.max(0, Math.round(percent / 10)))]
    }

    function levelColor() {
        if (charging)
            return Config.colors.blue

        if (percent <= 15)
            return Config.colors.red

        if (percent <= 30)
            return Config.colors.yellow

        return Config.colors.cyan
    }

    function duration(hours) {
        if (hours <= 0)
            return "—"

        const whole = Math.floor(hours)
        const minutes = Math.round((hours - whole) * 60)

        return whole + "h " + minutes + "m"
    }

    text: levelIcon() + " " + percent + "%"
    color: levelColor()

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    Process {
        id: batteryProc

        command: [
            "sh",
            "-c",
            "battery=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1); "
            + "[ -n \"$battery\" ] || exit 0; "
            + "for field in capacity status power_now energy_now energy_full "
            + "energy_full_design voltage_now cycle_count technology model_name; do "
            + "echo \"$field=$(cat $battery/$field 2>/dev/null)\"; "
            + "done; "
            + "echo \"ac=$(cat /sys/class/power_supply/A[CD]*/online 2>/dev/null | head -n 1)\""
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; i++) {
                    const split = lines[i].indexOf("=")

                    if (split < 0)
                        continue

                    const key = lines[i].slice(0, split)
                    const value = lines[i].slice(split + 1)

                    switch (key) {
                    case "capacity":
                        batteryRoot.percent = parseInt(value) || 0
                        break
                    case "status":
                        batteryRoot.status = value
                        break
                    case "power_now":
                        batteryRoot.powerNow = parseFloat(value) || 0
                        break
                    case "energy_now":
                        batteryRoot.energyNow = parseFloat(value) || 0
                        break
                    case "energy_full":
                        batteryRoot.energyFull = parseFloat(value) || 0
                        break
                    case "energy_full_design":
                        batteryRoot.energyDesign = parseFloat(value) || 0
                        break
                    case "voltage_now":
                        batteryRoot.voltageNow = parseFloat(value) || 0
                        break
                    case "cycle_count":
                        batteryRoot.cycles = parseInt(value) || 0
                        break
                    case "technology":
                        batteryRoot.technology = value
                        break
                    case "model_name":
                        batteryRoot.model = value
                        break
                    case "ac":
                        batteryRoot.acOnline = value === "1"
                        break
                    }
                }
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!batteryProc.running)
                batteryProc.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!batteryPopup.visible)
                batteryProc.running = true

            batteryPopup.visible = !batteryPopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            batteryPopup.visible = false
        }
    }

    PopupWindow {
        id: batteryPopup

        anchor {
            item: batteryRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 460
        implicitHeight: 200

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
                        text: "Battery"
                        color: Config.colors.cyan

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
                        text: batteryRoot.acOnline ? "󰚥 AC" : "󰁽 On battery"

                        color: batteryRoot.acOnline
                            ? Config.colors.blue
                            : Config.colors.muted

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
                        text: batteryRoot.levelIcon() + " " + batteryRoot.percent + "%"
                        color: batteryRoot.levelColor()

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 4
                            bold: true
                        }
                    }

                    Text {
                        text: batteryRoot.status
                        color: Config.colors.foreground

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
                        visible: batteryRoot.hoursLeft > 0

                        text: batteryRoot.duration(batteryRoot.hoursLeft)
                            + (batteryRoot.charging ? " to full" : " left")

                        color: Config.colors.muted

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true

                    implicitHeight: 8
                    radius: 4
                    color: Config.colors.muted

                    Rectangle {
                        width: parent.width * Math.min(batteryRoot.percent, 100) / 100
                        height: parent.height

                        radius: 4
                        color: batteryRoot.levelColor()

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

                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 4

                    Repeater {
                        model: [
                            {
                                label: "Draw",
                                value: (batteryRoot.powerNow / 1000000).toFixed(1) + " W"
                            },
                            {
                                label: "Voltage",
                                value: (batteryRoot.voltageNow / 1000000).toFixed(2) + " V"
                            },
                            {
                                label: "Charge",
                                value: (batteryRoot.energyNow / 1000000).toFixed(1)
                                    + " / " + (batteryRoot.energyFull / 1000000).toFixed(1) + " Wh"
                            },
                            {
                                label: "Design",
                                value: (batteryRoot.energyDesign / 1000000).toFixed(1) + " Wh"
                            },
                            {
                                label: "Health",
                                value: batteryRoot.health + "%"
                            },
                            {
                                label: "Cycles",
                                value: batteryRoot.cycles + ""
                            },
                            {
                                label: "Type",
                                value: batteryRoot.technology
                            },
                            {
                                label: "Model",
                                value: batteryRoot.model
                            }
                        ]

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: modelData.label
                                color: Config.colors.muted

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
                                color: Config.colors.foreground
                                elide: Text.ElideRight

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                }
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
