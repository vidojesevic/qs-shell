import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property color backgroundColor: "#1a1b26"
    property int radiusSize: 8

    default property alias content: layout.data

    color: backgroundColor
    radius: radiusSize

    implicitHeight: 26
    implicitWidth: layout.implicitWidth + 16

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 8
    }
}
