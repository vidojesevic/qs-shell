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
    property var focusApp

    function setOpen(open: bool): void {
	root.centerOpen = open
	if (open) autoClose.restart(); else autoClose.stop()
    }

    IpcHandler {
	target: "notifications"
	function toggle(): void { root.setOpen(!root.centerOpen) }
	function show(): void { root.setOpen(true) }
	function hide(): void { root.setOpen(false) }
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


	// The window outlives every open, so a plain running: true would fire
	// once and never again. A stopped Timer also keeps its elapsed time, so
	// a running: binding would close the panel right after the pointer
	// leaves. Drive it from the two events instead, always with restart().
	Timer {
	    id: autoClose
	    interval: 10000
	    onTriggered: root.centerOpen = false
	}

	Rectangle {
	    anchors.fill: parent
	    border.width: 1
	    color: Config.colors.background
	    border.color: Config.colors.purple

	    HoverHandler {
		onHoveredChanged:
		hovered ? autoClose.stop() : autoClose.restart()
	    }

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
			color: Config.text.active
			font.family: Config.bar.fontFamily
			font.pixelSize: Config.bar.fontSize + 2
			font.bold: true
		    }

		    Text {
			text: "Clear all"
			visible: historyModel.count > 0
			color: Config.text.critical

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
		    color: Config.text.dim

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
			required property string desktopEntry

			// Layout.fillWidth: true
			// Layout.preferredHeight: 60
			width: notificationList.width
			height: 60

			color: Config.colors.background
			border.width: 1
			border.color: urgency === NotificationUrgency.Critical
			    ? Config.colors.red
			    : Config.colors.purple

			MouseArea {
			    anchors.fill: parent
			    onClicked: {
				focusApp(appName, desktopEntry)
				root.setOpen(false)
				historyModel.remove(index)
			    }
			}

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
					color: Config.text.normal
					font.family: Config.bar.fontFamily
					font.pixelSize: Config.bar.fontSize
					font.bold: true
					elide: Text.ElideRight
				    }
				    Text {
					text: time
					color: Config.text.dim
					font.pixelSize: Config.bar.fontSize - 3
				    }
				    Text {
					text: "x"
					color: Config.text.critical
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
					color: Config.text.normal
					wrapMode: Text.NoWrap
					font.family: Config.bar.fontFamily
					font.pixelSize: Config.bar.fontSize - 2
					elide: Text.ElideRight
				    }

				    Text {
					visible: appName !== ""
					text: appName
					color: Config.text.dim
					font.family: Config.bar.fontFamily
					font.pixelSize: Config.bar.fontSize - 2
				    }
				}
			    }
			}
		    }
		}
	    }
	}
    }
}

