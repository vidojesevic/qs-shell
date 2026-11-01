import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

ColumnLayout {
    id: section

    required property var form

    spacing: 0

    NumberField {
        form: section.form
        key: "notifications.timeout"
        label: "Popup timeout"
        unit: "ms"
        from: 1000
        to: 30000
    }

    Text {
        Layout.topMargin: section.form.rowPadding

        text: "1000 – 30000 ms"
        color: section.form.text.dim

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize - 2
        }
    }
}
