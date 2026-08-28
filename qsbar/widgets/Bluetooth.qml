import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: btRoot

    property var adapter: Bluetooth.defaultAdapter

    property var connectedDevice: {
        const devices = Bluetooth.devices.values

        for (let i = 0; i < devices.length; i++) {
            if (devices[i].connected)
                return devices[i]
        }

        return null
    }

    color: btPopup.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    text: {
        if (!adapter || !adapter.enabled)
            return "󰂲"

        if (connectedDevice)
            return "󰂱 " + connectedDevice.name

        return "󰂯"
    }

    function deviceIcon(device) {
        if (device.connected)
            return "󰂱"

        if (device.paired)
            return "󰂲"

        return "󰂯"
    }

    function toggleDevice(device) {
        if (device.connected)
            device.disconnect()
        else if (!device.paired)
            device.pair()
        else
            device.connect()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            btPopup.visible = !btPopup.visible
        }
    }

    Connections {
        target: btRoot.adapter

        function onEnabledChanged() {
            if (btPopup.visible && btRoot.adapter.enabled)
                btRoot.adapter.discovering = true
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            btPopup.visible = false
        }
    }

    PopupWindow {
        id: btPopup

        anchor {
            item: btRoot

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
            if (btRoot.adapter && btRoot.adapter.enabled) {
                btRoot.adapter.discovering = visible
            }

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
                id: popupHover

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
                        text: "Bluetooth"
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

                    // Adapter on/off switch
                    Rectangle {
                        id: adapterSwitch

                        readonly property bool on:
                            btRoot.adapter && btRoot.adapter.enabled

                        readonly property bool pending:
                            btRoot.adapter
                            && (btRoot.adapter.state === BluetoothAdapterState.Enabling
                                || btRoot.adapter.state === BluetoothAdapterState.Disabling)

                        implicitWidth: 44
                        implicitHeight: 22

                        radius: 11

                        color: on
                            ? Config.colors.blue
                            : Config.colors.muted

                        opacity: btRoot.adapter && !pending ? 1 : 0.5

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

                            x: adapterSwitch.on
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

                            enabled: btRoot.adapter && !adapterSwitch.pending
                            cursorShape: enabled
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor

                            onClicked: {
                                popupCloseTimer.stop()
                                btRoot.adapter.enabled = !btRoot.adapter.enabled
                            }
                        }
                    }
                }

                Text {
                    text: {
                        if (!btRoot.adapter)
                            return "No adapter"

                        if (!btRoot.adapter.enabled)
                            return "󰂲 Disabled"

                        return btRoot.connectedDevice
                            ? "󰂱 " + btRoot.connectedDevice.name
                            : "󰂯 Not connected"
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

                        visible: deviceList.count === 0
                        text: btRoot.adapter && btRoot.adapter.discovering
                            ? "Scanning..."
                            : "No devices found"

                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 1
                        }
                    }

                    ListView {
                        id: deviceList

                        anchors.fill: parent

                        clip: true
                        spacing: 4

                        model: Bluetooth.devices

                        delegate: Rectangle {
                            required property var modelData

                            readonly property bool busy:
                                modelData.state === BluetoothDeviceState.Connecting
                                || modelData.state === BluetoothDeviceState.Disconnecting
                                || modelData.pairing

                            width: ListView.view.width
                            implicitHeight: 40

                            radius: 5

                            color: modelData.connected
                                ? Qt.alpha(Config.colors.blue, 0.18)
                                : (deviceMouse.containsMouse
                                    ? Config.colors.muted
                                    : "transparent")

                            border {
                                width: modelData.connected ? 1 : 0
                                color: Config.colors.blue
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: btRoot.deviceIcon(modelData)

                                    color: modelData.connected
                                        ? Config.text.active
                                        : Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text: modelData.name || modelData.address
                                    elide: Text.ElideRight

                                    color: modelData.connected
                                        ? Config.text.active
                                        : Config.text.normal

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 1
                                        bold: modelData.connected
                                    }
                                }

                                Text {
                                    visible: modelData.batteryAvailable

                                    text: "󰁹 " + Math.round(modelData.battery * 100) + "%"
                                    color: Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 3
                                    }
                                }

                                // Spinner while connecting or pairing.
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
                                    visible: modelData.connected && !busy

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
                                id: deviceMouse

                                anchors.fill: parent
                                hoverEnabled: true

                                enabled: !busy
                                cursorShape: enabled
                                    ? Qt.PointingHandCursor
                                    : Qt.ArrowCursor

                                onClicked: {
                                    popupCloseTimer.stop()
                                    btRoot.toggleDevice(modelData)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30

                    radius: 5

                    color: rescanMouse.containsMouse
                        ? Config.colors.muted
                        : "transparent"

                    border {
                        width: 1
                        color: Config.colors.muted
                    }

                    Text {
                        anchors.centerIn: parent

                        text: "󰑓 Rescan devices"
                        color: Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }
                    }

                    MouseArea {
                        id: rescanMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (!btRoot.adapter || !btRoot.adapter.enabled)
                                return

                            btRoot.adapter.discovering = false
                            btRoot.adapter.discovering = true
                        }
                    }
                }
            }
        }
    }
}
