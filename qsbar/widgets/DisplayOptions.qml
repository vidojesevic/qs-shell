import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: displayRoot

    // Monitors as reported by `hyprctl monitors all -j`, disabled ones included.
    property var monitors: []

    readonly property int activeCount:
        monitors.filter(monitor => !monitor.disabled).length

    property string lastError: ""

    readonly property var scaleSteps: [1, 1.25, 1.5, 1.75, 2]

    text: "󰍹 " + activeCount
    color: displayPopup.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    // "1920x1200@60.00Hz" as Hyprland wants it in a monitor rule.
    function modeValue(mode) {
        return mode.replace("Hz", "")
    }

    function currentMode(monitor) {
        return monitor.width + "x" + monitor.height
            + "@" + monitor.refreshRate.toFixed(2)
    }

    function transformLabel(transform) {
        switch (transform) {
        case 1: return "90°"
        case 2: return "180°"
        case 3: return "270°"
        default: return "0°"
        }
    }

    // One monitor rule carrying every field, so applying one does not
    // reset the others.
    function apply(monitor, overrides) {
        const mode = overrides.mode !== undefined
            ? overrides.mode
            : currentMode(monitor)

        const scale = overrides.scale !== undefined
            ? overrides.scale
            : monitor.scale

        const transform = overrides.transform !== undefined
            ? overrides.transform
            : monitor.transform

        const mirror = overrides.mirror !== undefined
            ? overrides.mirror
            : monitor.mirrorOf

        let rule = monitor.name + "," + mode + ","
            + monitor.x + "x" + monitor.y + "," + scale
            + ",transform," + transform

        if (mirror && mirror !== "none")
            rule += ",mirror," + mirror

        run(["hyprctl", "keyword", "monitor", rule])
    }

    function disable(monitor) {
        run(["hyprctl", "keyword", "monitor", monitor.name + ",disable"])
    }

    function enable(monitor) {
        run([
            "hyprctl", "keyword", "monitor",
            monitor.name + ",preferred,auto,1"
        ])
    }

    function run(command) {
        displayRoot.lastError = ""

        applyProc.command = command
        applyProc.running = true
    }

    // Next mode in the monitor's own list, wrapping around.
    function cycleMode(monitor) {
        const modes = monitor.availableModes || []

        if (modes.length < 2)
            return

        const current = currentMode(monitor)
        let index = modes.findIndex(mode => modeValue(mode) === current)

        index = (index + 1) % modes.length

        apply(monitor, { mode: modeValue(modes[index]) })
    }

    function cycleScale(monitor) {
        let index = scaleSteps.findIndex(
            step => Math.abs(step - monitor.scale) < 0.01
        )

        index = (index + 1) % scaleSteps.length

        apply(monitor, { scale: scaleSteps[index] })
    }

    function cycleTransform(monitor) {
        apply(monitor, { transform: (monitor.transform + 1) % 4 })
    }

    // none -> each other monitor -> none.
    function cycleMirror(monitor) {
        const others = monitors
            .filter(other => other.name !== monitor.name && !other.disabled)
            .map(other => other.name)

        if (others.length === 0)
            return

        const targets = ["none"].concat(others)
        const current = monitor.mirrorOf || "none"

        let index = targets.indexOf(current)
        index = (index + 1) % targets.length

        apply(monitor, { mirror: targets[index] })
    }

    Process {
        id: monitorsProc

        command: ["hyprctl", "monitors", "all", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                displayRoot.monitors = JSON.parse(text)
            }
        }
    }

    Process {
        id: applyProc

        stdout: StdioCollector {
            onStreamFinished: {
                const reply = text.trim()

                if (reply && reply !== "ok")
                    displayRoot.lastError = reply
            }
        }

        // Hyprland needs a moment before the new state shows up.
        onExited: reloadTimer.restart()
    }

    Timer {
        id: reloadTimer

        interval: 400
        repeat: false

        onTriggered: monitorsProc.running = true
    }

    // Keep the count in the bar honest about hotplugs.
    Timer {
        interval: 10000
        running: true
        repeat: true

        onTriggered: monitorsProc.running = true
        Component.onCompleted: monitorsProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!displayPopup.visible)
                monitorsProc.running = true

            displayPopup.visible = !displayPopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            displayPopup.visible = false
        }
    }

    PopupWindow {
        id: displayPopup

        anchor {
            item: displayRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 520
        implicitHeight: Math.min(
            120 + displayRoot.monitors.length * 96,
            520
        )

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
                        text: "Displays"
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

                    Text {
                        text: displayRoot.activeCount + " active"
                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
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

                        visible: monitorList.count === 0
                        text: "No monitors found"
                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 1
                        }
                    }

                    ListView {
                        id: monitorList

                        anchors.fill: parent

                        clip: true
                        spacing: 6

                        model: displayRoot.monitors

                        delegate: Rectangle {
                            id: monitorCard

                            required property var modelData

                            // Named apart from modelData so the chip delegate
                            // below, which shadows it, can still reach it.
                            readonly property var monitor: modelData

                            readonly property bool on: !modelData.disabled

                            width: ListView.view.width
                            implicitHeight: on ? 90 : 46

                            radius: 5

                            color: on
                                ? Qt.alpha(Config.colors.blue, 0.12)
                                : "transparent"

                            border {
                                width: 1

                                color: on
                                    ? Config.colors.blue
                                    : Config.colors.muted
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: on ? "󰍹" : "󰶐"

                                        color: on
                                            ? Config.text.active
                                            : Config.text.dim

                                        font {
                                            family: Config.bar.fontFamily
                                            pixelSize: Config.bar.fontSize
                                        }
                                    }

                                    Text {
                                        text: modelData.name

                                        color: on
                                            ? Config.text.active
                                            : Config.text.normal

                                        font {
                                            family: Config.bar.fontFamily
                                            pixelSize: Config.bar.fontSize - 1
                                            bold: true
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true

                                        text: modelData.description || ""
                                        elide: Text.ElideRight

                                        color: Config.text.dim

                                        font {
                                            family: Config.bar.fontFamily
                                            pixelSize: Config.bar.fontSize - 4
                                        }
                                    }

                                    // Monitor on/off switch
                                    Rectangle {
                                        implicitWidth: 40
                                        implicitHeight: 20

                                        radius: 10

                                        color: on
                                            ? Config.colors.blue
                                            : Config.colors.muted

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 150
                                            }
                                        }

                                        Rectangle {
                                            width: 16
                                            height: 16
                                            radius: 8

                                            anchors.verticalCenter: parent.verticalCenter

                                            x: on ? parent.width - width - 2 : 2

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

                                            // Refuse to switch off the last display.
                                            enabled: !on || displayRoot.activeCount > 1

                                            cursorShape: enabled
                                                ? Qt.PointingHandCursor
                                                : Qt.ArrowCursor

                                            onClicked: {
                                                popupCloseTimer.stop()

                                                if (on)
                                                    displayRoot.disable(modelData)
                                                else
                                                    displayRoot.enable(modelData)
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    visible: on
                                    spacing: 6

                                    Repeater {
                                        model: on
                                            ? [
                                                {
                                                    label: "󰍹 " + displayRoot.currentMode(modelData),
                                                    action: "mode"
                                                },
                                                {
                                                    label: "󰩭 " + modelData.scale.toFixed(2) + "x",
                                                    action: "scale"
                                                },
                                                {
                                                    label: "󰑨 " + displayRoot.transformLabel(modelData.transform),
                                                    action: "transform"
                                                },
                                                {
                                                    label: "󰡊 " + (modelData.mirrorOf === "none"
                                                        ? "no mirror"
                                                        : "mirror " + modelData.mirrorOf),
                                                    action: "mirror"
                                                }
                                            ]
                                            : []

                                        delegate: Rectangle {
                                            required property var modelData

                                            implicitWidth: chipText.implicitWidth + 16
                                            implicitHeight: 24

                                            radius: 4

                                            color: chipMouse.containsMouse
                                                ? Config.colors.muted
                                                : "transparent"

                                            border {
                                                width: 1
                                                color: Config.colors.muted
                                            }

                                            Text {
                                                id: chipText

                                                anchors.centerIn: parent

                                                text: modelData.label
                                                color: Config.text.normal

                                                font {
                                                    family: Config.bar.fontFamily
                                                    pixelSize: Config.bar.fontSize - 4
                                                }
                                            }

                                            MouseArea {
                                                id: chipMouse

                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    popupCloseTimer.stop()

                                                    const monitor = monitorCard.monitor

                                                    switch (modelData.action) {
                                                    case "mode":
                                                        displayRoot.cycleMode(monitor)
                                                        break
                                                    case "scale":
                                                        displayRoot.cycleScale(monitor)
                                                        break
                                                    case "transform":
                                                        displayRoot.cycleTransform(monitor)
                                                        break
                                                    case "mirror":
                                                        displayRoot.cycleMirror(monitor)
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true

                    visible: displayRoot.lastError !== ""

                    text: displayRoot.lastError
                    elide: Text.ElideRight

                    color: Config.text.critical

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 4
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

                        text: "󰑓 Rescan monitors"
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
                            popupCloseTimer.stop()
                            monitorsProc.running = true
                        }
                    }
                }
            }
        }
    }
}
