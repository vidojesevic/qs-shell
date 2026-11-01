import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

import "../config.js" as Config

// Screensaver: text animates in (Config.screensaver.animation), holds, fades,
// and comes back at a new spot (no burn-in). Manual start only, with
// SUPER + SHIFT + Escape; the same keybind closes it. Other keys and clicks
// are swallowed.
//
// Animations:
//   decrypt    - letters scramble through random glyphs, then settle
//   typewriter - letters are typed one by one behind a blinking cursor
//   drop       - letters fall from the top and bounce into place
//   scatter    - letters fly in from random spots across the screen
//   wave       - letters bob up and down in a sine wave, without end
//   dvd        - text floats diagonally, bounces off the edges and changes
//                color only when it hits a corner (no fade cycle)
//
// Test: qs ipc call screensaver toggle
Scope {
    id: root

    property bool active: false

    readonly property string message: Config.screensaver.text
    readonly property string animation: Config.screensaver.animation
    readonly property int fontSize: Config.screensaver.fontSize
    readonly property string glyphs: "!@#$%^&*<>/\\|{}[]=+-_?;:0123456789abcdef"

    // Time in ms since the current cycle started. Every letter is a function of it.
    property real t: 0
    property real startedAt: 0
    // Three random numbers per letter, new each cycle.
    property var seeds: message.split("").map(() => [0, 0, 0])
    // Text position as a fraction of the free screen space, same on all screens.
    property real fx: 0.5
    property real fy: 0.5
    property real textOpacity: 1

    // dvd: speed in screen fractions per second. Position is a triangle wave
    // of time, so it bounces between 0 and 1; each whole unit is one bounce.
    // Color changes only on a corner hit: an x and a y bounce close in time.
    readonly property real dvdX: fx + 0.12 * t / 1000
    readonly property real dvdY: fy + 0.19 * t / 1000
    readonly property real posX: animation === "dvd" ? bounce(dvdX) : fx
    readonly property real posY: animation === "dvd" ? bounce(dvdY) : fy
    readonly property var palette: [Config.colors.purple, Config.colors.blue, Config.colors.cyan,
        Config.colors.green, Config.colors.yellow, Config.colors.orange, Config.colors.red]
    readonly property color textColor: animation === "dvd"
        ? palette[colorIndex % palette.length]
        : Config.colors.accent
    readonly property int cornerWindow: 250 // ms between x and y bounce
    property int colorIndex: 0
    property int bouncesX: 0
    property int bouncesY: 0
    property real lastBounceX: -1e9
    property real lastBounceY: -1e9

    readonly property int introDuration: {
        switch (animation) {
        case "typewriter": return message.length * 120
        case "drop": return message.length * 80 + 900
        case "scatter": return message.length * 40 + 1200
        case "wave": return 0
        default: return 1600
        }
    }

    function show(): void {
        restart()
        active = true
    }

    function hide(): void {
        active = false
    }

    function restart(): void {
        seeds = message.split("").map(() => [Math.random(), Math.random(), Math.random()])
        fx = Math.random()
        fy = Math.random()
        textOpacity = 1
        fade.stop()
        startedAt = Date.now()
        t = 0
        bouncesX = 0
        bouncesY = 0
        lastBounceX = -1e9
        lastBounceY = -1e9
        holdTimer.interval = introDuration + 6000
        if (animation !== "dvd")
            holdTimer.restart()
    }

    function tick(): void {
        t = Date.now() - startedAt
        if (animation !== "dvd")
            return

        const bx = Math.floor(dvdX)
        const by = Math.floor(dvdY)
        if (bx === bouncesX && by === bouncesY)
            return

        if (bx !== bouncesX) { bouncesX = bx; lastBounceX = t }
        if (by !== bouncesY) { bouncesY = by; lastBounceY = t }
        if (Math.abs(lastBounceX - lastBounceY) < cornerWindow)
            colorIndex++
    }

    function bounce(u: real): real {
        const m = u % 2
        return m < 1 ? m : 2 - m
    }

    // 0..1 progress of letter i, which starts delay * i ms into the cycle.
    function progress(i: int, delay: int, duration: int): real {
        return Math.max(0, Math.min(1, (t - i * delay) / duration))
    }

    function easeOutCubic(p: real): real {
        return 1 - Math.pow(1 - p, 3)
    }

    function easeOutBounce(p: real): real {
        if (p < 1 / 2.75) return 7.5625 * p * p
        if (p < 2 / 2.75) return 7.5625 * (p -= 1.5 / 2.75) * p + 0.75
        if (p < 2.5 / 2.75) return 7.5625 * (p -= 2.25 / 2.75) * p + 0.9375
        return 7.5625 * (p -= 2.625 / 2.75) * p + 0.984375
    }

    function glyph(i: int): string {
        const ch = message.charAt(i)

        if (animation === "typewriter") {
            const typed = Math.min(Math.floor(t / 120), message.length)
            if (i < typed) return ch
            if (i === typed && Math.floor(t / 500) % 2 === 0) return "█"
            return " "
        }

        if (animation === "decrypt" && ch !== " " && t < seeds[i][0] * introDuration) {
            // Cheap hash, so a glyph changes every 40 ms and not on every frame.
            const h = Math.abs(Math.sin(i * 12.9898 + Math.floor(t / 40) * 78.233)) * 43758.5453
            return glyphs[Math.floor(h) % glyphs.length]
        }

        return ch
    }

    function offsetX(i: int, w: real): real {
        if (animation === "scatter")
            return (seeds[i][1] - 0.5) * w * (1 - easeOutCubic(progress(i, 40, 1200)))
        return 0
    }

    function offsetY(i: int, h: real): real {
        switch (animation) {
        case "drop": return -h * (1 - easeOutBounce(progress(i, 80, 900)))
        case "scatter": return (seeds[i][2] - 0.5) * h * (1 - easeOutCubic(progress(i, 40, 1200)))
        case "wave": return Math.sin(t / 250 - i * 0.6) * fontSize * 0.2
        default: return 0
        }
    }

    function letterOpacity(i: int): real {
        if (animation === "scatter")
            return Math.min(1, progress(i, 40, 1200) * 2)
        return 1
    }

    IpcHandler {
        target: "screensaver"

        function start(): void { root.show() }
        function stop(): void { root.hide() }
        function toggle(): void { root.active ? root.hide() : root.show() }
    }

    Timer {
        interval: 16
        repeat: true
        running: root.active
        onTriggered: root.tick()
    }

    Timer {
        id: holdTimer
        onTriggered: fade.restart()
    }

    SequentialAnimation {
        id: fade
        NumberAnimation { target: root; property: "textOpacity"; to: 0; duration: 1200; easing.type: Easing.InOutQuad }
        ScriptAction { script: root.restart() }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            visible: root.active
            color: "black"
            exclusionMode: ExclusionMode.Ignore

            anchors { top: true; bottom: true; left: true; right: true }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-screensaver"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                id: area
                anchors.fill: parent
                // Exclusive keyboard focus plus this item eat every key, so
                // nothing reaches the apps below. Hyprland binds still work.
                focus: true

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.BlankCursor
                }

                Row {
                    x: root.posX * (area.width - width)
                    y: root.posY * (area.height - height)
                    opacity: root.textOpacity

                    Repeater {
                        // Typewriter needs one extra slot for the cursor after the last letter.
                        model: root.message.length + (root.animation === "typewriter" ? 1 : 0)

                        Text {
                            required property int index

                            text: root.glyph(index)
                            opacity: root.letterOpacity(index)
                            color: root.textColor
                            font.family: Config.bar.fontFamily
                            font.pixelSize: root.fontSize
                            font.bold: true

                            transform: Translate {
                                x: root.offsetX(index, area.width)
                                y: root.offsetY(index, area.height)
                            }
                        }
                    }
                }
            }
        }
    }
}
