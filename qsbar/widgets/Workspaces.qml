import Quickshell.Hyprland
import QtQuick

import "../themes" as Themes

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
        ? Themes.Theme.cyan
        : (root.ws ? Themes.Theme.blue : Themes.Theme.muted)

    font {
        family: Themes.Theme.fontFamily
        pixelSize: Themes.Theme.fontSize
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
