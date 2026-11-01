import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// One row: label, dirty dot, 240 px text field. A required field left empty
// gets a yellow border and the hint under the row, and blocks Apply.
ColumnLayout {
    id: row

    required property var form
    required property string key
    required property string label
    property bool isRequired: false
    property string hint: ""
    property int maxLength: 64

    readonly property string value: form.valueOf(key)
    readonly property bool dirty: key in form.pending
    readonly property bool empty: row.isRequired && row.value === ""

    Layout.fillWidth: true
    spacing: 0

    onValueChanged: {
        if (!input.activeFocus)
            input.text = row.value
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: 28 + 2 * row.form.rowPadding

        Text {
            anchors.verticalCenter: parent.verticalCenter

            text: row.label
            color: Config.text.normal

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }

            Text {
                anchors.left: parent.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                visible: row.dirty
                text: "●"
                color: Config.colors.accent
                font: parent.font
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: 240
            height: 28

            radius: 6
            color: Config.colors.backgroundAlt
            border.width: 1
            border.color: row.empty ? Config.colors.yellow : Config.colors.border

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                text: row.value
                verticalAlignment: TextInput.AlignVCenter
                maximumLength: row.maxLength
                activeFocusOnTab: true
                selectByMouse: true
                clip: true

                color: Config.colors.foreground
                selectionColor: Config.colors.accent
                selectedTextColor: Config.colors.background

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }

                onTextEdited: {
                    row.form.change(row.key, text)
                    row.form.validate(row.key, !row.isRequired || text !== "")
                }
            }

            FocusRing {
                visible: input.activeFocus
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Config.colors.border
            visible: !row.empty
        }
    }

    Item {
        visible: row.empty

        Layout.fillWidth: true
        implicitHeight: 24

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            text: row.hint
            color: Config.colors.yellow

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Config.colors.border
        }
    }
}
