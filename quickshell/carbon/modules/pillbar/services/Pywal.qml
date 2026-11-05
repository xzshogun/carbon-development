pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick 6.10
import "../config" as QsConfig
import "." as QsServices
import "../../../Singletons" as CarbonSingletons

Singleton {
    id: root

    readonly property var theme: CarbonSingletons.Theme

    // Pywal color properties bound dynamically to Matugen Theme
    property color background: theme ? theme.m3background : "#0e0e12"
    property color foreground: theme ? theme.fg : "#e6e4f0"
    property color cursor: theme ? theme.fg : "#e6e4f0"

    // Individual color properties for easy access (mapped to Matugen)
    property color color0: theme ? theme.m3surfaceContainerLowest : "#070605"
    property color color1: theme ? theme.m3error : "#f97386"
    property color color2: theme ? theme.m3success : "#B5CCBA"
    property color color3: theme ? theme.warn : "#FF9F00"
    property color color4: theme ? theme.accent : "#ffb77a"
    property color color5: theme ? theme.m3secondary : "#bbc7db"
    property color color6: theme ? theme.m3tertiary : "#bbc7db"
    property color color7: theme ? theme.m3onSurface : "#e6e4f0"
    property color color8: theme ? theme.m3outline : "#75747f"
    property color color9: theme ? theme.m3error : "#f97386"
    property color color10: theme ? theme.m3success : "#B5CCBA"
    property color color11: theme ? theme.warn : "#FF9F00"
    property color color12: theme ? theme.accent : "#ffb77a"
    property color color13: theme ? theme.m3secondary : "#bbc7db"
    property color color14: theme ? theme.m3tertiary : "#bbc7db"
    property color color15: theme ? theme.m3onSurface : "#e6e4f0"

    // === Semantic Color Tokens ===
    // Use these instead of hardcoded colors for consistency

    // Primary accent color (derived from Matugen primary / accent)
    readonly property color primary: theme ? theme.accent : color4
    readonly property color primaryContainer: theme ? theme.m3primaryContainer : Qt.rgba(color4.r, color4.g, color4.b, 0.2)
    readonly property color onPrimary: theme ? theme.m3onPrimary : foreground

    // Secondary accent
    readonly property color secondary: theme ? theme.m3secondary : color5
    readonly property color secondaryContainer: theme ? theme.m3secondaryContainer : Qt.rgba(color5.r, color5.g, color5.b, 0.2)

    // Tertiary accent
    readonly property color tertiary: theme ? theme.m3tertiary : color6
    readonly property color tertiaryContainer: theme ? theme.m3tertiaryContainer : Qt.rgba(color6.r, color6.g, color6.b, 0.2)

    // Surface colors (solid Material 3-style containers from Matugen)
    readonly property color surface: theme ? theme.m3surface : Qt.lighter(background, 1.03)
    readonly property color surfaceDim: theme ? theme.m3surfaceDim : Qt.darker(background, 1.08)
    readonly property color surfaceBright: theme ? theme.m3surfaceBright : Qt.lighter(background, 1.12)
    readonly property color surfaceContainer: theme ? theme.m3surfaceContainer : Qt.lighter(background, 1.1)
    readonly property color surfaceContainerLow: theme ? theme.m3surfaceContainerLow : Qt.lighter(background, 1.06)
    readonly property color surfaceContainerHigh: theme ? theme.m3surfaceContainerHigh : Qt.lighter(background, 1.16)
    readonly property color surfaceContainerHighest: theme ? theme.m3surfaceContainerHighest : Qt.lighter(background, 1.22)
    readonly property color onSurface: theme ? theme.m3onSurface : foreground
    readonly property color onSurfaceVariant: theme ? theme.m3onSurfaceVariant : color8
    readonly property color onSurfaceMuted: theme ? theme.fgDim : Qt.rgba(foreground.r, foreground.g, foreground.b, 0.68)

    // Compatibility aliases kept for existing components now mapped to solid surfaces
    readonly property color glassLow: surfaceContainerLow
    readonly property color glassHigh: surfaceContainerHigh
    readonly property color glassHighest: surfaceContainerHighest
    readonly property color glassBorder: outlineVariant
    readonly property color glassBorderStrong: Qt.rgba(primary.r, primary.g, primary.b, 0.28)

    // Outline colors
    readonly property color outline: theme ? theme.m3outline : color8
    readonly property color outlineVariant: theme ? theme.m3outlineVariant : Qt.rgba(color8.r, color8.g, color8.b, 0.5)

    // State colors
    readonly property color success: theme ? theme.m3success : color2      // Green
    readonly property color onSuccess: theme ? theme.m3onSuccess : background
    readonly property color warning: theme ? theme.warn : color3            // Orange
    readonly property color onWarning: background
    readonly property color error: theme ? theme.m3error : color1          // Red
    readonly property color onError: theme ? theme.m3onError : foreground
    readonly property color info: primary

    // Interactive state overlays
    readonly property color stateLayerLight: Qt.rgba(foreground.r, foreground.g, foreground.b, 1)
    readonly property color stateLayerDark: Qt.rgba(background.r, background.g, background.b, 1)

    // Inverse colors (for contrast situations)
    readonly property color inverseSurface: foreground
    readonly property color inverseOnSurface: background
    readonly property color inversePrimary: Qt.lighter(primary, 1.5)

    // Scrim (overlay for modals)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.5)

    // Shadow color
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.3)
}
