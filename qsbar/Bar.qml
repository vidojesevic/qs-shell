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
	property string weatherCondition: ""
	property string weatherTemp: "Loading..."

	property string keyLayout: "en_US"

	// Nerd Font glyph for a wttr.in condition name, so the icon takes a
	// text color. The emoji wttr returns for %c would ignore one.
	function weatherIcon(condition) {
	    const c = condition.toLowerCase()

	    if (c.includes("thunder"))
		return "󰖓"

	    if (c.includes("fog") || c.includes("mist") || c.includes("haze"))
		return "󰖑"

	    if (c.includes("snow") || c.includes("blizzard"))
		return "󰖘"

	    if (c.includes("sleet") || c.includes("ice pellets")
		|| c.includes("hail") || c.includes("freezing"))
		return "󰖒"

	    if (c.includes("torrential") || c.includes("heavy rain"))
		return "󰖖"

	    if (c.includes("rain") || c.includes("drizzle") || c.includes("shower"))
		return "󰖗"

	    if (c.includes("partly"))
		return "󰖕"

	    if (c.includes("overcast") || c.includes("cloud"))
		return "󰖐"

	    if (c.includes("sunny"))
		return "󰖙"

	    if (c.includes("clear"))
		return "󰖔"

	    if (c.includes("wind") || c.includes("blowing"))
		return "󰖝"

	    return "󰖐"
	}

	// Must match INTERNAL in ~/.config/hypr/configuration/monitors.lua.
	readonly property string internalMonitor: "eDP-1"

	// First external output, whatever it is called. Null when undocked.
	readonly property var externalMonitor:
	    Hyprland.monitors.values.find(
		monitor => monitor.name !== root.internalMonitor
	    ) ?? null

	// Laptop alone: 1-9 on the panel.
	// External docked: 1-9 on the external, 10-14 on the panel.
	readonly property int wsStart: {
	    if (!root.externalMonitor)
		return 1

	    return root.screen.name === root.externalMonitor.name ? 1 : 10
	}

	readonly property int wsCount: root.wsStart === 1 ? 9 : 5

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

			// Icon and reading colored apart.
			textFormat: Text.StyledText

			text: "<font color=\"" + Config.text.normal + "\">"
			    + root.weatherIcon(root.weatherCondition)
			    + "</font> " + root.weatherTemp

			color: Config.text.normal

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
				"https://wttr.in/Belgrade?format=%C,%t"
			    ]

			    stdout: StdioCollector {
				onStreamFinished: {
				    const parts = text.trim().split(",")

				    if (parts.length < 2) {
					root.weatherCondition = ""
					root.weatherTemp = "N/A"
					return
				    }

				    root.weatherCondition = parts[0]
				    root.weatherTemp = parts[1]
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

		    Mail {}

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

		    DisplayOptions {}

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
