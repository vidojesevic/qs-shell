import QtQuick
import QtQuick.Layouts

import "../config.js" as Config

// One row: label, dirty dot, 32 x 18 switch. Space or a click toggles it.
// Off rows show the label muted. A locked switch stays on and says so.
Item {
    id: row

    required property var form
    required property string key
    required property string label
    property bool locked: false

    readonly property bool value: form.valueOf(key)
    readonly property bool dirty: key in form.pending

    Layout.fillWidth: true
    implicitHeight: 28 + 2 * form.rowPadding

    function toggle() {
        if (!row.locked)
            row.form.change(row.key, !row.value)
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter

        text: row.label
        color: row.value ? Config.text.normal : Config.text.dim

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

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: row.locked
            text: "always on"
            color: Config.text.dim

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 18

            radius: 9
            color: row.value ? Config.colors.accent : "transparent"
            border.width: 1
            border.color: row.value ? Config.colors.accent : Config.colors.border
            opacity: row.locked ? 0.55 : 1

            activeFocusOnTab: !row.locked
            Keys.onSpacePressed: row.toggle()

            Rectangle {
                x: row.value ? 17 : 3
                y: 3
                width: 12
                height: 12

                radius: 6
                color: row.value ? Config.colors.background : Config.colors.muted

                Behavior on x {
                    NumberAnimation { duration: 100 }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !row.locked
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    track.forceActiveFocus()
                    row.toggle()
                }
            }

            FocusRing {
                visible: track.activeFocus
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
