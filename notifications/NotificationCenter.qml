import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import Quickshell.Io
import QtQuick.Layouts

import "../config.js" as Config

Scope {
    id: root

    property var historyModel
    property bool centerOpen

    IpcHandler {
	target: "notifications"
	function toggle(): void { root.centerOpen = !root.centerOpen }
	function show(): void { root.centerOpen = true }
	function hide(): void { root.centerOpen = false }
    }

    // notification_center
    PanelWindow {
	visible: root.centerOpen
	anchors { top: true; right: true }
	margins { top: 32; right: 12 }

	color: "transparent"
	implicitWidth: 380
	implicitHeight: centerCol.implicitHeight + 24
	exclusionMode: ExclusionMode.Ignore

	Rectangle {
	    anchors.fill: parent
	    radius: 10
	    border.width: 2
	    color: Config.colors.background
	    border.color: Config.colors.purple

	    ColumnLayout {
		id: centerCol
		anchors.fill: parent
		anchors.margins: 12
		spacing: 10

		RowLayout {
		    Layout.fillWidth: true

		    Text {
			Layout.fillWidth: true
			text: "Notifications"
			color: Config.colors.cyan
			font.family: Config.bar.fontFamily
			font.pixelSize: Config.bar.fontSize + 2
			font.bold: true
		    }

		    Text {
			text: "Clear all"
			visible: history.count > 0
			color: Config.colors.red

			MouseArea {
			    anchors.fill: parent
			    onClicked: history.clear()
			}
		    }
		}

		Repeater {
		    model: history

		    delegate: Rectangle {
			required property int index
			required property string summary
			required property string body
			required property string appName
			required property int urgency
			required property string time

			Layout.fillWidth: true
			Layout.preferredHeight: 60

			radius: 8
			color: Config.colors.background
			border.width: 2
			border.color: urgency === NotificationUrgency.Critical
			? Config.colors.red
			: Config.colors.purple

			RowLayout { 
			    anchors.fill: parent
			    anchors.margins: 10

			    ColumnLayout {
				Layout.fillWidth: true

				RowLayout {
				    Layout.fillWidth: true
				    spacing: 6
				    Text {
					Layout.fillWidth: true
					text: summary
					color: Config.colors.cyan
					font.family: Config.bar.fontFamily
					font.pixelSize: Config.bar.fontSize
					font.bold: true
					elide: Text.ElideRight
				    }
				    Text {
					text: time
					color: Config.colors.foreground
					font.pixelSize: Config.bar.fontSize - 3
					font.family: Config.bar.fontFamily
				    }
				    Text {
					text: "x"
					color: Config.colors.red
					font.pixelSize: Config.bar.fontSize
					font.family: Config.bar.fontFamily
					MouseArea {
					    anchors.fill: parent
					    onClicked: history.remove(index)
					}
				    }
				}

				Text {
				    Layout.fillWidth: true
				    text: body
				    visible: body !== ""
				    color: Config.colors.foreground
				    wrapMode: Text.WordWrap
				    font.family: Config.bar.fontFamily
				    font.pixelSize: Config.bar.fontSize - 2
				    elide: Text.ElideRight
				}

				Text {
				    visible: appName !== ""
				    text: appName
				    color: Config.colors.foreground
				    font.family: Config.bar.fontFamily
				    font.pixelSize: Config.bar.fontSize - 2
				    // text: time
				    // color: Config.colors.foreground
				}
			    }
			}

			MouseArea {
			    anchors.fill: parent
			    onClicked: history.remove(index)
			}
		    }
		}
	    }
	}
    }
}

