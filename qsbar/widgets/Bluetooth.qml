import QtQuick
import Quickshell.Bluetooth

import "../themes" as Themes

Text {
    id: btDevices

    color: Themes.Theme.blue

    font {
        family: Themes.Theme.fontFamily
        pixelSize: Themes.Theme.fontSize
        bold: true
    }

    property var adapter: Bluetooth.defaultAdapter

    text: {
        if (!adapter || !adapter.enabled)
            return "󰂲"

        if (Bluetooth.devices.count > 0) {
            const device = Bluetooth.devices.get(0)
            return "󰂱 " + device.deviceName
        }

        return "󰂯"
    }
}
