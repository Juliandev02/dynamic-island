import QtQuick

// Content of one of the island's states: fades and settles gently in when shown, out when not.
Item {
    id: slide
    property bool shown
    anchors.fill: parent
    clip: true
    opacity: shown ? 1 : 0
    visible: opacity > 0
    // Old content leaves cleanly and the new one fades in smoothly after it, so they never overlap visibly.
    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation { duration: slide.shown ? 80 : 0 }
            NumberAnimation {
                duration: slide.shown ? 240 : 120
                easing.type: slide.shown ? Easing.OutCubic : Easing.OutQuad
            }
        }
    }
    transform: Translate {
        y: slide.shown ? 0 : -4
        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    }
}
