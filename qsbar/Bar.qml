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

	readonly property string internalMonitor: Config.monitors.internal

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

	// Right side widgets, bar order. Keys of Config.widgets.
	readonly property var systemWidgets: [
	    "cpu", "memory", "gpu", "battery", "docker", "claude", "keyboard",
	    "weather", "mail", "bluetooth", "volume", "wifi", "screen",
	    "display", "session"
	]

	// A separator goes before a widget when that widget and one before it are on.
	function separatorBefore(key) {
	    const before = root.systemWidgets.slice(0, root.systemWidgets.indexOf(key))

	    return Config.widgets[key].enabled
		&& before.some(other => Config.widgets[other].enabled)
	}

	anchors {
	    top: true
	    left: true
	    right: true
	}


	implicitHeight: Config.bar.height
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

		    Cpu {
			visible: Config.widgets.cpu.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("memory")
		    }

		    Memory {
			visible: Config.widgets.memory.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("gpu")
		    }

		    Gpu {
			visible: Config.widgets.gpu.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("battery")
		    }

		    Battery {
			visible: Config.widgets.battery.enabled
		    }

		    Rectangle {
		    	implicitWidth: 1
		    	implicitHeight: 16
		    	color: Config.colors.muted
		    	visible: root.separatorBefore("docker")
		    }

		    Docker {
			visible: Config.widgets.docker.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("claude")
		    }

		    ClaudeUsage {
			visible: Config.widgets.claude.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("keyboard")
		    }

		    KeyboardLayout {
			visible: Config.widgets.keyboard.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("weather")
		    }

		    Weather {
			visible: Config.widgets.weather.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("mail")
		    }

		    Mail {
			visible: Config.widgets.mail.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("bluetooth")
		    }

		    Bluetooth {
			visible: Config.widgets.bluetooth.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("volume")
		    }

		    Volume {
			visible: Config.widgets.volume.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("wifi")
		    }

		    // Wi-Fi
		    WiFi {
			visible: Config.widgets.wifi.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("screen")
		    }

		    Screen {
			visible: Config.widgets.screen.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("display")
		    }

		    DisplayOptions {
			visible: Config.widgets.display.enabled
		    }

		    Rectangle {
			implicitWidth: 1
			implicitHeight: 16
			color: Config.colors.muted
			visible: root.separatorBefore("session")
		    }

		    Session {
			visible: Config.widgets.session.enabled
			targetScreen: root.screen
		    }
		}
	    }
	}
    }
}
