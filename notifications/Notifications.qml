import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import Quickshell.Io
import QtQuick.Layouts

import "../config.js" as Config

Scope {
    id: root
    ListModel { id: history }
    property bool centerOpen: false

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
		time: Qt.formatDateTime(new Date(), "HH:mm"),
		appIcon: n.appIcon,
		image: n.image
	    })
	    n.tracked = true
	}
    }

    PushNotifications {
	notificationServer: server
    }

    NotificationCenter {
	historyModel: history
	centerOpen: root.centerOpen
    }
}
