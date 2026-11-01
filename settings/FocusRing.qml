import QtQuick

import "../config.js" as Config

// 1 px accent outline, 3 px outside the parent.
Rectangle {
    anchors.fill: parent
    anchors.margins: -3

    radius: parent.radius + 3
    color: "transparent"
    border.width: 1
    border.color: Config.colors.accent
}
