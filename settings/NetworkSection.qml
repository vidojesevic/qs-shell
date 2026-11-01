import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// Live section: every action runs nmcli at once. Enter connects or
// disconnects the focused row, Delete forgets its saved profile, Ctrl+R
// rescans (the modal calls rescan()).
ColumnLayout {
    id: section

    required property var form

    // Read by the modal: switch in the pane header, hint in the footer.
    readonly property Component header: radioSwitch
    readonly property string hint: "↵ connect · Del forget · ^R rescan"

    property bool radio: true
    property string device: ""
    property string profile: ""
    property string address: ""
    property var current: null
    property var networks: []
    property var wired: []
    property var saved: []

    // SSID of the row whose action runs now.
    property string busy: ""

    // SSID that waits for a password under its row.
    property string asking: ""

    // SSID of the focused row, to give focus back after the list changes.
    property string focusedSsid: ""

    spacing: 0

    function rescan() {
        section.refresh("yes")
    }

    function refresh(rescan) {
        radioProc.running = true
        deviceProc.running = true
        listProc.rescan = rescan
        savedProc.running = true
    }

    function run(ssid, command) {
        section.busy = ssid
        actionProc.command = command
        actionProc.running = true
    }

    function activate(network) {
        if (network.secured && !network.saved) {
            section.asking = network.ssid
            return
        }

        section.run(network.ssid, ["nmcli", "device", "wifi", "connect", network.ssid])
    }

    function forget(name) {
        section.run(name, ["nmcli", "connection", "delete", "id", name])
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

    function lines(text) {
        return text.trim().split("\n").filter(line => line.length > 0).map(section.splitFields)
    }

    function bars(signal) {
        const count = Math.max(1, Math.ceil(signal / 25))
        return "▂▄▆█".slice(0, count) + "_".repeat(4 - count)
    }

    function band(frequency) {
        const mhz = parseInt(frequency)
        return mhz >= 5925 ? "6 GHz" : mhz >= 5000 ? "5 GHz" : "2.4 GHz"
    }

    function security(network) {
        const parts = [section.bars(network.signal), network.security]
        if (network.saved)
            parts.push("saved")
        return parts.join(" · ")
    }

    Component.onCompleted: section.refresh("auto")

    // Keeps the rows current while the modal is open.
    Timer {
        interval: 5000
        repeat: true
        running: section.form.visible
        onTriggered: section.refresh("no")
    }

    Process {
        id: radioProc

        command: ["nmcli", "-t", "-f", "WIFI", "radio"]

        stdout: StdioCollector {
            onStreamFinished: section.radio = text.trim() === "enabled"
        }
    }

    Process {
        id: deviceProc

        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"]

        stdout: StdioCollector {
            onStreamFinished: {
                let device = ""
                let profile = ""
                const wired = []

                for (const fields of section.lines(text)) {
                    if (fields[1] === "wifi" && device === "") {
                        device = fields[0]
                        profile = fields[2] === "connected" ? fields[3] : ""
                    } else if (fields[1] === "ethernet" && fields[2] !== "unmanaged") {
                        wired.push({
                            name: fields[0],
                            state: fields[2] === "unavailable" ? "cable unplugged" : fields[2]
                        })
                    }
                }

                section.device = device
                section.profile = profile
                section.wired = wired

                if (profile !== "") {
                    addressProc.command = ["nmcli", "-g", "IP4.ADDRESS", "device", "show", device]
                    addressProc.running = true
                }
            }
        }
    }

    Process {
        id: addressProc

        stdout: StdioCollector {
            onStreamFinished: section.address = text.trim().split(" | ")[0].split("/")[0]
        }
    }

    Process {
        id: savedProc

        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                section.saved = section.lines(text)
                    .filter(fields => fields[1] === "802-11-wireless")
                    .map(fields => fields[0])
                listProc.running = true
            }
        }
    }

    Process {
        id: listProc

        // "auto" on open, "yes" for Ctrl+R, "no" for the timer.
        property string rescan: "auto"

        command: [
            "nmcli", "-t", "-f", "IN-USE,SIGNAL,FREQ,SECURITY,SSID",
            "device", "wifi", "list", "--rescan", listProc.rescan
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let current = null
                const networks = []
                const seen = {}

                for (const fields of section.lines(text)) {
                    const ssid = fields[4]
                    const security = fields[3].trim().split(" ").pop()
                    const network = {
                        ssid: ssid,
                        signal: parseInt(fields[1]) || 0,
                        band: section.band(fields[2]),
                        security: security === "" || security === "--" ? "open" : security,
                        secured: security !== "" && security !== "--",
                        saved: section.saved.indexOf(ssid) !== -1
                    }

                    if (fields[0] === "*")
                        current = network
                    else if (ssid !== "" && !seen[ssid])
                        networks.push(network)

                    seen[ssid] = true
                }

                // Saved networks first, each group by signal (nmcli order).
                const sorted = networks.filter(network => network.saved && network.ssid !== current?.ssid)
                    .concat(networks.filter(network => !network.saved && network.ssid !== current?.ssid))

                section.current = current

                // The timer refreshes signal every 5 s. Rebuild the rows,
                // which drops their focus, only when the list itself changes.
                const key = network => network.ssid + network.security + network.saved
                if (sorted.map(key).join() !== section.networks.map(key).join())
                    section.networks = sorted
            }
        }
    }

    Process {
        id: actionProc

        stderr: StdioCollector {
            id: actionError
        }

        onExited: code => {
            section.busy = ""
            if (code !== 0)
                section.form.showStatus("nmcli: " + actionError.text.trim().replace(/^Error: /, ""), section.form.colors.red)
            section.refresh("no")
        }
    }

    // The row list was rebuilt and took the focused row with it. Give focus
    // to the same network, else the current row, else the page, so the
    // modal keys still work.
    onNetworksChanged: Qt.callLater(() => {
        const focused = section.Window.activeFocusItem
        if (focused && focused !== section.Window.contentItem)
            return

        for (let i = 0; i < rows.count; i++) {
            const item = rows.itemAt(i)
            if (item.ssid === section.focusedSsid) {
                item.focusRow()
                return
            }
        }

        if (currentRow.activeFocusOnTab)
            currentRow.forceActiveFocus()
        else
            section.forceActiveFocus()
    })

    Component {
        id: radioSwitch

        Row {
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: "Wi-Fi"
                color: section.form.text.dim

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Rectangle {
                id: track

                function toggle() {
                    section.run("", ["nmcli", "radio", "wifi", section.radio ? "off" : "on"])
                }

                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 18

                radius: 9
                color: section.radio ? section.form.colors.accent : "transparent"
                border.width: 1
                border.color: section.radio ? section.form.colors.accent : section.form.colors.border

                activeFocusOnTab: true
                Keys.onSpacePressed: track.toggle()

                Rectangle {
                    x: section.radio ? 17 : 3
                    y: 3
                    width: 12
                    height: 12

                    radius: 6
                    color: section.radio ? section.form.colors.background : section.form.colors.muted

                    Behavior on x {
                        NumberAnimation { duration: 100 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        track.forceActiveFocus()
                        track.toggle()
                    }
                }

                FocusRing {
                    form: section.form
                    visible: track.activeFocus
                }
            }
        }
    }

    // One network row: name, state, details, action button. Focusable when
    // it has an action.
    component NetworkRow: Rectangle {
        id: row

        required property var form
        property string name
        property string status
        property string details
        property string action
        property bool primary: false
        property bool working: false

        signal act()
        signal forget()

        Layout.fillWidth: true
        implicitHeight: 28 + 2 * row.form.rowPadding

        radius: 6
        color: "transparent"

        activeFocusOnTab: row.action !== ""
        Keys.onReturnPressed: row.act()
        Keys.onEnterPressed: row.act()
        Keys.onDeletePressed: row.forget()

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                text: row.name
                color: row.form.text.normal

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Text {
                visible: row.status !== ""
                text: row.status
                color: row.form.colors.green

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Text {
                text: row.details
                color: row.form.text.dim

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: row.action !== ""
            width: label.implicitWidth + 16
            height: 24

            radius: 6
            color: "transparent"
            border.width: 1
            border.color: row.primary ? row.form.colors.accent : row.form.colors.border

            Text {
                id: label

                anchors.centerIn: parent

                text: row.working ? "…" : row.action
                color: row.primary ? row.form.colors.accent : row.form.colors.foregroundAlt

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    row.forceActiveFocus()
                    row.act()
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: row.form.colors.border
        }

        FocusRing {
            form: row.form
            visible: row.activeFocus
        }
    }

    component GroupLabel: Text {
        required property var form

        Layout.topMargin: 8
        Layout.preferredHeight: 32
        verticalAlignment: Text.AlignVCenter

        color: form.text.dim

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize - 2
        }
    }

    // Current connection.
    NetworkRow {
        id: currentRow

        form: section.form
        name: !section.radio ? "Wi-Fi is off"
            : section.current ? section.current.ssid
            : "Not connected"
        status: section.radio && section.current ? "connected" : ""
        details: section.radio && section.current
            ? [section.bars(section.current.signal), section.current.band, section.address].filter(part => part !== "").join(" · ")
            : ""
        action: section.radio && section.current ? "Disconnect" : ""
        working: section.busy !== "" && section.busy === section.current?.ssid

        onAct: section.run(section.current.ssid, ["nmcli", "device", "disconnect", section.device])
        onForget: {
            if (section.profile !== "")
                section.forget(section.profile)
        }
    }

    GroupLabel {
        form: section.form
        visible: section.radio
        text: listProc.running && listProc.rescan === "yes" ? "Available networks  scanning…" : "Available networks"
    }

    Repeater {
        id: rows

        model: section.radio ? section.networks : []

        ColumnLayout {
            id: entry

            required property var modelData
            readonly property string ssid: entry.modelData.ssid

            function focusRow() {
                networkRow.forceActiveFocus()
            }

            Layout.fillWidth: true
            spacing: 0

            NetworkRow {
                id: networkRow

                form: section.form
                name: entry.ssid
                details: section.security(entry.modelData)
                action: "Connect"
                primary: entry.modelData.saved
                working: section.busy === entry.ssid

                onActiveFocusChanged: {
                    if (activeFocus)
                        section.focusedSsid = entry.ssid
                }

                onAct: section.activate(entry.modelData)
                onForget: {
                    if (entry.modelData.saved)
                        section.forget(entry.ssid)
                }
            }

            // Password for a secured network without a saved profile.
            Item {
                visible: section.asking === entry.ssid

                Layout.fillWidth: true
                implicitHeight: 28 + 2 * section.form.rowPadding

                onVisibleChanged: {
                    password.text = ""
                    if (visible)
                        password.forceActiveFocus()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 24
                    anchors.verticalCenter: parent.verticalCenter

                    text: "Password"
                    color: section.form.text.normal

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 2
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    width: 240
                    height: 28

                    radius: 6
                    color: section.form.colors.backgroundAlt
                    border.width: 1
                    border.color: section.form.colors.border

                    TextInput {
                        id: password

                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        activeFocusOnTab: true
                        clip: true

                        color: section.form.colors.foreground
                        selectionColor: section.form.colors.accent
                        selectedTextColor: section.form.colors.background

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }

                        onAccepted: {
                            if (text === "")
                                return
                            const secret = text
                            section.asking = ""
                            networkRow.forceActiveFocus()
                            section.run(entry.ssid, ["nmcli", "device", "wifi", "connect", entry.ssid, "password", secret])
                        }

                        Keys.onEscapePressed: {
                            section.asking = ""
                            networkRow.forceActiveFocus()
                        }
                    }

                    FocusRing {
                        form: section.form
                        visible: password.activeFocus
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: section.form.colors.border
                }
            }
        }
    }

    GroupLabel {
        form: section.form
        visible: section.wired.length > 0
        text: "Wired"
    }

    Repeater {
        model: section.wired

        NetworkRow {
            required property var modelData

            form: section.form
            name: modelData.name
            details: modelData.state
        }
    }
}
