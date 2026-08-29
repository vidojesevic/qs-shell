import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: mailRoot

    // Thunderbird writes per-folder counts to folderCache.json in its
    // profile. Only inbox-flagged folders are counted; set this false to
    // count every folder instead.
    property bool inboxOnly: true

    // nsMsgFolderFlags::Inbox
    readonly property int inboxFlag: 0x1000

    // { account, name, unread, total } per folder that holds mail.
    property var folders: []

    // Mtime of folderCache.json, in seconds. Thunderbird only rewrites it
    // now and then, so the reading can trail the mailbox.
    property int updatedAt: 0
    property int now: 0

    readonly property var countedFolders: folders.filter(
        folder => !mailRoot.inboxOnly || folder.inbox
    )

    readonly property int unread: countedFolders.reduce(
        (sum, folder) => sum + folder.unread, 0
    )

    text: unread > 0 ? "󰇮 " + unread : "󰇯"

    color: mailPopup.visible
        ? Config.text.active
        : (unread > 0 ? Config.text.normal : Config.text.dim)

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    function humanAge(seconds) {
        if (seconds < 90)
            return "just now"

        const minutes = Math.round(seconds / 60)

        if (minutes < 60)
            return minutes + " min ago"

        const hours = Math.round(minutes / 60)

        if (hours < 48)
            return hours + "h ago"

        return Math.round(hours / 24) + "d ago"
    }

    // First line is the mtime, the rest is the JSON body.
    Process {
        id: cacheProc

        command: [
            "sh", "-c",
            'set -- "$HOME"/.thunderbird/*.default-release/folderCache.json;'
            + ' [ -f "$1" ] || exit 1;'
            + ' date +%s; stat -c %Y "$1"; cat "$1"'
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const firstBreak = text.indexOf("\n")
                const secondBreak = text.indexOf("\n", firstBreak + 1)

                if (secondBreak < 0)
                    return

                mailRoot.now = parseInt(text.slice(0, firstBreak))
                mailRoot.updatedAt = parseInt(
                    text.slice(firstBreak + 1, secondBreak)
                )

                const cache = JSON.parse(text.slice(secondBreak + 1))
                const parsed = []

                for (const path in cache) {
                    const folder = cache[path]

                    // Servers and stale duplicates carry no mail.
                    if (!(folder.totalMsgs > 0))
                        continue

                    const parts = path.split("/")

                    parsed.push({
                        account: parts[parts.length - 2],

                        name: folder.onlineName
                            || parts[parts.length - 1].replace(".msf", ""),

                        inbox: (folder.flags & mailRoot.inboxFlag) !== 0,
                        unread: folder.totalUnreadMsgs > 0
                            ? folder.totalUnreadMsgs
                            : 0,
                        total: folder.totalMsgs
                    })
                }

                parsed.sort((a, b) => b.unread - a.unread)

                mailRoot.folders = parsed
            }
        }
    }

    Process {
        id: launchProc

        command: ["thunderbird"]
    }

    Timer {
        interval: 60000
        running: true
        repeat: true

        onTriggered: cacheProc.running = true
        Component.onCompleted: cacheProc.running = true
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                launchProc.running = true
                return
            }

            if (!mailPopup.visible)
                cacheProc.running = true

            mailPopup.visible = !mailPopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            mailPopup.visible = false
        }
    }

    PopupWindow {
        id: mailPopup

        anchor {
            item: mailRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 400
        implicitHeight: Math.min(
            150 + mailRoot.countedFolders.length * 34,
            420
        )

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
                        text: "Mail"
                        color: Config.text.active

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize + 2
                            bold: true
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text: mailRoot.unread + " unread"

                        color: mailRoot.unread > 0
                            ? Config.text.normal
                            : Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 3
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Config.colors.muted
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent

                        visible: folderList.count === 0
                        text: mailRoot.updatedAt > 0
                            ? "No mail folders"
                            : "Thunderbird profile not found"

                        color: Config.text.dim

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize - 1
                        }
                    }

                    ListView {
                        id: folderList

                        anchors.fill: parent

                        clip: true
                        spacing: 2

                        model: mailRoot.countedFolders

                        delegate: Rectangle {
                            required property var modelData

                            width: ListView.view.width
                            implicitHeight: 32

                            radius: 4

                            color: modelData.unread > 0
                                ? Qt.alpha(Config.colors.blue, 0.12)
                                : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: modelData.unread > 0 ? "󰇮" : "󰇯"

                                    color: modelData.unread > 0
                                        ? Config.text.active
                                        : Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 2
                                    }
                                }

                                Text {
                                    text: modelData.name

                                    color: modelData.unread > 0
                                        ? Config.text.active
                                        : Config.text.normal

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 2
                                        bold: modelData.unread > 0
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text: modelData.account
                                    elide: Text.ElideRight

                                    color: Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 5
                                    }
                                }

                                Text {
                                    text: modelData.unread + " / " + modelData.total

                                    color: modelData.unread > 0
                                        ? Config.text.active
                                        : Config.text.dim

                                    font {
                                        family: Config.bar.fontFamily
                                        pixelSize: Config.bar.fontSize - 4
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true

                    // Thunderbird flushes the cache on its own schedule, so
                    // say how old the reading is rather than implying live.
                    text: mailRoot.updatedAt > 0
                        ? "Thunderbird cache: "
                            + mailRoot.humanAge(mailRoot.now - mailRoot.updatedAt)
                        : ""

                    color: Config.text.dim

                    font {
                        family: Config.bar.fontFamily
                        pixelSize: Config.bar.fontSize - 5
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30

                    radius: 5

                    color: openMouse.containsMouse
                        ? Config.colors.muted
                        : "transparent"

                    border {
                        width: 1
                        color: Config.colors.muted
                    }

                    Text {
                        anchors.centerIn: parent

                        text: "󰇮 Open Thunderbird"
                        color: Config.text.normal

                        font {
                            family: Config.bar.fontFamily
                            pixelSize: Config.bar.fontSize
                            bold: true
                        }
                    }

                    MouseArea {
                        id: openMouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            mailPopup.visible = false
                            launchProc.running = true
                        }
                    }
                }
            }
        }
    }
}
