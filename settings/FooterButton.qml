import QtQuick

import "../config.js" as Config

// Footer button with a muted shortcut hint. Space or Enter clicks it.
Rectangle {
    id: button

    required property string label
    required property string hint
    property bool primary: false

    signal clicked()

    readonly property bool filled: button.primary && button.enabled

    implicitWidth: content.implicitWidth + 24
    implicitHeight: 32

    radius: 6
    color: button.filled ? Config.colors.accent : "transparent"
    border.width: 1
    border.color: button.filled ? Config.colors.accent : Config.colors.border

    activeFocusOnTab: true

    Keys.onSpacePressed: button.clicked()
    Keys.onReturnPressed: event => {
        // Ctrl+Enter is Save & Close; let it reach the modal.
        if (event.modifiers & Qt.ControlModifier)
            event.accepted = false
        else
            button.clicked()
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 8

        Text {
            text: button.label
            color: !button.enabled ? Config.colors.muted
                : button.filled ? Config.colors.background
                : Config.colors.foreground

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }

        Text {
            text: button.hint
            color: button.filled ? Config.colors.background : Config.colors.muted
            opacity: button.filled ? 0.65 : 1

            font {
                family: Config.bar.fontFamily
                pixelSize: Config.bar.fontSize - 2
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: button.clicked()
    }

    FocusRing {
        visible: button.activeFocus
    }
}
