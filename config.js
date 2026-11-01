.import "theme/current.js" as Theme

const colors = Theme.colors
const text = Theme.text

const bar = {
    fontFamily: "JetBrainsMono Nerd Font",
    // fontFamily: "Ubuntu Mono",
    fontSize: 16,
    height: 30,
    padding: 2
}

const notifications = {
    timeout: 5000
}

/**
 * Screensaver
 * @description Text animation on a black screen. Manual start only, with
 *              SUPER + SHIFT + Escape (qs ipc call screensaver toggle).
 *              The same keybind closes it.
 * @reload      Quickshell reloads by itself when you save this file. If the
 *              old values still show, force a reload:
 *              qs ipc call shell reload
 */
const screensaver = {
    text: "The Code Tribe",
    fontSize: 96,
    animation: "dvd" // decrypt, typewriter, drop, scatter, wave, dvd
}
