# quickshell

Hyprland bar and notification daemon built with [Quickshell](https://quickshell.org). Tokyo Night colors.

## Bar

Workspaces (per-monitor), weather, clock, keyboard layout, CPU, memory, Docker, Claude usage, Bluetooth, WiFi, volume, battery, session.

Most widgets open a popup on click — not just a readout:

- **WiFi** — scan, connect, disconnect, toggle radio (`nmcli`)
- **Bluetooth** — pair, connect, trust, toggle adapter
- **Docker** — containers grouped by compose project, start/stop/restart
- **Claude usage** — tokens spent in the active 5 hour window, per model and per project. Turns red and sends a desktop warning past 80%
- **Volume** — per-sink and per-app sliders, output switching (`pactl`)
- **CPU / Memory / Battery** — live graphs, per-core load, top processes
- **Clock** — calendar
- **Session** — lock, suspend, reboot, poweroff (`loginctl`)

## Notifications

Popup toasts plus a notification center with history, grouping and inline actions.

## Settings

`SUPER + SHIFT + H` (`qs ipc call settings toggle`) opens a modal: network, Bluetooth, appearance, bar widgets, notifications, screensaver, system facts, and the laptop's own hardware switches. The last one needs a page for your machine in `settings/hardware/local/` (gitignored). Without one, it shows a short brief; see [settings/hardware/README.md](settings/hardware/README.md) for a guide and a ThinkPad example.

## Install

```sh
git clone <repo> ~/.config/quickshell
qs
```

Requires: Hyprland, Quickshell, a Nerd Font. Optional per widget: `nmcli`, `pactl`, `docker`, `curl`, `python3`, `notify-send`.

## Config

Colors, font and bar height live in [config.js](config.js). Weather city and monitor workspace ranges are in [qsbar/Bar.qml](qsbar/Bar.qml).

## License

MIT
