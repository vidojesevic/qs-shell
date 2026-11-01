import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

ColumnLayout {
    id: section

    required property var form

    spacing: 0

    TextField {
        form: section.form
        key: "screensaver.text"
        label: "Text"
        isRequired: true
        hint: "Text cannot be empty · 1 – 64 characters"
    }

    NumberField {
        form: section.form
        key: "screensaver.fontSize"
        label: "Font size"
        unit: "px"
        from: 24
        to: 200
    }

    SegmentedChoice {
        form: section.form
        key: "screensaver.animation"
        label: "Animation"
        options: ["decrypt", "typewriter", "drop", "scatter", "wave", "dvd"]
    }

    Text {
        Layout.topMargin: section.form.rowPadding

        text: "← → changes choice"
        color: Config.text.dim

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize - 2
        }
    }
}
