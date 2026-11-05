pragma Singleton

import QtQuick
import "."

QtObject {
    id: root

    readonly property color transparent: "transparent"
    readonly property color white: "#ffffff"
    readonly property color black: "#000000"
    readonly property color clearBlack: Qt.rgba(0, 0, 0, 0.4)

    // Status / Alert colors
    readonly property color error: (typeof Theme !== "undefined" && Theme.m3error) ? Theme.m3error : "#f87171"
    readonly property color danger: (typeof Theme !== "undefined" && Theme.m3error) ? Theme.m3error : "#f87171"
    readonly property color warning: "#f59e0b"
    readonly property color success: (typeof Theme !== "undefined" && Theme.m3success) ? Theme.m3success : "#4ade80"

    // Theme Accents
    readonly property color accent: Theme.accent
    readonly property color accentSoft: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)

    // Text hierarchy with solid contrast across dark/light themes
    readonly property color textPrimary: Theme.fg
    readonly property color textPrimaryBright: Theme.fg
    readonly property color textSecondary: (typeof Theme !== "undefined" && Theme.fgDim) ? Theme.fgDim : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.85)
    readonly property color textMuted: (typeof Theme !== "undefined" && Theme.fgDim) ? Theme.fgDim : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75)
    readonly property color textSubtle: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
    readonly property color textDisabled: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
    readonly property color textTertiary: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
    readonly property color textSoft: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.85)

    // Switch and Interactive controls
    readonly property color switchOff: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.30)
    readonly property color disabledControl: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35)
    readonly property color secondaryButton: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)
    readonly property color secondaryButtonHover: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22)
    readonly property color module: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.9)
    readonly property color moduleHover: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
    readonly property color prompt: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
    readonly property color input: Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.8)
    readonly property color inputBorder: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.20)

    readonly property int durationFast: 180
    readonly property int durationNormal: 300
    readonly property int durationSlow: 500

    readonly property color workspaceActiveBorder: Theme.accent
    readonly property color workspaceCellBorder: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
    readonly property color workspaceOverlay: Qt.rgba(0, 0, 0, 0.5)
    readonly property color workspaceCell: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.6)
    readonly property color overviewCard: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.8)
    readonly property color overviewBorder: Theme.outline
    readonly property color overviewInnerBorder: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.15)

    readonly property color panel: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
    readonly property color track: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.15)
    readonly property color cardFillHover: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
    readonly property color buttonFill: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.06)
    readonly property color buttonFillHover: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)
    readonly property color buttonFillPressed: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.18)
}
