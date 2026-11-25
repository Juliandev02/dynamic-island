import QtQuick
import QtQuick.Controls as QQC
import org.kde.kirigami as Kirigami
import Island
import "logic.js" as L
import "i18n.js" as I18n

Row {
    id: quick

    spacing: 6
    // objectName suffixes ("volume", "wifi", ...) of buttons to leave out.
    property var hidden: []
    // Connected Bluetooth devices: the emptiest battery shows as a badge on the Bluetooth button.
    property var devices: []
    readonly property var btSummary: L.bluetoothSummary(devices)
    // A tab the panel should switch to (the volume button opens the mixer).
    signal tabRequested(string tab)

    Rectangle {
        visible: SystemStatus.battery >= 0 && !quick.hidden.includes("battery")
        anchors.verticalCenter: parent.verticalCenter
        width: battRow.implicitWidth + 24
        height: 30
        radius: 15
        color: SystemStatus.charging ? Qt.rgba(0.19, 0.82, 0.35, 0.18) : palette.base
        border.color: SystemStatus.charging ? Qt.rgba(0.19, 0.82, 0.35, 0.4) : "transparent"

        Row {
            id: battRow
            anchors.centerIn: parent
            spacing: 6
            Kirigami.Icon {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                readonly property int level: Math.round(SystemStatus.battery / 20) * 20
                source: "battery-" + String(level).padStart(3, "0") + (SystemStatus.charging ? "-charging" : "")
                color: SystemStatus.charging ? "#30d158" : palette.windowText
                isMask: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SystemStatus.battery + "%" + (SystemStatus.charging && SystemStatus.batteryWatts > 0.5 ? " · " + Math.round(SystemStatus.batteryWatts) + " W" : "")
                color: SystemStatus.charging ? "#30d158" : palette.windowText
                font.pixelSize: 12
                font.weight: SystemStatus.charging ? Font.DemiBold : Font.Normal
                font.features: { "tnum": 1 }
            }
        }
        HoverHandler { id: battPillHover }
        QQC.ToolTip.visible: battPillHover.hovered
        QQC.ToolTip.text: L.batteryTooltip(SystemStatus.battery, SystemStatus.batteryState, SystemStatus.batteryMinutes, SystemStatus.batteryWatts)
        QQC.ToolTip.delay: 300
    }

    QuickButton {
        objectName: "qb-volume"
        label: I18n.t("Sound mixer · {level} (scroll to change, right-click to {action})", {
            level: SystemStatus.muted ? I18n.t("muted") : SystemStatus.volume + "%",
            action: SystemStatus.muted ? I18n.t("unmute") : I18n.t("mute")
        })
        iconName: SystemStatus.muted ? "audio-volume-muted" : "audio-volume-high"
        onClicked: quick.tabRequested("mixer")
        onRightClicked: SystemStatus.toggleMute()
        property int wheelAccum: 0
        onScrolled: delta => {
            const r = L.wheelSteps(wheelAccum, delta)
            wheelAccum = r.accum
            if (r.steps !== 0)
                SystemStatus.changeVolume(r.steps * 5)
            levelTimer.restart()
        }
        // While scrolling, the level shows in a bubble: a tooltip hides as soon as the wheel turns.
        showTip: !levelTimer.running
        Timer {
            id: levelTimer
            interval: 1500
        }
        Rectangle {
            objectName: "volumeBubble"
            visible: levelTimer.running
            anchors.top: parent.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96
            height: 30
            radius: 15
            z: 50
            color: palette.alternateBase
            border.color: palette.dark
            Row {
                anchors.centerIn: parent
                spacing: 8
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 4
                    radius: 2
                    color: palette.button
                    Rectangle {
                        width: SystemStatus.muted ? 0 : parent.width * Math.min(100, SystemStatus.volume) / 100
                        height: parent.height
                        radius: parent.radius
                        color: palette.accent
                    }
                }
                Text {
                    objectName: "volumeBubbleText"
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemStatus.muted ? I18n.t("Muted") : SystemStatus.volume + "%"
                    color: palette.windowText
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }
    }
    QuickButton {
        objectName: "qb-wifi"
        label: I18n.t("Wi-Fi")
        on: SystemStatus.wifi
        iconName: SystemStatus.wifi ? "network-wireless" : "network-wireless-disconnected"
        onClicked: SystemStatus.setWifi(!SystemStatus.wifi)
    }
    QuickButton {
        objectName: "qb-bluetooth"
        label: I18n.t("{label} (right-click for connected devices)", { label: quick.btSummary.label })
        badge: quick.btSummary.badge
        onRightClicked: btPopup.open()
        BluetoothDevices {
            id: btPopup
            objectName: "btPopup"
            devices: quick.devices
            y: parent.height + 8
            x: parent.width - width
        }
        on: SystemStatus.bluetooth
        iconName: "network-bluetooth-activated"
        onClicked: SystemStatus.setBluetooth(!SystemStatus.bluetooth)
    }
    QuickButton {
        objectName: "qb-dnd"
        label: I18n.t("Do not disturb")
        on: SystemStatus.dnd
        iconName: "notifications-disabled"
        onClicked: SystemStatus.setDnd(!SystemStatus.dnd)
    }
    QuickButton {
        objectName: "qb-awake"
        label: I18n.t("Keep screen awake")
        on: SystemStatus.keepAwake
        iconName: "system-suspend-inhibited"
        onClicked: SystemStatus.setKeepAwake(!SystemStatus.keepAwake)
    }
    QuickButton {
        objectName: "qb-nightcolor"
        label: I18n.t("Night Color")
        on: SystemStatus.nightColor
        iconName: "redshift-status-on"
        onClicked: SystemStatus.toggleNightColor()
    }
    QuickButton {
        objectName: "qb-powerprofile"
        visible: SystemStatus.powerProfile !== "" && !quick.hidden.includes("powerprofile")
        label: I18n.t("Power profile: {profile}", {
            profile: SystemStatus.powerProfile === "power-saver" ? I18n.t("Power Saver")
                   : SystemStatus.powerProfile === "performance" ? I18n.t("Performance")
                   : I18n.t("Balanced")
        })
        on: SystemStatus.powerProfile === "performance" || SystemStatus.powerProfile === "power-saver"
        iconName: SystemStatus.powerProfile === "power-saver" ? "battery-profile-powersave-symbolic"
                : SystemStatus.powerProfile === "performance" ? "battery-profile-performance-symbolic"
                : "battery-profile-balanced-symbolic"
        onClicked: SystemStatus.cyclePowerProfile()
    }
    QuickButton {
        objectName: "qb-screenshot"
        label: I18n.t("Screenshot")
        iconName: "camera-photo-symbolic"
        onClicked: SystemStatus.screenshot()
    }
    QuickButton {
        objectName: "qb-lock"
        label: I18n.t("Lock screen")
        iconName: "system-lock-screen-symbolic"
        onClicked: SystemStatus.lock()
    }

    component QuickButton: Rectangle {
        id: button
        property string iconName
        property string label
        property bool on: false
        property string badge: ""
        property bool showTip: true
        signal clicked()
        signal rightClicked()
        signal scrolled(int delta)

        visible: !quick.hidden.includes(objectName.slice(3))
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: 15
        color: on ? palette.accent : palette.base

        Kirigami.Icon {
            anchors.centerIn: parent
            width: 15
            height: 15
            source: button.iconName
            color: parent.on ? "#ffffff" : palette.windowText
            isMask: true
        }
        Rectangle {
            visible: button.badge !== ""
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -4
            anchors.bottomMargin: -3
            width: Math.max(16, badgeText.implicitWidth + 6)
            height: 13
            radius: 6.5
            color: Number(button.badge) <= 15 ? "#ff6b6b" : palette.button
            border.color: palette.window
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: button.badge
                color: Number(button.badge) <= 15 ? "#ffffff" : palette.windowText
                font.pixelSize: 8
                font.weight: Font.Bold
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? button.rightClicked() : button.clicked()
            onWheel: wheel => button.scrolled(L.scrollAmount(wheel.angleDelta.y, wheel.inverted))
        }
        QQC.ToolTip.visible: area.containsMouse && button.showTip
        QQC.ToolTip.text: button.label
        QQC.ToolTip.delay: 500
    }
}
