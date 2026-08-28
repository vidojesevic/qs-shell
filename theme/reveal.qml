import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Standalone instance: qs -p ~/.config/quickshell/theme/reveal.qml
//
// Freezes the current screen (grim screenshot per monitor) on an overlay,
// tells the main shell it is covered, then on "reveal start" punches a
// growing pixel-grid circle from the center through the frozen frame,
// showing the new theme underneath. Quits when done.
ShellRoot {
    id: root

    property int covered: 0
    property real progress: 0

    IpcHandler {
        target: "reveal"

        function start(): void {
            startDelay.running = true
        }
    }

    // Give the reloaded shell a moment to draw its first frame.
    Timer {
        id: startDelay

        interval: 250
        onTriggered: anim.running = true
    }

    NumberAnimation on progress {
        id: anim

        running: false
        from: 0
        to: 1
        duration: 1000
        easing.type: Easing.InQuad

        onFinished: {
            Quickshell.execDetached(["sh", "-c", 'rm -f "$XDG_RUNTIME_DIR"/qs-reveal-*.png'])
            Qt.quit()
        }
    }

    Process {
        id: notify

        command: ["qs", "ipc", "call", "theme", "covered"]
    }

    // Safety: never stay on screen forever if the shell never calls start.
    Timer {
        interval: 10000
        running: true
        onTriggered: Qt.quit()
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: scr

            required property var modelData
            // Unique per run: Canvas caches images by URL, so a reused name
            // would show the previous run's frame.
            property string file: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-reveal-" + modelData.name + "-" + Date.now() + ".png"
            property bool shot: false

            Process {
                running: true
                command: ["grim", "-o", scr.modelData.name, scr.file]

                // Load only once the file exists.
                onExited: {
                    scr.shot = true
                    cv.loadImage(scr.file)
                }
            }

            PanelWindow {
                visible: scr.shot
                screen: scr.modelData

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }

                color: "transparent"
                exclusionMode: ExclusionMode.Ignore

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-theme-reveal"

                Canvas {
                    id: cv

                    anchors.fill: parent

                    property int cell: 24

                    onImageLoaded: {
                        requestPaint()
                        root.covered++
                        if (root.covered === Quickshell.screens.length) notify.running = true
                    }

                    Connections {
                        target: root
                        function onProgressChanged() { cv.requestPaint() }
                    }

                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        ctx.clearRect(0, 0, width, height)
                        ctx.drawImage(scr.file, 0, 0, width, height)

                        // Dim the frozen frame so the reveal reads over app
                        // windows too, not only where wallpaper/bar changed.
                        ctx.fillStyle = "rgba(0, 0, 0, 0.35)"
                        ctx.fillRect(0, 0, width, height)

                        if (root.progress <= 0) return

                        const cx = width / 2
                        const cy = height / 2
                        const r = root.progress * Math.hypot(cx, cy)

                        // Cut cells whose center is inside the circle. Per-cell
                        // hash jitters the edge so it looks dithered, not clean.
                        ctx.globalCompositeOperation = "destination-out"
                        ctx.fillStyle = "black"   // opaque: cell fully removed
                        for (let y = 0; y < height; y += cell) {
                            for (let x = 0; x < width; x += cell) {
                                const jitter = ((x * 73856093) ^ (y * 19349663)) % (cell * 3)
                                const d = Math.hypot(x + cell / 2 - cx, y + cell / 2 - cy)
                                if (d < r - jitter) ctx.fillRect(x, y, cell, cell)
                            }
                        }
                    }
                }
            }
        }
    }
}
