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
	margins { top: 48; right: 18 }

	color: "transparent"
	implicitWidth: 380
	// implicitHeight: centerCol.implicitHeight + 24
	implicitHeight: historyModel.count > 0 ? 600 : 200
	// implicitHeight: Math.min(600, centerCol.implicitHeight + 24)
	exclusionMode: ExclusionMode.Ignore


	Timer {
	    interval: 10000
	    running: true
	    onTriggered: root.centerOpen = false
	}

	Rectangle {
	    anchors.fill: parent
	    border.width: 1
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
			visible: historyModel.count > 0
			color: Config.colors.red

			MouseArea {
			    anchors.fill: parent
			    onClicked: historyModel.clear()
			}
		    }
		}

		Text {
		    Layout.fillWidth: true
		    Layout.fillHeight: true

		    visible: historyModel.count === 0

		    text: "No notifications"
		    color: Config.colors.muted

		    horizontalAlignment: Text.AlignHCenter
		    verticalAlignment: Text.AlignVCenter

		    font {
			family: Config.bar.fontFamily
			pixelSize: Config.bar.fontSize - 1
		    }
		}

		ListView {
		    id: notificationList

		    visible: historyModel.count > 0

		    Layout.fillWidth: true
		    Layout.fillHeight: true

		    clip: true
		    spacing: 8

		    model: historyModel

		    delegate: Rectangle {
			required property int index
			required property string summary
			required property string body
			required property string appName
			required property int urgency
			required property string time

			// Layout.fillWidth: true
			// Layout.preferredHeight: 60
			width: notificationList.width
			height: 60

			color: Config.colors.background
			border.width: 1
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
				    }
				    Text {
					text: "x"
					color: Config.colors.red
					font.pixelSize: Config.bar.fontSize
					font.family: Config.bar.fontFamily
					MouseArea {
					    anchors.fill: parent
					    onClicked: historyModel.remove(index)
					}
				    }
				}

				RowLayout {
				    Layout.fillWidth: true
				    spacing: 6
				    Text {
					Layout.fillWidth: true
					text: body
					visible: body !== ""
					color: Config.colors.foreground
					wrapMode: Text.NoWrap
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
				    }
				}
			    }
			}

			MouseArea {
			    anchors.fill: parent
			    onClicked: historyModel.remove(index)
			}
		    }
		}
	    }
	}
    }
}

