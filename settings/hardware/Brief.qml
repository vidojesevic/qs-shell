import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

// Shown when settings/hardware/local/ has no page.
ColumnLayout {
    id: brief

    required property var form

    spacing: 8

    component Line: Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: brief.form.text.dim

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize - 2
        }
    }

    Line {
        Layout.topMargin: 12
        text: "No profile for \"" + brief.form.machine + "\"."
        color: brief.form.text.normal
    }

    Line {
        text: "Battery charge limit, fan, keyboard backlight and privacy switches "
            + "differ by vendor, so each laptop gets its own page in settings/hardware/local/."
    }

    Line {
        Layout.topMargin: 12
        text: "With an agent"
        color: brief.form.text.normal
    }

    Line {
        text: "\"Write a hardware profile for this laptop. Follow settings/hardware/README.md.\""
    }

    Line {
        Layout.topMargin: 12
        text: "By hand"
        color: brief.form.text.normal
    }

    Line {
        text: "Read settings/hardware/README.md and start from its ThinkPad example. "
            + "Change the sysfs paths to match this machine."
    }
}
