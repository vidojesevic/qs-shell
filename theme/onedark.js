.pragma library

var wallpaper = "onedark.png"
var vscode = "One Dark Pro"
var ghostty = "Atom One Dark"
var helium = "#61afef"
var nvim = "onedark"
var gtkAccent = "blue"

var colors = {
    background: "#282c34",
    backgroundAlt: "#21252b",
    foreground: "#abb2bf",
    foregroundAlt: "#828997",
    muted: "#4b5263",
    border: "#3e4451",
    red: "#e06c75",
    green: "#98c379",
    yellow: "#e5c07b",
    blue: "#61afef",
    purple: "#c678dd",
    cyan: "#56b6c2",
    orange: "#d19a66",
    accent: "#61afef",
    urgent: "#e06c75"
}

// Font colors. One default, one active, one critical per theme.
var text = {
    normal: colors.foreground,
    dim: colors.muted,
    active: colors.accent,
    critical: colors.red
}
