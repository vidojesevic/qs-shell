import QtQuick

// 1 px accent outline, 3 px outside the parent.
Rectangle {
    id: ring

    required property var form

    anchors.fill: parent
    anchors.margins: -3

    radius: parent.radius + 3
    color: "transparent"
    border.width: 1
    border.color: ring.form.colors.accent
}
