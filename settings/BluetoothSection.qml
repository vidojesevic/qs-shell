import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// Live section: every action goes to the adapter at once. Enter connects,
// disconnects or pairs the focused row, Delete forgets a paired device,
// Ctrl+R rescans (the modal calls rescan()).
ColumnLayout {
    id: section

    required property var form

    // Read by the modal: switch in the pane header, hint in the footer.
    readonly property Component header: adapterSwitch
    readonly property string hint: "↵ connect / pair · Del forget · ^R rescan"

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool powered: section.adapter?.enabled ?? false

    // Address of the focused row, to give focus back after the lists change.
    property string focusedAddress: ""

    spacing: 0

    function rescan() {
        if (!section.powered)
            return

        section.adapter.discovering = false
        section.scan()
    }

    function scan() {
        if (!section.powered || !section.form.visible)
            return

        section.adapter.discovering = true
        scanTimer.restart()
    }

    function stopScan() {
        scanTimer.stop()
        if (section.adapter)
            section.adapter.discovering = false
    }

    function type(device) {
        if (device.icon === "")
            return "unknown"
        if (device.icon === "audio-card")
            return "speaker"
        return device.icon.split("-").pop()
    }

    function details(device) {
        const parts = [section.type(device)]
        if (device.batteryAvailable)
            parts.push(Math.round(device.battery * 100) + " %")
        if (device.trusted && !device.connected)
            parts.push("trusted")
        return parts.join(" · ")
    }

    function busy(device) {
        return device.pairing
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting
    }

    // A row moved between the lists, or left them, and took focus with it.
    // Give focus to the same device, else the page, so the modal keys still
    // work.
    function restoreFocus() {
        const focused = section.Window.activeFocusItem
        if (focused && focused !== section.Window.contentItem)
            return

        for (const list of [paired, nearby]) {
            for (let i = 0; i < list.count; i++) {
                const item = list.itemAt(i)
                if (item.modelData.address === section.focusedAddress) {
                    item.forceActiveFocus()
                    return
                }
            }
        }

        section.forceActiveFocus()
    }

    Component.onCompleted: section.scan()
    Component.onDestruction: section.stopScan()

    onPoweredChanged: section.scan()

    Connections {
        target: section.form

        function onVisibleChanged() {
            if (section.form.visible)
                section.scan()
            else
                section.stopScan()
        }
    }

    // A scan runs for a while, not for as long as the modal is open.
    Timer {
        id: scanTimer

        interval: 15000
        onTriggered: section.stopScan()
    }

    ScriptModel {
        id: pairedModel

        values: section.powered ? Bluetooth.devices.values.filter(device => device.paired) : []
        onValuesChanged: Qt.callLater(section.restoreFocus)
    }

    ScriptModel {
        id: nearbyModel

        values: section.powered ? Bluetooth.devices.values.filter(device => !device.paired) : []
        onValuesChanged: Qt.callLater(section.restoreFocus)
    }

    Component {
        id: adapterSwitch

        Row {
            visible: section.adapter !== null
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter

                text: "Adapter"
                color: section.form.text.dim

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Rectangle {
                id: track

                function toggle() {
                    section.adapter.enabled = !section.powered
                }

                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 18

                radius: 9
                color: section.powered ? section.form.colors.accent : "transparent"
                border.width: 1
                border.color: section.powered ? section.form.colors.accent : section.form.colors.border

                activeFocusOnTab: true
                Keys.onSpacePressed: track.toggle()

                Rectangle {
                    x: section.powered ? 17 : 3
                    y: 3
                    width: 12
                    height: 12

                    radius: 6
                    color: section.powered ? section.form.colors.background : section.form.colors.muted

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

    // Small button inside a row. Rows take the keys; buttons take clicks.
    component ActionButton: Rectangle {
        id: button

        required property var form
        property string label
        property bool primary: false
        property bool danger: false

        signal clicked()

        width: caption.implicitWidth + 16
        height: 24

        radius: 6
        color: "transparent"
        border.width: 1
        border.color: button.primary ? button.form.colors.accent : button.form.colors.border

        Text {
            id: caption

            anchors.centerIn: parent

            text: button.label
            color: button.primary ? button.form.colors.accent
                : button.danger ? button.form.colors.red
                : button.form.colors.foregroundAlt

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // One device row: name, state, details, buttons on the right.
    component DeviceRow: Rectangle {
        id: row

        required property var form
        required property var modelData
        default property alias buttons: buttonRow.data
        property string status

        Layout.fillWidth: true
        implicitHeight: 28 + 2 * row.form.rowPadding

        radius: 6
        color: "transparent"

        activeFocusOnTab: true

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Text {
                text: row.modelData.name || row.modelData.address
                color: row.form.text.normal

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Text {
                visible: row.status !== ""
                text: row.status
                color: row.modelData.connected ? row.form.colors.green : row.form.text.dim

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }

            Text {
                text: section.details(row.modelData)
                color: row.form.text.dim

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }
            }
        }

        Row {
            id: buttonRow

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
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

    component GroupLabel: Item {
        id: group

        required property var form
        property string label
        property string note

        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 32

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: group.label
            color: group.form.text.dim

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: group.note
            color: group.form.text.dim

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }
    }

    Text {
        visible: !section.powered
        Layout.preferredHeight: 28 + 2 * section.form.rowPadding
        verticalAlignment: Text.AlignVCenter

        text: section.adapter ? "Bluetooth is off" : "No Bluetooth adapter"
        color: section.form.text.dim

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize - 2
        }
    }

    GroupLabel {
        form: section.form
        visible: section.powered
        label: "Paired devices"
    }

    Repeater {
        id: paired

        model: pairedModel

        DeviceRow {
            id: device

            form: section.form
            status: device.modelData.state === BluetoothDeviceState.Connecting ? "connecting…"
                : device.modelData.state === BluetoothDeviceState.Disconnecting ? "disconnecting…"
                : device.modelData.connected ? "connected"
                : ""

            function act() {
                if (section.busy(device.modelData))
                    return
                if (device.modelData.connected)
                    device.modelData.disconnect()
                else
                    device.modelData.connect()
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    section.focusedAddress = device.modelData.address
            }

            Keys.onReturnPressed: device.act()
            Keys.onEnterPressed: device.act()
            Keys.onDeletePressed: device.modelData.forget()

            ActionButton {
                form: section.form
                label: device.modelData.connected ? "Disconnect" : "Connect"
                primary: !device.modelData.connected
                onClicked: {
                    device.forceActiveFocus()
                    device.act()
                }
            }

            ActionButton {
                form: section.form
                label: "Forget"
                danger: true
                onClicked: device.modelData.forget()
            }
        }
    }

    GroupLabel {
        form: section.form
        visible: section.powered
        label: "Nearby"
        note: section.adapter?.discovering ? "scanning…" : ""
    }

    Repeater {
        id: nearby

        model: nearbyModel

        DeviceRow {
            id: stranger

            form: section.form
            status: stranger.modelData.pairing ? "pairing…" : ""

            function act() {
                if (!stranger.modelData.pairing)
                    stranger.modelData.pair()
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    section.focusedAddress = stranger.modelData.address
            }

            Keys.onReturnPressed: stranger.act()
            Keys.onEnterPressed: stranger.act()

            ActionButton {
                form: section.form
                label: "Pair"
                onClicked: {
                    stranger.forceActiveFocus()
                    stranger.act()
                }
            }
        }
    }
}
