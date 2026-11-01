import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// Label with one pill per option under it. Left/Right change the choice.
Item {
    id: choice

    required property var form
    required property string key
    required property string label
    required property var options

    readonly property string value: form.valueOf(key)
    readonly property bool dirty: key in form.pending

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 2 * form.rowPadding

    function step(delta) {
        const index = choice.options.indexOf(choice.value) + delta
        if (index >= 0 && index < choice.options.length)
            choice.form.change(choice.key, choice.options[index])
    }

    Column {
        id: column

        y: choice.form.rowPadding
        spacing: 8

        Text {
            text: choice.label
            color: Config.text.normal

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }

            Text {
                anchors.left: parent.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                visible: choice.dirty
                text: "●"
                color: Config.colors.accent
                font: parent.font
            }
        }

        Row {
            id: pills

            spacing: 4
            activeFocusOnTab: true

            Keys.onLeftPressed: choice.step(-1)
            Keys.onRightPressed: choice.step(1)

            Repeater {
                model: choice.options

                Rectangle {
                    id: pill

                    required property string modelData

                    readonly property bool selected: pill.modelData === choice.value

                    width: name.implicitWidth + 20
                    height: 28

                    radius: 6
                    color: pill.selected ? Config.colors.accent : "transparent"
                    border.width: 1
                    border.color: pill.selected ? Config.colors.accent : Config.colors.border

                    Text {
                        id: name

                        anchors.centerIn: parent

                        text: pill.modelData
                        color: pill.selected ? Config.colors.background : Config.colors.foregroundAlt

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 2
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pills.forceActiveFocus()
                            choice.form.change(choice.key, pill.modelData)
                        }
                    }

                    FocusRing {
                        visible: pills.activeFocus && pill.selected
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Config.colors.border
    }
}
