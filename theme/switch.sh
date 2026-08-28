#!/bin/sh
# Usage: switch.sh <catppuccin|dracula|tokyonight|ember>
# Relinks theme/current.js + theme/wallpaper and restarts swaybg.
# Quickshell reloads itself after this script exits (see ThemeSwitcher.qml).
set -e

dir="$(cd "$(dirname "$0")" && pwd)"
name="$1"

[ -f "$dir/$name.js" ] || { echo "unknown theme: $name" >&2; exit 1; }

wall="$(sed -n 's/^var wallpaper = "\(.*\)"/\1/p' "$dir/$name.js")"
vscode="$(sed -n 's/^var vscode = "\(.*\)"/\1/p' "$dir/$name.js")"
ghostty="$(sed -n 's/^var ghostty = "\(.*\)"/\1/p' "$dir/$name.js")"
helium="$(sed -n 's/^var helium = "\(.*\)"/\1/p' "$dir/$name.js")"

ln -sfn "$name.js" "$dir/current.js"
ln -sfn "$HOME/.config/walls/$wall" "$dir/wallpaper"

# Start the new swaybg before killing the old one. A gap with no wallpaper
# shows Hyprland's built-in default for a frame.
old="$(pgrep -x swaybg || true)"
setsid -f swaybg -i "$dir/wallpaper" >/dev/null 2>&1
sleep 0.3
[ -n "$old" ] && kill $old 2>/dev/null || true

# VSCode picks up settings.json changes live.
vs_settings="$HOME/.config/Code/User/settings.json"
[ -f "$vs_settings" ] && sed -i "s|^\(\s*\)\"workbench.colorTheme\": \".*\"|\1\"workbench.colorTheme\": \"$vscode\"|" "$vs_settings"

# Ghostty: included from ~/.config/ghostty/config; SIGUSR2 = reload_config.
echo "theme = $ghostty" > "$HOME/.config/ghostty/theme.conf"
pkill -USR2 -x ghostty || true

# Helium (Chromium): Preferences are only safe to edit while it is closed;
# applies on next launch.
pgrep -x helium-browser >/dev/null || "$dir/helium.py" "$helium" || true

# Manual use: reload running quickshell too.
[ -n "$QS_RELOAD_SELF" ] || qs ipc call theme reload >/dev/null 2>&1 || true
