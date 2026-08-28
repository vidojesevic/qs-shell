import Quickshell
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Rectangle {
    id: clockRoot

    property date now: new Date()

    // Month shown in the calendar, independent of today.
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()

    readonly property date gridStart: {
        const first = new Date(viewYear, viewMonth, 1)
        const offset = (first.getDay() + 6) % 7

        return new Date(viewYear, viewMonth, 1 - offset)
    }

    implicitWidth: clockText.implicitWidth
    implicitHeight: 24

    color: Config.colors.background

    function showToday() {
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
    }

    function shiftMonth(delta) {
        const shifted = new Date(viewYear, viewMonth + delta, 1)

        viewYear = shifted.getFullYear()
        viewMonth = shifted.getMonth()
    }

    Text {
        id: clockText

        anchors.fill: parent

        leftPadding: Config.bar.padding + 6
        rightPadding: Config.bar.padding + 6

        color: Config.colors.blue

        text: "\uf073 " + Qt.formatDateTime(
            clockRoot.now,
            "ddd, MMM dd - HH:mm"
        )

        font {
            family: Config.bar.fontFamily
            pixelSize: Config.bar.fontSize
            bold: true
        }

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: clockRoot.now = new Date()
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!calendarPopup.visible)
                clockRoot.showToday()

            calendarPopup.visible = !calendarPopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            calendarPopup.visible = false
        }
    }

    PopupWindow {
        id: calendarPopup

        anchor {
            item: clockRoot

            edges: Edges.Bottom | Edges.Left
            gravity: Edges.Bottom | Edges.Right

            margins.top: 32
            margins.left: 16
        }

        implicitWidth: 320
        implicitHeight: 388

        visible: false
        color: "transparent"
        grabFocus: true

        onVisibleChanged: {
            if (visible)
                popupCloseTimer.restart()
            else
                popupCloseTimer.stop()
        }

        Rectangle {
            anchors.fill: parent

            radius: 8
            color: Config.colors.background

            border {
                width: 1
                color: Config.colors.muted
            }

            // Keep popup open while pointer is over it.
            HoverHandler {
                onHoveredChanged: {
                    if (hovered)
                        popupCloseTimer.stop()
                    else
                        popupCloseTimer.restart()
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "\uf053"
                        color: previousMouse.containsMouse
                            ? Config.colors.cyan
                            : Config.colors.muted

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }

                        MouseArea {
                            id: previousMouse

                            anchors.fill: parent
                            anchors.margins: -6

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                popupCloseTimer.restart()
                                clockRoot.shiftMonth(-1)
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Qt.formatDate(
                            new Date(clockRoot.viewYear, clockRoot.viewMonth, 1),
                            "MMMM yyyy"
                        )

                        color: Config.colors.cyan

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                            bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                popupCloseTimer.restart()
                                clockRoot.showToday()
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "\uf054"
                        color: nextMouse.containsMouse
                            ? Config.colors.cyan
                            : Config.colors.muted

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }

                        MouseArea {
                            id: nextMouse

                            anchors.fill: parent
                            anchors.margins: -6

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                popupCloseTimer.restart()
                                clockRoot.shiftMonth(1)
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true

                    columns: 7
                    columnSpacing: 2
                    rowSpacing: 2

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        delegate: Text {
                            required property string modelData

                            Layout.fillWidth: true

                            horizontalAlignment: Text.AlignHCenter

                            text: modelData
                            color: Config.colors.muted

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 3
                                bold: true
                            }
                        }
                    }

                    Repeater {
                        model: 42

                        delegate: Rectangle {
                            required property int index

                            readonly property date day: new Date(
                                clockRoot.gridStart.getFullYear(),
                                clockRoot.gridStart.getMonth(),
                                clockRoot.gridStart.getDate() + index
                            )

                            readonly property bool inMonth:
                                day.getMonth() === clockRoot.viewMonth

                            readonly property bool isToday:
                                day.getFullYear() === clockRoot.now.getFullYear()
                                && day.getMonth() === clockRoot.now.getMonth()
                                && day.getDate() === clockRoot.now.getDate()

                            readonly property bool isWeekend:
                                day.getDay() === 0 || day.getDay() === 6

                            Layout.fillWidth: true

                            // 30px date number box, plus padding above and below.
                            implicitHeight: 30 + Config.bar.padding * 2
                            radius: 5

                            color: isToday
                                ? Qt.alpha(Config.colors.blue, 0.22)
                                : "transparent"

                            border {
                                width: isToday ? 1 : 0
                                color: Config.colors.blue
                            }

                            Text {
                                anchors.centerIn: parent

                                text: day.getDate()

                                color: {
                                    if (!inMonth)
                                        return Config.colors.muted

                                    if (isToday)
                                        return Config.colors.blue

                                    return isWeekend
                                        ? Config.colors.purple
                                        : Config.colors.foreground
                                }

                                font {
                                    family: Config.bar.fontFamily
                                    pixelSize: Config.bar.fontSize - 2
                                    bold: isToday
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: Qt.formatDate(clockRoot.now, "dddd, dd MMMM yyyy")
                        color: Config.colors.foreground

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Qt.formatTime(clockRoot.now, "HH:mm:ss")
                        color: Config.colors.cyan

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                            bold: true
                        }
                    }
                }
            }
        }
    }
}
