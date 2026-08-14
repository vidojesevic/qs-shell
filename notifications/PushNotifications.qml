import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import Quickshell.Io
import QtQuick.Layouts

import "../config.js" as Config

Scope {
    property var notificationServer
    PanelWindow {
	anchors {
	    bottom: true
	    right: true
	}

	margins {
	    bottom: 16
	    right: 16
	}

	color: "transparent"
	implicitWidth: 380
	implicitHeight: pushColumn.implicitHeight

	exclusionMode: ExclusionMode.Ignore

	ColumnLayout {
	    id: pushColumn
	    width: parent.width
	    spacing: 10

	    Repeater {
		model: server.trackedNotifications

		delegate: Rectangle {
		    id: card

		    required property var modelData

		    Layout.fillWidth: true
		    Layout.preferredHeight: 60

		    color: Config.colors.background
		    border.width: 2
		    border.color:
		    modelData.urgency === NotificationUrgency.Critical
		    ? Config.colors.red
		    : Config.colors.purple

		    Timer {
			running:
			card.modelData.urgency !== NotificationUrgency.Critical

			interval: Config.notifications.timeout

			onTriggered: {
			    card.modelData.expire()
			}
		    }

		    RowLayout {
			anchors.fill: parent
			anchors.margins: 10
			spacing: 10

			Image {
			    Layout.preferredWidth: 36
			    Layout.preferredHeight: 36
			    Layout.alignment: Qt.AlignTop

			    fillMode: Image.PreserveAspectFit

			    source:
			    card.modelData.image
			    || card.modelData.appIcon
			    || ""

			    visible: source.toString() !== ""
			}

			ColumnLayout {
			    Layout.fillWidth: true
			    spacing: 2

			    RowLayout {
				Layout.fillWidth: true
				spacing: 6
				Text {
				    Layout.fillWidth: true
				    text: card.modelData.summary
				    color: Config.colors.cyan
				    font.family: Config.bar.fontFamily
				    font.pixelSize: Config.bar.fontSize
				    font.bold: true
				    elide: Text.ElideRight
				}
				Text {
				    text: card.modelData.time
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
					onClicked: {
					    card.modelData.dismiss()
					}
				    }
				}
			    }

			    Text {
				Layout.fillWidth: true
				text: card.modelData.body
				visible: text !== ""

				color: Config.colors.foreground
				font.family: Config.bar.fontFamily
				font.pixelSize: Config.bar.fontSize - 2

				wrapMode: Text.WordWrap
			    }

			    Image {
				Layout.preferredWidth: 36
				Layout.preferredHeight: 36
				Layout.alignment: Qt.AlignTop

				fillMode: Image.PreserveAspectFit

				source:
				card.modelData.image
				|| card.modelData.image
				|| ""

				visible: source.toString() !== ""
			    }
			}
		    }

		}
	    }
	}
    }
}
