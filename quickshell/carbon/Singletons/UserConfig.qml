pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "."

Singleton {
    id: root

    property real islandHeight: 28
    property real islandWidth: 120
    property real islandTopMargin: 8
    property real islandPositionX: 50
    property real islandBackgroundOpacity: 96
    readonly property string userConfigPath: (Quickshell.env("HOME") || "") + "/.config/tide-island/userconfig.json"
    property string dynamicIslandPrimaryButton: "left"
    property string dynamicIslandPrimaryAction: "toggleControlCenter"
    property string dynamicIslandSecondaryButton: "right"
    property string dynamicIslandSecondaryAction: "toggleExpandedPlayer"
    property string hoverExpandAction: "expand"
    property bool islandAutoHideEnabled: false
    property int islandAutoHideDelayMs: 2000
    property string clockFormat: "24h"
    property string timeFontFamily: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Plus Jakarta Sans"
    property int bodyFontSize: 13
    property int titleFontSize: 14
    property int iconFontSize: 16
    property string heroFontFamily: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Plus Jakarta Sans"
    property string textFontFamily: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Plus Jakarta Sans"
    property string iconFontFamily: (Theme && Theme.fontIcon) ? Theme.fontIcon : "Material Symbols Rounded"
    property bool disableAutoExpandOnTrackChange: false
    property bool wallpaperCustomCommandEnabled: false
    property real islandExclusiveZone: 0
    property var dynamicIslandLeftSwipeItems: ["clock", "lyrics", "custom"]
    property string wallpaperPath: ""
    property string wallpaperLibraryPath: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
    property bool notchMode: false
    property bool showWorkspaceCapsule: true

    FileView {
        id: configFile
        path: root.userConfigPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: root.reloadConfig()
        onLoaded: root.reloadConfig()
    }

    function reloadConfig() {
        try {
            var txt = configFile.text().trim();
            if (txt.length > 0) {
                var d = JSON.parse(txt);
                if (d.islandPositionX !== undefined) root.islandPositionX = Number(d.islandPositionX);
                if (d.islandHeight !== undefined) root.islandHeight = Number(d.islandHeight);
                if (d.islandWidth !== undefined) root.islandWidth = Number(d.islandWidth);
                if (d.islandTopMargin !== undefined) root.islandTopMargin = Number(d.islandTopMargin);
                if (d.islandBackgroundOpacity !== undefined) root.islandBackgroundOpacity = Number(d.islandBackgroundOpacity);
                if (d.dynamicIslandPrimaryButton !== undefined) root.dynamicIslandPrimaryButton = String(d.dynamicIslandPrimaryButton);
                if (d.dynamicIslandPrimaryAction !== undefined) root.dynamicIslandPrimaryAction = String(d.dynamicIslandPrimaryAction);
                if (d.dynamicIslandSecondaryButton !== undefined) root.dynamicIslandSecondaryButton = String(d.dynamicIslandSecondaryButton);
                if (d.dynamicIslandSecondaryAction !== undefined) root.dynamicIslandSecondaryAction = String(d.dynamicIslandSecondaryAction);
                if (d.hoverExpandAction !== undefined) root.hoverExpandAction = String(d.hoverExpandAction);
                if (d.islandAutoHideEnabled !== undefined) root.islandAutoHideEnabled = Boolean(d.islandAutoHideEnabled);
                if (d.islandAutoHideDelayMs !== undefined) root.islandAutoHideDelayMs = Number(d.islandAutoHideDelayMs);
                if (d.clockFormat !== undefined) root.clockFormat = String(d.clockFormat);
                if (d.timeFontFamily !== undefined) root.timeFontFamily = String(d.timeFontFamily);
                if (d.heroFontFamily !== undefined) root.heroFontFamily = String(d.heroFontFamily);
                if (d.textFontFamily !== undefined) root.textFontFamily = String(d.textFontFamily);
                if (d.iconFontFamily !== undefined) root.iconFontFamily = String(d.iconFontFamily);
                if (d.bodyFontSize !== undefined) root.bodyFontSize = Number(d.bodyFontSize);
                if (d.titleFontSize !== undefined) root.titleFontSize = Number(d.titleFontSize);
                if (d.iconFontSize !== undefined) root.iconFontSize = Number(d.iconFontSize);
                if (d.disableAutoExpandOnTrackChange !== undefined) root.disableAutoExpandOnTrackChange = Boolean(d.disableAutoExpandOnTrackChange);
                if (d.wallpaperCustomCommandEnabled !== undefined) root.wallpaperCustomCommandEnabled = Boolean(d.wallpaperCustomCommandEnabled);
                if (d.islandExclusiveZone !== undefined) root.islandExclusiveZone = Number(d.islandExclusiveZone);
                if (d.dynamicIslandLeftSwipeItems !== undefined) root.dynamicIslandLeftSwipeItems = d.dynamicIslandLeftSwipeItems;
                if (d.wallpaperPath !== undefined) root.wallpaperPath = String(d.wallpaperPath);
                if (d.wallpaperLibraryPath !== undefined) root.wallpaperLibraryPath = String(d.wallpaperLibraryPath);
                if (d.notchMode !== undefined) root.notchMode = Boolean(d.notchMode);
                if (d.showWorkspaceCapsule !== undefined) root.showWorkspaceCapsule = Boolean(d.showWorkspaceCapsule);
                if (d.showWorkspaceOsd !== undefined) root.showWorkspaceCapsule = Boolean(d.showWorkspaceOsd);
            }
        } catch (e) {}
    }

    function mouseButton(btn) {
        if (btn === 1 || btn === "1" || btn === "left") return Qt.LeftButton;
        if (btn === 2 || btn === "2" || btn === "right") return Qt.RightButton;
        if (btn === 4 || btn === "4" || btn === "middle") return Qt.MiddleButton;
        return Qt.LeftButton;
    }

    function mouseButtonsMask(buttons) {
        var mask = 0;
        if (!buttons || !Array.isArray(buttons)) return Qt.LeftButton | Qt.RightButton;
        for (var i = 0; i < buttons.length; i++) {
            var b = buttons[i];
            if (b === 1 || b === "1" || b === "left") mask |= Qt.LeftButton;
            else if (b === 2 || b === "2" || b === "right") mask |= Qt.RightButton;
            else if (b === 4 || b === "4" || b === "middle") mask |= Qt.MiddleButton;
        }
        return mask > 0 ? (mask | Qt.LeftButton) : (Qt.LeftButton | Qt.RightButton);
    }
}
