import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: wifiRoot

    property bool radioEnabled: true
    property bool radioPending: false
    property string activeSsid: ""
    property string connectingSsid: ""
    property string selectedSsid: ""
    property var savedProfiles: []


    text: {
        if (!radioEnabled)
            return "󰤭 Off"

        return activeSsid.length > 0
            ? "󰤨 " + activeSsid
            : "󰤭 Offline"
    }

    color: wifiPopup.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    // nmcli -t escapes field separators as "\:".
    function splitFields(line) {
        const fields = []
        let current = ""

        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) {
                current += line[i + 1]
                i++
            } else if (line[i] === ":") {
                fields.push(current)
                current = ""
            } else {
                current += line[i]
            }
        }

        fields.push(current)
        return fields
    }

    function signalIcon(strength) {
        if (strength >= 80)
            return "󰤨"

        if (strength >= 60)
            return "󰤥"

        if (strength >= 40)
            return "󰤢"

        if (strength >= 20)
            return "󰤟"

        return "󰤯"
    }

    function isSaved(ssid) {
        return savedProfiles.indexOf(ssid) !== -1
    }

    function connectTo(ssid, password) {
        wifiRoot.connectingSsid = ssid

        connectProc.command = password.length > 0
            ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
            : ["nmcli", "device", "wifi", "connect", ssid]

        connectProc.running = true
    }

    function disconnectFrom(ssid) {
        wifiRoot.connectingSsid = ssid

        disconnectProc.command = ["nmcli", "connection", "down", "id", ssid]
        disconnectProc.running = true
    }

    function toggleNetwork(network) {
        if (network.inUse) {
            disconnectFrom(network.ssid)
            return
        }

        if (network.secured && !isSaved(network.ssid)) {
            wifiRoot.selectedSsid = network.ssid

            popupCloseTimer.stop()
            wifiPopup.visible = false

            Qt.callLater(function() {
                passwordInput.clear()
                passwordForWiFi.visible = true
            })

            return
        }

        connectTo(network.ssid, "")
    }

    ListModel {
        id: networks
    }

    // Wi-Fi radio state.
    Process {
        id: radioStateProc

        command: ["nmcli", "-t", "-f", "WIFI", "radio"]

        stdout: StdioCollector {
            onStreamFinished: {
                wifiRoot.radioEnabled = text.trim() === "enabled"
                wifiRoot.radioPending = false
            }
        }
    }

    // Currently connected network.
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
                wifiRoot.activeSsid = text.trim()
            }
        }
    }

    // Saved connection profiles, to know when a password is needed.
    Process {
        id: profilesProc

        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const names = []
                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0)
                        continue

                    const fields = wifiRoot.splitFields(lines[i])

                    if (fields[1] === "802-11-wireless")
                        names.push(fields[0])
                }

                wifiRoot.savedProfiles = names
            }
        }
    }

    // Scan available networks.
    Process {
        id: wifiScanProc

        command: [
            "nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID",
            "device", "wifi", "list", "--rescan", "yes"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                networks.clear()

                const lines = text.trim().split("\n")
                const seen = {}

                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0)
                        continue

                    const fields = wifiRoot.splitFields(lines[i])
                    const ssid = fields[3] ? fields[3].trim() : ""

                    if (ssid.length === 0 || seen[ssid])
                        continue

                    seen[ssid] = true

                    const security = fields[2] ? fields[2].trim() : ""

                    networks.append({
                        ssid: ssid,
                        strength: parseInt(fields[1]) || 0,
                        secured: security.length > 0 && security !== "--",
                        inUse: fields[0].trim() === "*"
                    })
                }
            }
        }
    }

    Process {
        id: connectProc

        onExited: {
            wifiRoot.connectingSsid = ""

            wifiStatusProc.running = true
            profilesProc.running = true
            wifiScanProc.running = true
        }
    }

    Process {
        id: disconnectProc

        onExited: {
            wifiRoot.connectingSsid = ""

            wifiStatusProc.running = true
            wifiScanProc.running = true
        }
    }

    Process {
        id: radioToggleProc

        onExited: {
            radioStateProc.running = true

            if (wifiPopup.visible)
                wifiScanProc.running = true
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true

        onTriggered: {
            radioStateProc.running = true
            wifiStatusProc.running = true
        }

        Component.onCompleted: {
            radioStateProc.running = true
            wifiStatusProc.running = true
            profilesProc.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            radioStateProc.running = true
            wifiStatusProc.running = true

            if (!wifiPopup.visible && wifiRoot.radioEnabled) {
                profilesProc.running = true
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
            color: Config.colors.background

            border {
                width: 1
                color: Config.colors.muted
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                Text {
                    Layout.fillWidth: true

                    text: "Connect to " + wifiRoot.selectedSsid
                    color: Config.text.active
                    elide: Text.ElideRight

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize + 1
                        bold: true
                    }
                }

                // Password field background
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36

                    radius: 5
                    color: Config.colors.backgroundAlt

                    border {
                        width: passwordInput.activeFocus ? 2 : 1

                        color: passwordInput.activeFocus
                            ? Config.colors.cyan
                            : Config.colors.muted
                    }

                    TextInput {
                        id: passwordInput

                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10

                        verticalAlignment: TextInput.AlignVCenter

                        color: Config.text.normal
                        selectionColor: Config.text.active

                        echoMode: TextInput.Password
                        passwordCharacter: "●"

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                        }

                        onAccepted: {
                            if (text.length > 0)
                                submitPassword()
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
                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
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
                            ? Config.colors.muted
                            : "transparent"

                        border {
                            width: 1
                            color: Config.colors.muted
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize
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
                            ? Config.colors.blue
                            : Config.colors.muted

                        opacity: passwordInput.text.length > 0
                            ? 1
                            : 0.5

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            color: Config.colors.background

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize
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
                                submitPassword()
                            }
                        }
                    }
                }
            }
        }
    }

    function submitPassword() {
        connectTo(wifiRoot.selectedSsid, passwordInput.text)

        passwordInput.clear()
        passwordForWiFi.visible = false
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

        onVisibleChanged: {
            if (visible)
                popupCloseTimer.restart()
            else
                popupCloseTimer.stop()
        }

        Rectangle {
            anchors.fill: parent

            radius: 8
            color: Config.colors.background

            border {
                width: 1
                color: Config.colors.muted
            }

            // Keep popup open while pointer is over it.
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        popupCloseTimer.stop()
                    else
                        popupCloseTimer.restart()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Wi-Fi"
                        color: Config.text.active

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                            bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Wi-Fi radio on/off switch
                    Rectangle {
                        id: radioSwitch

                        implicitWidth: 44
                        implicitHeight: 22

                        radius: 11

                        color: wifiRoot.radioEnabled
                            ? Config.colors.cyan
                            : Config.colors.muted

                        opacity: wifiRoot.radioPending ? 0.5 : 1

                        Behavior on color {
                            ColorAnimation {
                                duration: 150
                            }
                        }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9

                            anchors.verticalCenter: parent.verticalCenter

                            x: wifiRoot.radioEnabled
                                ? parent.width - width - 2
                                : 2

                            color: Config.colors.background

                            Behavior on x {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent

                            enabled: !wifiRoot.radioPending
                            cursorShape: enabled
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor

                            onClicked: {
                                popupCloseTimer.stop()

                                wifiRoot.radioPending = true

                                radioToggleProc.command = [
                                    "nmcli", "radio", "wifi",
                                    wifiRoot.radioEnabled ? "off" : "on"
                                ]

                                radioToggleProc.running = true
                            }
                        }
                    }
                }

                Text {
                    text: {
                        if (!wifiRoot.radioEnabled)
                            return "󰤭 Wi-Fi off"

                        return wifiRoot.activeSsid.length > 0
                            ? "󰤨 " + wifiRoot.activeSsid
                            : "󰤭 Not connected"
                    }

                    color: Config.text.normal

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize
                        bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent

                        visible: networkList.count === 0

                        text: !wifiRoot.radioEnabled
                            ? "Wi-Fi is off"
                            : (wifiScanProc.running
                                ? "Scanning..."
                                : "No Wi-Fi networks found")

                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 1
                        }
                    }

                    ListView {
                        id: networkList

                        anchors.fill: parent

                        clip: true
                        spacing: 4

                        model: wifiRoot.radioEnabled ? networks : null

                        delegate: Rectangle {
                            required property string ssid
                            required property int strength
                            required property bool secured
                            required property bool inUse

                            readonly property bool busy:
                                wifiRoot.connectingSsid === ssid

                            width: ListView.view.width
                            implicitHeight: 40

                            radius: 5

                            color: inUse
                                ? Qt.alpha(Config.colors.cyan, 0.18)
                                : (networkMouse.containsMouse
                                    ? Config.colors.muted
                                    : "transparent")

                            border {
                                width: inUse ? 1 : 0
                                color: Config.colors.cyan
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: wifiRoot.signalIcon(strength)

                                    color: inUse
                                        ? Config.text.active
                                        : Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text: ssid
                                    elide: Text.ElideRight

                                    color: inUse
                                        ? Config.text.active
                                        : Config.text.normal

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 1
                                        bold: inUse
                                    }
                                }

                                Text {
                                    visible: secured

                                    text: "󰌾"
                                    color: Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 3
                                    }
                                }

                                Text {
                                    text: strength + "%"
                                    color: Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 3
                                    }
                                }

                                // Spinner while connecting or disconnecting.
                                Text {
                                    visible: busy

                                    text: "󰔟"
                                    color: Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 1
                                    }

                                    RotationAnimation on rotation {
                                        running: busy
                                        loops: Animation.Infinite

                                        from: 0
                                        to: 360
                                        duration: 900
                                    }
                                }

                                Text {
                                    visible: inUse && !busy

                                    text: "Connected"
                                    color: Config.text.active

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 3
                                        bold: true
                                    }
                                }
                            }

                            MouseArea {
                                id: networkMouse

                                anchors.fill: parent
                                hoverEnabled: true

                                enabled: wifiRoot.connectingSsid.length === 0
                                cursorShape: enabled
                                    ? Qt.PointingHandCursor
                                    : Qt.ArrowCursor

                                onClicked: {
                                    popupCloseTimer.stop()

                                    wifiRoot.toggleNetwork({
                                        ssid: ssid,
                                        secured: secured,
                                        inUse: inUse
                                    })
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30

                    radius: 5

                    color: refreshMouse.containsMouse
                        ? Config.colors.muted
                        : "transparent"

                    border {
                        width: 1
                        color: Config.colors.muted
                    }

                    Text {
                        anchors.centerIn: parent

                        text: "󰑓 Refresh networks"
                        color: Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }
                    }

                    MouseArea {
                        id: refreshMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (!wifiRoot.radioEnabled)
                                return

                            wifiScanProc.running = true
                        }
                    }
                }
            }
        }
    }
}
