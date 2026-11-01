import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

ColumnLayout {
    id: section

    required property var form

    spacing: 0

    // Bar order, left to right: [key in Config.widgets, label].
    readonly property var widgets: [
        ["workspaces", "Workspaces"],
        ["clock", "Clock"],
        ["cpu", "CPU"],
        ["memory", "Memory"],
        ["gpu", "GPU"],
        ["battery", "Battery"],
        ["docker", "Docker"],
        ["claude", "Claude usage"],
        ["keyboard", "Keyboard layout"],
        ["weather", "Weather"],
        ["mail", "Mail"],
        ["bluetooth", "Bluetooth"],
        ["volume", "Volume"],
        ["wifi", "Wi-Fi"],
        ["screen", "Screen"],
        ["display", "Display options"],
        ["session", "Session"]
    ]

    // Widget settings, shown under the widget's row while it is on.
    readonly property var extras: ({
        claude: claudeRows,
        weather: weatherRows,
        mail: mailRows
    })

    NumberField {
        form: section.form
        key: "bar.height"
        label: "Bar height"
        unit: "px"
        from: 20
        to: 48
    }

    NumberField {
        form: section.form
        key: "bar.padding"
        label: "Bar padding"
        unit: "px"
        from: 0
        to: 8
    }

    Text {
        Layout.topMargin: 2 * section.form.rowPadding

        text: "Widgets · left → right"
        color: Config.text.dim

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize - 2
        }
    }

    Repeater {
        model: section.widgets

        ColumnLayout {
            id: widget

            required property var modelData

            readonly property string name: widget.modelData[0]
            readonly property string enabledKey: "widgets." + widget.name + ".enabled"

            Layout.fillWidth: true
            spacing: 0

            Switch {
                form: section.form
                key: widget.enabledKey
                label: widget.modelData[1]
                locked: widget.name === "workspaces" || widget.name === "clock"
            }

            Loader {
                Layout.fillWidth: true
                Layout.leftMargin: 24

                visible: section.form.valueOf(widget.enabledKey)
                sourceComponent: section.extras[widget.name] ?? null
            }
        }
    }

    Component {
        id: claudeRows

        ColumnLayout {
            spacing: 0

            NumberField {
                form: section.form
                key: "widgets.claude.dangerLevel"
                label: "Danger level"
                unit: "%"
                from: 50
                to: 100
            }

            NumberField {
                form: section.form
                key: "widgets.claude.refresh"
                label: "Refresh"
                unit: "s"
                from: 10
                to: 600
            }
        }
    }

    Component {
        id: weatherRows

        ColumnLayout {
            spacing: 0

            TextField {
                form: section.form
                key: "widgets.weather.city"
                label: "City"
                isRequired: true
                hint: "City cannot be empty"
            }

            NumberField {
                form: section.form
                key: "widgets.weather.refresh"
                label: "Refresh"
                unit: "s"
                from: 60
                to: 3600
            }
        }
    }

    Component {
        id: mailRows

        ColumnLayout {
            spacing: 0

            NumberField {
                form: section.form
                key: "widgets.mail.refresh"
                label: "Refresh"
                unit: "s"
                from: 10
                to: 600
            }

            Switch {
                form: section.form
                key: "widgets.mail.inboxOnly"
                label: "Inbox only"
            }
        }
    }
}
