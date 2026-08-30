import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: screenRoot

    // Panel backlight, written through elogind so the shell needs no root.
    property string backlightDevice: ""
    property int backlightMax: 0
    property int brightnessPercent: 0

    // hyprsunset owns the color transform matrix. Without it, no color control.
    property bool sunsetRunning: false
    property int temperature: screenRoot.neutralTemp
    property int gammaPercent: 100

    // hyprsunset's neutral point. Using it as "night light off" keeps the
    // daemon's own reading the single source of truth for the toggle.
    readonly property int neutralTemp: 6500
    readonly property int warmTemp: 4000
    readonly property int minTemp: 2500

    // At gamma 0 the matrix is all zeros and the screen goes black, with no
    // way back from a bar you can no longer see.
    readonly property int minGamma: 20

    readonly property bool hasBacklight: backlightDevice.length > 0
    readonly property bool nightLight:
        sunsetRunning && temperature < neutralTemp

    readonly property var presets: [
        { label: "Day", kelvin: 6500 },
        { label: "Warm", kelvin: 5000 },
        { label: "Sunset", kelvin: 4000 },
        { label: "Night", kelvin: 3400 },
        { label: "Ember", kelvin: 2700 }
    ]

    function brightnessIcon(percent) {
        if (percent >= 67)
            return "󰃠"

        if (percent >= 34)
            return "󰃟"

        return "󰃞"
    }

    text: brightnessIcon(brightnessPercent) + " " + brightnessPercent + "%"
        + (nightLight ? " 󰖔" : "")

    color: screenPopup.visible ? Config.text.active : Config.text.normal

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    function setBrightness(percent) {
        if (!hasBacklight || backlightMax <= 0)
            return

        // Never reach 0: the panel would go dark with the slider out of sight.
        screenRoot.brightnessPercent = Math.round(
            Math.max(1, Math.min(100, percent))
        )

        brightnessGuard.restart()
        brightnessTimer.restart()
    }

    function setTemperature(kelvin) {
        screenRoot.temperature = Math.round(
            Math.max(minTemp, Math.min(neutralTemp, kelvin))
        )

        sunsetGuard.restart()
        tempTimer.restart()
    }

    function setGamma(percent) {
        screenRoot.gammaPercent = Math.round(
            Math.max(minGamma, Math.min(100, percent))
        )

        sunsetGuard.restart()
        gammaTimer.restart()
    }

    function toggleNightLight() {
        setTemperature(nightLight ? neutralTemp : warmTemp)
    }

    function screenOff() {
        screenPopup.visible = false
        Quickshell.execDetached(["hyprctl", "dispatch", "dpms", "off"])
    }

    /*
     * hyprctl talks to hyprsunset over its own socket, so a stopped daemon
     * looks like a connection failure rather than a bad command. Start one
     * with the identity matrix and retry until it answers.
     */
    function applySunset(key, value) {
        Quickshell.execDetached([
            "sh",
            "-c",
            "hyprctl hyprsunset \"$1\" \"$2\" >/dev/null 2>&1 && exit 0; "
            + "hyprsunset --identity >/dev/null 2>&1 & "
            + "for _ in 1 2 3 4 5 6 7 8 9 10; do "
            + "sleep 0.2; "
            + "hyprctl hyprsunset \"$1\" \"$2\" >/dev/null 2>&1 && exit 0; "
            + "done",
            "_",
            key,
            String(value)
        ])

        sunsetRefresh.restart()
    }

    /*
     * Ignore poll results for a moment after a user change, so a reading
     * taken before the change landed cannot snap a slider back.
     */
    Timer {
        id: brightnessGuard

        interval: 600
        repeat: false
    }

    Timer {
        id: sunsetGuard

        interval: 900
        repeat: false
    }

    // Debounce, so dragging does not spawn a process per pixel.
    Timer {
        id: brightnessTimer

        interval: 60
        repeat: false

        onTriggered: {
            Quickshell.execDetached([
                "busctl", "--system", "call",
                "org.freedesktop.login1",
                "/org/freedesktop/login1/session/auto",
                "org.freedesktop.login1.Session",
                "SetBrightness", "ssu",
                "backlight",
                screenRoot.backlightDevice,
                String(Math.round(
                    screenRoot.brightnessPercent / 100 * screenRoot.backlightMax
                ))
            ])
        }
    }

    Timer {
        id: tempTimer

        interval: 60
        repeat: false

        onTriggered: screenRoot.applySunset("temperature", screenRoot.temperature)
    }

    Timer {
        id: gammaTimer

        interval: 60
        repeat: false

        onTriggered: screenRoot.applySunset("gamma", screenRoot.gammaPercent)
    }

    Process {
        id: probeProc

        command: [
            "sh",
            "-c",
            "dev=$(ls /sys/class/backlight 2>/dev/null | head -n1); "
            + "if [ -n \"$dev\" ]; then "
            + "printf 'device=%s\\nmax=%s\\nraw=%s\\n' \"$dev\" "
            + "\"$(cat /sys/class/backlight/$dev/max_brightness)\" "
            + "\"$(cat /sys/class/backlight/$dev/actual_brightness)\"; "
            + "fi; "
            + "t=$(hyprctl hyprsunset temperature 2>/dev/null); "
            + "g=$(hyprctl hyprsunset gamma 2>/dev/null); "
            + "case \"$t\" in ''|*[!0-9]*) exit 0;; esac; "
            + "case \"$g\" in ''|*[!0-9]*) exit 0;; esac; "
            + "printf 'sunset=1\\ntemp=%s\\ngamma=%s\\n' \"$t\" \"$g\""
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let device = ""
                let max = 0
                let raw = -1

                // Absent daemon means no matrix is applied, which is neutral.
                let running = false
                let temp = screenRoot.neutralTemp
                let gamma = 100

                const lines = text.trim().split("\n")

                for (let i = 0; i < lines.length; i++) {
                    const split = lines[i].indexOf("=")

                    if (split < 0)
                        continue

                    const key = lines[i].slice(0, split)
                    const value = lines[i].slice(split + 1)

                    switch (key) {
                    case "device": device = value; break
                    case "max": max = parseInt(value) || 0; break
                    case "raw": raw = parseInt(value); break
                    case "sunset": running = true; break
                    case "temp": temp = parseInt(value); break
                    case "gamma": gamma = parseInt(value); break
                    }
                }

                screenRoot.backlightDevice = device
                screenRoot.backlightMax = max
                screenRoot.sunsetRunning = running

                if (max > 0 && raw >= 0
                    && !brightnessGuard.running && !brightnessRow.pressed) {
                    screenRoot.brightnessPercent = Math.round(raw / max * 100)
                }

                if (sunsetGuard.running || tempRow.pressed || gammaRow.pressed)
                    return

                screenRoot.temperature = temp
                screenRoot.gammaPercent = gamma
            }
        }
    }

    Timer {
        id: refreshTimer

        // The hardware keys move the backlight too, so poll faster while the
        // sliders are on screen.
        interval: screenPopup.visible ? 1000 : 5000

        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!probeProc.running)
                probeProc.running = true
        }
    }

    // Give a freshly started daemon time to answer before reading it back.
    Timer {
        id: sunsetRefresh

        interval: 1200
        repeat: false

        onTriggered: probeProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                screenRoot.toggleNightLight()
                return
            }

            screenPopup.visible = !screenPopup.visible
        }

        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 5 : -5
            screenRoot.setBrightness(screenRoot.brightnessPercent + step)
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            screenPopup.visible = false
        }
    }

    // One labelled slider. Three controls share the styling.
    component ControlRow: RowLayout {
        id: row

        property string icon: ""
        property color accent: Config.colors.accent
        property string readout: ""
        property alias from: slider.from
        property alias to: slider.to
        property alias stepSize: slider.stepSize
        property alias value: slider.value
        property alias pressed: slider.pressed

        signal moved(real value)

        spacing: 12

        Text {
            text: row.icon
            color: row.enabled ? Config.text.normal : Config.text.dim

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize + 2
                bold: true
            }
        }

        Slider {
            id: slider

            Layout.fillWidth: true

            enabled: row.enabled

            onMoved: row.moved(value)

            background: Rectangle {
                x: slider.leftPadding
                y: slider.topPadding + slider.availableHeight / 2 - height / 2

                implicitWidth: 120
                implicitHeight: 6

                width: slider.availableWidth
                height: implicitHeight

                radius: 3
                color: Config.colors.muted

                Rectangle {
                    width: slider.visualPosition * parent.width
                    height: parent.height

                    radius: 3

                    color: row.enabled ? row.accent : Config.colors.muted
                }
            }

            handle: Rectangle {
                x: slider.leftPadding
                    + slider.visualPosition * (slider.availableWidth - width)

                y: slider.topPadding + slider.availableHeight / 2 - height / 2

                implicitWidth: 14
                implicitHeight: 14

                radius: 7

                color: Config.colors.background

                border {
                    width: 2
                    color: row.enabled ? row.accent : Config.colors.muted
                }
            }
        }

        Text {
            Layout.preferredWidth: 56

            horizontalAlignment: Text.AlignRight

            text: row.readout
            color: row.enabled ? Config.text.normal : Config.text.dim

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize
                bold: true
            }
        }
    }

    PopupWindow {
        id: screenPopup

        anchor {
            item: screenRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 480
        implicitHeight: 300

        visible: false
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible) {
                probeProc.running = true
                popupCloseTimer.restart()
            } else {
                popupCloseTimer.stop()
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
                spacing: 8

                Text {
                    text: screenRoot.hasBacklight
                        ? "Backlight · " + screenRoot.backlightDevice
                        : "Backlight · no device"

                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                ControlRow {
                    id: brightnessRow

                    Layout.fillWidth: true

                    enabled: screenRoot.hasBacklight

                    icon: screenRoot.brightnessIcon(screenRoot.brightnessPercent)
                    accent: Config.colors.yellow
                    readout: screenRoot.brightnessPercent + "%"

                    from: 1
                    to: 100
                    stepSize: 1
                    value: screenRoot.brightnessPercent

                    onMoved: value => {
                        popupCloseTimer.restart()
                        screenRoot.setBrightness(value)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Text {
                    text: screenRoot.sunsetRunning
                        ? "Color · hyprsunset"
                        : "Color · hyprsunset idle, starts on first change"

                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                // Software gamma dims below the backlight floor, and reaches
                // external outputs that carry no backlight device at all.
                ControlRow {
                    id: gammaRow

                    Layout.fillWidth: true

                    icon: "󰃚"
                    accent: Config.colors.blue
                    readout: screenRoot.gammaPercent + "%"

                    from: screenRoot.minGamma
                    to: 100
                    stepSize: 1
                    value: screenRoot.gammaPercent

                    onMoved: value => {
                        popupCloseTimer.restart()
                        screenRoot.setGamma(value)
                    }
                }

                ControlRow {
                    id: tempRow

                    Layout.fillWidth: true

                    icon: screenRoot.nightLight ? "󰖔" : "󰖙"
                    accent: Config.colors.orange
                    readout: screenRoot.temperature + "K"

                    from: screenRoot.minTemp
                    to: screenRoot.neutralTemp
                    stepSize: 100
                    value: screenRoot.temperature

                    onMoved: value => {
                        popupCloseTimer.restart()
                        screenRoot.setTemperature(value)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: screenRoot.presets

                        Rectangle {
                            required property var modelData

                            readonly property bool current:
                                screenRoot.temperature === modelData.kelvin

                            Layout.fillWidth: true
                            implicitHeight: 26

                            radius: 5

                            color: current
                                ? Qt.alpha(Config.colors.orange, 0.18)
                                : (presetMouse.containsMouse
                                    ? Config.colors.muted
                                    : "transparent")

                            border {
                                width: current ? 1 : 0
                                color: Config.colors.orange
                            }

                            Text {
                                anchors.centerIn: parent

                                text: modelData.label

                                color: current
                                    ? Config.text.active
                                    : Config.text.normal

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                    bold: current
                                }
                            }

                            MouseArea {
                                id: presetMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    popupCloseTimer.restart()
                                    screenRoot.setTemperature(modelData.kelvin)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28

                    radius: 5

                    color: dpmsMouse.containsMouse
                        ? Config.colors.muted
                        : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8

                        Text {
                            text: "󰶐"
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 1
                            }
                        }

                        Text {
                            Layout.fillWidth: true

                            text: "Screen off"
                            color: Config.text.normal

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                            }
                        }

                        Text {
                            text: "move mouse to wake"
                            color: Config.text.dim

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 4
                            }
                        }
                    }

                    MouseArea {
                        id: dpmsMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: screenRoot.screenOff()
                    }
                }
            }
        }
    }
}
