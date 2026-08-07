import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../themes" as Theme

Text {
    id: wifiRoot

    property string wifiName: "󰤭 Offline"
    property string wifiList: "Scanning..."

    text: wifiName
    color: Theme.Theme.cyan

    font {
	family: Theme.Theme.fontFamily
	pixelSize: Theme.Theme.fontSize
	bold: true
    }

    function dummyConnect() {
	console.log(
	    "Dummy Wi-Fi connection:",
	    wifiRoot.selectedSsid,
	    passwordInput.text
	)

	passwordInput.clear()
	passwordForWiFi.visible = false
    }

    // Get currently connected Wi-Fi.
    Process {
	id: wifiStatusProc

	command: [
	    "sh",
	    "-c",
	    "nmcli -t -f active,ssid dev wifi "
	    + "| grep '^yes' "
	    + "| cut -d: -f2- "
	    + "| head -n 1"
	]

	stdout: StdioCollector {
	    onStreamFinished: {
		const result = text.trim()

		wifiRoot.wifiName = result.length > 0
		? "󰤨 " + result
		: "󰤭 Offline"
	    }
	}
    }

    // Scan available networks.
    Process {
	id: wifiScanProc

	command: [
	    "sh",
	    "-c",
	    "nmcli -f IN-USE,SIGNAL,SECURITY,SSID "
	    + "device wifi list --rescan yes"
	]

	stdout: StdioCollector {
	    onStreamFinished: {
		const result = text.trim()

		wifiRoot.wifiList = result.length > 0
		? result
		: "No Wi-Fi networks found"
	    }
	}
    }

    Timer {
	interval: 5000
	running: true
	repeat: true

	onTriggered: wifiStatusProc.running = true

	Component.onCompleted: {
	    wifiStatusProc.running = true
	}
    }

    MouseArea {
	anchors.fill: parent
	cursorShape: Qt.PointingHandCursor

	onClicked: {
	    wifiStatusProc.running = true

	    if (!wifiPopup.visible) {
		wifiRoot.wifiList = "Scanning..."
		wifiScanProc.running = true
	    }

	    wifiPopup.visible = !wifiPopup.visible
	}
    }

    // Close if inactive
    Timer {
	id: popupCloseTimer

	interval: 5000
	repeat: false

	onTriggered: {
	    wifiPopup.visible = false
	}
    }

    PopupWindow {
	id: passwordForWiFi

	anchor {
	    item: wifiRoot

	    edges: Edges.Bottom | Edges.Right
	    gravity: Edges.Bottom | Edges.Left

	    margins.top: 32
	    margins.right: 16
	}

	implicitWidth: 320
	implicitHeight: 170

	visible: false
	color: "transparent"
	grabFocus: true

	onVisibleChanged: {
	    if (visible) {
		Qt.callLater(function() {
		    passwordInput.forceActiveFocus()
		})
	    }
	}

	Rectangle {
	    anchors.fill: parent

	    radius: 8
	    color: Theme.Theme.background

	    border {
		width: 1
		color: Theme.Theme.muted
	    }

	    ColumnLayout {
		anchors.fill: parent
		anchors.margins: 14
		spacing: 10

		Text {
		    Layout.fillWidth: true

		    text: "Connect to " + wifiRoot.selectedSsid
		    color: Theme.Theme.cyan
		    elide: Text.ElideRight

		    font {
			family: Theme.Theme.fontFamily
			pixelSize: Theme.Theme.fontSize + 1
			bold: true
		    }
		}

		// Password field background
		Rectangle {
		    Layout.fillWidth: true
		    implicitHeight: 36

		    radius: 5
		    color: "#11131a"

		    border {
			width: passwordInput.activeFocus ? 2 : 1

			color: passwordInput.activeFocus
			? Theme.Theme.cyan
			: Theme.Theme.muted
		    }

		    TextInput {
			id: passwordInput

			anchors.fill: parent
			anchors.leftMargin: 10
			anchors.rightMargin: 10

			verticalAlignment: TextInput.AlignVCenter

			color: Theme.Theme.foreground
			selectionColor: Theme.Theme.blue

			echoMode: TextInput.Password
			passwordCharacter: "●"

			font {
			    family: Theme.Theme.fontFamily
			    pixelSize: Theme.Theme.fontSize
			}

			onAccepted: {
			    dummyConnect()
			}

			Keys.onEscapePressed: {
			    passwordForWiFi.visible = false
			    clear()
			}
		    }

		    Text {
			anchors {
			    left: parent.left
			    leftMargin: 10
			    verticalCenter: parent.verticalCenter
			}

			visible: passwordInput.text.length === 0
			text: "Enter password"
			color: Theme.Theme.muted

			font {
			    family: Theme.Theme.fontFamily
			    pixelSize: Theme.Theme.fontSize
			}
		    }
		}

		Item {
		    Layout.fillHeight: true
		}

		RowLayout {
		    Layout.fillWidth: true
		    spacing: 8

		    Item {
			Layout.fillWidth: true
		    }

		    Rectangle {
			implicitWidth: 80
			implicitHeight: 30

			radius: 5
			color: cancelMouse.containsMouse
			? Theme.Theme.muted
			: "transparent"

			border {
			    width: 1
			    color: Theme.Theme.muted
			}

			Text {
			    anchors.centerIn: parent
			    text: "Cancel"
			    color: Theme.Theme.foreground

			    font {
				family: Theme.Theme.fontFamily
				pixelSize: Theme.Theme.fontSize
			    }
			}

			MouseArea {
			    id: cancelMouse

			    anchors.fill: parent
			    hoverEnabled: true
			    cursorShape: Qt.PointingHandCursor

			    onClicked: {
				passwordInput.clear()
				passwordForWiFi.visible = false
			    }
			}
		    }

		    Rectangle {
			implicitWidth: 90
			implicitHeight: 30

			radius: 5

			color: passwordInput.text.length > 0
			? Theme.Theme.blue
			: Theme.Theme.muted

			opacity: passwordInput.text.length > 0
			? 1
			: 0.5

			Text {
			    anchors.centerIn: parent
			    text: "Connect"
			    color: "#ffffff"

			    font {
				family: Theme.Theme.fontFamily
				pixelSize: Theme.Theme.fontSize
				bold: true
			    }
			}

			MouseArea {
			    anchors.fill: parent

			    enabled: passwordInput.text.length > 0
			    cursorShape: enabled
			    ? Qt.PointingHandCursor
			    : Qt.ArrowCursor

			    onClicked: {
				dummyConnect()
			    }
			}
		    }
		}
	    }
	}
    }

    PopupWindow {
	id: wifiPopup

	anchor {
	    item: wifiRoot
	    edges: Edges.Bottom | Edges.Right
	    gravity: Edges.Bottom | Edges.Left
	    margins.top: 32
	    margins.right: 16
	}

	implicitWidth: 460
	implicitHeight: 280

	visible: false
	color: "transparent"
	grabFocus: true

	Rectangle {
	    anchors.fill: parent

	    radius: 8
	    color: Theme.Theme.background

	    border {
		width: 1
		color: Theme.Theme.muted
	    }

	    ColumnLayout {
		anchors.fill: parent
		anchors.margins: 14
		spacing: 10

		Text {
		    text: "Wi-Fi"
		    color: Theme.Theme.cyan

		    font {
			family: Theme.Theme.fontFamily
			pixelSize: Theme.Theme.fontSize + 2
			bold: true
		    }
		}

		Text {
		    text: wifiRoot.wifiName
		    color: Theme.Theme.blue

		    font {
			family: Theme.Theme.fontFamily
			pixelSize: Theme.Theme.fontSize
			bold: true
		    }
		}

		Rectangle {
		    Layout.fillWidth: true
		    implicitHeight: 1
		    color: Theme.Theme.muted
		}

		Flickable {
		    Layout.fillWidth: true
		    Layout.fillHeight: true

		    clip: true

		    contentWidth: width
		    contentHeight: wifiListText.implicitHeight

		    Text {
			id: wifiListText

			width: parent.width
			text: wifiRoot.wifiList

			color: Theme.Theme.foreground
			wrapMode: Text.WrapAnywhere

			font {
			    family: Theme.Theme.fontFamily
			    pixelSize: Theme.Theme.fontSize - 1
			}

			MouseArea {
			    id: wifiConnectMouse

			    anchors.fill: parent
			    cursorShape: Qt.PointingHandCursor

			    onClicked: {
				wifiRoot.selectedSsid = "Example Wi-Fi"

				popupCloseTimer.stop()
				wifiPopup.visible = false

				Qt.callLater(function() {
				    passwordInput.clear()
				    passwordForWiFi.visible = true
				})
			    }
			}}

                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30

                    radius: 5

                    color: refreshMouse.containsMouse
                        ? Theme.Theme.muted
                        : "transparent"

                    border {
                        width: 1
                        color: Theme.Theme.muted
                    }

                    Text {
                        anchors.centerIn: parent

                        text: "󰑓 Refresh networks"
                        color: Theme.Theme.cyan

                        font {
                            family: Theme.Theme.fontFamily
                            pixelSize: Theme.Theme.fontSize
                            bold: true
                        }
                    }

                    MouseArea {
                        id: refreshMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            wifiRoot.wifiList = "Scanning..."
                            wifiScanProc.running = true
                        }
                    }
                }
            }
        }
    }
}
