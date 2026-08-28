import Quickshell.Hyprland
import QtQuick

import "../../config.js" as Config

Text {
    id: root

    required property int index
    required property int wsStart
    required property var screen

    property int wsId: root.wsStart + root.index

    property var ws: Hyprland.workspaces.values.find(
        workspace => workspace.id === root.wsId
    )

    property var hyprMonitor: Hyprland.monitorFor(root.screen)

    property bool isActive:
        hyprMonitor?.activeWorkspace?.id === root.wsId

    text: root.wsId

    color: root.isActive
        ? Config.colors.cyan
        : (root.ws ? Config.colors.blue : Config.colors.muted)

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            Hyprland.dispatch("workspace " + root.wsId)
        }
    }
}
