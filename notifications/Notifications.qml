import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import Quickshell.Io
import QtQuick.Layouts
import Quickshell.Hyprland

import "../config.js" as Config

Scope {
    id: root
    ListModel { id: history }
    property bool centerOpen: false

    // Hyprland runs with misc:focus_on_activate = false, so the wlr activate
    // request a Toplevel would send is ignored. Jump through the IPC
    // dispatcher instead. The config is Lua, hence the hl.dsp.focus form, and
    // Hyprland reports addresses without the 0x the dispatcher wants back.
    function focusApp(appName: string, desktopEntry: string): void {
	// A notification may name the app either way round, so match
	// "com.ktechpit.whatsie" against "whatsie" and the reverse.
	const keys = s => {
	    const l = (s || "").toLowerCase()
	    return l ? [l, l.split(".").pop()] : []
	}

	const wanted = keys(desktopEntry).concat(keys(appName))
	if (wanted.length === 0) return

	const matches = Hyprland.toplevels.values.filter(t => {
	    const cls = (t.wayland && t.wayland.appId)
		|| (t.lastIpcObject && t.lastIpcObject.class)
		|| ""
	    return keys(cls).some(k => wanted.indexOf(k) !== -1)
	})
	if (matches.length === 0) return

	// Several windows of one app: the urgent one raised the notification.
	const t = matches.find(t => t.urgent) || matches[0]
	Hyprland.dispatch('hl.dsp.focus{ window = "address:0x' + t.address + '" }')
    }

    // toplevels carry no class until the first refresh, and a click must not
    // be the thing that asks for it.
    Component.onCompleted: Hyprland.refreshToplevels()

    NotificationServer {
	id: server
	actionsSupported: true
	bodySupported: true
	imageSupported: true
	onNotification: n => {
	    history.insert(0, {
		summary: n.summary,
		body: n.body,
		appName: n.appName,
		urgency: n.urgency,
		time: Qt.formatDateTime(new Date(), "HH:mm:ss"),
		appIcon: n.appIcon,
		desktopEntry: n.desktopEntry,
		image: n.image
	    })
	    n.tracked = true
	}
    }

    PushNotifications {
	notificationServer: server
	focusApp: root.focusApp
    }

    NotificationCenter {
	historyModel: history
	centerOpen: root.centerOpen
	focusApp: root.focusApp
    }
}
