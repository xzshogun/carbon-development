pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../Singletons"

/**
 * NotificationService Singleton
 * 
 * Central Notification Data Layer:
 *  - Maintains notifications list in memory with unread status, timestamps, and tab classification (All, Chat, System).
 *  - Tracks unread count for badges and DND state.
 *  - Categorizes notifications based on desktop entry, appName, hints, and summary.
 *  - Exposes actions to invoke freedesktop action keys (via Action.invoke() or D-Bus ActionInvoked) and dismiss (CloseNotification).
 *  - Signals incoming notifications for toast presentation (suppressed when DND is active).
 */
Singleton {
    id: root

    // Reference to Quickshell NotificationServer (bound from shell.qml)
    property var server: null

    // Do Not Disturb state (synced with Theme.dnd)
    property bool dnd: Theme.dnd
    property bool _loadingConfig: false
    property real _lastWriteTime: 0

    function persistDnd(state) {
        root._lastWriteTime = Date.now()
        Quickshell.execDetached(["python3", "-c",
            "import json, os\n" +
            "for p in [os.path.expanduser('~/.config/carbon/carbon-notifications.json'), os.path.expanduser('~/.config/hypr/carbon-notifications.json')]:\n" +
            "    try:\n" +
            "        d = json.load(open(p)) if os.path.exists(p) else {}\n" +
            "        d['dnd'] = " + (state ? "True" : "False") + "\n" +
            "        os.makedirs(os.path.dirname(p), exist_ok=True)\n" +
            "        with open(p, 'w') as f: json.dump(d, f, indent=2)\n" +
            "    except Exception:\n" +
            "        pass\n"
        ])
    }

    onDndChanged: {
        if (Theme.dnd !== root.dnd) {
            Theme.dnd = root.dnd
        }
        if (GlobalState.doNotDisturb !== root.dnd) {
            GlobalState.doNotDisturb = root.dnd
        }
        if (!root._loadingConfig) {
            root.persistDnd(root.dnd)
            Quickshell.execDetached(["sh", "-c",
                (root.dnd ? "touch /tmp/carbon-dnd.on; command -v swaync-client >/dev/null 2>&1 && swaync-client -dn || true" : "rm -f /tmp/carbon-dnd.on; command -v swaync-client >/dev/null 2>&1 && swaync-client -df || true")
            ])
        }
    }

    Connections {
        target: GlobalState
        function onDoNotDisturbChanged() {
            if (root.dnd !== GlobalState.doNotDisturb) {
                root.dnd = GlobalState.doNotDisturb
            }
        }
    }

    Connections {
        target: Theme
        function onDndChanged() {
            if (root.dnd !== Theme.dnd) {
                root.dnd = Theme.dnd
            }
        }
    }

    function toggleDnd() {
        root.dnd = !root.dnd
    }

    property bool notificationsEnabled: true
    property int toastTimeoutMs: 5000

    FileView {
        id: notifConfigFile
        path: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/carbon-notifications.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadNotifConfig()
        onFileChanged: {
            reload()
            root.reloadNotifConfig()
        }
    }

    FileView {
        id: hyprNotifConfigFile
        path: ((Quickshell.env("HOME") || "") + "/.config/hypr/carbon-notifications.json")
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadNotifConfig()
        onFileChanged: {
            reload()
            root.reloadNotifConfig()
        }
    }

    function reloadNotifConfig() {
        if (Date.now() - root._lastWriteTime < 1500)
            return
        try {
            notifConfigFile.reload()
            var txt = notifConfigFile.text()
            if (!txt || txt.trim().length === 0) {
                hyprNotifConfigFile.reload()
                txt = hyprNotifConfigFile.text()
            }
            if (!txt || txt.trim().length === 0) return
            var d = JSON.parse(txt)
            if (d.enabled !== undefined) root.notificationsEnabled = Boolean(d.enabled)
            if (d.dnd !== undefined && Boolean(d.dnd) !== root.dnd) {
                root._loadingConfig = true
                root.dnd = Boolean(d.dnd)
                Theme.dnd = root.dnd
                GlobalState.doNotDisturb = root.dnd
                root._loadingConfig = false
            }
            if (d.timeout !== undefined) root.toastTimeoutMs = Math.max(1000, (parseInt(d.timeout) || 5) * 1000)
        } catch (e) {}
    }

    // List of notification objects stored in memory:
    // [{
    //    id: string/number,
    //    rawNotification: var,
    //    appName: string,
    //    summary: string,
    //    body: string,
    //    appIcon: string,
    //    timeStr: string,
    //    timestamp: number,
    //    urgency: int (0: Low, 1: Normal, 2: Critical),
    //    category: string ("chat" | "system"),
    //    unread: bool,
    //    actions: array of { key: string, text: string, rawAction: var, invoke: function() },
    //    expireTimeout: int
    // }]
    property var list: []
    onListChanged: {
        GlobalState.notificationsList = root.list
    }
    property int unreadCount: 0

    // Signal emitted when a new notification arrives (carries item data for toast)
    signal notificationArrived(var item)

    // Signal emitted when a specific notification is dismissed or cleared
    signal notificationRemoved(var item)

    // Signal emitted when notifications are cleared
    signal allCleared()

    function classifyCategory(notif) {
        if (!notif) return "system"
        var appName = String(notif.appName || "").trim().toLowerCase()
        var desktopEntry = String(notif.desktopEntry || "").trim().toLowerCase()
        var summary = String(notif.summary || notif.title || "").trim().toLowerCase()
        var body = String(notif.body || "").trim().toLowerCase()
        var hints = notif.hints || {}
        var hintCat = String(hints["category"] || hints.category || "").trim().toLowerCase()

        // 1. Freedesktop specification category hint check
        if (hintCat.startsWith("im") || hintCat.startsWith("email") || hintCat.startsWith("call")) {
            return "chat"
        }
        if (hintCat.startsWith("device") || hintCat.startsWith("network") || hintCat.startsWith("sys") || hintCat.startsWith("transfer")) {
            return "system"
        }

        // 2. Comprehensive Chat, Messaging, Social & Mail Application identifiers
        var chatAppRegex = /discord|vesktop|webcord|armcord|ripcord|telegram|ayugram|kotatogram|nekogram|whatsapp|zapzap|whatsdesk|signal|slack|element|fluffychat|cinny|nheko|neochat|matrix|fractal|weechat|hexchat|irssi|gajim|dino|pidgin|session|briar|simplex|revolt|rocketchat|zulip|mattermost|thunderbird|betterbird|geary|mailspring|evolution|kmail|instagram|messenger|caprine|facebook|twitter|\bx\b|tweet|reddit|mastodon|bluesky|threads|linkedin|tiktok|snapchat|skype|teams|msteams|zoom|viber|line|wechat|qq|beeper|texts|ferdium|franz|rambox|kdeconnect|gsconnect|google-messages|messages|sms/i

        if (chatAppRegex.test(appName) || chatAppRegex.test(desktopEntry)) {
            return "chat"
        }

        // 3. Web Browser & Web App notifications (e.g. Instagram / WhatsApp Web / Telegram Web opened in Firefox/Chrome/Brave/Zen)
        var browserRegex = /firefox|zen|chrome|chromium|brave|edge|vivaldi|opera|webkit|epiphany|browser/i
        var isBrowser = browserRegex.test(appName) || browserRegex.test(desktopEntry)

        var chatKeywordRegex = /instagram|whatsapp|telegram|discord|messenger|slack|gmail|outlook|protonmail|reddit|twitter|\bx\b|mastodon|bluesky|threads|linkedin|signal|element|matrix|teams|skype|zoom|wechat|line|viber|tiktok|snapchat|inbox/i
        var conversationalRegex = /(?:new\s+)?(?:chat|message|dm|direct\s+message|mention|reply|reaction)|(?:sent\s+you|replied\s+to|mentioned\s+you|reacted\s+to|commented\s+on|incoming\s+call|missed\s+call|voice\s+message|audio\s+call|video\s+call)/i

        if (isBrowser || appName === "" || appName === "system") {
            if (chatKeywordRegex.test(summary) || chatKeywordRegex.test(body)) {
                return "chat"
            }
            if (conversationalRegex.test(summary) || conversationalRegex.test(body)) {
                return "chat"
            }
        } else {
            // Even for non-browser apps, check if summary or conversational keywords explicitly indicate chat/social
            if (chatKeywordRegex.test(summary) || conversationalRegex.test(summary)) {
                return "chat"
            }
        }

        // 4. Default: all other notifications belong to system
        return "system"
    }

    function reclassifyAll() {
        var updated = []
        for (var i = 0; i < root.list.length; i++) {
            var it = root.list[i]
            var newCat = root.classifyCategory(it.rawNotification || it)
            updated.push(Object.assign({}, it, { category: newCat }))
        }
        root.list = updated
    }

    function formatRelativeTime(ts) {
        var diffMs = Date.now() - ts
        var diffSec = Math.floor(diffMs / 1000)
        var diffMin = Math.floor(diffSec / 60)
        var diffHour = Math.floor(diffMin / 60)
        var diffDay = Math.floor(diffHour / 24)

        if (diffSec < 45) return "now"
        if (diffMin < 60) return diffMin + "m"
        if (diffHour < 24) return diffHour + "h"
        return diffDay + "d"
    }

    Timer {
        id: relativeTimeTimer
        interval: 30000
        running: root.list.length > 0
        repeat: true
        onTriggered: {
            var updated = []
            for (var i = 0; i < root.list.length; i++) {
                var it = root.list[i]
                var newTimeStr = root.formatRelativeTime(it.timestamp)
                if (newTimeStr !== it.timeStr) {
                    updated.push(Object.assign({}, it, { timeStr: newTimeStr }))
                } else {
                    updated.push(it)
                }
            }
            root.list = updated
        }
    }

    function cleanBody(raw) {
        if (!raw) return ""
        return String(raw).replace(/<[^>]*>/g, "").trim()
    }

    function addNotification(notif) {
        if (!notif) return
        console.log("[NotificationService] addNotification appName:", notif.appName, "summary:", notif.summary, "body:", notif.body, "desktopEntry:", notif.desktopEntry)

        // Extract actions safely
        var parsedActions = []
        if (notif.actions) {
            var actCount = notif.actions.length !== undefined ? notif.actions.length : (notif.actions.count || 0)
            for (var a = 0; a < actCount; a++) {
                var act = notif.actions[a]
                if (act) {
                    parsedActions.push({
                        key: act.identifier || act.key || ("action_" + a),
                        text: act.text || act.name || "Action",
                        rawAction: act,
                        invoke: function() {
                            if (this.rawAction && typeof this.rawAction.invoke === "function") {
                                try { this.rawAction.invoke() } catch(e) {}
                            }
                        }
                    })
                }
            }
        }

        var now = Date.now()
        var app = (notif.appName && notif.appName.length > 0)
            ? notif.appName
            : ((notif.desktopEntry && notif.desktopEntry.length > 0) ? notif.desktopEntry : "System")
        var sum = (notif.summary && notif.summary.length > 0)
            ? notif.summary
            : ((notif.title && notif.title.length > 0) ? notif.title : "Notification")
        var bod = root.cleanBody(notif.body)
        var iconStr = notif.appIcon || notif.image || ""

        var item = {
            id: notif.id !== undefined ? notif.id : ("notif_" + now + "_" + Math.floor(Math.random() * 10000)),
            rawNotification: notif,
            appName: app,
            summary: sum,
            body: bod,
            appIcon: iconStr,
            timeStr: root.formatRelativeTime(now),
            timestamp: now,
            urgency: notif.urgency !== undefined ? notif.urgency : 1,
            category: root.classifyCategory(notif),
            unread: true,
            actions: parsedActions,
            expireTimeout: notif.expireTimeout !== undefined ? notif.expireTimeout : -1
        }

        // Insert at beginning of list (newest first)
        var nextList = [item].concat(root.list)
        root.list = nextList
        root.recalculateUnread()

        // Emit signal for toast and live panels
        root.notificationArrived(item)
    }

    function recalculateUnread() {
        var count = 0
        for (var i = 0; i < root.list.length; i++) {
            if (root.list[i].unread) count++
        }
        root.unreadCount = count
    }

    function markRead(id) {
        var changed = false
        var next = []
        for (var i = 0; i < root.list.length; i++) {
            var it = root.list[i]
            if (it.id === id && it.unread) {
                var copy = Object.assign({}, it, { unread: false })
                next.push(copy)
                changed = true
            } else {
                next.push(it)
            }
        }
        if (changed) {
            root.list = next
            root.recalculateUnread()
        }
    }

    function markAllRead() {
        var next = []
        for (var i = 0; i < root.list.length; i++) {
            next.push(Object.assign({}, root.list[i], { unread: false }))
        }
        root.list = next
        root.recalculateUnread()
    }

    function dismiss(id) {
        var removedItem = null
        var next = []
        for (var i = 0; i < root.list.length; i++) {
            var it = root.list[i]
            if (it.id === id) {
                removedItem = it
                if (it.rawNotification && typeof it.rawNotification.dismiss === "function") {
                    try {
                        it.rawNotification.dismiss()
                    } catch(e) {
                        console.warn("[NotificationService] Error dismissing rawNotification:", e)
                    }
                }
            } else {
                next.push(it)
            }
        }
        root.list = next
        root.recalculateUnread()
        if (removedItem) {
            root.notificationRemoved(removedItem)
        }
    }

    function invokeAction(item, actionObj) {
        if (!item || !actionObj) return
        
        if (actionObj.rawAction && typeof actionObj.rawAction.invoke === "function") {
            try {
                actionObj.rawAction.invoke()
            } catch(e) {
                console.warn("[NotificationService] Error invoking rawAction:", e)
            }
        } else if (typeof actionObj.invoke === "function") {
            try {
                actionObj.invoke()
            } catch(e) {
                console.warn("[NotificationService] Error invoking actionObj:", e)
            }
        }

        root.markRead(item.id)
    }

    function clearCategory(cat) {
        var normalizedCat = String(cat || "all").toLowerCase()
        var toDismiss = []
        var remaining = []
        for (var i = 0; i < root.list.length; i++) {
            var it = root.list[i]
            if (normalizedCat === "all" || it.category === normalizedCat) {
                toDismiss.push(it)
            } else {
                remaining.push(it)
            }
        }

        for (var j = 0; j < toDismiss.length; j++) {
            var item = toDismiss[j]
            if (item.rawNotification && typeof item.rawNotification.dismiss === "function") {
                try {
                    item.rawNotification.dismiss()
                } catch(e) {}
            }
        }

        if (normalizedCat === "all" && root.server && root.server.trackedNotifications && root.server.trackedNotifications.values) {
            try {
                var serverList = [...root.server.trackedNotifications.values]
                for (var s = 0; s < serverList.length; s++) {
                    if (serverList[s] && typeof serverList[s].dismiss === "function") {
                        serverList[s].dismiss()
                    }
                }
            } catch(e) {}
        }

        root.list = remaining
        root.recalculateUnread()
        root.allCleared()
    }

    function clearAll() {
        root.clearCategory("all")
    }

    Component.onCompleted: {
        root.reloadNotifConfig()
        root.reclassifyAll()
    }
}
