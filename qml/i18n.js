.pragma library

// Active UI language ("en" or "de"). Defaults to "en" so unit tests run against source strings.
var lang = "en"

function resolve(pref, localeName) {
    if (pref === "de")
        return "de"
    if (pref === "en")
        return "en"
    return String(localeName || "").toLowerCase().startsWith("de") ? "de" : "en"
}

function setLang(pref, localeName) {
    lang = resolve(pref, localeName)
    return lang
}

function isGerman() {
    return lang === "de"
}

function t(key, params) {
    let out = (lang === "de" && DE[key] !== undefined) ? DE[key] : key
    if (params) {
        for (const k in params)
            out = out.replace("{" + k + "}", String(params[k]))
    }
    return out
}

var DE = {
    // --- General / Common ---
    "Join": "Beitreten",
    "Undo": "Rückgängig",
    "now": "jetzt",
    "just now": "gerade eben",
    "Copied": "Kopiert",
    "Copy": "Kopieren",
    "Delete": "Löschen",
    "Clear": "Leeren",
    "Clear all": "Alle löschen",
    "Edit": "Bearbeiten",
    "Add": "Hinzufügen",
    "Remove": "Entfernen",
    "Skip": "Überspringen",
    "Next": "Weiter",
    "Got it": "Verstanden",
    "Start": "Starten",
    "Pause": "Pause",
    "Paused": "Pausiert",
    "Resume": "Fortsetzen",
    "Reset": "Zurücksetzen",
    "Muted": "Stumm",
    "muted": "stumm",
    "mute": "stumm",
    "unmute": "laut",
    "Today": "Heute",
    "Tomorrow": "Morgen",
    "Yesterday": "Gestern",
    "All day": "Ganztägig",
    "None": "Keine",
    "None yet": "Noch keine",
    "Automatic": "Automatisch",
    "Custom…": "Eigene…",
    "Change…": "Ändern…",
    "Find": "Suchen",
    "Move up": "Nach oben",
    "Settings": "Einstellungen",
    "Dynamic Island settings": "Dynamic Island – Einstellungen",

    // --- Island / Pill / Alerts ---
    "Timer": "Timer",
    "Timer paused": "Timer pausiert",
    "{n} jobs": "{n} Aufträge",
    "+{n} more": "+{n} weitere",
    "plug in": "anstecken",
    "in {n} min": "in {n} Min.",
    "On battery": "Akkubetrieb",
    "Plugged in, full": "Angeschlossen, voll",
    "Charging": "Lädt",
    "Fully charged": "Vollständig geladen",
    "Plugged in, not charging": "Angeschlossen, lädt nicht",
    "{time} until full": "noch {time} bis voll",
    "{time} left": "noch {time}",
    "Num Lock on": "Num-Taste ein",
    "Num Lock off": "Num-Taste aus",
    "Caps Lock on": "Feststelltaste ein",
    "Caps Lock off": "Feststelltaste aus",
    "is using the camera": "nutzt die Kamera",
    "is using the microphone": "nutzt das Mikrofon",
    "Downloaded": "Heruntergeladen",
    "Copied file": "Kopiert",
    "Extracted": "Entpackt",
    "Finished": "Abgeschlossen",
    "Download failed": "Download fehlgeschlagen",
    "Copy failed": "Kopieren fehlgeschlagen",
    "Extraction failed": "Entpacken fehlgeschlagen",
    "Job failed": "Auftrag fehlgeschlagen",

    // --- Pill right-click menu ---
    "Resume notifications": "Benachrichtigungen fortsetzen",
    "Pause notifications for 1 hour": "Benachrichtigungen 1 Std. pausieren",
    "Show the island": "Island anzeigen",
    "Hide for 1 hour": "1 Std. ausblenden",

    // --- First-run tour ---
    "Open the panel": "Panel öffnen",
    "Click the island, or press Meta+N from anywhere. Esc or Meta+N closes it.": "Klicke auf die Island oder drücke überall Meta+N. Esc oder Meta+N schließt sie wieder.",
    "Gestures on the pill": "Gesten auf der Pill",
    "Swipe sideways to switch turns; scroll for volume. Middle-click plays or pauses.": "Seitwärts wischen wechselt Ansichten, Scrollen regelt die Lautstärke. Mittelklick startet/pausiert.",
    "Quick menu and settings": "Schnellmenü & Einstellungen",
    "Right-click for timers, do not disturb or hiding. The gear in the panel opens Settings.": "Rechtsklick für Timer, Nicht stören oder Ausblenden. Das Zahnrad im Panel öffnet die Einstellungen.",

    // --- Pomodoro ---
    "Back to focus": "Zurück zum Fokus",
    "{n} minutes of focus": "{n} Minuten Fokus",
    "Time for a break": "Zeit für eine Pause",
    "Break": "Pause",
    "Focus": "Fokus",
    "Long break": "Lange Pause",
    "{phase} · round {n}": "{phase} · Runde {n}",
    "A long break: {n} minutes": "Eine lange Pause: {n} Minuten",
    "{n} minutes": "{n} Minuten",

    // --- Panel tabs ---
    "Home": "Start",
    "Music": "Musik",
    "Sound Mixer": "Audiomixer",
    "Notifications": "Benachrichtigungen",
    "To-Do": "Aufgaben",
    "More": "Mehr",
    "Clipboard": "Zwischenablage",
    "Notes": "Notizen",
    "Shelf": "Ablage",
    "Quick links": "Schnelllinks",
    "Colour picker": "Farbwähler",

    // --- Undo ---
    "Clipboard item deleted": "Zwischenablage-Eintrag gelöscht",
    "Note deleted": "Notiz gelöscht",
    "Task deleted": "Aufgabe gelöscht",

    // --- Music ---
    "Nothing playing": "Keine Wiedergabe",
    "Open {app}": "{app} öffnen",
    "Looking for lyrics…": "Suche Songtext…",
    "Instrumental": "Instrumental",
    "Lyrics are off in Settings": "Songtexte sind in den Einstellungen deaktiviert",
    "No lyrics found for this song": "Kein Songtext für diesen Titel gefunden",

    // --- Timer ---
    "TIMER": "TIMER",
    "Ends at {time}": "Endet um {time}",
    "Drag the tape or scroll to set": "Band ziehen oder scrollen zum Einstellen",
    "Pomodoro": "Pomodoro",
    "25 minutes of focus, then a 5 minute break; every fourth break is 15 minutes": "25 Minuten Fokus, dann 5 Minuten Pause; jede vierte Pause dauert 15 Minuten",
    "End this phase and start the next": "Diese Phase beenden und die nächste starten",

    // --- Weather ---
    "Clear": "Klar",
    "Partly cloudy": "Teilweise bewölkt",
    "Cloudy": "Bewölkt",
    "Fog": "Nebel",
    "Drizzle": "Nieselregen",
    "Rain": "Regen",
    "Snow": "Schnee",
    "Showers": "Schauer",
    "Thunderstorm": "Gewitter",
    "Weather unavailable": "Wetter nicht verfügbar",
    "H {high}° L {low}°": "H {high}° T {low}°",

    // --- Calendar / UpNext ---
    "UP NEXT": "ALS NÄCHSTES",
    "Upcoming": "Anstehend",
    "Holiday": "Feiertag",
    "Festival": "Gedenktag",
    "Add your Google Calendar link to see events here": "Füge deinen Google-Kalender-Link hinzu, um Termine hier zu sehen",
    "Loading events…": "Lade Termine…",
    "Couldn't reach Google Calendar · last updated {time}": "Google Kalender nicht erreichbar · zuletzt aktualisiert {time}",
    "Couldn't reach Google Calendar": "Google Kalender nicht erreichbar",
    "Nothing on this day": "Keine Termine an diesem Tag",
    "Nothing else today or tomorrow": "Heute und morgen keine weiteren Termine",

    // --- Quick buttons & Bluetooth ---
    "Sound mixer · {level} (scroll to change, right-click to {action})": "Audiomixer · {level} (Scrollen zum Ändern, Rechtsklick für {action})",
    "Wi-Fi": "WLAN",
    "Bluetooth": "Bluetooth",
    "{label} (right-click for connected devices)": "{label} (Rechtsklick für verbundene Geräte)",
    "Do not disturb": "Nicht stören",
    "Keep screen awake": "Bildschirm wach halten",
    "Screenshot": "Bildschirmfoto",
    "Lock screen": "Bildschirm sperren",
    "BLUETOOTH DEVICES": "BLUETOOTH-GERÄTE",
    "No devices connected": "Keine Geräte verbunden",

    // --- Mixer ---
    "OUTPUT": "AUSGABE",
    "INPUT": "EINGABE",
    "APPS": "ANWENDUNGEN",
    "Reset all to 100%": "Alle auf 100 % zurücksetzen",
    "No apps are playing sound": "Keine Apps geben Ton wieder",

    // --- Clipboard ---
    "Search what you copied": "Kopiertes durchsuchen",
    "All": "Alle",
    "Text": "Text",
    "Links": "Links",
    "Images": "Bilder",
    "Pinned": "Angepinnt",
    "Recent": "Zuletzt",
    "Nothing matches": "Keine Treffer",
    "Nothing copied yet": "Noch nichts kopiert",
    "PREVIEW": "VORSCHAU",
    "Pin": "Anpinnen",
    "Unpin": "Lösen",
    "Clear history": "Verlauf leeren",
    "Pinned items stay": "Angepinnte Einträge bleiben erhalten",
    "Image · {w} × {h} · {when}": "Bild · {w} × {h} · {when}",
    "Image · {w} × {h}": "Bild · {w} × {h}",
    "Link · {when}": "Link · {when}",
    "Text · {n} characters · {when}": "Text · {n} Zeichen · {when}",
    "{t} ago": "vor {t}",

    // --- Notes ---
    "NOTES": "NOTIZEN",
    "+ New": "+ Neu",
    "Write something…": "Schreibe etwas…",
    "First line is the title": "Die erste Zeile ist der Titel",
    "Saving…": "Speichert…",
    "Saved": "Gespeichert",

    // --- To-Do ---
    "Add a task": "Aufgabe hinzufügen",
    "Nothing to do. Add a task above; the next one shows on the idle pill.": "Nichts zu tun. Füge oben eine Aufgabe hinzu; die nächste erscheint in der Pill.",
    "Clear {n} done": "{n} erledigte löschen",

    // --- Notifications tab ---
    "{n} new": "{n} neu",
    "all seen": "alle gelesen",
    "No notifications": "Keine Benachrichtigungen",
    "New ones will be saved here.": "Neue werden hier gespeichert.",

    // --- Shelf ---
    "SHELF": "ABLAGE",
    "Drag files here to keep them for later": "Dateien hierher ziehen, um sie zwischenzulagern",

    // --- Quick links ---
    "QUICK LINKS": "SCHNELLLINKS",
    "Sites and folders you open every day, one click away": "Webseiten und Ordner, die du täglich öffnest – einen Klick entfernt",
    "Add links in Settings": "Links in den Einstellungen hinzufügen",

    // --- Colour picker ---
    "Pick any colour on your screen": "Wähle eine beliebige Farbe auf dem Bildschirm",
    "Pick a colour": "Farbe aufnehmen",
    "RECENT": "ZULETZT",

    // --- Updates ---
    "Everything is up to date": "Alles ist aktuell",
    "1 update waiting": "1 Update verfügbar",
    "{n} updates waiting": "{n} Updates verfügbar",
    "Update now": "Jetzt aktualisieren",
    "Opens a terminal to run the upgrade": "Öffnet ein Terminal für das System-Update",

    // --- Settings pages & search ---
    "Search settings": "Einstellungen durchsuchen",
    "Nothing matches.": "Keine Treffer.",
    "Look": "Aussehen",
    "Behaviour": "Verhalten",
    "Alerts": "Meldungen",
    "When idle": "Im Leerlauf",
    "Calendar": "Kalender",
    "Weather": "Wetter",
    "Quick buttons": "Schnelltasten",
    "General": "Allgemein",

    // --- Settings: Look ---
    "Style:": "Stil:",
    "Notch, joined to the top edge": "Notch, am oberen Rand angedockt",
    "Pill, floating below the edge": "Pill, schwebend unter dem Rand",
    "Accent colour:": "Akzentfarbe:",
    "Tint music controls with the cover's colour": "Musiksteuerung in der Cover-Farbe einfärben",
    "Colours:": "Farben:",
    "Dark": "Dunkel",
    "Light": "Hell",
    "Follow Plasma": "Plasma folgen",
    "Island colour:": "Island-Farbe:",
    "The theme's colour": "Farbe des Designs",
    "Choose the island's colour": "Island-Farbe wählen",
    "Choose an accent colour": "Akzentfarbe wählen",
    "Opacity:": "Deckkraft:",
    "Blur what shows through": "Hintergrund weichzeichnen",
    "Blur strength:": "Weichzeichner-Stärke:",
    "No blur effect is running in KWin.": "In KWin ist kein Weichzeichner-Effekt aktiv.",
    "KWin has one blur strength for every window, so this changes the blur everywhere.": "KWin nutzt eine gemeinsame Weichzeichner-Stärke für alle Fenster – dies ändert sie systemweit.",
    "KWin has one blur strength for every window, so this changes the blur everywhere (Better Blur DX's setting).": "KWin nutzt eine gemeinsame Weichzeichner-Stärke für alle Fenster – dies ändert sie systemweit (Better Blur DX).",
    "Level bars follow the sound": "Pegelbalken folgen dem Ton",
    "Height:": "Höhe:",
    "Width when empty:": "Breite im Leerlauf:",
    "Width with music or timer:": "Breite bei Musik oder Timer:",
    "Corner roundness:": "Eckenrundung:",
    "Curves at the top:": "Kurven am oberen Rand:",
    "Top of the open panel:": "Kopfzeile im offenen Panel:",
    "Time": "Uhrzeit",
    "Date": "Datum",

    // --- Settings: Behaviour ---
    "Switch music and timer every:": "Musik und Timer wechseln alle:",
    "After a swipe, hold for:": "Nach dem Wischen halten für:",
    "Keep paused music for:": "Pausierte Musik behalten für:",
    "Animation duration:": "Animationsdauer:",
    "Missing song covers:": "Fehlende Albumcover:",
    "Look up on iTunes (sends the artist and title to Apple)": "Bei iTunes suchen (sendet Interpret und Titel an Apple)",
    "Lyrics:": "Songtexte:",
    "Show lyrics in the Music tab (sends the song to the sources below when shown)": "Songtexte im Musik-Tab anzeigen (sendet den Titel bei Bedarf an die Quellen unten)",
    "Show the line being sung in place of the title on the pill": "Aktuelle Textzeile statt des Titels in der Pill anzeigen",
    "Lyrics sources:": "Songtext-Quellen:",
    "word by word": "Wort für Wort",
    "word by word, a big catalogue": "Wort für Wort, großer Katalog",
    "line by line, the last choice": "Zeile für Zeile, Fallback",
    "Open the panel:": "Panel öffnen:",
    "On click": "Per Klick",
    "When the pointer rests on it": "Wenn der Mauszeiger darauf ruht",

    // --- Settings: Alerts ---
    "Show:": "Anzeigen:",
    "Volume and brightness (hides Plasma's box)": "Lautstärke & Helligkeit (blendet Plasma-OSD aus)",
    "Notifications (hides Plasma's popups)": "Benachrichtigungen (blendet Plasma-Popups aus)",
    "Microphone and camera in use": "Mikrofon- & Kamerazugriff",
    "Bluetooth devices connecting": "Verbindende Bluetooth-Geräte",
    "Join button for meetings": "Beitreten-Button für Meetings",
    "Charger plugged in or out": "Ladegerät angesteckt / getrennt",
    "Downloads and file copies": "Downloads & Dateikopien",
    "Over full-screen apps:": "Über Vollbild-Apps:",
    "Volume and brightness": "Lautstärke & Helligkeit",
    "Show all notifications": "Alle Benachrichtigungen anzeigen",
    "Urgent apps:": "Dringende Apps:",
    "Apps show up here once they send a notification.": "Apps erscheinen hier, sobald sie eine Benachrichtigung senden.",
    "History:": "Verlauf:",
    "Save notifications": "Benachrichtigungen speichern",
    "Keep them for:": "Aufbewahren für:",
    "1 day": "1 Tag",
    "7 days": "7 Tage",
    "30 days": "30 Tage",
    "Save from:": "Speichern von:",
    "System": "System",
    "Apps": "Apps",
    "Others": "Sonstige",

    // --- Settings: When idle ---
    "Glances": "Kurzinfos",
    "My animation": "Eigene Animation",
    "Nothing": "Nichts",
    "Glances:": "Kurzinfos:",
    "Events starting in 30 minutes or less": "Termine in den nächsten 30 Minuten",
    "Battery (warns at 15% or less)": "Akku (warnt ab 15 % oder weniger)",
    "Pending system updates": "Ausstehende System-Updates",
    "Next task from the To-Do list": "Nächste Aufgabe aus der To-Do-Liste",
    "Animation:": "Animation:",
    "Aurora": "Polarlicht",
    "Wave": "Welle",
    "Fireflies": "Glühwürmchen",
    "Cat": "Katze",
    "My own GIF or WebP…": "Eigenes GIF oder WebP…",
    "File:": "Datei:",
    "Point at the island to see it play.": "Zeige auf die Island, um die Animation abzuspielen.",
    "Only play when the pointer is on the island": "Nur abspielen, wenn der Mauszeiger darauf liegt",
    "Choose an animation": "Animation wählen",

    // --- Settings: Calendar ---
    "Holidays and festivals:": "Feiertage & Gedenktage:",
    "Include festivals and religious days, not only public holidays": "Auch Gedenk- und religiöse Tage einschließen (nicht nur gesetzliche Feiertage)",
    "Check for changes every:": "Auf Änderungen prüfen alle:",
    "Calendars:": "Kalender:",
    "Add a calendar:": "Kalender hinzufügen:",
    "Secret address in iCal format": "Geheime Adresse im iCal-Format",
    "Google Calendar → Settings → your calendar → Integrate calendar → Secret address in iCal format.": "Google Kalender → Einstellungen → dein Kalender → Kalender integrieren → Geheime Adresse im iCal-Format.",
    "Refresh now": "Jetzt aktualisieren",
    "Updated {time}": "Aktualisiert {time}",
    "Couldn't reach the calendar": "Kalender nicht erreichbar",

    // --- Settings: Weather ---
    "Location:": "Standort:",
    "Find automatically": "Automatisch ermitteln",
    "Use {city}": "{city} verwenden",
    "Use a city I choose": "Eigene Stadt wählen",
    "City name": "Stadtname",
    "Temperature:": "Temperatur:",
    "Looking…": "Suche…",
    "No city found with that name": "Keine Stadt mit diesem Namen gefunden",
    "Couldn't search right now": "Suche derzeit nicht möglich",
    "Using {place}": "Verwende {place}",

    // --- Settings: Quick buttons & Quick links ---
    "Battery": "Akku",
    "Volume": "Lautstärke",
    "Links:": "Links:",
    "Add a link:": "Link hinzufügen:",
    "Site or folder, e.g. ~/Documents": "Webseite oder Ordner, z. B. ~/Dokumente",
    "Name (optional)": "Name (optional)",
    "They open from the island: ⋯ → Quick links.": "Zu öffnen über die Island: ⋯ → Schnelllinks.",

    // --- Settings: General ---
    "Language:": "Sprache:",
    "Follow system": "Systemsprache",
    "Monitor:": "Monitor:",
    "Automatic (Primary)": "Automatisch (Primär)",
    "Week starts on:": "Woche beginnt am:",
    "Monday": "Montag",
    "Sunday": "Sonntag",
    "Night Color": "Nachtfarbe",
    "Power profile": "Energieprofil",
    "Power profile: {profile}": "Energieprofil: {profile}",
    "Power Saver": "Energiesparen",
    "Balanced": "Ausgeglichen",
    "Performance": "Leistung",
    "Screen recording": "Bildschirmaufnahme",
    "Start at login:": "Beim Anmelden starten:",
    "Getting started:": "Erste Schritte:",
    "Show the tour again": "Tour erneut anzeigen",
    "Reset to defaults": "Auf Standard zurücksetzen",
    "Your calendars and animation file are kept.": "Deine Kalender und deine Animationsdatei bleiben erhalten."
}
