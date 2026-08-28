import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: sessionRoot

    // Screen the menu opens on, passed in by the bar.
    property var targetScreen: null

    text: "󰍃"
    color: sessionMenu.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    Process {
        id: sessionProc
    }

    function run(command) {
        sessionMenu.visible = false

        sessionProc.command = command
        sessionProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            sessionMenu.visible = !sessionMenu.visible
        }
    }

    PanelWindow {
        id: sessionMenu

        screen: sessionRoot.targetScreen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        visible: false
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-session"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // Blur everything behind the overlay.
        BackgroundEffect.blurRegion: Region {
            item: dim
        }

        Rectangle {
            id: dim

            anchors.fill: parent
            color: Qt.alpha(Config.colors.background, 0.4)

            focus: true

            Keys.onEscapePressed: {
                sessionMenu.visible = false
            }

            // Click outside the panel closes.
            MouseArea {
                anchors.fill: parent

                onClicked: {
                    sessionMenu.visible = false
                }
            }

            Rectangle {
                anchors.centerIn: parent

                implicitWidth: sessionColumn.implicitWidth + 60
                implicitHeight: sessionColumn.implicitHeight + 50

                radius: 12
                color: Config.colors.background

                border {
                    width: 1
                    color: Config.colors.muted
                }

                // Swallow clicks so they do not close the menu.
                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: sessionColumn

                    anchors.centerIn: parent
                    spacing: 20

                    Text {
                        Layout.alignment: Qt.AlignHCenter

                        text: "Session"
                        color: Config.text.active

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 4
                            bold: true
                        }
                    }

                    RowLayout {
                        spacing: 16

                        Repeater {
                            model: [
                                {
                                    icon: "󰤄",
                                    label: "Suspend",
                                    accent: Config.text.normal,
                                    command: ["loginctl", "suspend"]
                                },
                                {
                                    icon: "󰍃",
                                    label: "Logout",
                                    accent: Config.text.normal,
                                    command: [
                                        "loginctl", "terminate-user",
                                        Quickshell.env("USER")
                                    ]
                                },
                                {
                                    icon: "󰜉",
                                    label: "Reboot",
                                    accent: Config.text.normal,
                                    command: ["loginctl", "reboot"]
                                },
                                {
                                    icon: "󰐥",
                                    label: "Poweroff",
                                    accent: Config.text.critical,
                                    command: ["loginctl", "poweroff"]
                                }
                            ]

                            delegate: Rectangle {
                                required property var modelData

                                implicitWidth: 120
                                implicitHeight: 110

                                radius: 8

                                color: buttonMouse.containsMouse
                                    ? Qt.alpha(modelData.accent, 0.18)
                                    : "transparent"

                                border {
                                    width: buttonMouse.containsMouse ? 2 : 1

                                    color: buttonMouse.containsMouse
                                        ? modelData.accent
                                        : Config.text.dim
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 10

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter

                                        text: modelData.icon
                                        color: modelData.accent

                                        font {
                                            family: Config.bar.fontFamily
                                            pixelSize: Config.bar.fontSize + 20
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter

                                        text: modelData.label
                                        color: Config.text.normal

                                        font {
                                            family: Config.bar.fontFamily
                                            pixelSize: Config.bar.fontSize
                                            bold: buttonMouse.containsMouse
                                        }
                                    }
                                }

                                MouseArea {
                                    id: buttonMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        sessionRoot.run(modelData.command)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter

                        text: "Esc to cancel"
                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
                    }
                }
            }
        }
    }
}
