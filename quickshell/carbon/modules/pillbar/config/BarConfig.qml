import QtQuick 6.10

QtObject {
    readonly property var workspaces: QtObject {
        // Workspace count
        property int count: 8
        
        // Modern indicator style
        property bool showOccupiedIndicator: true
        property bool showActiveIndicator: true
        
        // Unified pill capsule configuration
        property bool unifiedPill: true
        property int pillPadding: 8
        
        // Smooth animations
        property bool enableClickAnimation: true
        property bool enableSwitchAnimation: true
        property int animationDuration: 200
        
        // Pywal-based colors
        property string activeColor: "#BE5052"
        property string occupiedColor: "#9A847D"
        property string emptyColor: "#a3a0a1"
        property string activeTextColor: "#e9e5e6"
        property string inactiveTextColor: "#a3a0a1"
        property string backgroundColor: "#070605"
        property string pillBackgroundColor: "#0a0908"
        
        // Modern sizing
        property int workspaceSize: 18
        property int spacing: 6
        property int cornerRadius: 10
        property int indicatorSize: 4
    }
    
    // Continuous Pill Mode bar design
    readonly property int height: 38                // Floating pill capsule bar height
    readonly property int padding: 4               // Padding around content
    readonly property real backgroundOpacity: 0.92  // Solid surface capsule
    
    // Pill styling
    readonly property var islands: QtObject {
        property int borderRadius: 19              // Full capsule radius (height / 2)
        property real surfaceOpacity: 0.92          // Solid surface
        property real borderOpacity: 0.18          // Subtle border glow
        property int spacing: 6                    // Gap between internal elements
    }
}
