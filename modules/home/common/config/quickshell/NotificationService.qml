pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property int lowTimeout: 5000
    readonly property int normalTimeout: 10000
    readonly property int criticalTimeout: 0

    readonly property var codePattern: /\b(\d{4,8})\b/

    property bool doNotDisturb: false

    property var popupIds: []

    property var arrivals: ({})

    readonly property var history: server.trackedNotifications.values.slice().reverse()
    readonly property var popups: history.filter(entry => root.popupIds.includes(entry.id))
    readonly property var groups: root.group(history)
    readonly property int count: history.length

    function applicationName(notification) {
        return notification.appName.length > 0 ? notification.appName : "Notifications";
    }

    function group(notifications) {
        const grouped = [];
        for (const notification of notifications) {
            const name = root.applicationName(notification);
            const existing = grouped.find(entry => entry.name === name);
            if (existing)
                existing.entries.push(notification);
            else
                grouped.push({
                    name: name,
                    entries: [notification]
                });
        }
        return grouped;
    }

    function remember(notification) {
        const arrivals = {};
        for (const entry of root.history) {
            if (root.arrivals[entry.id] !== undefined)
                arrivals[entry.id] = root.arrivals[entry.id];
        }
        arrivals[notification.id] = Date.now();
        root.arrivals = arrivals;
    }

    function relativeTime(notification, now) {
        const arrival = root.arrivals[notification.id];
        if (arrival === undefined)
            return "";

        const minutes = Math.floor((now.getTime() - arrival) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return `${minutes}m`;

        const hours = Math.floor(minutes / 60);
        return hours < 24 ? `${hours}h` : `${Math.floor(hours / 24)}d`;
    }

    function timeout(notification) {
        if (notification.expireTimeout > 0)
            return Math.round(notification.expireTimeout);

        switch (notification.urgency) {
        case NotificationUrgency.Low:
            return root.lowTimeout;
        case NotificationUrgency.Critical:
            return root.criticalTimeout;
        default:
            return root.normalTimeout;
        }
    }

    function code(notification) {
        const match = root.codePattern.exec(notification.body) || root.codePattern.exec(notification.summary);
        return match ? match[1] : "";
    }

    function copyCode(notification) {
        const value = root.code(notification);
        if (value.length > 0)
            Quickshell.execDetached(["wl-copy", "--", value]);
    }

    function defaultAction(notification) {
        return notification.actions.find(action => action.identifier === "default") || null;
    }

    function buttonActions(notification) {
        return notification.actions.filter(action => action.identifier !== "default");
    }

    function show(notification) {
        if (!root.popupIds.includes(notification.id))
            root.popupIds = [notification.id, ...root.popupIds];
    }

    function hide(notification) {
        root.popupIds = root.popupIds.filter(id => id !== notification.id);
    }

    function retire(notification) {
        root.hide(notification);
        if (notification.transient)
            notification.expire();
    }

    function dismiss(notification) {
        root.hide(notification);
        notification.dismiss();
    }

    function invoke(notification, action) {
        root.hide(notification);
        action.invoke();
    }

    function clearGroup(group) {
        for (const notification of group.entries)
            root.dismiss(notification);
    }

    function clear() {
        for (const notification of root.history)
            notification.dismiss();
        root.popupIds = [];
    }

    function toggleDoNotDisturb() {
        root.doNotDisturb = !root.doNotDisturb;
        if (root.doNotDisturb)
            root.popupIds = [];
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: false

        onNotification: notification => {
            notification.tracked = true;
            root.remember(notification);

            const silenced = root.doNotDisturb && notification.urgency !== NotificationUrgency.Critical;
            if (silenced) {
                if (notification.transient)
                    notification.expire();
                return;
            }

            if (!notification.lastGeneration)
                root.show(notification);
        }
    }
}
