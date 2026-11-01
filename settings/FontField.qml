import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// One row: label, dirty dot, 240 px field. While the field has focus, a list
// of installed fonts shows under it, each name in its own font. Typing
// filters the list, Up/Down move, Enter or a click picks.
ColumnLayout {
    id: row

    required property var form
    required property string key
    required property string label

    readonly property string value: form.valueOf(key)
    readonly property bool dirty: key in form.pending

    readonly property var families: Qt.fontFamilies().sort()
    property string query: ""
    readonly property var matches: row.families.filter(
        name => name.toLowerCase().includes(row.query.toLowerCase()))

    Layout.fillWidth: true
    spacing: 0

    function pick(event) {
        // Ctrl+Enter is Save & Close; let it reach the modal.
        if (event.modifiers & Qt.ControlModifier) {
            event.accepted = false
            return
        }

        // Enter with no match picks nothing.
        const name = row.matches[list.currentIndex]
        if (name !== undefined)
            row.choose(name)
    }

    function choose(name) {
        input.text = name
        input.selectAll()
        row.query = ""
        list.currentIndex = row.families.indexOf(name)
        row.form.change(row.key, name)
    }

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

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: 240
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

                text: row.value
                verticalAlignment: TextInput.AlignVCenter
                activeFocusOnTab: true
                selectByMouse: true
                clip: true

                color: row.form.colors.foreground
                selectionColor: row.form.colors.accent
                selectedTextColor: row.form.colors.background

                font {
                    family: Config.bar.fontFamily
                    pixelSize: Config.bar.fontSize - 2
                }

                onTextEdited: row.query = text

                // Open on the whole list at the current font; leave showing
                // the picked one.
                onActiveFocusChanged: {
                    if (activeFocus) {
                        row.query = ""
                        list.currentIndex = row.families.indexOf(row.value)
                        selectAll()
                    } else {
                        text = row.value
                    }
                }

                Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
                Keys.onDownPressed: list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1)
                Keys.onReturnPressed: event => row.pick(event)
                Keys.onEnterPressed: event => row.pick(event)
            }

            FocusRing {
                form: row.form
                visible: input.activeFocus
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: row.form.colors.border
            visible: !input.activeFocus
        }
    }

    Item {
        visible: input.activeFocus

        Layout.fillWidth: true
        implicitHeight: 5 * 24 + 8 + row.form.rowPadding

        Rectangle {
            anchors.right: parent.right
            width: 240
            height: 5 * 24 + 8

            radius: 6
            color: row.form.colors.backgroundAlt
            border.width: 1
            border.color: row.form.colors.border

            ListView {
                id: list

                anchors.fill: parent
                anchors.margins: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                model: row.matches

                onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

                delegate: Rectangle {
                    id: entry

                    required property int index
                    required property string modelData

                    readonly property bool current: entry.index === list.currentIndex

                    width: list.width
                    height: 24

                    radius: 4
                    color: entry.current ? row.form.colors.accent : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16

                        text: entry.modelData
                        color: entry.current ? row.form.colors.background : row.form.colors.foreground
                        elide: Text.ElideRight

                        font {
                            family: entry.modelData
                            pixelSize: Config.bar.fontSize - 2
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.choose(entry.modelData)
                    }
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
}
