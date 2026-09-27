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

	property string keyLayout: "en_US"

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

		    Gpu {}

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

		    ClaudeUsage {}

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

		    Weather {}

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

		    Screen {}

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
