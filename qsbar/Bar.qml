import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

import "widgets"
import "../config.js" as Config

Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
	id: root

	required property var modelData
	screen: modelData

	// System data
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

	// Vladin monitori
	// property int wsStart: screen.name === "DP-3" ? 1 : 10
	// property int wsCount: screen.name === "DP-3" ? 9 : 5

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

		// radius: 3
		color: Config.colors.background

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

	    Clock {
		Layout.alignment: Qt.AlignVCenter
	    }

	    Item {
		Layout.fillWidth: true
	    }

	    // RIGHT BACKGROUND: all system widgets
	    Rectangle {
		Layout.alignment: Qt.AlignVCenter

		implicitWidth: systemRow.implicitWidth + 16
		implicitHeight: 24

		// radius: 3
		color: Config.colors.background

		RowLayout {
		    id: systemRow

		    anchors.centerIn: parent
		    spacing: 8

		    Cpu {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
		    }

		    Memory {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
		    }

		    Battery {}

		    Rectangle {
		    	implicitWidth: 1
		    	implicitHeight: 16
		    	color: Config.colors.muted
		    }

		    Docker {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
		    }

		    KeyboardLayout {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
		    }

		    // Weather
		    Text {
			id: weatherText

			text: root.weather
			color: Config.colors.yellow

			font {
			    family: Config.bar.fontFamily
			    pixelSize: Config.bar.fontSize
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
			color: Config.colors.muted
		    }

		    Bluetooth {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
		    }

		    Volume {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
		    }

		    // Wi-Fi
		    WiFi {}

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
		    }

		    Session {
			targetScreen: root.screen
		    }
		}
	    }
	}
    }
}
