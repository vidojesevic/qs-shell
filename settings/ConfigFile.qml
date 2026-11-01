import Quickshell
import Quickshell.Io
import QtQuick

// Writes values back to config.js. Only the changed values are replaced, so
// comments, order and formatting stay. The FileView in shell.qml sees the
// write and reloads the shell.
Scope {
    id: configFile

    // Write error or failed reload. The reason string is for the status line.
    signal failed(string reason)

    property bool saving: false

    // changes maps a key path to a new value:
    // { "notifications.timeout": 3000, "widgets.weather.city": "Paris" }
    // Returns "" when the file is written, else the reason it was not.
    function save(changes) {
        let src = file.text()

        try {
            for (const key in changes) {
                const range = configFile.valueRange(src, key)
                src = src.slice(0, range.start)
                    + JSON.stringify(changes[key])
                    + src.slice(range.end)
            }
        } catch (reason) {
            return reason
        }

        configFile.saving = true
        file.setText(src)
        return ""
    }

    // Start and end of the value for a key path like "widgets.weather.city".
    function valueRange(src, key) {
        const names = key.split(".")
        const top = new RegExp("^const\\s+" + names[0] + "\\s*=\\s*", "m").exec(src)
        if (!top)
            throw "Unknown key: " + key

        let i = top.index + top[0].length

        for (const name of names.slice(1)) {
            if (src[i] !== "{")
                throw "Unknown key: " + key

            i = configFile.findKey(src, i + 1, name)
            if (i < 0)
                throw "Unknown key: " + key
        }

        if (src[i] === "{" || src[i] === "[")
            throw key + " is not a single value"

        // The value ends at a comma, a closing bracket, a line end or a comment.
        let end = i
        while (end < src.length && !/[,}\]\n]/.test(src[end])
               && !src.startsWith("//", end) && !src.startsWith("/*", end))
            end = configFile.skip(src, end)

        while (/\s/.test(src[end - 1]))
            end--

        return { start: i, end: end }
    }

    // Index of the value for key name in the object body that starts at i,
    // or -1. Only keys at this depth count; nested objects, strings and
    // comments are skipped.
    function findKey(src, i, name) {
        const keyPattern = /([A-Za-z_$][\w$]*)\s*:\s*/y
        let depth = 0

        while (i < src.length) {
            const c = src[i]

            if (c === "{" || c === "[") {
                depth++
            } else if (c === "}" || c === "]") {
                if (depth === 0)
                    return -1
                depth--
            } else if (depth === 0 && !/[\w$.]/.test(src[i - 1])) {
                keyPattern.lastIndex = i
                const match = keyPattern.exec(src)
                if (match && match[1] === name)
                    return i + match[0].length
            }

            i = configFile.skip(src, i)
        }

        return -1
    }

    // Index after the string or comment that starts at i, else i + 1.
    function skip(src, i) {
        const c = src[i]

        if (c === '"' || c === "'" || c === "`") {
            let j = i + 1
            while (j < src.length && src[j] !== c)
                j += src[j] === "\\" ? 2 : 1
            return j + 1
        }

        if (src.startsWith("//", i)) {
            const j = src.indexOf("\n", i)
            return j < 0 ? src.length : j
        }

        if (src.startsWith("/*", i))
            return src.indexOf("*/", i + 2) + 2

        return i + 1
    }

    FileView {
        id: file

        path: Quickshell.shellDir + "/config.js"
        blockLoading: true

        onSaveFailed: error => {
            configFile.saving = false
            configFile.failed(FileViewError.toString(error))
        }
    }

    // On success the shell reloads and this object is gone. On failure the
    // old shell stays and gets the reason.
    Connections {
        target: Quickshell
        enabled: configFile.saving

        function onReloadFailed(errorString) {
            configFile.saving = false
            configFile.failed(errorString)
        }
    }
}
