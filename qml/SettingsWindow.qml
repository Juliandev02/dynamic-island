import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import org.kde.kirigami as Kirigami
import Island
import "logic.js" as L
import "i18n.js" as I18n

QQC.ApplicationWindow {
    id: win

    required property var prefs
    // Bound to Main.qml's activeLang in the app; defaults to "en" in unit tests.
    property string lang: I18n.lang
    function tr(s, p) { lang; return I18n.t(s, p) }
    property var calendar: null
    // The AppConfig singleton; passed in so the window also loads without the C++ module (tests).
    property var appConfig: null
    // BlurSettings: KWin's blur strength. Passed in, like appConfig, so tests load without it.
    property var blur: null
    signal tourRequested()

    title: win.tr("Dynamic Island settings")
    width: 760
    height: 600
    minimumWidth: 620
    minimumHeight: 400
    // The island is a layer-shell surface, which can't parent a normal window.
    transientParent: null

    readonly property var calendarUrls: L.toList(prefs.calendar.icsUrls)
    readonly property var disabledUrls: L.toList(prefs.calendar.disabled)
    readonly property var hiddenButtons: L.toList(prefs.quickButtons.hidden)
    readonly property var lyricSourcesOff: L.toList(prefs.behaviour.lyricSourcesOff)
    readonly property var links: L.parseLinks(prefs.tools.links)
    readonly property var knownApps: L.parseKnownApps(prefs.history.known)
    readonly property var offApps: L.toList(prefs.history.off)
    readonly property var urgentApps: L.toList(prefs.fullScreen.urgent)

    function saveLinks(list) { prefs.tools.links = JSON.stringify(list) }
    function moved(list, from, to) {
        const out = list.slice()
        out.splice(to, 0, out.splice(from, 1)[0])
        return out
    }

    function toggled(list, item, on) {
        const rest = list.filter(x => x !== item)
        return on ? rest.concat([item]) : rest
    }

    property int page: 0

    // Search: matches the text of every label, switch, check box and button on the pages.
    property string query: ""
    // Filled when the query changes, not as a binding: the labels' text isn't bindable from here.
    property var results: []
    onQueryChanged: results = query.trim().length >= 2 ? searchFor(query) : []
    function searchFor(q) {
        const words = q.toLowerCase().trim().split(/\s+/)
        const out = []
        const seen = {}
        for (let i = 0; i < stack.children.length; ++i) {
            const pg = stack.children[i]
            collectText(pg, i, pg.title, words, out, seen)
        }
        return out.slice(0, 40)
    }
    function collectText(item, pageIndex, pageTitle, words, out, seen) {
        // Text fields hold what the user typed, not a setting's name.
        const editable = item.cursorPosition !== undefined
        if (!editable && typeof item.text === "string" && item.text.length > 1 && item.objectName !== "searchSkip") {
            const label = item.text.replace(/:$/, "").replace(/&/g, "")
            const hay = (label + " " + pageTitle).toLowerCase()
            const key = pageIndex + "|" + label
            if (!seen[key] && label !== pageTitle && words.every(w => hay.includes(w))) {
                seen[key] = true
                out.push({ label: label, page: pageIndex, pageTitle: pageTitle, item: item })
            }
        }
        for (let c = 0; c < item.children.length; ++c)
            collectText(item.children[c], pageIndex, pageTitle, words, out, seen)
    }
    // Opens a result's page, scrolls it into view and flashes it.
    function reveal(r) {
        query = ""
        page = r.page
        const pg = stack.children[r.page]
        Qt.callLater(() => {
            const flick = pg.contentItem
            const p = r.item.mapToItem(flick.contentItem, 0, 0)
            flick.contentY = Math.max(0, Math.min(p.y - 40, flick.contentHeight - flick.height))
            const q = r.item.mapToItem(win.contentItem, 0, 0)
            flash.x = q.x - 6
            flash.y = q.y - 4
            flash.width = r.item.width + 12
            flash.height = r.item.height + 8
            flash.target = r.item
            flashAnim.restart()
        })
    }
    readonly property var pages: [
            { label: win.tr("Look"), icon: "preferences-desktop-theme-global" },
            { label: win.tr("Behaviour"), icon: "preferences-system-windows-behavior" },
            { label: win.tr("Alerts"), icon: "preferences-desktop-notification" },
            { label: win.tr("When idle"), icon: "preferences-desktop-screensaver" },
            { label: win.tr("Calendar"), icon: "view-calendar" },
            { label: win.tr("Weather"), icon: "weather-few-clouds" },
            { label: win.tr("Quick buttons"), icon: "view-grid" },
            { label: win.tr("Quick links"), icon: "link" },
            { label: win.tr("General"), icon: "preferences-system" }
    ]

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // One page per topic, so no single page turns into a long scroll.
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 190
            Layout.maximumWidth: 190
            spacing: 0
        Kirigami.SearchField {
            id: search
            objectName: "settingsSearch"
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            placeholderText: win.tr("Search settings")
            text: win.query
            onTextChanged: win.query = text
            Keys.onReturnPressed: if (win.results.length) win.reveal(win.results[0])
            Keys.onEscapePressed: win.query = ""
        }
        QQC.Label {
            objectName: "searchEmpty"
            visible: win.query.trim().length >= 2 && win.results.length === 0
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing
            text: win.tr("Nothing matches.")
            opacity: 0.7
            wrapMode: Text.WordWrap
        }
        QQC.ScrollView {
            visible: win.results.length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                objectName: "searchResults"
                model: win.results
                delegate: QQC.ItemDelegate {
                    required property var modelData
                    required property int index
                    objectName: "searchResult" + index
                    width: ListView.view.width
                    contentItem: Column {
                        QQC.Label {
                            width: parent.width
                            text: modelData.label
                            elide: Text.ElideRight
                        }
                        QQC.Label {
                            width: parent.width
                            text: modelData.pageTitle
                            font: Kirigami.Theme.smallFont
                            opacity: 0.7
                        }
                    }
                    onClicked: win.reveal(modelData)
                }
            }
        }
        QQC.ScrollView {
            visible: win.query.trim().length < 2
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                topMargin: Kirigami.Units.smallSpacing
                model: win.pages
                delegate: QQC.ItemDelegate {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    text: modelData.label
                    icon.name: modelData.icon
                    highlighted: win.page === index
                    onClicked: win.page = index
                }
            }
        }
        }
        Kirigami.Separator { Layout.fillHeight: true }
        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: win.page
            Page {
                title: win.tr("Look")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.ButtonGroup { id: lookGroup }
                    QQC.RadioButton {
                        Kirigami.FormData.label: win.tr("Style:")
                        text: win.tr("Notch, joined to the top edge")
                        QQC.ButtonGroup.group: lookGroup
                        checked: win.prefs.style.look === "notch"
                        onToggled: win.prefs.style.look = "notch"
                    }
                    QQC.RadioButton {
                        text: win.tr("Pill, floating below the edge")
                        QQC.ButtonGroup.group: lookGroup
                        checked: win.prefs.style.look === "pill"
                        onToggled: win.prefs.style.look = "pill"
                    }
                    RowLayout {
                        Kirigami.FormData.label: win.tr("Accent colour:")
                        spacing: 8
                        Repeater {
                            model: ["#0a84ff", "#5e5ce6", "#bf5af2", "#ff375f", "#ff453a", "#ff9f0a", "#ffd60a", "#30d158", "#64d2ff", "#8e8e93"]
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool current: win.prefs.style.accent.toLowerCase() === modelData
                                width: 26
                                height: 26
                                radius: 13
                                color: modelData
                                border.width: current ? 3 : 0
                                border.color: Kirigami.Theme.textColor
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.prefs.style.accent = parent.modelData
                                }
                            }
                        }
                        QQC.Button {
                            text: win.tr("Custom…")
                            icon.name: "color-picker"
                            onClicked: accentDialog.open()
                        }
                    }
                    QQC.CheckBox {
                        objectName: "coverTint"
                        text: win.tr("Tint music controls with the cover's colour")
                        checked: win.prefs.style.coverTint
                        onToggled: win.prefs.style.coverTint = checked
                    }
                    QQC.ComboBox {
                        objectName: "themePicker"
                        Kirigami.FormData.label: win.tr("Colours:")
                        textRole: "label"
                        valueRole: "key"
                        model: [{ key: "dark", label: win.tr("Dark") }, { key: "light", label: win.tr("Light") }, { key: "system", label: win.tr("Follow Plasma") }]
                        currentIndex: Math.max(0, model.findIndex(m => m.key === win.prefs.style.theme))
                        onActivated: win.prefs.style.theme = currentValue
                    }
                    RowLayout {
                        Kirigami.FormData.label: win.tr("Island colour:")
                        spacing: 8
                        Repeater {
                            model: ["", "#000000", "#1c1c1e", "#0b1f33", "#1e1033", "#0f2a1d", "#2a1512", "#f2f2f7", "#fff4dc"]
                            delegate: Rectangle {
                                required property string modelData
                                required property int index
                                objectName: "islandColor" + index
                                readonly property bool current: (win.prefs.style.color || "").toLowerCase() === modelData
                                width: 26
                                height: 26
                                radius: 13
                                // The first one is the theme's own colour, shown half dark, half light.
                                color: modelData || "#000000"
                                border.width: current ? 3 : 1
                                border.color: current ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                                Rectangle {
                                    visible: parent.modelData === ""
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: parent.border.width
                                    width: parent.width / 2 - parent.border.width
                                    height: parent.height - 2 * parent.border.width
                                    radius: height / 2
                                    color: "#f2f2f7"
                                }
                                QQC.ToolTip.visible: swatchArea.containsMouse
                                QQC.ToolTip.text: modelData === "" ? win.tr("The theme's colour") : modelData
                                MouseArea {
                                    id: swatchArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.prefs.style.color = parent.modelData
                                }
                            }
                        }
                        QQC.Button {
                            objectName: "islandColorCustom"
                            text: win.tr("Custom…")
                            icon.name: "color-picker"
                            onClicked: islandColorDialog.open()
                        }
                    }
                    ColorDialog {
                        id: islandColorDialog
                        title: win.tr("Choose the island's colour")
                        selectedColor: win.prefs.style.color || "#000000"
                        onAccepted: win.prefs.style.color = selectedColor.toString().slice(0, 7)
                    }
                    SliderRow {
                        objectName: "islandOpacity"
                        Kirigami.FormData.label: win.tr("Opacity:")
                        from: 20; to: 100; suffix: "%"
                        value: L.islandOpacity(win.prefs.style.opacity, win.prefs.style.translucent)
                        onMoved: v => win.prefs.style.opacity = v
                    }
                    QQC.CheckBox {
                        objectName: "translucent"
                        text: win.tr("Blur what shows through")
                        enabled: L.islandOpacity(win.prefs.style.opacity, win.prefs.style.translucent) < 100
                        checked: win.prefs.style.translucent
                        onToggled: {
                            // Old configs have no opacity yet; keep the one they see instead of letting it follow this box.
                            if (win.prefs.style.opacity < 0)
                                win.prefs.style.opacity = L.islandOpacity(-1, win.prefs.style.translucent)
                            win.prefs.style.translucent = checked
                        }
                    }
                    SliderRow {
                        objectName: "blurStrength"
                        Kirigami.FormData.label: win.tr("Blur strength:")
                        visible: win.blur !== null
                        enabled: win.blur !== null && win.blur.effect !== "" && win.prefs.style.translucent
                        from: 1; to: 15; suffix: ""
                        value: win.blur ? win.blur.strength : 12
                        onMoved: v => win.blur.strength = v
                    }
                    QQC.Label {
                        visible: win.blur !== null
                        Layout.maximumWidth: 380
                        wrapMode: Text.WordWrap
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                        text: win.blur && win.blur.effect === "" ? win.tr("No blur effect is running in KWin.")
                            : win.blur && win.blur.effect === "better_blur_dx"
                              ? win.tr("KWin has one blur strength for every window, so this changes the blur everywhere (Better Blur DX's setting).")
                              : win.tr("KWin has one blur strength for every window, so this changes the blur everywhere.")
                    }
                    QQC.CheckBox {
                        objectName: "liveBars"
                        text: win.tr("Level bars follow the sound")
                        checked: win.prefs.style.liveBars
                        onToggled: win.prefs.style.liveBars = checked
                    }
                    ColorDialog {
                        id: accentDialog
                        title: win.tr("Choose an accent colour")
                        selectedColor: win.prefs.style.accent
                        onAccepted: win.prefs.style.accent = selectedColor.toString()
                    }
                    Item { Kirigami.FormData.isSection: true }
                    SliderRow {
                        Kirigami.FormData.label: win.tr("Height:")
                        from: 24; to: 48; suffix: " px"
                        value: win.prefs.shape.height
                        onMoved: v => win.prefs.shape.height = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: win.tr("Width when empty:")
                        from: 100; to: 320; suffix: " px"
                        value: win.prefs.shape.idleWidth
                        onMoved: v => win.prefs.shape.idleWidth = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: win.tr("Width with music or timer:")
                        from: 160; to: 420; suffix: " px"
                        value: win.prefs.shape.compactWidth
                        onMoved: v => win.prefs.shape.compactWidth = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: win.tr("Corner roundness:")
                        from: 0; to: 20; suffix: " px"
                        value: win.prefs.shape.radius
                        onMoved: v => win.prefs.shape.radius = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: win.tr("Curves at the top:")
                        enabled: win.prefs.style.look === "notch"
                        from: 0; to: 16; suffix: " px"
                        value: win.prefs.shape.ears
                        onMoved: v => win.prefs.shape.ears = v
                    }
                    Item { Kirigami.FormData.isSection: true }
                    QQC.CheckBox {
                        Kirigami.FormData.label: win.tr("Top of the open panel:")
                        text: win.tr("Time")
                        checked: win.prefs.panel.time
                        onToggled: win.prefs.panel.time = checked
                    }
                    QQC.CheckBox {
                        text: win.tr("Date")
                        checked: win.prefs.panel.date
                        onToggled: win.prefs.panel.date = checked
                    }
                }
            }
            Page {
                title: win.tr("Behaviour")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    SliderRow {
                        Kirigami.FormData.label: win.tr("Switch music and timer every:")
                        from: 3; to: 30; suffix: " s"
                        value: win.prefs.behaviour.cycleSeconds
                        onMoved: v => win.prefs.behaviour.cycleSeconds = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: win.tr("After a swipe, hold for:")
                        from: 5; to: 60; suffix: " s"
                        value: win.prefs.behaviour.swipeHoldSeconds
                        onMoved: v => win.prefs.behaviour.swipeHoldSeconds = v
                    }
                    SliderRow {
                        Kirigami.FormData.label: win.tr("Keep paused music for:")
                        from: 1; to: 60; suffix: " min"
                        value: win.prefs.behaviour.pausedMinutes
                        onMoved: v => win.prefs.behaviour.pausedMinutes = v
                    }
                    SliderRow {
                        objectName: "animationSpeed"
                        Kirigami.FormData.label: win.tr("Animation duration:")
                        from: 0; to: 150; suffix: "%"
                        value: win.prefs.behaviour.animationSpeed
                        onMoved: v => win.prefs.behaviour.animationSpeed = v
                    }
                    QQC.CheckBox {
                        Kirigami.FormData.label: win.tr("Missing song covers:")
                        text: win.tr("Look up on iTunes (sends the artist and title to Apple)")
                        checked: win.prefs.behaviour.coverLookup
                        onToggled: win.prefs.behaviour.coverLookup = checked
                    }
                    QQC.CheckBox {
                        objectName: "lyricsSwitch"
                        Kirigami.FormData.label: win.tr("Lyrics:")
                        text: win.tr("Show lyrics in the Music tab (sends the song to the sources below when shown)")
                        checked: win.prefs.behaviour.lyrics
                        onToggled: win.prefs.behaviour.lyrics = checked
                    }
                    QQC.CheckBox {
                        objectName: "pillLyricsSwitch"
                        text: win.tr("Show the line being sung in place of the title on the pill")
                        enabled: win.prefs.behaviour.lyrics
                        checked: win.prefs.behaviour.pillLyrics
                        onToggled: win.prefs.behaviour.pillLyrics = checked
                    }
                    Repeater {
                        model: L.lyricSources
                        delegate: QQC.CheckBox {
                            required property var modelData
                            required property int index
                            objectName: "lyricSource_" + modelData.key
                            Kirigami.FormData.label: index === 0 ? win.tr("Lyrics sources:") : ""
                            text: modelData.label + " (" + win.tr(modelData.note) + ")"
                            enabled: win.prefs.behaviour.lyrics
                            checked: !win.lyricSourcesOff.includes(modelData.key)
                            onToggled: win.prefs.behaviour.lyricSourcesOff = win.toggled(win.lyricSourcesOff, modelData.key, !checked)
                        }
                    }
                    QQC.ButtonGroup { id: openGroup }
                    QQC.RadioButton {
                        Kirigami.FormData.label: win.tr("Open the panel:")
                        text: win.tr("On click")
                        QQC.ButtonGroup.group: openGroup
                        checked: !win.prefs.behaviour.openOnHover
                        onToggled: win.prefs.behaviour.openOnHover = false
                    }
                    QQC.RadioButton {
                        text: win.tr("When the pointer rests on it")
                        QQC.ButtonGroup.group: openGroup
                        checked: win.prefs.behaviour.openOnHover
                        onToggled: win.prefs.behaviour.openOnHover = true
                    }
                }
            }
            Page {
                title: win.tr("Alerts")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: [
                            { key: "levels", label: win.tr("Volume and brightness (hides Plasma's box)") },
                            { key: "notifications", label: win.tr("Notifications (hides Plasma's popups)") },
                            { key: "privacy", label: win.tr("Microphone and camera in use") },
                            { key: "devices", label: win.tr("Bluetooth devices connecting") },
                            { key: "meetings", label: win.tr("Join button for meetings") },
                            { key: "power", label: win.tr("Charger plugged in or out") },
                            { key: "jobs", label: win.tr("Downloads and file copies") }
                        ]
                        delegate: QQC.CheckBox {
                            required property var modelData
                            required property int index
                            Kirigami.FormData.label: index === 0 ? win.tr("Show:") : ""
                            text: modelData.label
                            checked: win.prefs.show[modelData.key]
                            onToggled: win.prefs.show[modelData.key] = checked
                        }
                    }

                    // What still comes in front of a full-screen game or film.
                    Item { Kirigami.FormData.isSection: true }
                    Repeater {
                        model: [
                            { key: "levels", label: win.tr("Volume and brightness") },
                            { key: "jobs", label: win.tr("Downloads and file copies") },
                            { key: "privacy", label: win.tr("Microphone and camera in use") },
                            { key: "devices", label: win.tr("Bluetooth devices connecting") },
                            { key: "power", label: win.tr("Charger plugged in or out") },
                            { key: "allNotifications", label: win.tr("Show all notifications") }
                        ]
                        delegate: QQC.CheckBox {
                            required property var modelData
                            required property int index
                            objectName: "fullScreen-" + modelData.key
                            Kirigami.FormData.label: index === 0 ? win.tr("Over full-screen apps:") : ""
                            text: modelData.label
                            checked: win.prefs.fullScreen[modelData.key]
                            onToggled: win.prefs.fullScreen[modelData.key] = checked
                        }
                    }
                    ColumnLayout {
                        Kirigami.FormData.label: win.tr("Urgent apps:")
                        spacing: 0
                        QQC.Label {
                            visible: win.knownApps.length === 0
                            text: win.tr("Apps show up here once they send a notification.")
                            opacity: 0.7
                        }
                        Repeater {
                            model: win.knownApps
                            delegate: RowLayout {
                                id: urgent
                                required property var modelData
                                QQC.CheckBox {
                                    id: urgentBox
                                    objectName: "urgentApp-" + urgent.modelData.key
                                    enabled: !win.prefs.fullScreen.allNotifications
                                    checked: win.urgentApps.includes(urgent.modelData.key)
                                    onToggled: win.prefs.fullScreen.urgent = win.toggled(win.urgentApps, urgent.modelData.key, checked)
                                }
                                Kirigami.Icon {
                                    enabled: urgentBox.enabled
                                    implicitWidth: Kirigami.Units.iconSizes.small
                                    implicitHeight: Kirigami.Units.iconSizes.small
                                    source: urgent.modelData.icon || "preferences-desktop-notification"
                                    fallback: "preferences-desktop-notification"
                                }
                                QQC.Label {
                                    enabled: urgentBox.enabled
                                    text: urgent.modelData.name
                                }
                            }
                        }
                    }

                    Item { Kirigami.FormData.isSection: true }
                    QQC.CheckBox {
                        objectName: "historySave"
                        Kirigami.FormData.label: win.tr("History:")
                        text: win.tr("Save notifications")
                        checked: win.prefs.history.save
                        onToggled: win.prefs.history.save = checked
                    }
                    QQC.ComboBox {
                        objectName: "historyDays"
                        Kirigami.FormData.label: win.tr("Keep them for:")
                        enabled: win.prefs.history.save
                        textRole: "label"
                        valueRole: "days"
                        readonly property var choices: [
                            { days: 1, label: win.tr("1 day") },
                            { days: 7, label: win.tr("7 days") },
                            { days: 30, label: win.tr("30 days") }
                        ]
                        model: choices
                        // indexOfValue() gives -1 before the model loads, so the index is found by hand.
                        currentIndex: Math.max(0, choices.findIndex(c => c.days === win.prefs.history.days))
                        onActivated: win.prefs.history.days = currentValue
                    }
                    // Switching a kind or an app off only stops new ones; what is saved stays.
                    Repeater {
                        model: [
                            { key: "system", label: win.tr("System") },
                            { key: "apps", label: win.tr("Apps") },
                            { key: "others", label: win.tr("Others") }
                        ]
                        delegate: ColumnLayout {
                            id: kind
                            required property var modelData
                            required property int index
                            Kirigami.FormData.label: index === 0 ? win.tr("Save from:") : ""
                            spacing: 0
                            QQC.CheckBox {
                                objectName: "historyKind-" + kind.modelData.key
                                text: kind.modelData.label
                                enabled: win.prefs.history.save
                                checked: win.prefs.history[kind.modelData.key]
                                onToggled: win.prefs.history[kind.modelData.key] = checked
                            }
                            Repeater {
                                model: win.knownApps.filter(a => a.kind === kind.modelData.key)
                                delegate: RowLayout {
                                    id: app
                                    required property var modelData
                                    Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                                    QQC.CheckBox {
                                        id: appBox
                                        objectName: "historyApp-" + app.modelData.key
                                        enabled: win.prefs.history.save && win.prefs.history[kind.modelData.key]
                                        checked: !win.offApps.includes(app.modelData.key)
                                        onToggled: win.prefs.history.off = win.toggled(win.offApps, app.modelData.key, !checked)
                                    }
                                    Kirigami.Icon {
                                        enabled: appBox.enabled
                                        implicitWidth: Kirigami.Units.iconSizes.small
                                        implicitHeight: Kirigami.Units.iconSizes.small
                                        source: app.modelData.icon || "preferences-desktop-notification"
                                        fallback: "preferences-desktop-notification"
                                    }
                                    QQC.Label {
                                        enabled: appBox.enabled
                                        text: app.modelData.name
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Page {
                title: win.tr("When idle")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.ButtonGroup { id: idleGroup }
                    Repeater {
                        model: [
                            { key: "glances", label: win.tr("Glances") },
                            { key: "animation", label: win.tr("My animation") },
                            { key: "nothing", label: win.tr("Nothing") }
                        ]
                        delegate: QQC.RadioButton {
                            required property var modelData
                            required property int index
                            Kirigami.FormData.label: index === 0 ? win.tr("Show:") : ""
                            text: modelData.label
                            QQC.ButtonGroup.group: idleGroup
                            checked: win.prefs.idle.mode === modelData.key
                            onToggled: win.prefs.idle.mode = modelData.key
                        }
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        Kirigami.FormData.label: win.tr("Glances:")
                        text: win.tr("Events starting in 30 minutes or less")
                        checked: win.prefs.idle.events
                        onToggled: win.prefs.idle.events = checked
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        text: win.tr("Battery (warns at 15% or less)")
                        checked: win.prefs.idle.battery
                        onToggled: win.prefs.idle.battery = checked
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        text: win.tr("Time")
                        checked: win.prefs.idle.time
                        onToggled: win.prefs.idle.time = checked
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        text: win.tr("Weather")
                        checked: win.prefs.idle.weather
                        onToggled: win.prefs.idle.weather = checked
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        text: win.tr("Pending system updates")
                        checked: win.prefs.idle.updates
                        onToggled: win.prefs.idle.updates = checked
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "glances"
                        text: win.tr("Next task from the To-Do list")
                        checked: win.prefs.idle.todo
                        onToggled: win.prefs.idle.todo = checked
                    }
                    QQC.ComboBox {
                        id: artPicker
                        visible: win.prefs.idle.mode === "animation"
                        Kirigami.FormData.label: win.tr("Animation:")
                        readonly property string current: win.prefs.idle.animation || "builtin:aurora"
                        textRole: "label"
                        valueRole: "key"
                        model: [
                            { key: "builtin:aurora", label: win.tr("Aurora") },
                            { key: "builtin:wave", label: win.tr("Wave") },
                            { key: "builtin:fireflies", label: win.tr("Fireflies") },
                            { key: "builtin:cat", label: win.tr("Cat") },
                            { key: "file", label: win.tr("My own GIF or WebP…") }
                        ]
                        currentIndex: current.startsWith("builtin:") ? Math.max(0, indexOfValue(current)) : 4
                        onActivated: {
                            if (currentValue === "file")
                                animationDialog.open()
                            else
                                win.prefs.idle.animation = currentValue
                        }
                    }
                    RowLayout {
                        visible: win.prefs.idle.mode === "animation" && !artPicker.current.startsWith("builtin:")
                        Kirigami.FormData.label: win.tr("File:")
                        QQC.Label {
                            Layout.maximumWidth: 200
                            elide: Text.ElideMiddle
                            text: decodeURIComponent(artPicker.current.split("/").pop())
                        }
                        QQC.Button {
                            text: win.tr("Change…")
                            icon.name: "document-open"
                            onClicked: animationDialog.open()
                        }
                    }
                    QQC.Label {
                        visible: win.prefs.idle.mode === "animation"
                        text: win.tr("Point at the island to see it play.")
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                    QQC.CheckBox {
                        visible: win.prefs.idle.mode === "animation"
                        text: win.tr("Only play when the pointer is on the island")
                        checked: win.prefs.idle.animateOnHoverOnly
                        onToggled: win.prefs.idle.animateOnHoverOnly = checked
                    }
                    FileDialog {
                        id: animationDialog
                        title: win.tr("Choose an animation")
                        nameFilters: ["Animations (*.gif *.webp)"]
                        onAccepted: win.prefs.idle.animation = selectedFile.toString()
                        onRejected: artPicker.currentIndex = artPicker.current.startsWith("builtin:") ? artPicker.indexOfValue(artPicker.current) : 4
                    }
                }
            }
            Page {
                title: win.tr("Calendar")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.ComboBox {
                        objectName: "holidayCountry"
                        Kirigami.FormData.label: win.tr("Holidays and festivals:")
                        textRole: "label"
                        valueRole: "key"
                        readonly property string autoKey: L.holidayCountry("auto", Qt.locale().name)
                        model: [{ key: "auto", label: win.tr("Automatic") + (autoKey ? " (" + L.holidayLabel(autoKey) + ")" : "") }, { key: "", label: win.tr("None") }]
                               .concat(L.HOLIDAY_COUNTRIES.map(c => ({ key: c.key, label: c.label })))
                        currentIndex: Math.max(0, model.findIndex(m => m.key === win.prefs.calendar.holidays))
                        onActivated: win.prefs.calendar.holidays = currentValue
                    }
                    QQC.CheckBox {
                        objectName: "observances"
                        text: win.tr("Include festivals and religious days, not only public holidays")
                        enabled: L.holidayCountry(win.prefs.calendar.holidays, Qt.locale().name) !== ""
                        checked: win.prefs.calendar.observances
                        onToggled: win.prefs.calendar.observances = checked
                    }
                    SliderRow {
                        Kirigami.FormData.label: win.tr("Check for changes every:")
                        from: 5; to: 120; suffix: " min"
                        value: win.prefs.calendar.refreshMinutes
                        onMoved: v => win.prefs.calendar.refreshMinutes = v
                    }
                    // One child for the whole list: rows added later would otherwise land at the end of the form.
                    ColumnLayout {
                        Kirigami.FormData.label: win.tr("Calendars:")
                        Kirigami.FormData.labelAlignment: Qt.AlignTop
                        QQC.Label {
                            visible: win.calendarUrls.length === 0
                            text: win.tr("None yet")
                            opacity: 0.7
                        }
                        Repeater {
                            model: win.calendarUrls
                            delegate: RowLayout {
                                required property string modelData
                                QQC.Switch {
                                    text: L.calendarLabel(modelData)
                                    checked: !win.disabledUrls.includes(modelData)
                                    onToggled: win.prefs.calendar.disabled = win.toggled(win.disabledUrls, modelData, !checked)
                                }
                                QQC.ToolButton {
                                    icon.name: "edit-delete-remove"
                                    text: win.tr("Remove")
                                    display: QQC.AbstractButton.IconOnly
                                    QQC.ToolTip.text: text
                                    QQC.ToolTip.visible: hovered
                                    onClicked: {
                                        win.prefs.calendar.icsUrls = win.calendarUrls.filter(u => u !== modelData)
                                        win.prefs.calendar.disabled = win.disabledUrls.filter(u => u !== modelData)
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Kirigami.FormData.label: win.tr("Add a calendar:")
                        QQC.TextField {
                            id: newUrl
                            Layout.preferredWidth: 240
                            // It's a secret link, so keep it off the screen.
                            echoMode: TextInput.Password
                            placeholderText: win.tr("Secret address in iCal format")
                            onAccepted: addButton.clicked()
                        }
                        QQC.Button {
                            id: addButton
                            text: win.tr("Add")
                            enabled: /^https?:\/\//.test(newUrl.text.trim()) && !win.calendarUrls.includes(newUrl.text.trim())
                            onClicked: {
                                win.prefs.calendar.icsUrls = win.calendarUrls.concat([newUrl.text.trim()])
                                newUrl.clear()
                            }
                        }
                    }
                    QQC.Label {
                        text: win.tr("Google Calendar → Settings → your calendar → Integrate calendar → Secret address in iCal format.")
                        wrapMode: Text.Wrap
                        Layout.maximumWidth: 300
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                    RowLayout {
                        visible: win.calendar !== null && win.calendarUrls.length > 0
                        QQC.Button {
                            text: win.tr("Refresh now")
                            icon.name: "view-refresh"
                            onClicked: win.calendar.refresh()
                        }
                        QQC.Label {
                            opacity: 0.7
                            text: !win.calendar || !win.calendar.loaded ? ""
                                : win.calendar.ok ? win.tr("Updated {time}", { time: Qt.formatTime(win.calendar.lastSuccess, "HH:mm") })
                                : win.tr("Couldn't reach the calendar")
                        }
                    }
                }
            }
            Page {
                title: win.tr("Weather")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.ButtonGroup { id: placeGroup }
                    QQC.RadioButton {
                        id: autoPlace
                        Kirigami.FormData.label: win.tr("Location:")
                        text: win.tr("Find automatically")
                        QQC.ButtonGroup.group: placeGroup
                        checked: win.prefs.weather.city === ""
                        onToggled: win.prefs.weather.city = ""
                    }
                    QQC.RadioButton {
                        id: manualPlace
                        text: win.prefs.weather.city !== "" ? win.tr("Use {city}", { city: win.prefs.weather.city }) : win.tr("Use a city I choose")
                        QQC.ButtonGroup.group: placeGroup
                        checked: win.prefs.weather.city !== ""
                    }
                    RowLayout {
                        visible: manualPlace.checked
                        QQC.TextField {
                            id: cityField
                            Layout.preferredWidth: 200
                            placeholderText: win.tr("City name")
                            onAccepted: findButton.clicked()
                        }
                        QQC.Button {
                            id: findButton
                            text: win.tr("Find")
                            enabled: cityField.text.trim() !== ""
                            onClicked: win.findCity(cityField.text.trim())
                        }
                    }
                    QQC.Label {
                        id: cityStatus
                        visible: manualPlace.checked && text !== ""
                        opacity: 0.7
                    }
                    QQC.ButtonGroup { id: unitGroup }
                    QQC.RadioButton {
                        Kirigami.FormData.label: win.tr("Temperature:")
                        text: "Celsius (°C)"
                        QQC.ButtonGroup.group: unitGroup
                        checked: !win.prefs.weather.fahrenheit
                        onToggled: win.prefs.weather.fahrenheit = false
                    }
                    QQC.RadioButton {
                        text: "Fahrenheit (°F)"
                        QQC.ButtonGroup.group: unitGroup
                        checked: win.prefs.weather.fahrenheit
                        onToggled: win.prefs.weather.fahrenheit = true
                    }
                }
            }
            Page {
                title: win.tr("Quick buttons")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: [
                            { key: "battery", label: win.tr("Battery") },
                            { key: "volume", label: win.tr("Volume") },
                            { key: "wifi", label: win.tr("Wi-Fi") },
                            { key: "bluetooth", label: win.tr("Bluetooth") },
                            { key: "dnd", label: win.tr("Do not disturb") },
                            { key: "awake", label: win.tr("Keep screen awake") },
                            { key: "screenshot", label: win.tr("Screenshot") },
                            { key: "lock", label: win.tr("Lock screen") }
                        ]
                        delegate: QQC.CheckBox {
                            required property var modelData
                            required property int index
                            Kirigami.FormData.label: index === 0 ? win.tr("Show:") : ""
                            text: modelData.label
                            checked: !win.hiddenButtons.includes(modelData.key)
                            onToggled: win.prefs.quickButtons.hidden = win.toggled(win.hiddenButtons, modelData.key, !checked)
                        }
                    }
                }
            }
            Page {
                title: win.tr("Quick links")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    // One child for the whole list: rows added later would otherwise land at the end of the form.
                    ColumnLayout {
                        Kirigami.FormData.label: win.tr("Links:")
                        Kirigami.FormData.labelAlignment: Qt.AlignTop
                        QQC.Label {
                            visible: win.links.length === 0
                            text: win.tr("None yet")
                            opacity: 0.7
                        }
                        Repeater {
                            model: win.links
                            delegate: RowLayout {
                                required property var modelData
                                required property int index
                                QQC.Label {
                                    Layout.preferredWidth: 220
                                    elide: Text.ElideRight
                                    text: (modelData.name || L.linkName(modelData.url)) + "  ·  " + L.linkName(modelData.url)
                                }
                                QQC.ToolButton {
                                    icon.name: "go-up"
                                    text: win.tr("Move up")
                                    display: QQC.AbstractButton.IconOnly
                                    enabled: index > 0
                                    QQC.ToolTip.text: text
                                    QQC.ToolTip.visible: hovered
                                    onClicked: win.saveLinks(win.moved(win.links, index, index - 1))
                                }
                                QQC.ToolButton {
                                    icon.name: "edit-delete-remove"
                                    text: win.tr("Remove")
                                    display: QQC.AbstractButton.IconOnly
                                    QQC.ToolTip.text: text
                                    QQC.ToolTip.visible: hovered
                                    onClicked: win.saveLinks(win.links.filter((_, i) => i !== index))
                                }
                            }
                        }
                    }
                    QQC.TextField {
                        id: linkAddress
                        Kirigami.FormData.label: win.tr("Add a link:")
                        Layout.preferredWidth: 280
                        placeholderText: win.tr("Site or folder, e.g. ~/Documents")
                        onAccepted: addLink.clicked()
                    }
                    RowLayout {
                        QQC.TextField {
                            id: linkName
                            Layout.preferredWidth: 200
                            placeholderText: win.tr("Name (optional)")
                            onAccepted: addLink.clicked()
                        }
                        QQC.Button {
                            id: addLink
                            text: win.tr("Add")
                            icon.name: "list-add"
                            enabled: linkAddress.text.trim() !== ""
                            onClicked: {
                                const url = L.linkUrl(linkAddress.text, StandardPaths.writableLocation(StandardPaths.HomeLocation).toString())
                                win.saveLinks(win.links.concat([{ name: linkName.text.trim(), url: url }]))
                                linkAddress.clear()
                                linkName.clear()
                            }
                        }
                    }
                    QQC.Label {
                        text: win.tr("They open from the island: ⋯ → Quick links.")
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
            Page {
                title: win.tr("General")
                Kirigami.FormLayout {
                    Layout.fillWidth: true
                    QQC.ComboBox {
                        objectName: "languagePicker"
                        Kirigami.FormData.label: win.tr("Language:")
                        textRole: "label"
                        valueRole: "key"
                        model: [
                            { key: "system", label: win.tr("Follow system") },
                            { key: "de", label: "Deutsch" },
                            { key: "en", label: "English" }
                        ]
                        currentIndex: Math.max(0, model.findIndex(m => m.key === win.prefs.behaviour.language))
                        onActivated: win.prefs.behaviour.language = currentValue
                    }
                    QQC.Switch {
                        Kirigami.FormData.label: win.tr("Start at login:")
                        enabled: win.appConfig !== null
                        checked: win.appConfig ? win.appConfig.autostart : false
                        onToggled: if (win.appConfig) win.appConfig.autostart = checked
                    }
                    QQC.Button {
                        objectName: "tourAgain"
                        Kirigami.FormData.label: win.tr("Getting started:")
                        text: win.tr("Show the tour again")
                        icon.name: "help-hint"
                        onClicked: win.tourRequested()
                    }
                    QQC.Button {
                        text: win.tr("Reset to defaults")
                        icon.name: "edit-reset"
                        onClicked: win.prefs.reset()
                    }
                    QQC.Label {
                        text: win.tr("Your calendars and animation file are kept.")
                        opacity: 0.7
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }

    function findCity(name) {
        cityStatus.text = win.tr("Looking…")
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            let hit = null
            try {
                const results = JSON.parse(xhr.responseText).results
                hit = results && results.length ? results[0] : null
            } catch (e) {}
            if (xhr.status !== 200 || !hit) {
                cityStatus.text = xhr.status === 200 ? win.tr("No city found with that name") : win.tr("Couldn't search right now")
                return
            }
            win.prefs.weather.latitude = hit.latitude
            win.prefs.weather.longitude = hit.longitude
            win.prefs.weather.city = hit.name
            cityStatus.text = win.tr("Using {place}", { place: hit.name + (hit.country ? ", " + hit.country : "") })
            cityField.clear()
        }
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(name))
        xhr.send()
    }

    // The setting a search result led to, flashed for a moment.
    Rectangle {
        id: flash
        property var target: null
        parent: win.contentItem
        z: 100
        radius: 6
        color: "transparent"
        border.color: Kirigami.Theme.highlightColor
        border.width: 2
        opacity: 0
        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: flash; property: "opacity"; to: 1; duration: 120 }
            PauseAnimation { duration: 900 }
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 400 }
        }
    }

    component Page: QQC.ScrollView {
        id: pageView
        property string title
        default property alias content: column.data
        contentWidth: availableWidth
        ColumnLayout {
            id: column
            width: pageView.availableWidth
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Heading {
                Layout.topMargin: Kirigami.Units.largeSpacing * 2
                Layout.leftMargin: Kirigami.Units.largeSpacing * 3
                text: pageView.title
                level: 2
            }
        }
    }

    component SliderRow: RowLayout {
        id: row
        property int from
        property int to
        property int value
        property string suffix
        signal moved(int v)
        QQC.Slider {
            Layout.preferredWidth: 200
            from: row.from
            to: row.to
            stepSize: 1
            value: row.value
            onMoved: row.moved(Math.round(value))
        }
        QQC.Label {
            text: row.value + row.suffix
            Layout.minimumWidth: 60
        }
    }
}
