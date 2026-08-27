import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: volumeRoot

    property int volumePercent: 0
    property bool muted: false

    text: muted
    ? "󰖁 " + volumePercent + "%"
    : "󰕾 " + volumePercent + "%"

    color: Config.colors.yellow

    font {
	family: Config.bar.fontFamily
	pixelSize: Config.bar.fontSize
	bold: true
    }

    function refreshVolume() {
	if (!volumeProc.running)
	volumeProc.running = true
    }

    property int requestedVolume: 0

    function setVolume(value) {
	requestedVolume = Math.round(
	    Math.max(0, Math.min(100, value))
	)

	setVolumeTimer.restart()
    }

    Timer {
	id: setVolumeTimer

	interval: 60
	repeat: false

	onTriggered: {
	    Quickshell.execDetached([
		"pactl",
		"set-sink-volume",
		"@DEFAULT_SINK@",
		volumeRoot.requestedVolume + "%"
	    ])

	    if (volumeRoot.requestedVolume > 0) {
		Quickshell.execDetached([
		    "pactl",
		    "set-sink-mute",
		    "@DEFAULT_SINK@",
		    "0"
		])
	    }
	}
    }

    Process {
	id: volumeProc

	command: [
	    "wpctl",
	    "get-volume",
	    "@DEFAULT_AUDIO_SINK@"
	]

	stdout: StdioCollector {
	    onStreamFinished: {
		const output = text.trim()
		const match = output.match(/Volume:\s+([0-9.]+)/)

		if (!match) {
		    volumeRoot.text = "󰕾 N/A"
		    return
		}

		const percentage = Math.round(
		    parseFloat(match[1]) * 100
		)

		volumeRoot.volumePercent = percentage
		volumeRoot.muted = output.includes("[MUTED]")

		/*
		 * Do not overwrite the handle while the user
		 * is actively dragging it.
		 */
		if (!volumeSlider.pressed)
		volumeSlider.value = percentage
	    }
	}
    }

	//    /*
	//     * Debounces volume changes so dragging the slider does not
	//     * start hundreds of wpctl processes.
	//     */
	//    Timer {
	// id: setVolumeTimer
	//
	// interval: 50
	// repeat: false
	//
	// onTriggered: {
	//     volumeRoot.setVolume(volumeSlider.value)
	// }
	//    }

    Timer {
	id: refreshTimer

	interval: 2000
	running: true
	repeat: true
	triggeredOnStart: true

	onTriggered: volumeRoot.refreshVolume()
    }

    MouseArea {
	anchors.fill: parent
	cursorShape: Qt.PointingHandCursor
	acceptedButtons: Qt.LeftButton

	onClicked: {
	    volumePopup.visible = !volumePopup.visible

	    if (volumePopup.visible)
	    volumeRoot.refreshVolume()
	}
    }

    PopupWindow {
	id: volumePopup

	visible: false
	color: "transparent"

	implicitWidth: 250
	implicitHeight: 90

	anchor {
	    window: volumeRoot.QsWindow.window

	    /*
	     * Map the volume widget's position into the bar window,
	     * then position the popup directly underneath it.
	     */
	    rect.x: {
		const position = volumeRoot.mapToItem(
		    volumeRoot.QsWindow.window.contentItem,
		    0,
		    0
		)

		return position.x
		+ volumeRoot.width
		- volumePopup.implicitWidth
	    }

	    rect.y: {
		const position = volumeRoot.mapToItem(
		    volumeRoot.QsWindow.window.contentItem,
		    0,
		    0
		)

		return position.y + volumeRoot.height + 6
	    }
	}

	Rectangle {
	    anchors.fill: parent

	    radius: 6
	    color: Config.colors.background
	    border.width: 1
	    border.color: Config.colors.muted

	    RowLayout {
		anchors {
		    fill: parent
		    leftMargin: 14
		    rightMargin: 14
		    topMargin: 12
		    bottomMargin: 12
		}

		spacing: 12

		Text {
		    text: volumeRoot.muted ? "󰖁" : "󰕾"
		    color: volumeRoot.muted
		    ? Config.colors.muted
		    : Config.colors.yellow

		    font {
			family: Config.bar.fontFamily
			pixelSize: Config.bar.fontSize + 2
			bold: true
		    }

		    MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: {
			    Quickshell.execDetached([
				"wpctl",
				"set-mute",
				"@DEFAULT_AUDIO_SINK@",
				"toggle"
			    ])

			    muteRefreshTimer.restart()
			}
		    }
		}

		Slider {
		    id: volumeSlider

		    Layout.fillWidth: true

		    from: 0
		    to: 100
		    value: volumeRoot.volumePercent
		    stepSize: 1

		    onMoved: {
			const percentage = Math.round(value)

			volumeRoot.volumePercent = percentage
			volumeRoot.setVolume(percentage)
		    }
		}

		Text {
		    Layout.preferredWidth: 42

		    horizontalAlignment: Text.AlignRight

		    text: Math.round(volumeSlider.value) + "%"
		    color: Config.colors.foreground

		    font {
			family: Config.bar.fontFamily
			pixelSize: Config.bar.fontSize
			bold: true
		    }
		}
	    }
	}
    }

    Timer {
	id: muteRefreshTimer

	interval: 100
	repeat: false

	onTriggered: volumeRoot.refreshVolume()
    }
}
