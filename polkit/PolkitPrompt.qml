import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import QtQuick

import "../config.js" as Config
import "../settings"

// Polkit agent: the password prompt for pkexec and other privileged
// actions. Stays idle when another agent already holds the session
// (agent.isRegistered is false then).
Scope {
    id: root

    // FooterButton and FocusRing read colors and text from a form.
    readonly property var colors: Config.colors
    readonly property var text: Config.text

    readonly property bool registered: agent.isRegistered

    // Null between requests.
    readonly property var flow: agent.flow
    readonly property bool ready: root.flow?.isResponseRequired ?? false

    PolkitAgent {
        id: agent

        onIsActiveChanged: {
            if (!agent.isActive) {
                prompt.visible = false
                return
            }

            const focused = Hyprland.focusedMonitor?.name
            prompt.screen = Quickshell.screens.find(s => s.name === focused) ?? Quickshell.screens[0]
            password.text = ""
            prompt.visible = true
        }
    }

    // A wrong password starts a new session by itself; the error shows in
    // supplementaryMessage.
    Connections {
        target: root.flow

        function onAuthenticationFailed() {
            password.text = ""
        }
    }

    function submit() {
        if (!root.ready || password.text === "")
            return

        root.flow.submit(password.text)
        password.text = ""
    }

    function cancel() {
        root.flow?.cancelAuthenticationRequest()
    }

    PanelWindow {
        id: prompt

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
        WlrLayershell.namespace: "quickshell-polkit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible)
                password.forceActiveFocus()
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(root.colors.background, 0.7)

            // Clicks outside the box do nothing; Cancel is explicit.
            MouseArea {
                anchors.fill: parent
            }

            Rectangle {
                anchors.centerIn: parent

                width: 440
                height: column.implicitHeight + 48

                radius: 8
                color: root.colors.background
                border.color: root.colors.border
                border.width: 1

                Column {
                    id: column

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    spacing: 12

                    Text {
                        text: "Authentication required"
                        color: root.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap

                        text: root.flow?.message ?? ""
                        color: root.colors.foregroundAlt

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideMiddle

                        text: root.flow?.actionId ?? ""
                        color: root.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }
                    }

                    Text {
                        topPadding: 4

                        text: (root.flow?.inputPrompt ?? "Password").replace(/:\s*$/, "")
                            + " · " + (root.flow?.selectedIdentity?.displayName ?? "")
                        color: root.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 28

                        radius: 6
                        color: root.colors.backgroundAlt
                        border.width: 1
                        border.color: root.colors.border
                        opacity: root.ready ? 1 : 0.55

                        TextInput {
                            id: password

                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                            enabled: root.ready
                            clip: true

                            color: root.colors.foreground
                            selectionColor: root.colors.accent
                            selectedTextColor: root.colors.background

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 2
                            }

                            onAccepted: root.submit()
                            Keys.onEscapePressed: root.cancel()
                        }

                        FocusRing {
                            form: root
                            visible: password.activeFocus
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap

                        visible: text !== ""
                        text: root.flow?.supplementaryMessage ?? ""
                        color: root.flow?.supplementaryIsError ? root.colors.red : root.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 8

                        FooterButton {
                            form: root
                            label: "Cancel"
                            hint: "Esc"
                            onClicked: root.cancel()
                        }

                        FooterButton {
                            form: root
                            label: "Authenticate"
                            hint: "↵"
                            primary: true
                            enabled: root.ready && password.text !== ""
                            onClicked: root.submit()
                        }
                    }
                }
            }
        }
    }
}
