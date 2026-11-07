.import "theme/current.js" as Theme

const colors = Theme.colors
const text = Theme.text

const bar = {
    fontFamily: "JetBrainsMono Nerd Font",
    // fontFamily: "Ubuntu Mono",
    fontSize: 14,
    height: 30,
    padding: 2
}

/**
 * Monitors
 * @description internal must match INTERNAL in
 *              ~/.config/hypr/configuration/monitors.lua.
 */
const monitors = {
    internal: "eDP-1"
}

/**
 * Bar widgets
 * @description enabled: false hides a widget and its separator.
 *              workspaces and clock stay on. refresh is in seconds.
 */
const widgets = {
    workspaces: { enabled: true },
    clock: { enabled: true },
    cpu: { enabled: true },
    memory: { enabled: true },
    gpu: { enabled: true },
    battery: { enabled: true },
    docker: { enabled: true },
    claude: { enabled: true, dangerLevel: 80, refresh: 60 },
    keyboard: { enabled: true },
    weather: { enabled: true, city: "Belgrade", refresh: 600 },
    mail: { enabled: true, refresh: 60, inboxOnly: true },
    bluetooth: { enabled: true },
    volume: { enabled: true },
    wifi: { enabled: true },
    screen: { enabled: true },
    display: { enabled: true },
    session: { enabled: true }
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
    text: "DevOps",
    fontSize: 96,
    animation: "dvd" // decrypt, typewriter, drop, scatter, wave, dvd
}
