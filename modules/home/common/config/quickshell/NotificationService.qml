pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    readonly property int popupBatchInterval: 500

    property bool doNotDisturb: false

    property var popupIds: []
    property var pendingPopupIds: []
    property int overflow: 0

    property var records: ({})
    property var mutedUntil: ({})
    property var popupTimes: ({})
    property double now: Date.now()
    property int adopted: 0

    readonly property double started: Date.now()

    readonly property var live: server.trackedNotifications.values
    readonly property var history: root.live.slice().sort((a, b) => root.updated(b) - root.updated(a))
    readonly property var stored: root.history.filter(notification => NotificationPolicy.tier(notification) !== NotificationPolicy.Tier.Feedback)
    readonly property var popups: root.history.filter(notification => root.popupIds.includes(notification.id))
    readonly property var groups: root.group(root.stored)
    readonly property int count: root.stored.length
    readonly property int unseen: root.stored.filter(notification => root.badged(notification)).length

    function applicationName(notification) {
        return notification.appName.length > 0 ? notification.appName : "Notifications";
    }

    function record(notification) {
        return root.records[notification.id] ?? {
            updated: 0,
            repeats: 1,
            seen: true
        };
    }

    function updated(notification) {
        return root.record(notification).updated;
    }

    function muted(source) {
        return (root.mutedUntil[source] ?? 0) > root.now;
    }

    function badged(notification) {
        return NotificationPolicy.tier(notification) >= NotificationPolicy.Tier.Active && !root.record(notification).seen && !root.muted(NotificationPolicy.source(notification));
    }

    function group(notifications) {
        const grouped = [];
        for (const notification of notifications) {
            const key = NotificationPolicy.source(notification);
            let entry = grouped.find(candidate => candidate.key === key);
            if (!entry) {
                entry = {
                    key: key,
                    name: root.applicationName(notification),
                    entries: [],
                    critical: false,
                    latest: root.updated(notification)
                };
                grouped.push(entry);
            }
            entry.entries.push(notification);
            entry.critical = entry.critical || NotificationPolicy.tier(notification) === NotificationPolicy.Tier.Critical;
        }

        const rank = notification => {
            switch (NotificationPolicy.tier(notification)) {
            case NotificationPolicy.Tier.Critical:
                return 2;
            case NotificationPolicy.Tier.Passive:
                return 0;
            default:
                return 1;
            }
        };
        for (const entry of grouped)
            entry.entries.sort((a, b) => rank(b) - rank(a) || root.updated(b) - root.updated(a));
        return grouped.sort((a, b) => Number(b.critical) - Number(a.critical) || b.latest - a.latest);
    }

    function relativeTime(notification, now) {
        const time = root.updated(notification);
        if (time === 0)
            return "";

        const minutes = Math.floor((now.getTime() - time) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return `${minutes}m`;

        const hours = Math.floor(minutes / 60);
        return hours < 24 ? `${hours}h` : `${Math.floor(hours / 24)}d`;
    }

    function timeout(notification) {
        return NotificationPolicy.popupTimeout(notification, NotificationPolicy.tier(notification));
    }

    function copyCode(notification) {
        const value = NotificationPolicy.code(notification);
        if (value.length > 0)
            Quickshell.execDetached(["wl-copy", "--", value]);
    }

    function defaultAction(notification) {
        return notification.actions.find(action => action.identifier === "default") || null;
    }

    function buttonActions(notification) {
        return notification.actions.filter(action => action.identifier !== "default");
    }

    function activatable(notification) {
        return root.defaultAction(notification) !== null || NotificationPolicy.url(notification).length > 0;
    }

    function activate(notification) {
        const action = root.defaultAction(notification);
        if (action) {
            root.invoke(notification, action);
            return;
        }

        const url = NotificationPolicy.url(notification);
        if (url.length > 0) {
            Quickshell.execDetached(["xdg-open", url]);
            root.dismiss(notification);
        }
    }

    function predecessor(notification) {
        const source = NotificationPolicy.source(notification);
        const key = NotificationPolicy.replaceKey(notification);
        return root.live.find(candidate => {
            if (candidate === notification || NotificationPolicy.source(candidate) !== source)
                return false;
            if (key.length > 0)
                return NotificationPolicy.replaceKey(candidate) === key;
            return NotificationPolicy.replaceKey(candidate).length === 0 && candidate.summary === notification.summary && candidate.body === notification.body;
        }) ?? null;
    }

    function remember(notification, previous) {
        const prior = previous ? root.records[previous.id] : undefined;
        const unchanged = prior !== undefined && previous.summary === notification.summary && previous.body === notification.body;
        const liveIds = root.live.map(entry => entry.id);
        const records = {};
        for (const id of liveIds) {
            if (root.records[id] !== undefined)
                records[id] = root.records[id];
        }
        records[notification.id] = {
            updated: Date.now(),
            repeats: unchanged ? prior.repeats + 1 : 1,
            seen: unchanged ? prior.seen : false
        };
        root.records = records;
        return unchanged;
    }

    function ingest(notification) {
        const tier = NotificationPolicy.tier(notification);
        const previous = root.predecessor(notification);
        const visible = previous !== null && root.popupIds.includes(previous.id);
        const unchanged = root.remember(notification, previous);

        if (unchanged && visible)
            root.popupIds = root.popupIds.map(id => id === previous.id ? notification.id : id);
        else if (previous !== null)
            root.hide(previous);

        if (previous !== null)
            previous.expire();

        if (!unchanged && root.interrupts(notification, tier))
            root.show(notification);

        root.enforceLimit();
    }

    function interrupts(notification, tier) {
        if (NotificationPolicy.breaksThrough(tier))
            return true;
        if (tier === NotificationPolicy.Tier.Passive)
            return false;
        return !root.doNotDisturb && !root.muted(NotificationPolicy.source(notification));
    }

    function flushPopups() {
        const time = Date.now();
        const pending = root.pendingPopupIds.map(id => root.live.find(notification => notification.id === id)).filter(notification => notification !== undefined && !root.popupIds.includes(notification.id));
        root.pendingPopupIds = [];

        const times = {};
        for (const source in root.popupTimes) {
            const recent = root.popupTimes[source].filter(stamp => time - stamp < NotificationPolicy.burstWindow);
            if (recent.length > 0)
                times[source] = recent;
        }

        const accepted = [];
        let overflow = root.overflow;
        let sound = "";
        for (const notification of pending) {
            const tier = NotificationPolicy.tier(notification);
            const source = NotificationPolicy.source(notification);
            const recent = times[source] ?? [];
            if (!NotificationPolicy.breaksThrough(tier) && recent.length >= NotificationPolicy.burstLimit) {
                overflow += 1;
                continue;
            }
            times[source] = [...recent, time];
            accepted.push(notification.id);
            if (sound.length === 0)
                sound = NotificationPolicy.sound(notification, tier);
        }
        root.popupTimes = times;

        const pinned = id => {
            const notification = root.live.find(entry => entry.id === id);
            return notification !== undefined && NotificationPolicy.tier(notification) === NotificationPolicy.Tier.Critical;
        };
        const ids = [...accepted, ...root.popupIds];
        const room = Math.max(0, NotificationPolicy.maxPopups - ids.filter(pinned).length);
        const kept = ids.filter(id => !pinned(id)).slice(0, room);
        overflow += accepted.filter(id => !pinned(id) && !kept.includes(id)).length;

        root.popupIds = ids.filter(id => pinned(id) || kept.includes(id));
        root.overflow = overflow;

        if (sound.length > 0)
            Quickshell.execDetached(["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", "-af", "volume=2.0", sound]);
    }

    function show(notification) {
        if (root.popupIds.includes(notification.id) || root.pendingPopupIds.includes(notification.id))
            return;

        root.pendingPopupIds = [notification.id, ...root.pendingPopupIds];
        if (!popupBatchTimer.running)
            popupBatchTimer.start();
    }

    function hide(notification) {
        root.pendingPopupIds = root.pendingPopupIds.filter(id => id !== notification.id);
        root.popupIds = root.popupIds.filter(id => id !== notification.id);
        if (root.pendingPopupIds.length === 0)
            popupBatchTimer.stop();
        if (root.popupIds.length === 0)
            root.overflow = 0;
    }

    function retire(notification) {
        root.hide(notification);
        if (NotificationPolicy.tier(notification) === NotificationPolicy.Tier.Feedback)
            notification.expire();
    }

    function close(notification) {
        root.markSeen([notification]);
        root.retire(notification);
    }

    function dismiss(notification) {
        root.hide(notification);
        notification.dismiss();
    }

    function invoke(notification, action) {
        root.hide(notification);
        action.invoke();
    }

    function markSeen(notifications) {
        const records = Object.assign({}, root.records);
        for (const notification of notifications) {
            if (records[notification.id] !== undefined)
                records[notification.id] = Object.assign({}, records[notification.id], {
                    seen: true
                });
        }
        root.records = records;
    }

    function clearOverflow() {
        root.overflow = 0;
    }

    function mute(source) {
        const muted = Object.assign({}, root.mutedUntil);
        muted[source] = Date.now() + NotificationPolicy.muteDuration;
        root.mutedUntil = muted;
        root.now = Date.now();
        for (const notification of root.popups) {
            if (NotificationPolicy.source(notification) === source && !NotificationPolicy.breaksThrough(NotificationPolicy.tier(notification)))
                root.hide(notification);
        }
    }

    function unmute(source) {
        const muted = Object.assign({}, root.mutedUntil);
        delete muted[source];
        root.mutedUntil = muted;
    }

    function clearGroup(group) {
        for (const notification of group.entries)
            root.dismiss(notification);
    }

    function clear() {
        popupBatchTimer.stop();
        root.pendingPopupIds = [];
        for (const notification of root.stored)
            notification.dismiss();
        root.popupIds = root.popupIds.filter(id => root.live.some(notification => notification.id === id));
        root.overflow = 0;
    }

    function toggleDoNotDisturb() {
        root.doNotDisturb = !root.doNotDisturb;
        if (!root.doNotDisturb)
            return;

        for (const notification of root.popups) {
            if (!NotificationPolicy.breaksThrough(NotificationPolicy.tier(notification)))
                root.hide(notification);
        }
    }

    function enforceLimit() {
        const excess = root.stored.length - NotificationPolicy.historyLimit;
        if (excess <= 0)
            return;

        const candidates = root.stored.slice().sort((a, b) => NotificationPolicy.tier(a) - NotificationPolicy.tier(b) || root.updated(a) - root.updated(b));
        for (const notification of candidates.slice(0, excess)) {
            root.hide(notification);
            notification.expire();
        }
    }

    function sweep() {
        root.now = Date.now();
        for (const notification of root.stored.slice()) {
            const limit = NotificationPolicy.retention(notification, NotificationPolicy.tier(notification));
            if (limit > 0 && root.now - root.updated(notification) > limit && !root.popupIds.includes(notification.id))
                notification.expire();
        }

        const muted = {};
        for (const source in root.mutedUntil) {
            if (root.mutedUntil[source] > root.now)
                muted[source] = root.mutedUntil[source];
        }
        root.mutedUntil = muted;
    }

    function adopt(notification) {
        if (root.records[notification.id] !== undefined)
            return;

        const records = Object.assign({}, root.records);
        records[notification.id] = {
            updated: root.started + root.adopted,
            repeats: 1,
            seen: true
        };
        root.adopted += 1;
        root.records = records;
    }

    Component.onCompleted: {
        for (const notification of root.live)
            root.adopt(notification);
    }

    Timer {
        id: popupBatchTimer

        interval: root.popupBatchInterval
        onTriggered: root.flushPopups()
    }

    Timer {
        interval: NotificationPolicy.minute
        running: true
        repeat: true
        onTriggered: root.sweep()
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
            if (notification.lastGeneration)
                root.adopt(notification);
            else
                root.ingest(notification);
        }
    }
}
