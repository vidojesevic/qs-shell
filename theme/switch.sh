#!/bin/sh
# Usage: switch.sh <catppuccin|onedark|dracula|tokyonight|ember>
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
nvim="$(sed -n 's/^var nvim = "\(.*\)"/\1/p' "$dir/$name.js")"
gtk_accent="$(sed -n 's/^var gtkAccent = "\(.*\)"/\1/p' "$dir/$name.js")"
herdr="$(sed -n 's/^var herdr = "\(.*\)"/\1/p' "$dir/$name.js")"

# One palette color from the theme file, e.g. color backgroundAlt.
color() { sed -n "s/^ *$1: \"\(#[0-9a-fA-F]*\)\".*/\1/p" "$dir/$name.js"; }

ln -sfn "$name.js" "$dir/current.js"
ln -sfn "$HOME/.config/walls/$wall" "$dir/wallpaper"

# Start the new swaybg before killing the old one. A gap with no wallpaper
# shows Hyprland's built-in default for a frame.
old="$(pgrep -x swaybg || true)"
setsid -f swaybg -m fill -i "$dir/wallpaper" >/dev/null 2>&1
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

# Neovim: default for new instances + live switch in running ones.
echo "return \"$nvim\"" > "$HOME/.config/nvim/lua/config/theme.lua"
for sock in "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/nvim.*.0; do
    [ -S "$sock" ] && nvim --server "$sock" --remote-expr "execute('colorscheme $nvim')" >/dev/null 2>&1 || true
done

# GTK4/libadwaita (Nautilus). Colors go in the user stylesheet; scheme and accent
# are gsettings because libadwaita reads those itself. GTK4 caches the stylesheet
# at startup, so running apps keep the old colors until a new window opens.
"$dir/gtk.py" "$dir/$name.js"
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
gsettings set org.gnome.desktop.interface accent-color "$gtk_accent"

# Herdr: built-in theme name, and the [theme.custom] surfaces that already
# exist in config.toml, from the palette. Every running session reloads it.
herdr_config="$HOME/.config/herdr/config.toml"
if command -v herdr >/dev/null && [ -f "$herdr_config" ]; then
    sed -i \
        -e "/^\[theme\]/,/^\[/ s|^name = .*|name = \"$herdr\"|" \
        -e "/^\[theme\.custom\]/,/^\[/ s|^sidebar_bg = .*|sidebar_bg = \"$(color backgroundAlt)\"|" \
        -e "/^\[theme\.custom\]/,/^\[/ s|^panel_bg = .*|panel_bg = \"$(color background)\"|" \
        -e "/^\[theme\.custom\]/,/^\[/ s|^active_row_bg = .*|active_row_bg = \"$(color border)\"|" \
        "$herdr_config"
    for session in $(herdr session list | awk 'NR > 1 && $2 == "running" { print $1 }'); do
        herdr --session "$session" server reload-config >/dev/null 2>&1 || true
    done
fi

# Manual use: reload running quickshell too.
[ -n "$QS_RELOAD_SELF" ] || qs ipc call theme reload >/dev/null 2>&1 || true
