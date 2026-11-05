import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    width: parent ? parent.width : (Screen.width || 1366)
    height: parent ? parent.height : (Screen.height || 768)

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || (root.home + "/.config/carbon")
    readonly property string symlink: root.configDir + "/current_wallpaper"
    readonly property string stateFile: root.configDir + "/current_wallpaper_path"
    readonly property string modeConfigFile: root.configDir + "/carbon-bar-mode.json"

    property string currentWpPath: ""
    property string pendingNewPath: ""
    property string activeBuffer: "A" // "A" or "B"
    property bool isAnimating: false

    // Animation settings (loaded from carbon-bar-mode.json)
    property string animType: "cinematic" // "cinematic", "crossfade", "slide-left", "slide-right", "zoom-out"
    property int animDuration: 800

    function getWallpaperType(filePath) {
        if (!filePath) return "image"
        const p = filePath.toLowerCase()
        if (p.includes("carbon-live") || p.includes("carbon-atom") || p.includes("carbon-lewis") || p.includes("carbon-quantum")) return "carbon-live"
        if (p.endsWith(".mp4") || p.endsWith(".m4v") || p.endsWith(".webm") || p.endsWith(".mkv")) return "video"
        if (p.endsWith(".gif")) return "gif"
        return "image"
    }

    readonly property string currentType: getWallpaperType(root.currentWpPath)

    function resolveWpUrl(filePath) {
        if (!filePath) return ""
        var clean = filePath.trim()
        if (clean.startsWith("file://")) clean = clean.substring(7)
        return "file://" + clean
    }

    /* ── Config Watcher (carbon-bar-mode.json) ─────────────────────── */
    FileView {
        id: modeConfigWatcher
        path: root.modeConfigFile
        watchChanges: true
        printErrors: false
        onFileChanged: {
            modeConfigWatcher.reload()
        }
        onLoaded: root.loadConfig()
    }

    function loadConfig() {
        try {
            const raw = modeConfigWatcher.text().trim()
            if (!raw) return
            const cfg = JSON.parse(raw)
            if (cfg.wallpaperAnimation) {
                root.animType = cfg.wallpaperAnimation
            }
            if (cfg.wallpaperDuration && cfg.wallpaperDuration > 100) {
                root.animDuration = cfg.wallpaperDuration
            }
        } catch (e) {}
    }

    readonly property string hyprStateFile: root.home + "/.config/hypr/current_wallpaper_path"

    /* ── State Watcher (current_wallpaper_path in carbon and hypr) ─── */
    FileView {
        id: stateWatcher
        path: root.stateFile
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: {
            reload()
            const p = stateWatcher.text().trim()
            if (p && p !== root.currentWpPath && p !== root.pendingNewPath) {
                root.applyNewWallpaper(p)
            }
        }
        onLoaded: {
            const p = stateWatcher.text().trim()
            if (p && !root.currentWpPath) {
                root.initWallpaper(p)
            } else if (p && p !== root.currentWpPath && p !== root.pendingNewPath) {
                root.applyNewWallpaper(p)
            }
        }
    }

    FileView {
        id: hyprStateWatcher
        path: root.hyprStateFile
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: {
            reload()
            const p = hyprStateWatcher.text().trim()
            if (p && p !== root.currentWpPath && p !== root.pendingNewPath) {
                root.applyNewWallpaper(p)
            }
        }
        onLoaded: {
            const p = hyprStateWatcher.text().trim()
            if (p && !root.currentWpPath) {
                root.initWallpaper(p)
            } else if (p && p !== root.currentWpPath && p !== root.pendingNewPath) {
                root.applyNewWallpaper(p)
            }
        }
    }

    /* Fallback polling in case external tools change symlink directly */
    Process {
        id: wpReader
        command: ["sh", "-c", "readlink -f \"" + root.configDir + "/current_wallpaper\" 2>/dev/null || readlink -f \"$HOME/.config/hypr/current_wallpaper\" 2>/dev/null || cat \"" + root.configDir + "/current_wallpaper_path\" 2>/dev/null || cat \"$HOME/.config/hypr/current_wallpaper_path\" 2>/dev/null || echo \"\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = wpReader.stdout.text.toString().trim()
                if (p && p !== root.currentWpPath && p !== root.pendingNewPath) {
                    console.log("[WallpaperMod] wpReader detected new wallpaper:", p)
                    root.applyNewWallpaper(p)
                }
            }
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            if (!wpReader.running && !root.isAnimating) {
                wpReader.running = true
            }
        }
    }

    /* ── Initial Load ─────────────────────────────────────────────── */
    function initWallpaper(path) {
        if (!path) return
        console.log("[WallpaperMod] initWallpaper:", path)
        root.currentWpPath = path
        root.pendingNewPath = ""
        root.isAnimating = false
        root.activeBuffer = "A"
        const type = getWallpaperType(path)

        if (type === "image") {
            bufA.source = resolveWpUrl(path)
            bufA.opacity = 1.0
            bufA.scale = 1.0
            bufA.x = 0
            bufA.visible = true
            bufB.visible = false
            imageContainer.opacity = 1.0
            imageContainer.visible = true
        } else if (type === "video") {
            root.startVideo(path)
        } else if (type === "gif") {
            gifPlayer.source = "file://" + path
            gifPlayer.opacity = 1.0
            gifPlayer.visible = true
        } else if (type === "carbon-live") {
            carbonLiveBg.opacity = 1.0
            carbonLiveBg.visible = true
        }
    }

    /* ── Apply New Wallpaper with Smooth Animation ────────────────── */
    function applyNewWallpaper(newPath) {
        if (!newPath) return
        if (newPath === root.currentWpPath) {
            console.log("[WallpaperMod] applyNewWallpaper called with same path; ensuring visibility")
            const curType = getWallpaperType(newPath)
            if (curType === "image") {
                imageContainer.opacity = 1.0
                imageContainer.visible = true
                if (root.activeBuffer === "B") {
                    bufB.visible = true
                    bufB.opacity = 1.0
                } else {
                    bufA.visible = true
                    bufA.opacity = 1.0
                }
            }
            return
        }
        if (newPath === root.pendingNewPath) return
        console.log("[WallpaperMod] applyNewWallpaper:", newPath, "from current:", root.currentWpPath)

        const newType = getWallpaperType(newPath)
        const oldType = getWallpaperType(root.currentWpPath)

        root.pendingNewPath = newPath

        if (newType === "image" && (oldType === "image" || !root.currentWpPath)) {
            // Dual-buffer Image-to-Image transition
            const incoming = (root.activeBuffer === "A" ? bufB : bufA)
            incoming.opacity = 0.0
            incoming.visible = true
            const targetUrl = resolveWpUrl(newPath)
            if (incoming.source.toString() === targetUrl && incoming.status === Image.Ready) {
                root.startImageTransition()
            } else {
                incoming.source = targetUrl
                if (incoming.status === Image.Ready) {
                    root.startImageTransition()
                }
            }
        } else {
            root.startCrossTypeTransition(newPath, newType, oldType)
        }
    }

    /* ── Static Image-to-Image Animation Trigger ─────────────────── */
    function startImageTransition() {
        if (!root.pendingNewPath) return
        const incoming = (root.activeBuffer === "A" ? bufB : bufA)
        const outgoing = (root.activeBuffer === "A" ? bufA : bufB)
        console.log("[WallpaperMod] >>> startImageTransition! Incoming buffer:", (root.activeBuffer === "A" ? "B" : "A"), "animType:", root.animType)

        if (transitionAnim.running) {
            transitionAnim.stop()
            if (transitionAnim.outgoingTarget) {
                transitionAnim.outgoingTarget.visible = false
                transitionAnim.outgoingTarget.source = ""
            }
            root.activeBuffer = (root.activeBuffer === "A" ? "B" : "A")
            root.isAnimating = false
        }

        // Set incoming starting transform based on animation type
        incoming.opacity = 0.0
        if (root.animType === "circular-reveal") {
            incoming.scale = 1.0
            incoming.x = 0
            incoming.y = 0
        } else if (root.animType === "cinematic") {
            incoming.scale = 1.06
            incoming.x = 0
            incoming.y = 0
        } else if (root.animType === "slide-left") {
            incoming.scale = 1.0
            incoming.x = root.width
            incoming.y = 0
        } else if (root.animType === "slide-right") {
            incoming.scale = 1.0
            incoming.x = -root.width
            incoming.y = 0
        } else if (root.animType === "zoom-out") {
            incoming.scale = 0.94
            incoming.x = 0
            incoming.y = 0
        } else { // "crossfade"
            incoming.scale = 1.0
            incoming.x = 0
            incoming.y = 0
        }
        incoming.visible = true
        imageContainer.visible = true
        imageContainer.opacity = 1.0

        // Configure dynamic animation targets and endpoints
        animInOpacity.from = 0.0
        animInOpacity.to = 1.0
        animInScale.from = incoming.scale
        animInScale.to = 1.0
        animInX.from = incoming.x
        animInX.to = 0

        animOutOpacity.from = outgoing.opacity
        animOutOpacity.to = 0.0
        animOutScale.from = outgoing.scale
        animOutScale.to = (root.animType === "cinematic" ? 0.96 : (root.animType === "zoom-out" ? 1.05 : 1.0))
        animOutX.from = outgoing.x
        animOutX.to = (root.animType === "slide-left" ? -root.width * 0.35 : (root.animType === "slide-right" ? root.width * 0.35 : 0))

        transitionAnim.incomingTarget = incoming
        transitionAnim.outgoingTarget = outgoing
        root.isAnimating = true
        transitionAnim.start()
    }

    /* Retrigger current wallpaper animation during mode transitions */
    function retriggerTransition() {
        if (!root.currentWpPath) return
        const incoming = (root.activeBuffer === "A" ? bufB : bufA)
        incoming.source = resolveWpUrl(root.currentWpPath)
        root.pendingNewPath = root.currentWpPath
        root.startImageTransition()
    }

    /* ── Cross-Type (Image <-> Video/GIF/Live) Transition ─────────── */
    function startCrossTypeTransition(newPath, newType, oldType) {
        root.isAnimating = true

        if (newType === "video" && oldType === "video") {
            root.startVideo(newPath)
            root.currentWpPath = newPath
            root.pendingNewPath = ""
            root.isAnimating = false
            return
        }

        if (newType === "video") {
            root.startVideo(newPath)
            crossFadeAnim.targetIn = videoLoader
        } else if (newType === "gif") {
            gifPlayer.source = "file://" + newPath
            gifPlayer.visible = true
            crossFadeAnim.targetIn = gifPlayer
        } else if (newType === "carbon-live") {
            carbonLiveBg.visible = true
            crossFadeAnim.targetIn = carbonLiveBg
        } else if (newType === "image") {
            const incoming = (root.activeBuffer === "A" ? bufB : bufA)
            incoming.opacity = 1.0
            incoming.scale = 1.0
            incoming.x = 0
            incoming.visible = true
            incoming.source = resolveWpUrl(newPath)
            imageContainer.visible = true
            crossFadeAnim.targetIn = imageContainer
        }

        // Outgoing target
        if (oldType === "video") crossFadeAnim.targetOut = videoLoader
        else if (oldType === "gif") crossFadeAnim.targetOut = gifPlayer
        else if (oldType === "carbon-live") crossFadeAnim.targetOut = carbonLiveBg
        else crossFadeAnim.targetOut = imageContainer

        crossFadeAnim.start()
    }

    /* ── Animation Definitions ───────────────────────────────────── */
    ParallelAnimation {
        id: transitionAnim
        property var incomingTarget: null
        property var outgoingTarget: null

        NumberAnimation {
            id: animInOpacity
            target: transitionAnim.incomingTarget
            property: "opacity"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animInScale
            target: transitionAnim.incomingTarget
            property: "scale"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animInX
            target: transitionAnim.incomingTarget
            property: "x"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            id: animOutOpacity
            target: transitionAnim.outgoingTarget
            property: "opacity"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animOutScale
            target: transitionAnim.outgoingTarget
            property: "scale"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            id: animOutX
            target: transitionAnim.outgoingTarget
            property: "x"
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }

        onFinished: {
            console.log("[WallpaperMod] >>> transitionAnim finished!")
            if (transitionAnim.outgoingTarget) {
                transitionAnim.outgoingTarget.visible = false
                transitionAnim.outgoingTarget.source = ""
            }
            root.activeBuffer = (root.activeBuffer === "A" ? "B" : "A")
            root.currentWpPath = root.pendingNewPath
            root.pendingNewPath = ""
            root.isAnimating = false
        }
    }

    ParallelAnimation {
        id: crossFadeAnim
        property var targetIn: null
        property var targetOut: null

        NumberAnimation {
            target: crossFadeAnim.targetIn
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: crossFadeAnim.targetOut
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: root.animDuration
            easing.type: Easing.OutCubic
        }

        onFinished: {
            if (crossFadeAnim.targetOut) {
                crossFadeAnim.targetOut.visible = false
                if (crossFadeAnim.targetOut === videoLoader) {
                    root.stopVideo()
                } else if (crossFadeAnim.targetOut === gifPlayer) {
                    gifPlayer.source = ""
                }
            }
            root.currentWpPath = root.pendingNewPath
            root.pendingNewPath = ""
            root.isAnimating = false
        }
    }

    /* ── Static Image Container (Dual-Buffer Ping-Pong) ───────────── */
    Item {
        id: imageContainer
        anchors.fill: parent
        clip: true
        visible: false
        opacity: 0.0

        Image {
            id: bufA
            anchors.fill: parent
            sourceSize.width: 1920
            sourceSize.height: 1080
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignBottom
            asynchronous: true
            cache: true
            visible: false
            opacity: 0.0
            scale: 1.0

            onStatusChanged: {
                console.log("[WallpaperMod] bufA statusChanged:", status, "source:", source)
                if (status === Image.Ready && root.pendingNewPath && root.pendingNewPath !== root.currentWpPath && root.activeBuffer === "B" && !transitionAnim.running) {
                    root.startImageTransition()
                }
            }
        }

        Image {
            id: bufB
            anchors.fill: parent
            sourceSize.width: 1920
            sourceSize.height: 1080
            fillMode: Image.PreserveAspectCrop
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignBottom
            asynchronous: true
            cache: true
            visible: false
            opacity: 0.0
            scale: 1.0

            onStatusChanged: {
                console.log("[WallpaperMod] bufB statusChanged:", status, "source:", source)
                if (status === Image.Ready && root.pendingNewPath && root.pendingNewPath !== root.currentWpPath && root.activeBuffer === "A" && !transitionAnim.running) {
                    root.startImageTransition()
                }
            }
        }
    }

    /* ── Video Wallpaper (.mp4, .webm) ────────────────────────────────
       MediaPlayer/VideoOutput come from the optional QtMultimedia QML
       module. They are instantiated lazily through a Loader so the shell
       still starts (static/GIF/Carbon-live wallpapers keep working) on
       systems without qt6-multimedia installed. */
    property string pendingVideoPath: ""

    function startVideo(path) {
        if (!path) return
        var clean = path.trim()
        if (clean.startsWith("file://")) clean = clean.substring(7)
        var url = "file://" + clean

        videoLoader.visible = true
        videoLoader.opacity = 1.0

        if (!videoLoader.item) {
            root.pendingVideoPath = url
            videoLoader.active = true
            return
        }
        root.pendingVideoPath = ""
        videoLoader.item.player.source = url
        videoLoader.item.player.play()
        if (videoLoader.item.output) {
            videoLoader.item.output.opacity = 1.0
            videoLoader.item.output.visible = true
        }
    }

    function stopVideo() {
        if (videoLoader.item) {
            videoLoader.item.player.stop()
            videoLoader.item.player.source = ""
        }
        videoLoader.visible = false
    }

    Loader {
        id: videoLoader
        anchors.fill: parent
        active: true
        source: "VideoWallpaper.qml"
        visible: root.currentType === "video"
        opacity: root.currentType === "video" ? 1.0 : 0.0
        onLoaded: {
            if (root.pendingVideoPath) root.startVideo(root.pendingVideoPath)
        }
    }

    readonly property var videoPlayer: videoLoader.item ? videoLoader.item.player : null
    readonly property var videoOutput: videoLoader.item ? videoLoader.item.output : null

    /* ── Animated GIF Wallpaper (.gif) ────────────────────────────── */
    AnimatedImage {
        id: gifPlayer
        anchors.fill: parent
        visible: false
        opacity: 0.0
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }

    /* ── Native Carbon Live Animated Wallpaper ────────────────────── */
    Rectangle {
        id: carbonLiveBg
        anchors.fill: parent
        color: root.isLightMode ? "#FFFFFF" : "#000000"
        visible: false
        opacity: 0.0

        Loader {
            anchors.centerIn: parent
            active: carbonLiveBg.visible && carbonLiveBg.opacity > 0.01
            sourceComponent: Component {
                CarbonLewisWallpaper {
                    isLight: root.isLightMode
                }
            }
        }
    }

    readonly property bool isLightMode: {
        const p = (root.pendingNewPath || root.currentWpPath).toLowerCase()
        return p.includes("white") || p.includes("light")
    }
}
