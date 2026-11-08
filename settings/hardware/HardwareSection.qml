import QtQuick

// Loads this machine's page from local/ (gitignored), or Brief.qml when
// there is none. The modal reads header and hint from the
// loaded page.
Loader {
    id: section

    required property var form

    readonly property Component header: section.item?.header ?? null
    readonly property string hint: section.item?.hint ?? ""

    // The model name comes from a process, so it can still be empty right
    // after a reload. Stay blank until it is known.
    function load() {
        if (section.form.machine === "")
            return

        section.setSource(section.form.localPage ? "local/" + section.form.localPage : "Brief.qml",
            { form: section.form })
    }

    Component.onCompleted: section.load()

    Connections {
        target: section.form

        function onMachineChanged() {
            section.load()
        }
    }
}
