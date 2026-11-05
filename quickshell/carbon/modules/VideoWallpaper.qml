import QtQuick
import QtMultimedia

/**
 * Video wallpaper surface (.mp4/.webm/.mkv/.m4v).
 *
 * This lives in its own file because it depends on the optional QtMultimedia
 * QML module. WallpaperMod instantiates it lazily through a Loader, so a
 * system that does not ship qt6-multimedia can still start the shell and use
 * static / GIF / Carbon-live wallpapers instead of crash-looping.
 */
Item {
    id: root
    anchors.fill: parent

    property alias player: videoPlayer
    property alias output: videoOutput

    MediaPlayer {
        id: videoPlayer
        videoOutput: videoOutput
        loops: MediaPlayer.Infinite
        audioOutput: null
    }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        visible: true
        opacity: 1.0
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
