import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// One row: label, dirty dot, number field, unit. Up/Down step by 1,
// Shift+Up/Down by 10. Values outside from-to are clamped.
Item {
    id: row

    required property var form
    required property string key
    required property string label
    property string unit: ""
    property int from: 0
    property int to: 100

    readonly property int value: form.valueOf(key)
    readonly property bool dirty: key in form.pending

    Layout.fillWidth: true
    implicitHeight: 28 + 2 * form.rowPadding

    function clamp(n) {
        return Math.min(row.to, Math.max(row.from, n))
    }

    function step(delta) {
        const next = row.clamp(row.value + delta)
        input.text = String(next)
        row.form.change(row.key, next)
    }

    // Show the stored value again, unless the user is typing.
    onValueChanged: {
        if (!input.activeFocus)
            input.text = String(row.value)
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter

        text: row.label
        color: row.form.text.normal

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
            color: row.form.colors.accent
            font: parent.font
        }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: row.unit === "ms" ? 88 : 72
            height: 28

            radius: 6
            color: row.form.colors.backgroundAlt
            border.width: 1
            border.color: row.form.colors.border

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8

                text: String(row.value)
                horizontalAlignment: TextInput.AlignRight
                verticalAlignment: TextInput.AlignVCenter
                activeFocusOnTab: true
                selectByMouse: true
                validator: RegularExpressionValidator { regularExpression: /[0-9]{0,6}/ }

                color: row.form.colors.foreground
                selectionColor: row.form.colors.accent
                selectedTextColor: row.form.colors.background

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }

                // The stored value is always in range; the text shows what
                // was typed until focus leaves.
                onTextEdited: {
                    if (text !== "")
                        row.form.change(row.key, row.clamp(parseInt(text)))
                }

                onActiveFocusChanged: {
                    if (activeFocus)
                        selectAll()
                    else
                        text = String(row.value)
                }

                Keys.onUpPressed: event => row.step(event.modifiers & Qt.ShiftModifier ? 10 : 1)
                Keys.onDownPressed: event => row.step(event.modifiers & Qt.ShiftModifier ? -10 : -1)
            }

            FocusRing {
                form: row.form
                visible: input.activeFocus
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: row.unit !== ""
            text: row.unit
            color: row.form.text.dim

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: row.form.colors.border
    }
}
