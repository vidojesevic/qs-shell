import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "../../config.js" as Config

Text {
    id: dockerRoot

    property int runningCount: 0
    property int totalCount: 0

    // [{ project, containers: [{ id, name, service, state, status, dir, file }] }]
    property var groups: []

    // Project name -> collapsed, and container id -> action in flight.
    property var collapsed: ({})
    property var busy: ({})

    property var queue: []

    // Serialized last result, so an unchanged poll does not rebuild the list.
    property string lastSnapshot: ""

    text: "󰡨 " + runningCount
    color: dockerPopup.visible
        ? Config.text.active
        : (runningCount > 0 ? Config.text.normal : Config.text.dim)

    leftPadding: Config.bar.padding
    rightPadding: Config.bar.padding

    font {
        family: Config.bar.fontFamily
        pixelSize: Config.bar.fontSize
        bold: true
    }

    function isCollapsed(project) {
        return collapsed[project] === true
    }

    function toggleGroup(project) {
        const next = Object.assign({}, collapsed)

        next[project] = !isCollapsed(project)
        collapsed = next
    }

    function isBusy(id) {
        return busy[id] === true
    }

    function enqueue(id, command) {
        const nextBusy = Object.assign({}, busy)

        nextBusy[id] = true
        busy = nextBusy

        queue = queue.concat([{ id: id, command: command }])

        if (!actionProc.running)
            runNext()
    }

    function runNext() {
        if (queue.length === 0)
            return

        const job = queue[0]

        queue = queue.slice(1)

        actionProc.jobId = job.id
        actionProc.command = job.command
        actionProc.running = true
    }

    function start(container) {
        enqueue(container.id, ["docker", "start", container.id])
    }

    function stop(container) {
        enqueue(container.id, ["docker", "stop", container.id])
    }

    /*
     * Compose containers get a real rebuild from their own compose file.
     * Anything else can only be restarted.
     */
    function rebuild(container) {
        if (container.file.length === 0) {
            enqueue(container.id, ["docker", "restart", container.id])
            return
        }

        enqueue(container.id, [
            "docker", "compose",
            "-f", container.file,
            "--project-directory", container.dir,
            "up", "-d", "--build", container.service
        ])
    }

    // Any container of a compose project carries the file to drive it with.
    function composeFile(group) {
        for (let i = 0; i < group.containers.length; i++) {
            if (group.containers[i].file.length > 0)
                return group.containers[i]
        }

        return null
    }

    function composeRun(group, args) {
        const source = composeFile(group)

        if (!source)
            return

        enqueue("compose:" + group.project, [
            "docker", "compose",
            "-f", source.file,
            "--project-directory", source.dir
        ].concat(args))
    }

    function composeUp(group) {
        composeRun(group, ["up", "-d"])
    }

    function composeDown(group) {
        composeRun(group, ["down"])
    }

    function composeBuild(group) {
        composeRun(group, ["up", "-d", "--build"])
    }

    Process {
        id: actionProc

        property string jobId: ""

        onExited: {
            const next = Object.assign({}, dockerRoot.busy)

            delete next[actionProc.jobId]
            dockerRoot.busy = next

            listProc.running = true
            dockerRoot.runNext()
        }
    }

    Process {
        id: listProc

        command: [
            "docker", "ps", "-a", "--format",
            "{{.ID}}|{{.Names}}|{{.State}}|{{.Status}}"
            + "|{{.Label \"com.docker.compose.project\"}}"
            + "|{{.Label \"com.docker.compose.service\"}}"
            + "|{{.Label \"com.docker.compose.project.working_dir\"}}"
            + "|{{.Label \"com.docker.compose.project.config_files\"}}"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n")
                const byProject = {}

                let running = 0
                let total = 0

                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].length === 0)
                        continue

                    const parts = lines[i].split("|")
                    const project = parts[4] || "Standalone"

                    const container = {
                        id: parts[0],
                        name: parts[1],
                        service: parts[5] || parts[1],
                        state: parts[2],
                        status: parts[3],
                        dir: parts[6] || "",
                        file: (parts[7] || "").split(",")[0]
                    }

                    total++

                    if (container.state === "running")
                        running++

                    if (!byProject[project])
                        byProject[project] = []

                    byProject[project].push(container)
                }

                const names = Object.keys(byProject).sort()
                const result = []

                for (let n = 0; n < names.length; n++) {
                    if (names[n] === "Standalone")
                        continue

                    result.push({
                        project: names[n],
                        containers: byProject[names[n]]
                    })
                }

                if (byProject["Standalone"]) {
                    result.push({
                        project: "Standalone",
                        containers: byProject["Standalone"]
                    })
                }

                dockerRoot.runningCount = running
                dockerRoot.totalCount = total

                const snapshot = JSON.stringify(result)

                if (snapshot === dockerRoot.lastSnapshot)
                    return

                dockerRoot.lastSnapshot = snapshot
                dockerRoot.groups = result
            }
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!listProc.running)
                listProc.running = true
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!dockerPopup.visible)
                listProc.running = true

            dockerPopup.visible = !dockerPopup.visible
        }
    }

    // Close if inactive
    Timer {
        id: popupCloseTimer

        interval: 5000
        repeat: false

        onTriggered: {
            dockerPopup.visible = false
        }
    }

    PopupWindow {
        id: dockerPopup

        anchor {
            item: dockerRoot

            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left

            margins.top: 32
            margins.right: 16
        }

        implicitWidth: 560
        implicitHeight: 420

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
                        text: "Docker"
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
                        text: dockerRoot.runningCount + " / "
                            + dockerRoot.totalCount + " running"

                        color: Config.text.dim

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

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    clip: true

                    contentWidth: width
                    contentHeight: groupColumn.implicitHeight

                    ColumnLayout {
                        id: groupColumn

                        width: parent.width
                        spacing: 6

                        Text {
                            Layout.fillWidth: true

                            visible: dockerRoot.groups.length === 0

                            text: "No containers"
                            color: Config.text.dim

                            font {
                                family: Config.bar.fontFamily
                                pixelSize: Config.bar.fontSize - 1
                            }
                        }

                        Repeater {
                            model: dockerRoot.groups

                            delegate: ColumnLayout {
                                required property var modelData

                                readonly property bool folded:
                                    dockerRoot.isCollapsed(modelData.project)

                                readonly property bool hasCompose:
                                    dockerRoot.composeFile(modelData) !== null

                                readonly property bool composeWorking:
                                    dockerRoot.isBusy("compose:" + modelData.project)

                                readonly property int upCount: {
                                    let up = 0

                                    for (let i = 0; i < modelData.containers.length; i++) {
                                        if (modelData.containers[i].state === "running")
                                            up++
                                    }

                                    return up
                                }

                                Layout.fillWidth: true
                                spacing: 4

                                // Project header
                                Rectangle {
                                    Layout.fillWidth: true

                                    implicitHeight: 28
                                    radius: 5

                                    color: groupMouse.containsMouse
                                        ? Config.colors.muted
                                        : "transparent"

                                    RowLayout {
                                        // Above the header's own click area.
                                        z: 1

                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        Text {
                                            text: folded ? "" : ""
                                            color: Config.text.dim

                                            font {
                                                family: Config.bar.fontFamily
                                                pixelSize: Config.bar.fontSize - 3
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true

                                            text: modelData.project
                                            elide: Text.ElideRight

                                            color: upCount > 0
                                                ? Config.text.active
                                                : Config.text.normal

                                            font {
                                                family: Config.bar.fontFamily
                                                pixelSize: Config.bar.fontSize - 1
                                                bold: true
                                            }
                                        }

                                        Text {
                                            text: upCount + "/"
                                                + modelData.containers.length

                                            color: Config.text.dim

                                            font {
                                                family: Config.bar.fontFamily
                                                pixelSize: Config.bar.fontSize - 3
                                            }
                                        }

                                        // Spinner while a project command runs.
                                        Text {
                                            visible: composeWorking

                                            text: "󰔟"
                                            color: Config.text.dim

                                            font {
                                                family: Config.bar.fontFamily
                                                pixelSize: Config.bar.fontSize - 1
                                            }

                                            RotationAnimation on rotation {
                                                running: composeWorking
                                                loops: Animation.Infinite

                                                from: 0
                                                to: 360
                                                duration: 900
                                            }
                                        }

                                        Text {
                                            visible: hasCompose && !composeWorking

                                            text: "up"
                                            color: upMouse.containsMouse
                                                ? Config.text.active
                                                : Config.text.dim

                                            font {
                                                family: Config.bar.fontFamily
                                                pixelSize: Config.bar.fontSize - 3
                                                bold: true
                                            }

                                            MouseArea {
                                                id: upMouse

                                                anchors.fill: parent
                                                anchors.margins: -4

                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    popupCloseTimer.restart()
                                                    dockerRoot.composeUp(modelData)
                                                }
                                            }
                                        }

                                        Text {
                                            visible: hasCompose && !composeWorking

                                            text: "down"
                                            color: downMouse.containsMouse
                                                ? Config.text.critical
                                                : Config.text.dim

                                            font {
                                                family: Config.bar.fontFamily
                                                pixelSize: Config.bar.fontSize - 3
                                                bold: true
                                            }

                                            MouseArea {
                                                id: downMouse

                                                anchors.fill: parent
                                                anchors.margins: -4

                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    popupCloseTimer.restart()
                                                    dockerRoot.composeDown(modelData)
                                                }
                                            }
                                        }

                                        Text {
                                            visible: hasCompose && !composeWorking

                                            text: "build"
                                            color: buildMouse.containsMouse
                                                ? Config.text.active
                                                : Config.text.dim

                                            font {
                                                family: Config.bar.fontFamily
                                                pixelSize: Config.bar.fontSize - 3
                                                bold: true
                                            }

                                            MouseArea {
                                                id: buildMouse

                                                anchors.fill: parent
                                                anchors.margins: -4

                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                onClicked: {
                                                    popupCloseTimer.restart()
                                                    dockerRoot.composeBuild(modelData)
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: groupMouse

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            popupCloseTimer.restart()
                                            dockerRoot.toggleGroup(modelData.project)
                                        }
                                    }
                                }

                                Repeater {
                                    model: folded ? [] : modelData.containers

                                    delegate: Rectangle {
                                        id: containerRow

                                        required property var modelData

                                        readonly property bool up:
                                            containerRow.modelData.state === "running"

                                        readonly property bool working:
                                            dockerRoot.isBusy(containerRow.modelData.id)

                                        Layout.fillWidth: true
                                        Layout.leftMargin: 18

                                        implicitHeight: 32
                                        radius: 5

                                        color: up
                                            ? Qt.alpha(Config.colors.blue, 0.14)
                                            : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 8

                                            Rectangle {
                                                implicitWidth: 8
                                                implicitHeight: 8
                                                radius: 4

                                                color: up
                                                    ? Config.colors.cyan
                                                    : Config.colors.muted
                                            }

                                            Text {
                                                Layout.fillWidth: true

                                                text: containerRow.modelData.service
                                                elide: Text.ElideRight

                                                color: up
                                                    ? Config.text.normal
                                                    : Config.text.dim

                                                font {
                                                    family: Config.bar.fontFamily
                                                    pixelSize: Config.bar.fontSize - 2
                                                }
                                            }

                                            Text {
                                                text: containerRow.modelData.status
                                                elide: Text.ElideRight

                                                Layout.maximumWidth: 150

                                                color: Config.text.dim

                                                font {
                                                    family: Config.bar.fontFamily
                                                    pixelSize: Config.bar.fontSize - 4
                                                }
                                            }

                                            // Spinner while a command runs.
                                            Text {
                                                visible: working

                                                text: "󰔟"
                                                color: Config.text.dim

                                                font {
                                                    family: Config.bar.fontFamily
                                                    pixelSize: Config.bar.fontSize - 1
                                                }

                                                RotationAnimation on rotation {
                                                    running: working
                                                    loops: Animation.Infinite

                                                    from: 0
                                                    to: 360
                                                    duration: 900
                                                }
                                            }

                                            Text {
                                                visible: !working && !up

                                                text: "󰐊"
                                                color: playMouse.containsMouse
                                                    ? Config.text.active
                                                    : Config.text.dim

                                                font {
                                                    family: Config.bar.fontFamily
                                                    pixelSize: Config.bar.fontSize
                                                }

                                                MouseArea {
                                                    id: playMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor

                                                    onClicked: {
                                                        popupCloseTimer.restart()
                                                        dockerRoot.start(containerRow.modelData)
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: !working && up

                                                text: "󰓛"
                                                color: stopMouse.containsMouse
                                                    ? Config.text.critical
                                                    : Config.text.dim

                                                font {
                                                    family: Config.bar.fontFamily
                                                    pixelSize: Config.bar.fontSize
                                                }

                                                MouseArea {
                                                    id: stopMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor

                                                    onClicked: {
                                                        popupCloseTimer.restart()
                                                        dockerRoot.stop(containerRow.modelData)
                                                    }
                                                }
                                            }

                                            Text {
                                                visible: !working

                                                text: "󰑓"
                                                color: rebuildMouse.containsMouse
                                                    ? Config.text.active
                                                    : Config.text.dim

                                                font {
                                                    family: Config.bar.fontFamily
                                                    pixelSize: Config.bar.fontSize
                                                }

                                                MouseArea {
                                                    id: rebuildMouse

                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor

                                                    onClicked: {
                                                        popupCloseTimer.restart()
                                                        dockerRoot.rebuild(containerRow.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
