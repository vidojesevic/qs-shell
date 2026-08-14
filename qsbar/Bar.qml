import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "widgets"
import "themes" as Theme

Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	// System data
	property int cpuUsage: 0
	property int memUsage: 0
	property var lastCpuIdle: 0
	property var lastCpuTotal: 0
	property string wifiName: "󰤭 Offline"
	property string weatherText: ""
	property string weather: "󰖐 Loading..."

	property string keyLayout: "en_US"

	// Single Monitor
	// property int wsStart: screen.name === "eDP-1" ? 1 : 9
	// property int wsCount: screen.name === "eDP-1" ? 9 : 5

	// Work Monitor
	property int wsStart: screen.name === "HDMI-A-2" ? 1 : 10
	property int wsCount: screen.name === "HDMI-A-2" ? 9 : 5

	anchors {
	    top: true
	    left: true
	    right: true
	}


	implicitHeight: 30
	color: "transparent"

	RowLayout {
	    anchors.fill: parent
	    anchors.margins: 4
	    spacing: 12

	    // LEFT BACKGROUND: workspaces
	    Rectangle {
		Layout.alignment: Qt.AlignVCenter

		implicitWidth: workspaceRow.implicitWidth + 16
		implicitHeight: 24

		radius: 3
		color: Theme.Theme.background

		RowLayout {
		    id: workspaceRow

		    anchors.centerIn: parent
		    spacing: 8

		    Repeater {
			model: root.wsCount

			Workspaces {
			    wsStart: root.wsStart
			    screen: root.screen
			}
		    }
		}
	    }

	    // TRANSPARENT MIDDLE
	    Item {
		Layout.fillWidth: true
	    }

	    // Date and Time
	    Rectangle {
		Layout.alignment: Qt.AlignVCenter

		implicitWidth: clock.implicitWidth + 16
		implicitHeight: 24

		radius: 3
		color: Theme.Theme.background

		Text {
		    id: clock

		    color: Theme.Theme.blue

		    text: " " + Qt.formatDateTime(
			new Date(),
			"ddd, MMM dd - HH:mm"
		    )

		    font {
			family: Theme.Theme.fontFamily
			pixelSize: Theme.Theme.fontSize
			bold: true
		    }

		    horizontalAlignment: Text.AlignHCenter
		    verticalAlignment: Text.AlignVCenter

		    Timer {
			interval: 1000
			running: true
			repeat: true

			onTriggered: {
			    clock.text = " " + Qt.formatDateTime(
				new Date(),
				"ddd, MMM dd - HH:mm"
			    )
			}
		    }
		}
	    }

	    Item {
		Layout.fillWidth: true
	    }

	    // RIGHT BACKGROUND: all system widgets
	    Rectangle {
		Layout.alignment: Qt.AlignVCenter

		implicitWidth: systemRow.implicitWidth + 16
		implicitHeight: 24

		radius: 3
		color: Theme.Theme.background

		RowLayout {
		    id: systemRow

		    anchors.centerIn: parent
		    spacing: 8

		    // CPU
		    Text {
			text: "󰍛 " + root.cpuUsage + "%"
			color: Theme.Theme.yellow

			font {
			    family: Theme.Theme.fontFamily
			    pixelSize: Theme.Theme.fontSize
			    bold: true
			}

			Process {
			    id: cpuProc
			    command: ["sh", "-c", "head -1 /proc/stat"]

			    stdout: SplitParser {
				onRead: data => {
				    if (!data)
				    return

				    const parts = data.trim().split(/\s+/)
				    const idle =
				    parseInt(parts[4]) + parseInt(parts[5])

				    const total = parts
				    .slice(1, 8)
				    .reduce((sum, value) =>
				    sum + parseInt(value), 0)

				    if (root.lastCpuTotal > 0) {
					root.cpuUsage = Math.round(
					    100 * (
						1 -
						(idle - root.lastCpuIdle) /
						(total - root.lastCpuTotal)
					    )
					)
				    }

				    root.lastCpuTotal = total
				    root.lastCpuIdle = idle
				}
			    }
			}

			Timer {
			    interval: 2000
			    running: true
			    repeat: true

			    onTriggered: cpuProc.running = true
			    Component.onCompleted: cpuProc.running = true
			}
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Theme.Theme.muted
		    }

		    // Memory
		    Text {
			text: " " + root.memUsage + "%"
			color: Theme.Theme.cyan

			font {
			    family: Theme.Theme.fontFamily
			    pixelSize: Theme.Theme.fontSize
			    bold: true
			}

			Process {
			    id: memProc
			    command: ["sh", "-c", "free | grep Mem"]

			    stdout: SplitParser {
				onRead: data => {
				    if (!data)
				    return

				    const parts = data.trim().split(/\s+/)
				    const total = parseInt(parts[1]) || 1
				    const used = parseInt(parts[2]) || 0

				    root.memUsage =
				    Math.round(100 * used / total)
				}
			    }
			}

			Timer {
			    interval: 2000
			    running: true
			    repeat: true

			    onTriggered: memProc.running = true
			    Component.onCompleted: memProc.running = true
			}
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Theme.Theme.muted
		    }

		    KeyboardLayout {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Theme.Theme.muted
		    }

		    // Weather
		    Text {
			id: weatherText

			text: root.weather
			color: Theme.Theme.yellow

			font {
			    family: Theme.Theme.fontFamily
			    pixelSize: Theme.Theme.fontSize
			    bold: true
			}

			Process {
			    id: weatherProc

			    command: [
				"curl",
				"-fsSL",
				"--max-time",
				"10",
				"https://wttr.in/Belgrade?format=%c+%t"
			    ]

			    stdout: StdioCollector {
				onStreamFinished: {
				    const result = text.trim()

				    root.weather = result.length > 0
				    ? result
				    : "󰖐 N/A"
				}
			    }
			}

			Timer {
			    interval: 600000
			    running: true
			    repeat: true

			    onTriggered: weatherProc.running = true
			    Component.onCompleted: weatherProc.running = true
			}

			MouseArea {
			    anchors.fill: parent
			    cursorShape: Qt.PointingHandCursor

			    onClicked: weatherProc.running = true
			}
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Theme.Theme.muted
		    }

		    Bluetooth {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Theme.Theme.muted
		    }

		    Volume {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Theme.Theme.muted
		    }

		    // Wi-Fi
		    WiFi {}
		}
	    }
	}
    }
}
