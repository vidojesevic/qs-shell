import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

import "../config.js" as Config

// Recording indicator: qs ipc call recording region <x> <y> <w> <h>
//                      qs ipc call recording monitor <name>
//                      qs ipc call recording stop
//
// The border is drawn just OUTSIDE the captured rect and the badge sits clear
// of it, so wf-recorder's -g crop never contains them. For a whole-output
// recording the badge goes on a different monitor, which -o does not capture.
// This is why no layerrule is needed: Hyprland's no_screen_share blanks the
// entire surface, which would black out the video.
Scope {
    id: root

    property bool active: false
    property int rx: 0
    property int ry: 0
    property int rw: 0
    property int rh: 0
    property string badgeScreen: ""
    property int elapsed: 0

    readonly property int bw: 3
    readonly property color accent: "#ff4444"

    IpcHandler {
        target: "recording"

        function region(x: int, y: int, w: int, h: int): void {
            root.rx = x; root.ry = y; root.rw = w; root.rh = h
            root.badgeScreen = ""
            root.begin()
        }

        function monitor(name: string): void {
            const other = Quickshell.screens.find(s => s.name !== name)
            root.rw = 0
            root.badgeScreen = other ? other.name : ""
            root.begin()
        }

        function stop(): void {
            root.active = false
            ticker.running = false
        }
    }

    function begin(): void {
        elapsed = 0
        active = true
        ticker.running = true
    }

    Timer {
        id: ticker
        interval: 1000
        repeat: true
        onTriggered: root.elapsed++
    }

    function clock(s: int): string {
        const m = Math.floor(s / 60)
        const r = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData

            // Region rect in this screen's local coordinates.
            readonly property int lx: root.rx - modelData.x
            readonly property int ly: root.ry - modelData.y
            readonly property bool hasRegion: root.rw > 0
                && root.rx < modelData.x + modelData.width
                && root.rx + root.rw > modelData.x
                && root.ry < modelData.y + modelData.height
                && root.ry + root.rh > modelData.y
            readonly property bool hasBadge: root.badgeScreen === modelData.name

            screen: modelData
            visible: root.active && (hasRegion || hasBadge)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors { top: true; bottom: true; left: true; right: true }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-recording"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Empty input region: clicks fall through to whatever is below.
            mask: Region {}

            // Border sits entirely outside the captured rect.
            Rectangle {
                visible: win.hasRegion

                x: win.lx - root.bw
                y: win.ly - root.bw
                width: root.rw + root.bw * 2
                height: root.rh + root.bw * 2

                color: "transparent"
                border.color: root.accent
                border.width: root.bw
                radius: 2
            }

            // Badge: above the region if there is room, otherwise below it.
            Rectangle {
                id: badge

                readonly property int gap: 6

                visible: win.hasRegion || win.hasBadge

                x: win.hasRegion
                    ? Math.max(4, win.lx - root.bw)
                    : 24
                y: win.hasRegion
                    ? (win.ly - root.bw - height - gap >= 0
                        ? win.ly - root.bw - height - gap
                        : win.ly + root.rh + root.bw + gap)
                    : Config.bar.height + 12

                implicitWidth: label.implicitWidth + 20
                implicitHeight: label.implicitHeight + 10

                radius: 6
                color: Qt.alpha(Config.colors.background, 0.9)
                border.color: root.accent
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: 9
                        implicitHeight: 9
                        radius: 5
                        color: root.accent

                        SequentialAnimation on opacity {
                            running: root.active
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 700 }
                            NumberAnimation { to: 1.0;  duration: 700 }
                        }
                    }

                    Text {
                        id: label

                        anchors.verticalCenter: parent.verticalCenter
                        text: "REC  " + root.clock(root.elapsed)
                        color: root.accent

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                            bold: true
                        }
                    }
                }
            }
        }
    }
}
