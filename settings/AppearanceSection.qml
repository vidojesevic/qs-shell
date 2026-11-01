import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

ColumnLayout {
    id: section

    required property var form

    spacing: 0

    // Not in config.js. The modal previews the theme; Apply sends it to the
    // theme switcher.
    SegmentedChoice {
        form: section.form
        key: "theme"
        label: "Theme"
        options: ["catppuccin", "dracula", "onedark", "tokyonight", "ember"]
    }

    FontField {
        form: section.form
        key: "bar.fontFamily"
        label: "Font family"
    }

    NumberField {
        form: section.form
        key: "bar.fontSize"
        label: "Font size"
        unit: "px"
        from: 10
        to: 24
    }

    Text {
        Layout.topMargin: section.form.rowPadding

        text: "← → changes choice · Full picker: SUPER+SHIFT+T"
        color: section.form.text.dim

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize - 2
        }
    }
}
