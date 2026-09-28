pragma Singleton

import QtQuick
import Quickshell.Services.Notifications

QtObject {
    id: root

    enum Tier {
        Feedback,
        Passive,
        Active,
        TimeSensitive,
        Critical
    }

    readonly property int second: 1000
    readonly property int minute: root.second * 60
    readonly property int hour: root.minute * 60

    readonly property int maxPopups: 3
    readonly property int burstLimit: 3
    readonly property int burstWindow: root.minute
    readonly property int muteDuration: root.hour
    readonly property int historyLimit: 100

    readonly property string feedbackHint: "x-canonical-private-synchronous"
    readonly property string replaceHint: "x-dunst-stack-tag"
    readonly property string levelHint: "x-interruption-level"
    readonly property string urlHint: "x-default-url"

    readonly property var levels: ({
            "passive": NotificationPolicy.Tier.Passive,
            "active": NotificationPolicy.Tier.Active,
            "time-sensitive": NotificationPolicy.Tier.TimeSensitive
        })

    readonly property var codeSources: ["firefox"]
    readonly property var codeContext: /(code|otp|passcode|verification|verify|2fa|one[- ]time|kod|doğrulama|şifre)/i
    readonly property var codePattern: /(?:^|[^\d:.#\/-])(\d{4,8})(?![\d:.\/-])/

    function source(notification) {
        const identity = notification.desktopEntry.length > 0 ? notification.desktopEntry : notification.appName;
        return identity.length > 0 ? identity.toLowerCase() : "notifications";
    }

    function replaceKey(notification) {
        const key = notification.hints[root.feedbackHint] ?? notification.hints[root.replaceHint];
        return key === undefined ? "" : String(key);
    }

    function feedback(notification) {
        return notification.transient || notification.hints[root.feedbackHint] !== undefined;
    }

    function code(notification) {
        if (!root.codeSources.includes(root.source(notification)))
            return "";

        const text = `${notification.summary}\n${notification.body}`;
        if (!root.codeContext.test(text))
            return "";

        const match = root.codePattern.exec(text);
        return match ? match[1] : "";
    }

    function tier(notification) {
        if (notification.urgency === NotificationUrgency.Critical)
            return NotificationPolicy.Tier.Critical;
        if (root.feedback(notification))
            return NotificationPolicy.Tier.Feedback;

        const level = root.levels[notification.hints[root.levelHint]];
        if (level !== undefined)
            return level;
        if (root.code(notification).length > 0)
            return NotificationPolicy.Tier.TimeSensitive;
        if (notification.urgency === NotificationUrgency.Low)
            return NotificationPolicy.Tier.Passive;
        return NotificationPolicy.Tier.Active;
    }

    function breaksThrough(tier) {
        return tier === NotificationPolicy.Tier.Critical || tier === NotificationPolicy.Tier.Feedback;
    }

    function popupTimeout(notification, tier) {
        if (tier === NotificationPolicy.Tier.Critical)
            return 0;
        if (notification.expireTimeout > 0)
            return Math.round(notification.expireTimeout);

        switch (tier) {
        case NotificationPolicy.Tier.Feedback:
            return root.second * 3;
        case NotificationPolicy.Tier.TimeSensitive:
            return root.second * 12;
        default:
            return root.second * 8;
        }
    }

    function retention(notification, tier) {
        if (root.code(notification).length > 0)
            return root.minute * 10;

        switch (tier) {
        case NotificationPolicy.Tier.Critical:
            return 0;
        case NotificationPolicy.Tier.Passive:
            return root.hour;
        default:
            return root.hour * 12;
        }
    }

    function sound(notification, tier) {
        if (tier < NotificationPolicy.Tier.TimeSensitive || notification.hints["suppress-sound"] === true)
            return "";

        const file = notification.hints["sound-file"];
        return typeof file === "string" ? file : "";
    }

    function url(notification) {
        const value = notification.hints[root.urlHint];
        return typeof value === "string" ? value : "";
    }
}
