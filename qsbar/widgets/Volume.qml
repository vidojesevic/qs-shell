import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: volumeRoot

    property int volumePercent: 0
    property bool muted: false
    property string defaultSink: ""

    text: muted
        ? "󰖁 " + volumePercent + "%"
        : "󰕾 " + volumePercent + "%"

    color: Config.colors.yellow

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    function setVolume(value) {
        if (defaultSink.length === 0)
            return

        volumeRoot.volumePercent = Math.round(
            Math.max(0, Math.min(100, value))
        )

        applyGuard.restart()
        applyTimer.restart()
    }

    function toggleMute() {
        if (defaultSink.length === 0)
            return

        Quickshell.execDetached([
            "pactl", "set-sink-mute", defaultSink, "toggle"
        ])

        refreshTimer.restart()
        sinkProc.running = true
    }

    /*
     * Switch output: make the sink default, then move every playing
     * stream onto it, the way pavucontrol does.
     */
    function selectSink(name) {
        Quickshell.execDetached([
            "sh",
            "-c",
            "pactl set-default-sink \"$1\"; "
            + "for input in $(pactl list short sink-inputs | cut -f1); do "
            + "pactl move-sink-input \"$input\" \"$1\"; "
            + "done",
            "_",
            name
        ])

        switchRefreshTimer.restart()
    }

    /*
     * Ignore poll results for a moment after a user change, so a reading
     * taken before the server applied it cannot snap the slider back.
     */
    Timer {
        id: applyGuard

        interval: 600
        repeat: false
    }

    // Debounce, so dragging does not spawn a process per pixel.
    Timer {
        id: applyTimer

        interval: 60
        repeat: false

        onTriggered: {
            Quickshell.execDetached([
                "pactl", "set-sink-volume", volumeRoot.defaultSink,
                volumeRoot.volumePercent + "%"
            ])

            if (volumeRoot.volumePercent > 0 && volumeRoot.muted) {
                Quickshell.execDetached([
                    "pactl", "set-sink-mute", volumeRoot.defaultSink, "0"
                ])
            }
        }
    }

    ListModel {
        id: sinks
    }

    Process {
        id: sinkProc

        command: [
            "sh",
            "-c",
            "pactl get-default-sink; pactl -f json list sinks"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const split = text.indexOf("\n")

                if (split < 0)
                    return

                const defaultName = text.slice(0, split).trim()
                const list = JSON.parse(text.slice(split + 1))

                volumeRoot.defaultSink = defaultName

                sinks.clear()

                for (let i = 0; i < list.length; i++) {
                    const sink = list[i]
                    const channels = Object.keys(sink.volume)

                    let percent = 0

                    for (let c = 0; c < channels.length; c++) {
                        percent = Math.max(percent, parseInt(
                            sink.volume[channels[c]].value_percent
                        ) || 0)
                    }

                    const isDefault = sink.name === defaultName

                    sinks.append({
                        name: sink.name,
                        description: sink.description,
                        volume: percent,
                        sinkMuted: sink.mute,
                        isDefault: isDefault
                    })

                    if (!isDefault)
                        continue

                    volumeRoot.muted = sink.mute

                    // A local change is still settling, or is being dragged.
                    if (applyGuard.running || volumeSlider.pressed)
                        continue

                    volumeRoot.volumePercent = percent
                }
            }
        }
    }

    Timer {
        id: refreshTimer

        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!sinkProc.running)
                sinkProc.running = true
        }
    }

    // Give the server a moment to apply an output switch.
    Timer {
        id: switchRefreshTimer

        interval: 250
        repeat: false

        onTriggered: sinkProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                volumeRoot.toggleMute()
                return
            }

            volumePopup.visible = !volumePopup.visible
        }

        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? 5 : -5
            volumeRoot.setVolume(volumeRoot.volumePercent + step)
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            volumePopup.visible = false
        }
    }

    PopupWindow {
        id: volumePopup

        anchor {
            item: volumeRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 620
        implicitHeight: 320

        visible: false
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible) {
                sinkProc.running = true
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
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: volumeRoot.muted ? "󰖁" : "󰕾"

                        color: volumeRoot.muted
                            ? Config.colors.muted
                            : Config.colors.yellow

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                            bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                popupCloseTimer.restart()
                                volumeRoot.toggleMute()
                            }
                        }
                    }

                    Slider {
                        id: volumeSlider

                        Layout.fillWidth: true

                        from: 0
                        to: 100
                        stepSize: 1

                        value: volumeRoot.volumePercent

                        onMoved: {
                            popupCloseTimer.restart()
                            volumeRoot.setVolume(value)
                        }

                        background: Rectangle {
                            x: volumeSlider.leftPadding
                            y: volumeSlider.topPadding
                                + volumeSlider.availableHeight / 2 - height / 2

                            implicitWidth: 120
                            implicitHeight: 6

                            width: volumeSlider.availableWidth
                            height: implicitHeight

                            radius: 3
                            color: Config.colors.muted

                            Rectangle {
                                width: volumeSlider.visualPosition * parent.width
                                height: parent.height

                                radius: 3

                                color: volumeRoot.muted
                                    ? Config.colors.muted
                                    : Config.colors.yellow
                            }
                        }

                        handle: Rectangle {
                            x: volumeSlider.leftPadding
                                + volumeSlider.visualPosition
                                    * (volumeSlider.availableWidth - width)

                            y: volumeSlider.topPadding
                                + volumeSlider.availableHeight / 2 - height / 2

                            implicitWidth: 14
                            implicitHeight: 14

                            radius: 7

                            color: Config.colors.background

                            border {
                                width: 2

                                color: volumeRoot.muted
                                    ? Config.colors.muted
                                    : Config.colors.yellow
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: 42

                        horizontalAlignment: Text.AlignRight

                        text: volumeRoot.volumePercent + "%"
                        color: Config.colors.foreground

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Text {
                    text: "Output"
                    color: Config.colors.muted

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 3
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true
                    spacing: 4

                    model: sinks

                    delegate: Rectangle {
                        required property string name
                        required property string description
                        required property int volume
                        required property bool sinkMuted
                        required property bool isDefault

                        width: ListView.view.width
                        implicitHeight: 34

                        radius: 5

                        color: isDefault
                            ? Qt.alpha(Config.colors.yellow, 0.18)
                            : (sinkMouse.containsMouse
                                ? Config.colors.muted
                                : "transparent")

                        border {
                            width: isDefault ? 1 : 0
                            color: Config.colors.yellow
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: sinkMuted ? "󰖁" : "󰕾"

                                color: isDefault
                                    ? Config.colors.yellow
                                    : Config.colors.muted

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 1
                                }
                            }

                            Text {
                                Layout.fillWidth: true

                                text: description
                                elide: Text.ElideRight

                                color: isDefault
                                    ? Config.colors.yellow
                                    : Config.colors.foreground

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                    bold: isDefault
                                }
                            }

                            Text {
                                text: volume + "%"
                                color: Config.colors.muted

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 3
                                }
                            }
                        }

                        MouseArea {
                            id: sinkMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                popupCloseTimer.restart()
                                volumeRoot.selectSink(name)
                            }
                        }
                    }
                }
            }
        }
    }
}
