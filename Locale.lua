local ADDON_NAME = ...
ForeverCooldowns = ForeverCooldowns or {}
local FCD = ForeverCooldowns

-- Sprachen.
--
-- Die Schlüssel sind die deutschen Zeichenketten selbst, nicht erfundene
-- Kürzel wie L.ALIGNMENT. Das hat zwei Gründe: der Code bleibt lesbar - man
-- sieht beim Lesen, was auf dem Schirm steht, statt ein Kürzel nachschlagen
-- zu müssen - und eine fehlende Übersetzung fällt auf Deutsch zurück
-- statt auf nil oder auf einen Platzhalter.
--
-- Diese Datei wird als erste geladen, weil einige Module ihre Beschriftungen
-- schon beim Laden in Tabellen ablegen.

local translations = {}

-- Leer heißt Deutsch: dann liefert der Nachschlag den Schlüssel selbst.
local active = {}

local L = setmetatable({}, {
    __index = function(_, key)
        return active[key] or key
    end,
})
FCD.L = L

-- Rückgabe: der Sprachcode, der tatsächlich gilt ("deDE" oder "enUS")
function FCD.SetLanguage(code)
    if code == "auto" or code == nil then
        local client = type(GetLocale) == "function" and GetLocale() or "enUS"
        code = (type(client) == "string" and client:sub(1, 2) == "de") and "deDE" or "enUS"
    end
    if code ~= "deDE" and code ~= "enUS" then
        code = "enUS"
    end
    active = (code == "deDE") and {} or (translations[code] or {})
    FCD.language = code
    return code
end

function FCD.GetLanguage()
    return FCD.language or "deDE"
end

-- Damit spätere Dateien nachtragen können, ohne diese hier zu verändern.
function FCD.AddTranslations(code, entries)
    translations[code] = translations[code] or {}
    for key, value in pairs(entries) do
        translations[code][key] = value
    end
    -- Wird nachgetragen, während diese Sprache schon aktiv ist, muss der
    -- Nachschlag die neuen Einträge sehen.
    if FCD.language == code then
        active = translations[code]
    end
end

-- ------------------------------------------------------------- Englisch

FCD.AddTranslations("enUS", {
    -- Leistenfenster: Ausrichtung und Maße
    ["Ausrichtung"] = "Orientation",
    ["Symbolausrichtung"] = "Icon direction",
    ["Horizontal"] = "Horizontal",
    ["Vertikal"] = "Vertical",
    ["Nach rechts"] = "To the right",
    ["Nach links"] = "To the left",
    ["Nach unten"] = "Downwards",
    ["Nach oben"] = "Upwards",
    ["Spalten"] = "Columns",
    ["Symbolgröße"] = "Icon size",
    ["Symbolabstand"] = "Icon spacing",
    ["Transparenz"] = "Opacity",
    ["Balkenbreite"] = "Bar width",
    ["Balkeninhalt"] = "Bar content",
    ["Symbole je Reihe"] = "Icons per row",
    ["Symbol und Name"] = "Icon and name",
    ["Nur Symbol"] = "Icon only",
    ["Nur Name"] = "Name only",

    -- Sichtbarkeit
    ["Sichtbarkeit"] = "Visibility",
    ["Immer sichtbar"] = "Always visible",
    ["Nur im Kampf"] = "In combat only",
    ["Nur mit Ziel"] = "With a target only",
    ["Außerhalb des Kampfes"] = "Out of combat only",
    ["Nie"] = "Never",
    ["Bei Inaktivität verbergen"] = "Hide when inactive",

    -- Schalter
    ["Timer anzeigen"] = "Show timer",
    ["Tooltips anzeigen"] = "Show tooltips",
    ["Beim Anklicken benutzen"] = "Use on click",
    ["Rang anzeigen"] = "Show rank",
    ["Anzahl anzeigen"] = "Show count",
    ["Nicht Gelerntes verbergen"] = "Hide unlearned",

    -- Fertig-Meldung
    ["Melden, wenn bereit"] = "Alert when ready",
    ["Keines"] = "None",
    ["Aus"] = "Off",
    ["Wie Leiste"] = "Same as bar",
    ["Leuchten und Ton"] = "Glow and sound",
    ["Nur Leuchten"] = "Glow only",
    ["Nur Ton"] = "Sound only",
    ["Ton"] = "Sound",
    ["Je Eintrag festlegen"] = "Set per entry",
    ["Fertig-Meldung je Eintrag"] = "Ready alert per entry",
    ["Einzelne Symbole dürfen von der Leiste abweichen -"] =
        "Individual icons may differ from the bar -",
    ["melden, obwohl die Leiste stumm ist, oder umgekehrt."] =
        "alerting although the bar is silent, or the other way round.",
    ["Diese Leiste meldet nichts."] = "This bar alerts for nothing.",
    ["Fertig-Meldung: "] = "Ready alert: ",
    ["Leiste "] = "Bar ",
    ["Zauber "] = "Spell ",
    ["Gegenstand "] = "Item ",

    -- Töne
    ["Schlachtzugswarnung"] = "Raid warning",
    ["Bereitschaftsprüfung"] = "Ready check",
    ["Wecker"] = "Alarm clock",
    ["Quest erledigt"] = "Quest complete",
    ["Sieg"] = "Victory",
    ["Klick"] = "Click",
    ["Standardton"] = "Default sound",

    -- Knöpfe im Leistenfenster
    ["Änderungen verwerfen"] = "Discard changes",
    ["Auf Standardposition zurücksetzen"] = "Reset to default position",
    ["Abklingzeitmanager-Optionen"] = "Cooldown manager options",
    ["Blizzards Fenster öffnen"] = "Open Blizzard's window",

    -- Leisten
    ["Zum Bearbeiten anklicken"] = "Click to edit",

    -- Hinweise aus dem Viewer
    ["Dieser Client kennt SecureActionButtonTemplate nicht -"] =
        "This client does not have SecureActionButtonTemplate -",
    ["'Beim Anklicken benutzen' bleibt deshalb wirkungslos."] =
        "so 'Use on click' has no effect.",
    ["Dieser Client schützt die Abklingzeit-Werte -"] =
        "This client protects cooldown values -",
    ["das Ende lässt sich damit nicht erkennen."] =
        "so the end of a cooldown cannot be detected.",
    ["Im Kampf lässt sich die Belegung nicht setzen -"] =
        "Click actions cannot be set in combat -",
    [" sie greift nach dem Kampf."] = " it will apply after combat.",
    ["Die Leiste zeigt dieses Symbol gerade nicht -"] =
        "The bar is not showing this icon right now -",
    ["das Aufleuchten ist deshalb nicht zu sehen."] =
        "so the glow cannot be seen.",

    -- Bearbeitungsmodus-Fenster für Blizzards Leisten
    ["Diese Einstellung ließ sich nicht setzen - Einzelheiten in /fcd log."] =
        "This setting could not be applied - details in /fcd log.",
    ["Unser Fenster ließ sich nicht öffnen - Einzelheiten in /fcd log."] =
        "Our window could not be opened - details in /fcd log.",
    ["Leistenfenster ließ sich nicht übernehmen - /fcd log."] =
        "Could not take over the bar window - /fcd log.",
    ["Ihr Fenster ließ sich nicht öffnen."] = "Their window could not be opened.",
    ["Im Bearbeitungsmodus erscheint wieder ihr Fenster."] =
        "Edit Mode shows their window again.",
    ["Im Bearbeitungsmodus erscheint unser Fenster."] =
        "Edit Mode shows our window.",
    ["Eigenes Fenster im Bearbeitungsmodus ist derzeit "] =
        "Our own window in Edit Mode is currently ",
    [". Umschalten mit  /fcd editui on  bzw.  off"] =
        ". Toggle with  /fcd editui on  or  off",

    -- Log-Zeilen. Sie stehen nur in /fcd log, gehören aber genauso
    -- übersetzt: wer das AddOn auf Englisch benutzt, schickt auch ein
    -- englisches Log, wenn etwas nicht geht.
    ["Haken auf ihrem Bearbeitungsmodus-Fenster gesetzt."] =
        "Hooked their Edit Mode window.",
    ["Ihr Leistenfenster geht auf: "] = "Their bar window is opening: ",
    ["keine Abklingzeit-Leiste"] = "not a cooldown bar",
    ["Keine Übernahme: Einstellung="] = "No takeover: setting=",
    ["Übernahme fehlgeschlagen: "] = "Takeover failed: ",
    ["Übernommen: Ebene=%s, Höhe=%.0f, links=%s, oben=%s, Deckkraft=%s, offen=%s"] =
        "Taken over: strata=%s, height=%.0f, left=%s, top=%s, alpha=%s, shown=%s",
    ["Eigenes Leistenfenster fehlgeschlagen: "] = "Our own bar window failed: ",
    ["Eigenes Leistenfenster hat abgelehnt (Enum oder Verwalter fehlt)."] =
        "Our own bar window declined (enum or manager missing).",
    ["Eigenes Leistenfenster war zu - erneut geöffnet."] =
        "Our own bar window was closed - reopened.",
    [" (Sollte nicht mehr vorkommen, seit es nicht mehr in"] =
        " (Should no longer happen now that it is not in",
    [" UISpecialFrames steht.)"] = " UISpecialFrames.)",
    ["Leistenfenster zu: "] = "Bar window closed: ",
    ["von außen"] = "from outside",
    ["Einstellung nicht geschrieben: "] = "Setting not written: ",
    ["Kein Enum für "] = "No enum for ",
    [" - Feld bleibt weg."] = " - leaving the field out.",
    [" nutzt Enum "] = " uses enum ",
    ["|cffff6060Dieser Client schützt die"] = "|cffff6060This client protects",
    [" Abklingzeit-Werte - es meldet nichts von selbst.|r"] =
        " cooldown values - nothing alerts by itself.|r",
-- ------------------------------------------------------------- Panel

    ["Suchtext eingeben"] = "Search",
    ["Profil"] = "Profile",
    ["Für "] = "For ",
    ["diesen Charakter"] = "this character",
    ["Eigenes Layout"] = "Own layout",
    ["Startlayout"] = "Default layout",
    ["Neues Layout"] = "New layout",
    ["Importieren"] = "Import",
    ["Zum Kopieren anzeigen"] = "Show for copying",
    ["(zum Teilen)"] = "(to share)",
    ["Layout teilen ("] = "Share layout (",
    ["Verwerfen: "] = "Delete: ",
    ["(Blizzard)"] = "(Blizzard)",
    ["(Blizzard, aktiv)"] = "(Blizzard, active)",

    -- Reiter und Abschnitte
    ["Zauber"] = "Spells",
    ["Stärkungseffekte"] = "Buffs",
    ["Eigene Zauber"] = "Own spells",
    ["Gegenstände"] = "Items",
    ["Auswahl"] = "Selection",
    ["Weitere Filter"] = "More filters",
    ["Verschieben nach"] = "Move to",
    ["Auf die Leiste"] = "Onto the bar",
    ["Von der Leiste nehmen"] = "Take off the bar",
    ["+ Zauber aufnehmen..."] = "+ Add a spell...",
    ["+ Gegenstand aufnehmen..."] = "+ Add an item...",
    ["Blizzards Fenster..."] = "Blizzard's window...",
    ["Rückgängig"] = "Undo",
    ["%s  (%d, davon %d gelernt)"] = "%s  (%d, %d of them known)",

    -- Hinweise und Tooltips im Panel
    ["Ziehen verschiebt zwischen den Abschnitten,"] =
        "Drag to move between sections,",
    [" Doppelklick blendet aus."] = " double-click to hide.",
    [" Rechtsklick entfernt Eigene."] = " right-click removes your own.",
    ["Doppelklick legt auf die Leiste,"] = "Double-click puts it on the bar,",
    ["Das steht nicht in der eigenen Liste - es kommt aus Tasche"] =
        "This is not on your own list - it comes from your bags",
    [" oder Ausrüstung."] = " or equipment.",
    ["Neu laden - behebt Blizzards Fehlermeldungen"] =
        "Reload - clears Blizzard's error messages",
    ["Änderungen anwenden (Neuladen)"] = "Apply changes (reload)",
    ["   |   "] = "   |   ",
    ["Forever Cooldowns"] = "Forever Cooldowns",

    -- Meldungen des Panels
    ["'%s' aufgenommen."] = "'%s' added.",
    ["Nicht aufgenommen: "] = "Not added: ",
    ["%s angewendet (%d Änderungen)."] = "%s applied (%d changes).",
    ["Nicht angewendet: "] = "Not applied: ",
    ["%d Abklingzeit(en) nach '%s' - sofort wirksam."] =
        "%d cooldown(s) moved to '%s' - effective immediately.",
    ["%d Abklingzeit(en) nach '%s' - wirksam nach dem Neuladen."] =
        "%d cooldown(s) moved to '%s' - effective after reloading.",
    ["Nichts zurückzunehmen: "] = "Nothing to undo: ",
    [" wiederhergestellt."] = " restored.",
    ["Sicherung von "] = "Backup from ",
    ["Kein Profil aktiv - ohne Profil gibt es keine Leiste."] =
        "No profile active - without one there is no bar.",
    ["Layout nicht lesbar: "] = "Layout not readable: ",
    ["Nicht lesbar: "] = "Not readable: ",
    ["Schreiben fehlgeschlagen: "] = "Write failed: ",
    ["Abgelehnt: "] = "Rejected: ",
    ["Abgebrochen, Rundlauf fehlerhaft: "] = "Aborted, round trip faulty: ",

    -- Sofortmodus
    ["Sofortmodus an - Änderungen wirken ohne Neuladen."] =
        "Instant mode on - changes apply without reloading.",
    ["Sofortmodus aus - Änderungen wirken beim nächsten Neuladen,"] =
        "Instant mode off - changes apply on the next reload,",
    ["dafür bleibt Blizzards Aurenanzeige unberührt."] =
        "and Blizzard's aura display stays untouched.",
    ["Im Kampf wird nicht sofort geschrieben - der Taint würde Blizzards"] =
        "No instant write in combat - the taint would block Blizzard's",
    ["Fenster blockieren. Die Änderung wird sicher gespeichert und"] =
        "windows. The change is stored safely and",
    ["greift nach dem nächsten Neuladen."] = "applies on the next reload.",
    ["Blizzards Viewer wirft seit der Änderung Fehler bei Auren."] =
        "Blizzard's viewer has been throwing aura errors since the change.",
    ["Ein /reload räumt das auf - die Änderungen bleiben erhalten."] =
        "A /reload clears that up - your changes are kept.",

    -- Blizzards Fenster
    ["Blizzards Fenster ist in diesem Client nicht vorhanden."] =
        "This client does not have Blizzard's window.",
    ["Im Kampf wird ihr Fenster nicht angefasst."] =
        "Their window is not touched in combat.",
    ["Panel ließ sich nicht öffnen - Einzelheiten in /fcd log."] =
        "The panel could not be opened - details in /fcd log.",
    ["Haken auf ihrem Fenster gesetzt."] = "Hooked their window.",
    ["Haken auf ihrem Fenster ließ sich nicht setzen."] =
        "Could not hook their window.",
    ["Ihr Fenster geht auf."] = "Their window is opening.",
    ["Keine Übernahme: Einstellung=%s, Ausnahme=%s, Kampf=%s"] =
        "No takeover: setting=%s, exception=%s, combat=%s",
    ["Verdrängen fehlgeschlagen: "] = "Takeover failed: ",
    ["Verdrängt: Bearbeitungsmodus=%s, ihres noch offen=%s, ihre Ebene=%s, unsere Ebene=%s"] =
        "Taken over: edit mode=%s, theirs still shown=%s, their strata=%s, ours=%s",
-- --------------------------------------------------------- Befehle

    ["/fcd - Blizzards Abklingzeit-Einstellungen mit unserem Panel öffnen"] =
        "/fcd - open Blizzard's cooldown settings with our panel",
    ["/fcd dock - Panel neben Blizzards Fenster ein-/ausblenden"] =
        "/fcd dock - show or hide the panel next to Blizzard's window",
    ["/fcd wide - zwischen schmaler und breiter Ansicht wechseln"] =
        "/fcd wide - switch between the narrow and wide view",
    ["/fcd instant on|off - sofort wirksam (Standard) oder erst nach /reload"] =
        "/fcd instant on|off - apply immediately (default) or only after /reload",
    ["/fcd log - alle bisherigen Ausgaben zum Kopieren"] =
        "/fcd log - all output so far, ready to copy",
    ["/fcd store - Bestand sofort in Blizzards Layout sichern"] =
        "/fcd store - save your data into Blizzard's layout right now",
    ["/fcd blizz - Blizzards Fenster holen (Layout wechseln)"] =
        "/fcd blizz - fetch Blizzard's window (to switch layouts)",
    ["/fcd replace on|off - ob FCD an die Stelle ihres Fensters tritt"] =
        "/fcd replace on|off - whether FCD takes the place of their window",
    ["/fcd editui on|off - eigenes Fenster im Bearbeitungsmodus"] =
        "/fcd editui on|off - our own window in Edit Mode",
    ["/fcd lang de|en|auto - Sprache der Oberfläche"] =
        "/fcd lang de|en|auto - interface language",
    ["/fcd round on|off - abgerundete Symbolecken (wirkt nach /reload)"] =
        "/fcd round on|off - rounded icon corners (applies after /reload)",
    ["/fcd check - Funktionsprüfung dieses Clients im Chat"] =
        "/fcd check - feature check for this client, in chat",
    ["/fcd probe - vollständigen API-Bericht als Text öffnen"] =
        "/fcd probe - open the full API report as text",
    ["/fcd report - Abgleich mit dem Blizzard-Manager"] =
        "/fcd report - comparison with Blizzard's manager",
    ["/fcd layout - Layout-Daten des Blizzard-Managers anzeigen"] =
        "/fcd layout - show the layout data of Blizzard's manager",
    ["/fcd layouttest - prüfen, ob sie beschreibbar sind (ändert nichts)"] =
        "/fcd layouttest - check whether it is writable (changes nothing)",
    ["/fcd roundtrip - prüfen, ob ein Blob bitgleich neu erzeugt werden kann"] =
        "/fcd roundtrip - check whether a blob can be rebuilt bit for bit",
    ["/fcd snapshot - Layout-Stand sichern, /fcd diff - Änderungen anzeigen"] =
        "/fcd snapshot - save the layout state, /fcd diff - show changes",
    ["/fcd hide|show <AbklingzeitID> - im Blizzard-Manager aus-/einblenden"] =
        "/fcd hide|show <cooldownID> - hide or show it in Blizzard's manager",
    ["/fcd state <AbklingzeitID> - Blob- und API-Zustand nebeneinander"] =
        "/fcd state <cooldownID> - blob and API state side by side",
    ["/fcd trace [Filter] | off - Ereignisse mitschneiden"] =
        "/fcd trace [filter] | off - record events",
    ["/fcd find <Text> - Globals, C_*-Namespaces und Enums durchsuchen"] =
        "/fcd find <text> - search globals, C_* namespaces and enums",
    ["/fcd dump <Name> - Mitglieder eines Objekts auflisten"] =
        "/fcd dump <name> - list the members of an object",
    ["/fcd shown - welche benannten Rahmen gerade offen sind"] =
        "/fcd shown - which named frames are open right now",
    ["/fcd layouts - Blizzards Layout-Liste"] = "/fcd layouts - Blizzard's layout list",
    ["/fcd editmode - Rahmen und Schreibwege ihres Bearbeitungsmodus"] =
        "/fcd editmode - frames and write paths of their Edit Mode",
    ["/fcd editsettings - Einstellungen der angeklickten Leiste"] =
        "/fcd editsettings - settings of the bar you clicked",
    ["/fcd editset <Name> <Wert> - eine davon probeweise setzen"] =
        "/fcd editset <name> <value> - set one of them as a test",
    ["/fcd instances - laufende Objekte des Managers suchen"] =
        "/fcd instances - look for live objects of the manager",
    ["/fcd compare - unsere Kategorien gegen Blizzards halten (taintet)"] =
        "/fcd compare - hold our categories against Blizzard's (taints)",
    ["/fcd fields - Felderverteilung der Cache-Einträge je Kategorie"] =
        "/fcd fields - field distribution of the cache entries per category",
    ["/fcd art on - Blizzards Grafik abschauen (aus, kosmetisch)"] =
        "/fcd art on - borrow Blizzard's artwork (off, cosmetic)",
    ["/fcd backups - Sicherungen auflisten, /fcd restore - letzte zurücknehmen"] =
        "/fcd backups - list backups, /fcd restore - undo the last one",
    ["/fcd unlock | lock - Leisten bewegen oder festsetzen"] =
        "/fcd unlock | lock - make bars movable or fix them in place",
    ["/fcd profiles - Profile auflisten"] = "/fcd profiles - list profiles",
    ["/fcd profile <Name> - Profil aktivieren"] = "/fcd profile <name> - activate a profile",
    ["/fcd export | import - Profil teilen"] = "/fcd export | import - share a profile",
    ["/fcd rule form <FormID> <Profil> - Profilwechsel bei Haltung/Form"] =
        "/fcd rule form <formID> <profile> - switch profile on stance or form",
    ["/fcd rule combat <on|off> <Profil> - Profilwechsel im Kampf"] =
        "/fcd rule combat <on|off> <profile> - switch profile in combat",
    ["/fcd rules - Regeln auflisten, /fcd rule remove <Nummer>"] =
        "/fcd rules - list rules, /fcd rule remove <number>",
    ["/fcd spell <ZauberID> - beliebigen Zauber aufnehmen"] =
        "/fcd spell <spellID> - add any spell",
    ["/fcd item <ItemID> - Item dauerhaft in den Katalog aufnehmen"] =
        "/fcd item <itemID> - add an item to the catalogue for good",
    ["/fcd form - aktuelle Form-/Haltungs-ID anzeigen"] =
        "/fcd form - show the current form or stance ID",
    ["/fcd rescan - Zauberbuch und Katalog neu einlesen"] =
        "/fcd rescan - read the spellbook and catalogue again",
    ["/fcd undo - letzte Änderung zurücknehmen"] = "/fcd undo - undo the last change",
    ["/fcd instant on   - sofort wirksam, taintet Blizzards Viewer"] =
        "/fcd instant on   - immediate, taints Blizzard's viewer",
    ["/fcd instant off  - sicher, wirkt nach /reload"] =
        "/fcd instant off  - safe, applies after /reload",
    ["/fcd öffnet den Editor, /fcd log zeigt diese Ausgaben"] =
        "/fcd opens the editor, /fcd log shows this output",
    [" zum Kopieren."] = " ready to copy.",

    -- ------------------------------------------------ Fenstertitel

    ["Bisherige Ausgaben"] = "Output so far",
    ["Ereignis-Mitschnitt"] = "Event recording",
    ["Offene Rahmen"] = "Open frames",
    ["Bearbeitungsmodus"] = "Edit Mode",
    ["Einstellungen der Leiste"] = "Bar settings",
    ["Blizzards Layout-Liste"] = "Blizzard's layout list",
    ["Layout-Daten des Abklingzeit-Managers"] = "Layout data of the cooldown manager",
    ["Vergleich der Layout-Daten"] = "Layout data comparison",
    ["Zustand einer Abklingzeit"] = "State of a cooldown",
    ["Abgleich der Kategorien"] = "Category comparison",
    ["Felderanalyse"] = "Field analysis",
    ["Laufende Objekte"] = "Live objects",
    ["Suche in der Client-API"] = "Search in the client API",
    ["Inhalt eines Objekts"] = "Contents of an object",
    ["Forever Cooldowns - API-Bericht"] = "Forever Cooldowns - API report",
    ["Forever Cooldowns - Katalogbericht"] = "Forever Cooldowns - catalogue report",
    ["Profil exportieren"] = "Export profile",
    ["Profil importieren"] = "Import profile",
    ["Leisten-Optionen"] = "Bar options",
    ["Strg+A markiert alles, Strg+C kopiert."] =
        "Ctrl+A selects everything, Ctrl+C copies.",

    -- ------------------------------------------------ Abfragen und Dialoge

    ["Name der Kopie:"] = "Name of the copy:",
    ["Name des neuen Profils:"] = "Name of the new profile:",
    ["Name für das Layout-Profil:"] = "Name for the layout profile:",
    ["Layout '%s' wirklich verwerfen?"] = "Really delete layout '%s'?",
    ["Keine Zauber-ID erkannt."] = "No spell ID recognised.",
    ["Keine Gegenstands-ID erkannt."] = "No item ID recognised.",

    -- ------------------------------------------------ Meldungen

    ["Panel geöffnet."] = "Panel opened.",
    ["Panel geschlossen."] = "Panel closed.",
    ["Geschlossen."] = "Closed.",
    ["Schmale Ansicht."] = "Narrow view.",
    ["Breite Ansicht."] = "Wide view.",
    ["Unbekannter Befehl."] = "Unknown command.",
    ["Fehler im Befehl /fcd "] = "Error in the command /fcd ",
    ["Fehler: "] = "Error: ",
    ["Noch nichts ausgegeben."] = "Nothing has been output yet.",
    ["Nichts rückgängig zu machen."] = "Nothing to undo.",
    ["Rückgängig: "] = "Undone: ",
    ["Geschrieben: "] = "Written: ",
    ["Abgelehnt: "] = "Rejected: ",
    ["Nicht geschrieben: "] = "Not written: ",
    ["Nicht gespeichert: "] = "Not saved: ",
    ["Nicht verworfen: "] = "Not deleted: ",
    ["Nicht aufgenommen: "] = "Not added: ",
    ["Lesen fehlgeschlagen: "] = "Read failed: ",
    ["Wiederherstellen fehlgeschlagen: "] = "Restore failed: ",
    ["Import fehlgeschlagen: "] = "Import failed: ",
    ["Rundlauf geprüft: "] = "Round trip checked: ",
    ["Sicherung von "] = "Backup from ",
    ["Keine Sicherungen vorhanden."] = "No backups available.",
    ["Keine Layout-Profile gespeichert."] = "No layout profiles saved.",
    ["Keine Leiste ausgewählt."] = "No bar selected.",
    ["Keine Regeln hinterlegt."] = "No rules stored.",
    ["Regel hinzugefügt."] = "Rule added.",
    ["Regel nicht gefunden."] = "Rule not found.",
    ["Regel "] = "Rule ",
    [" entfernt."] = " removed.",
    ["Unbekannte Regelart. /fcd help"] = "Unknown rule type. /fcd help",
    ["Unbekanntes Profil: "] = "Unknown profile: ",
    ["Profil konnte nicht angelegt werden (Name leer oder vergeben)."] =
        "Profile could not be created (name empty or already taken).",
    ["Profil '"] = "Profile '",
    ["Layout '"] = "Layout '",
    ["Layout-Profil '"] = "Layout profile '",
    ["' aktiv."] = "' active.",
    ["' angelegt."] = "' created.",
    ["' gespeichert und aktiv."] = "' saved and active.",
    ["' importiert."] = "' imported.",
    ["' verworfen. Die Zuweisungen bleiben,"] = "' deleted. The assignments stay,",
    [" bis ein anderes Layout gewählt wird."] = " until another layout is chosen.",
    [" ist bereits "] = " is already ",
    ["Leisten können jetzt mit der Maus verschoben werden."] =
        "Bars can now be moved with the mouse.",
    ["Leisten festgesetzt."] = "Bars fixed in place.",
    ["Item "] = "Item ",
    ["Zauber "] = "Spell ",
    [" aufgenommen."] = " added.",
    ["'%s' aufgenommen."] = "'%s' added.",
    ["'%s' aufgenommen - im Reiter Eigene Zauber"] = "'%s' added - on the Own spells tab",
    ["'%s' aufgenommen - steht jetzt im"] = "'%s' added - it is now on the",
    [" Reiter Eigene Zauber."] = " Own spells tab.",
    [" anklicken, um ihn auf die Leiste zu legen."] = " click it to put it on a bar.",
    ["Neu eingelesen: %d Fähigkeiten, %d mit mehreren Rängen, %d Katalogeinträge."] =
        "Read again: %d abilities, %d with several ranks, %d catalogue entries.",
    ["FormID: %s, Index: %s, Formen: %s"] = "FormID: %s, index: %s, forms: %s",
    ["Format: /fcd item <ItemID>"] = "Format: /fcd item <itemID>",
    ["Format: /fcd rule "] = "Format: /fcd rule ",
    [" <Nummer> <Profil>"] = " <number> <profile>",
    ["Format: /fcd rule combat <on|off> <Profil>"] =
        "Format: /fcd rule combat <on|off> <profile>",
    ["Format: /fcd hide <AbklingzeitID>  bzw.  /fcd show <AbklingzeitID>"] =
        "Format: /fcd hide <cooldownID>  or  /fcd show <cooldownID>",
    ["Die IDs stehen in /fcd layout."] = "The IDs are listed in /fcd layout.",
    ["So: /fcd editset <Name> <Wert>  -  Namen zeigt /fcd editsettings"] =
        "Like this: /fcd editset <name> <value>  -  /fcd editsettings shows the names",

    -- Sofortmodus und Schreibwege
    ["Sofortmodus ist derzeit "] = "Instant mode is currently ",
    ["Sofortmodus AN."] = "Instant mode ON.",
    ["Änderungen wirken jetzt ohne Neuladen - über Blizzards eigenes"] =
        "Changes now apply without reloading - through Blizzard's own",
    ["Datenmodell. Der Preis: sobald AddOn-Code es anfasst, gilt es für"] =
        "data model. The price: once addon code touches it, it counts as",
    ["die restliche Sitzung als tainted, und Blizzards Viewer kann keine"] =
        "tainted for the rest of the session, and Blizzard's viewer can no",
    ["Auren mehr lesen. Betrifft nur ihre Anzeige, nicht unsere, und ein"] =
        "longer read auras. That affects their display, not ours, and a",
    ["/reload setzt es zurück."] = "/reload clears it.",
    ["Sofortmodus AUS. Änderungen werden sicher geschrieben und mit dem"] =
        "Instant mode OFF. Changes are written safely and take effect on the",
    ["nächsten Neuladen wirksam."] = "next reload.",
    ["Stattdessen wird der Layout-Blob über die C-Funktion SetLayoutData"] =
        "Instead the layout blob goes through the C function SetLayoutData",
    ["geschrieben - das taintet nichts."] = "- which taints nothing.",
    ["Weg über Blizzards Lua-Objekte ist aus (beschädigt ihren Viewer)."] =
        "The route through Blizzard's Lua objects is off (it breaks their viewer).",
    ["Solange der Rundlauf den Inhalt nicht erhält, wird nichts geschrieben."] =
        "As long as the round trip loses content, nothing is written.",
    [": Blob geschrieben. Mit  /fcd restore  zurücknehmen."] =
        ": blob written. Undo with  /fcd restore .",
    [": keine Standardkategorie bekannt, kann nicht eingeblendet werden."] =
        ": no default category known, cannot be shown.",
    ["|cffff4040Abgebrochen:|r "] = "|cffff4040Aborted:|r ",
    ["|cffff4040Schreiben fehlgeschlagen:|r "] = "|cffff4040Write failed:|r ",

    -- Blizzards Fenster und Grafik
    ["Blizzards Fenster geht wieder normal auf."] =
        "Blizzard's window opens normally again.",
    ["FCD tritt an die Stelle ihres Fensters."] =
        "FCD takes the place of their window.",
    ["Verdrängung ist derzeit "] = "Takeover is currently ",
    [". Umschalten mit  /fcd replace on  bzw.  off"] =
        ". Toggle with  /fcd replace on  or  off",
    [". Umschalten mit  /fcd round on  bzw.  off"] =
        ". Toggle with  /fcd round on  or  off",
    ["Abgerundete Ecken an - wirkt nach /reload."] =
        "Rounded corners on - applies after /reload.",
    ["Abgerundete Ecken aus - wirkt nach /reload."] =
        "Rounded corners off - applies after /reload.",
    ["Abgerundete Symbolecken sind derzeit "] = "Rounded icon corners are currently ",
    ["Sprache: "] = "Language: ",
    [" - umschalten mit  /fcd lang de|en|auto"] =
        " - switch with  /fcd lang de|en|auto",
    [" - wirkt nach /reload."] = " - applies after /reload.",
    ["Im Kampf wird Blizzards Fenster nicht angefasst - zeige nur das Panel."] =
        "Blizzard's window is not touched in combat - showing only the panel.",
    ["Blizzards Fenster lässt sich nicht öffnen - zeige nur das Panel."] =
        "Blizzard's window cannot be opened - showing only the panel.",
    ["Abklingzeit-Einstellungen geöffnet, Panel dockt rechts an."] =
        "Cooldown settings opened, the panel docks to the right.",
    ["Es erscheint sonst automatisch neben Blizzards Abklingzeit-Einstellungen."] =
        "Otherwise it appears automatically next to Blizzard's cooldown settings.",
    ["Blizzards Grafik als Vorlage"] = "Blizzard's artwork as a template",
    ["Blizzards Grafik wird nicht mehr übernommen."] =
        "Blizzard's artwork is no longer borrowed.",
    ["Blizzards Grafik wird wieder übernommen, sobald ihr Fenster offen ist."] =
        "Blizzard's artwork will be borrowed again once their window is open.",
    ["Nach einem /reload zeichnet das Panel wieder selbst."] =
        "After a /reload the panel draws its own again.",

    -- Speicher und Anmeldung
    ["Bestand ins Layout geschrieben."] = "Data written into the layout.",
    ["Gegengelesen: der Eintrag steht im Layout."] =
        "Verified: the entry is in the layout.",
    ["|cffff6060Gegengelesen: der Eintrag ist sofort wieder weg|r"] =
        "|cffff6060Verified: the entry is gone again immediately|r",
    [" - der Client verwirft ihn beim Schreiben."] =
        " - the client discards it when writing.",
    ["Kein Bestand im Layout: "] = "No data in the layout: ",
    ["Bestand aus Blizzards Layout"] = "Data from Blizzard's layout",
    [" übernommen (%d Einträge, Datei hatte %d)."] =
        " taken over (%d entries, the file had %d).",
    ["Datei ist aktueller als das Layout"] = "The file is newer than the layout",
    [" (%d gegen %d Einträge)."] = " (%d against %d entries).",
    ["Aus der Datei geladen: %d Profil(e),"] = "Loaded from the file: %d profile(s),",
    [" %d Leiste(n), %d Eintrag/Einträge."] = " %d bar(s), %d entry/entries.",
    [" Eintrag/Einträge."] = " entry/entries.",
    ["Profil '%s' - %s."] = "Profile '%s' - %s.",
    ["Kein Profil aktiv - eigene Leisten bleiben leer."] =
        "No profile active - your own bars stay empty.",
    ["%d Layout-Profil(e): %s. Aktiv: %s."] = "%d layout profile(s): %s. Active: %s.",
    ["geladen. Client %s (Build %s), Interface %d."] =
        "loaded. Client %s (build %s), interface %d.",
    ["Hinweis: .toc meldet Interface %d,"] = "Note: the .toc reports interface %d,",
    [" der Client %d."] = " the client %d.",
    ["Nicht vollständig geladen (keine Datenbank). Meist ein Lua-Fehler beim Start:"] =
        "Not fully loaded (no database). Usually a Lua error at startup:",
    ["Fehlermeldungen einschalten mit  /console scriptErrors 1  und neu laden."] =
        "Turn on error messages with  /console scriptErrors 1  and reload.",
    ["Die kontoweite Datei kam leer an - Bestand aus der"] =
        "The account-wide file arrived empty - data from the",
    [" Zweitablage des Charakters wiederhergestellt."] =
        " character's secondary store restored.",
    ["Gespeicherte Daten kamen verspätet an und wurden"] =
        "Saved data arrived late and was",
    [" nachträglich übernommen."] = " taken over afterwards.",
    ["|cffff6060Aus der Datei kam nichts an|r - die"] =
        "|cffff6060Nothing arrived from the file|r - the",
    [" gespeicherten Daten wurden nicht geladen."] = " saved data was not loaded.",
    ["  ForeverCooldownsDB: %s, FCDStore: %s"] = "ForeverCooldownsDB: %s, FCDStore: %s",
    ["  ForeverCooldownsDB.layoutProfiles existiert nicht."] =
        "  ForeverCooldownsDB.layoutProfiles does not exist.",
    ["  Tabelle vorhanden, "] = "  Table present, ",
    ["== Layout-Profile (Blizzards Kategorien) =="] =
        "== Layout profiles (Blizzard's categories) ==",
    ["== Leisten-Profile (eigene Leisten) =="] = "== Bar profiles (your own bars) ==",
    ["Aktiv laut Einstellungen: "] = "Active according to settings: ",
    ["%d. %s - %s (%d Zeichen)"] = "%d. %s - %s (%d characters)",
    ["%d. %s = %s -> %s"] = "%d. %s = %s -> %s",
    ["  %s%s  (%d Zuweisungen, gesichert %s)"] = "%s%s  (%d assignments, saved %s)",

    -- Mitschnitt und Vergleich
    ["Mitschnitt an - es wird alles aufgezeichnet, hervorgehoben wird '"] =
        "Recording on - everything is recorded, highlighted is '",
    ["Mitschnitt aus - kein einziges Ereignis aufgezeichnet."] =
        "Recording off - not a single event was recorded.",
    ["Jetzt im Blizzard-Fenster etwas ändern, dann  /fcd trace off."] =
        "Now change something in Blizzard's window, then  /fcd trace off.",
    ["  ausgeführt: SetCooldownToCategory, "] = "  ran: SetCooldownToCategory, ",
    [" -> Kategorie "] = " -> category ",
    ["  Datenmodell vorher: "] = "  Data model before: ",
    ["  Datenmodell jetzt:  "] = "  Data model now:    ",
    ["  Statische Abfrage vorher: "] = "  Static query before: ",
    ["  Statische Abfrage jetzt:  "] = "  Static query now:    ",
    ["  vorher: "] = "  before: ",
    ["  jetzt:  "] = "  now:    ",
    ["Das Datenmodell hat sich nicht bewegt - SetCooldownToCategory erwartet"] =
        "The data model did not move - SetCooldownToCategory probably expects",
    ["vermutlich andere Argumente. /fcd dump CooldownViewerSettings.dataProvider"] =
        "different arguments. /fcd dump CooldownViewerSettings.dataProvider",
    ["zeigt, welchen Zustand es führt."] = "shows what state it holds.",
    ["Die statische Abfrage bewegt sich erwartungsgemäß nicht."] =
        "The static query does not move, as expected.",
    ["Ob es wirkt, zeigt Blizzards Fenster nach einem /reload - nicht die"] =
        "Whether it works shows in Blizzard's window after a /reload - not in the",
    ["Abfrage unten, die nur die statische Einordnung meldet."] =
        "query below, which only reports the static assignment.",
    ["Wirkung prüfen: /reload, dann im Blizzard-Fenster den Abschnitt"] =
        "To check: /reload, then in Blizzard's window expand the section",
    ["'Nicht angezeigt' aufklappen - dort muss der Eintrag stehen."] =
        "'Hidden' - the entry has to be there.",
    [" (über Blizzards Datenschicht)"] = " (through Blizzard's data layer)",

    -- Leisteneinstellungen im Editor
    ["Symbolgröße"] = "Icon size",
    ["Symbole pro Zeile"] = "Icons per row",
    ["Abstand"] = "Spacing",
    ["Skalierung"] = "Scale",
    ["Deckkraft"] = "Opacity",
    ["Wachstum"] = "Growth",
    ["Ungelerntes ausblenden"] = "Hide unlearned",
    ["nur laufende Abklingzeiten"] = "only running cooldowns",
    ["immer sichtbar"] = "always visible",
    ["nur im Kampf"] = "in combat only",
    ["nur mit Ziel"] = "with a target only",
    ["Importieren"] = "Import",
-- ------------------------------------------ Funktionsprüfung

    ["Funktionsprüfung für Client-Build "] = "Feature check for client build ",
    ["Eigene Leisten, Layout, Sichtbarkeit"] = "Own bars, layout, visibility",
    ["Mehrfachauswahl und Sammelaktionen"] = "Multi-select and bulk actions",
    ["Profile, Import/Export, Rückgängig"] = "Profiles, import/export, undo",
    ["Rang-Stapelung (immer bester Rang)"] = "Rank stacking (always the highest rank)",
    ["Downranking (fester Rang)"] = "Downranking (a fixed rank)",
    ["Rangzahl auf dem Icon"] = "Rank number on the icon",
    ["Abklingzeit-Anzeige"] = "Cooldown display",
    ["Aufladungen / Stapel"] = "Charges / stacks",
    ["Ressourcen-Abdunklung (zu wenig Wut)"] = "Resource dimming (not enough rage)",
    ["Filter 'nur mit Abklingzeit'"] = "Filter 'with a cooldown only'",
    ["Item- und Schmuckstück-Abklingzeiten"] = "Item and trinket cooldowns",
    ["Aura-/Buff-Verfolgung"] = "Aura and buff tracking",
    ["Abgleich mit dem Blizzard-Manager"] = "Comparison with Blizzard's manager",
    ["Blizzards Kategorien umsortieren"] = "Reordering Blizzard's categories",
    ["... ohne Neuladen wirksam"] = "... effective without reloading",
    ["Fertig-Meldung (Leuchten und Ton)"] = "Ready alert (glow and sound)",
    ["Blizzards Leuchten für 'bereit'"] = "Blizzard's glow for 'ready'",
    ["Ihre Leisten im eigenen Fenster einstellen"] =
        "Configuring their bars in our own window",
    ["Profilwechsel bei Haltung/Form"] = "Profile switch on stance or form",
    ["Profilwechsel bei Spezialisierung"] = "Profile switch on specialisation",
    ["|cffffcc00Hinweis:|r Dieser Client schützt Abklingzeit-Werte. Wischer und Restzeit"] =
        "|cffffcc00Note:|r This client protects cooldown values. The swipe and remaining time",
    [" zeichnet die Blizzard-Uhr; eigene Restzeit, GCD-Unterdrückung und das Abdunkeln"] =
        " are drawn by Blizzard's own clock; our own timer, GCD suppression and dimming",
    [" laufender Abklingzeiten entfallen."] = " of running cooldowns are unavailable.",

    -- ------------------------------------------ Layout-Diagnose

    ["Layout-Verwaltung"] = "Layout management",
    ["Datenmodell"] = "Data model",
    ["GetLayoutData gibt es in diesem Client nicht."] =
        "This client does not have GetLayoutData.",
    ["GetLayoutData lieferte nichts ("] = "GetLayoutData returned nothing (",
    [") - Schreibtest nicht möglich."] = ") - no write test possible.",
    ["SetLayoutData gibt es in diesem Client nicht - Blizzards Kategorien sind nicht beschreibbar."] =
        "This client does not have SetLayoutData - Blizzard's categories cannot be written.",
    ["|cff40dd40SetLayoutData wurde angenommen.|r Unverändert zurückgeschrieben, es hat sich nichts geändert."] =
        "|cff40dd40SetLayoutData was accepted.|r Written back unchanged, nothing was altered.",
    ["Blizzards Kategorien können damit gefahrlos bearbeitet werden."] =
        "Blizzard's categories can therefore be edited safely.",
    ["|cffff4040SetLayoutData abgelehnt:|r "] = "|cffff4040SetLayoutData rejected:|r ",
    ["Die Funktion ist vermutlich geschützt und nur für Blizzard-Code aufrufbar."] =
        "The function is probably protected and callable from Blizzard code only.",
    ["Präfix: "] = "Prefix: ",
    [" Zeichen, Nutzlast: "] = " characters, payload: ",
    ["Entschlüsselt nach Rezept: "] = "Decoded by recipe: ",
    ["|cffff4040Entschlüsseln fehlgeschlagen:|r "] = "|cffff4040Decoding failed:|r ",
    ["|cffff4040Neu zusammensetzen fehlgeschlagen:|r "] =
        "|cffff4040Re-encoding failed:|r ",
    ["|cffff4040Neu erzeugter Blob ist nicht wieder lesbar:|r "] =
        "|cffff4040The rebuilt blob cannot be read again:|r ",
    ["|cff40dd40Rundlauf bitgleich.|r "] = "|cff40dd40Round trip bit for bit.|r ",
    [" Zeichen, identisch zum Original."] = " characters, identical to the original.",
    ["|cff40dd40Inhaltlich gleich.|r Nur die Schlüsselreihenfolge unterscheidet sich,"] =
        "|cff40dd40Same content.|r Only the key order differs,",
    ["was bei CBOR-Maps bedeutungslos ist. Bearbeiten ist damit sicher."] =
        "which is meaningless for CBOR maps. Editing is therefore safe.",
    ["|cffff4040Inhalt weicht ab:|r "] = "|cffff4040Content differs:|r ",
    ["Bytes weichen ab ("] = "bytes differ (",
    [" statt "] = " instead of ",
    [" + "] = " + ",
    ["Solange das so ist, wird nichts geschrieben."] =
        "As long as that is the case, nothing is written.",
    ["Momentaufnahme gespeichert ("] = "Snapshot saved (",
    [" Zeichen). Jetzt im Blizzard-Fenster"] = " characters). Now in Blizzard's window",
    ["etwas ändern, dann  /fcd diff  aufrufen."] = "change something, then run  /fcd diff .",
    [" Zeichen), prüfe den Inhalt..."] = " characters), checking the content...",
    [" Zeichen."] = " characters.",
    ["Sofortmodus: Änderung wirkt. Blizzards Viewer wirft ab jetzt bei"] =
        "Instant mode: the change applies. Blizzard's viewer will now throw",
    ["jedem Aurenereignis einen Fehler - ein /reload behebt das."] =
        "an error on every aura event - a /reload fixes that.",
    ["Dauerhaft vermeiden: Häkchen 'sofort wirksam' abschalten."] =
        "To avoid it for good: turn off the 'apply immediately' checkbox.",

    -- ------------------------------------------ Ausrüstungsplätze

    ["Kopf"] = "Head",
    ["Hals"] = "Neck",
    ["Umhang"] = "Back",
    ["Handschuhe"] = "Hands",
    ["Gürtel"] = "Waist",
    ["Füße"] = "Feet",
    ["Ring 1"] = "Ring 1",
    ["Ring 2"] = "Ring 2",
    ["Schmuckstück 1"] = "Trinket 1",
    ["Schmuckstück 2"] = "Trinket 2",
-- ------------------------------------------ Kategorien und Abschnitte

    ["Verfolgte Stärkungseffekte"] = "Tracked Buffs",
    ["Gruppenstärkungseffekte"] = "Party Buffs",
    ["Gegenstände (verfolgt)"] = "Items (tracked)",
    ["Gegenstände verfolgen"] = "Track items",
    ["Ausgerüstet"] = "Equipped",
    ["Selbst hinzugefügt"] = "Added by you",
    ["Ränge stapeln"] = "Stack ranks",
    [" Ränge - bewegen sich gemeinsam"] = " ranks - they move together",
    ["Änderungen stehen aus"] = "Changes pending",
    ["Eigene Leiste geändert"] = "Own bar changed",
    ["Änderung"] = "Change",
    ["Zurück an Blizzards Fenster andocken."] = "Dock back onto Blizzard's window.",
    ["Die Leiste hat %d Eintrag/Einträge, aber keiner ist ein Gegenstand."] =
        "The bar has %d entry/entries, but none of them is an item.",
    ["Nichts gefunden. Gegenstände aus der Tasche hierher ziehen."] =
        "Nothing found. Drag items here from your bags.",
    ["Nichts ausgewählt.\nSymbole anklicken, Strg für mehrere."] =
        "Nothing selected.\nClick icons, Ctrl for several.",
    ["%d Fähigkeiten\n%d Abklingzeit(en)"] = "%d abilities\n%d cooldown(s)",
    ["Beliebige Zauber-ID oder eingefügten Link - auch was im Zauberbuch nicht steht."] =
        "Any spell ID or a pasted link - including what the spellbook does not list.",
    ["Beliebige Gegenstands-ID oder eingefügten Link - auch was gerade nicht im Beutel liegt."] =
        "Any item ID or a pasted link - including what is not in your bags right now.",
    ["Zauber aufnehmen - ID oder Link einfügen\n(Umschalt-Klick auf einen Zauber fügt den Link ein):"] =
        "Add a spell - paste an ID or link\n(shift-click a spell to insert its link):",
    ["Gegenstand aufnehmen - ID oder Link einfügen\n(Shift-Klick auf einen Gegenstand fügt den Link ein):"] =
        "Add an item - paste an ID or link\n(shift-click an item to insert its link):",
    ["Kein Ereignis enthält '"] = "No event contains '",
    ["Leisten angelegt, aber ohne Einträge"] = "bars created, but without entries",
    ["Das letzte Profil kann nicht gelöscht werden."] =
        "The last profile cannot be deleted.",
    ["Profilstring beschädigt: "] = "Profile string damaged: ",
    ["Profilstring enthält kein gültiges Profil."] =
        "The profile string does not contain a valid profile.",

    -- ------------------------------------------ Layout und Speicher

    ["CooldownViewerDataProvider steht nicht zur Verfügung"] =
        "CooldownViewerDataProvider is not available",
    ["Der Client erlaubt derzeit keine Änderungen (im Kampf?)"] =
        "The client currently allows no changes (in combat?)",
    ["Der Client lehnt die Änderung ab (Status "] =
        "The client rejects the change (status ",
    ["Kein Wiederherstellungspunkt verfügbar"] = "No restore point available",
    ["Entschlüsseln fehlgeschlagen: "] = "Decoding failed: ",
    ["inhaltlich gleich, %d statt %d Zeichen (Schlüsselreihenfolge weicht ab)"] =
        "same content, %d instead of %d characters (key order differs)",
    ["Nicht geschrieben, Blob übersteht die Kette nicht: "] =
        "Not written, the blob does not survive the chain: ",

    -- ------------------------------------------ Katalogbericht

    ["C_CooldownViewer ist in diesem Client nicht lesbar - kein Abgleich möglich."] =
        "C_CooldownViewer cannot be read in this client - no comparison possible.",
    ["Forever Cooldowns läuft dann rein aus dem Zauberbuch."] =
        "Forever Cooldowns then runs purely from the spellbook.",
    ["Manager-Einträge gesamt: %d"] = "Manager entries in total: %d",
    ["Zauber auflöst. Die Kategorien sind lesbar, die Zuordnung nicht -"] =
        "resolves to a spell. The categories are readable, the mapping is not -",
    ["ein inhaltlicher Abgleich ist damit nicht möglich."] =
        "so a comparison by content is not possible.",
    ["  Abklingzeit-ID %s (%s): kein Zauber auflösbar"] =
        "  cooldown ID %s (%s): no spell resolvable",
    ["  %s: %d von %d Rängen im Manager"] = "  %s: %d of %d ranks in the manager",
    ["Gelernte Fähigkeiten mit Abklingzeit, die im Manager fehlen"] =
        "Learned abilities with a cooldown that are missing from the manager",
    ["Manager-Einträge ohne auflösbaren Zauber"] =
        "Manager entries without a resolvable spell",
    ["Fähigkeiten mit unvollständiger Rangabdeckung"] =
        "Abilities with incomplete rank coverage",
    ["Manager-Einträge, die dieser Charakter nicht kennt"] =
        "Manager entries this character does not know",
    ["Zauberbuch: %d Einträge, %d Fähigkeiten, davon %d mit mehreren Rängen."] =
        "Spellbook: %d entries, %d abilities, %d of them with several ranks.",

    -- ------------------------------------------ Diagnoseberichte

    ["== Werkzeuge zum Entschlüsseln =="] = "== Tools for decoding ==",
    ["  C_EncodingUtil fehlt - der Blob lässt sich nicht öffnen."] =
        "  C_EncodingUtil is missing - the blob cannot be opened.",
    ["== Entschlüsselt =="] = "== Decoded ==",
    ["  Schlüssel %s (%d Einträge):"] = "  key %s (%d entries):",
    ["Wenn hier die Zuordnung Kategorie -> Abklingzeit-IDs steht, lässt"] =
        "If the mapping category -> cooldown IDs is shown here, Blizzard's",
    ["sich Blizzards Manager direkt bearbeiten: ändern, neu serialisieren,"] =
        "manager can be edited directly: change it, serialise it again,",
    ["mit SetLayoutData zurückschreiben."] = "write it back with SetLayoutData.",
    ["  Nicht entschlüsselbar: "] = "  Not decodable: ",
    ["  %s  (table, %d Einträge)"] = "  %s  (table, %d entries)",
    ["Eine Vorlage trägt nur Funktionen. Erst ein Objekt mit Zustandsfeldern"] =
        "A template carries functions only. Only an object with state fields",
    ["kann Änderungen wirklich ausführen."] = "can actually carry out changes.",
    ["%d Tabelle(n) waren für AddOn-Code gesperrt und wurden übersprungen."] =
        "%d table(s) were locked for addon code and were skipped.",
    ["== Rückgabe bekannter Einstiegspunkte =="] = "== Return of known entry points ==",
    ["tainted - ein /reload danach räumt das auf."] =
        "tainted - a /reload afterwards clears that up.",
    ["Datenmodell nicht erreichbar. Blizzards Fenster einmal öffnen."] =
        "Data model not reachable. Open Blizzard's window once.",
    ["Forever Cooldowns - Felderanalyse der Cache-Einträge"] =
        "Forever Cooldowns - field analysis of the cache entries",
    ["Gesucht ist ein Feld, dessen Werte die Einträge einer Kategorie so"] =
        "We are looking for a field whose values group the entries of a category",
    ["== Kategorie %d: %d Einträge =="] = "== Category %d: %d entries ==",
    ["dann im Blizzard-Fenster etwas ändern, dann  /fcd diff."] =
        "then change something in Blizzard's window, then  /fcd diff .",
    ["Der Blob ist unverändert - im Blizzard-Fenster hat sich nichts bewegt,"] =
        "The blob is unchanged - nothing moved in Blizzard's window,",
    ["oder die Änderung wird erst beim Schließen des Fensters gespeichert."] =
        "or the change is only saved when the window closes.",
    ["Mindestens einer der beiden Blobs ließ sich nicht entschlüsseln."] =
        "At least one of the two blobs could not be decoded.",
    ["== Geschützte Werte (secret values) =="] = "== Protected values (secret values) ==",
    ["  Abklingzeiten geschützt: "] = "  cooldowns protected: ",
    ["  Aufladungen geschützt:   "] = "  charges protected:    ",
    ["  Benutzbarkeit geschützt: "] = "  usability protected:  ",
    ["  Auren geschützt:         "] = "  auras protected:      ",
    ["== Funktionsprüfung =="] = "== Feature check ==",
    ["  Zauber auflöst. Die Kategorie-Listen sind lesbar, die Zuordnung"] =
        "  resolves to a spell. The category lists are readable, the mapping",
    ["  %s (%d): %s Einträge"] = "  %s (%d): %s entries",
    ["  Einträge gelesen: %d"] = "  entries read: %d",
    ["  Fähigkeiten (Rangfamilien): %d"] = "  abilities (rank families): %d",
    ["  davon mit mehreren Rängen: %d"] = "  of them with several ranks: %d",
    ["  Einträge im Zauberbuch:"] = "  entries in the spellbook:",
    ["    Keine Fähigkeit mit mehreren Rängen gefunden."] =
        "    No ability with several ranks found.",
    ["  Kandidaten (Ausrüstung + Taschen): %d"] = "  candidates (equipment + bags): %d",
    ["%s  (%d Eintrag/Einträge)"] = "%s  (%d entry/entries)",
    [" Einträge)"] = " entries)",
    ["  Maße: %.0f x %.0f"] = "  size: %.0f x %.0f",
    ["%s über %s: %s -> %s"] = "%s via %s: %s -> %s",
    ["kein Fehler, aber Wert unverändert"] = "no error, but the value did not change",
    ["-- Enums für Leisteneinstellungen --"] = "-- Enums for bar settings --",
    ["  Bearbeitungsmodus öffnen, eine ihrer Leisten anklicken,"] =
        "  Open Edit Mode, click one of their bars,",
    [" (Client-Einschränkung)"] = " (client restriction)",
    ["<geschützt>"] = "<protected>",
    [" geschützt."] = " protected.",
    ["vollständig"] = "complete",
    ["SerializeCBOR oder EncodeBase64 fehlt - Selbsttest nicht möglich."] =
        "SerializeCBOR or EncodeBase64 is missing - no self-test possible.",

    -- ------------------------------------------ Grafik abschauen

    ["%s %s (%d Grafiken, %d gleich große)"] = "%s %s (%d textures, %d of equal size)",
    ["Auswahlrahmen übernommen (%d Texturen)."] = "Selection frame borrowed (%d textures).",
    ["== Blizzards Einträge als Vorlage =="] = "== Blizzard's entries as a template ==",
    ["Öffne es und rufe den Befehl erneut auf."] = "Open it and run the command again.",
-- ------------------------------------------ Panel: Abschnitte

    ["Auf der Leiste"] = "On the bar",
    ["Nicht in Blizzards Manager"] = "Not in Blizzard's manager",
    ["Im Manager vorhanden"] = "Present in the manager",
    ["In Taschen"] = "In bags",
    ["Noch nichts gesetzt - unten etwas anklicken."] =
        "Nothing set yet - click something below.",
    ["Die Leiste ist leer - unten etwas anklicken."] =
        "The bar is empty - click something below.",
    ["Symbole hierher ziehen"] = "Drag icons here",
    ["Leiste nicht gefunden. Aktives Profil: %s, Leisten: %d."] =
        "Bar not found. Active profile: %s, bars: %d.",
    ["Kategorie "] = "Category ",
    ["nur gelernte"] = "known only",
    ["nur mit Abklingzeit"] = "with a cooldown only",
    ["sofort wirksam"] = "apply immediately",
    ["Zauber aufnehmen"] = "Add a spell",
    ["Ziehen geht auch."] = "Dragging works too.",
    ["Dieselben Daten, nur mit mehr Platz pro Zeile."] =
        "The same data, just with more room per row.",
    ["Blizzards Abklingzeit-Fenster"] = "Blizzard's cooldown window",
    ["Das Layout wechseln geht nur dort - ihr Layoutverwalter ist"] =
        "Layouts can only be switched there - their layout manager is",
    ["Ziehen: in einen anderen Abschnitt"] = "Drag: into another section",
    ["Doppelklick: von der Leiste nehmen"] = "Double-click: take off the bar",
    ["Doppelklick: auf die Leiste legen"] = "Double-click: put on the bar",
    ["Doppelklick: ein-/ausblenden"] = "Double-click: show or hide",
    ["Rechtsklick: aus der Liste entfernen"] = "Right-click: remove from the list",
    ["Abklingzeit "] = "Cooldown ",
    ["Profil "] = "Profile ",
    ["Leiste"] = "Bar",
    ["Symbol"] = "Icon",

    -- ------------------------------------------ Fertig-Meldung

    ["Diese Leiste meldet: "] = "This bar alerts: ",
    ["Diese Leiste meldet: %s (%s)."] = "This bar alerts: %s (%s).",
    ["unsere Leiste angeklickt"] = "our own bar was clicked",
    ["ihr Fenster ging zu"] = "their window closed",
    ["Bearbeitungsmodus zu"] = "Edit Mode closed",

    -- ------------------------------------------ Profile und Layout

    ["Layout-Profil importieren"] = "Import layout profile",
    ["Kein Name angegeben"] = "No name given",
    ["Unbekanntes Profil"] = "Unknown profile",
    ["Unbekanntes Profil."] = "Unknown profile.",
    ["Kein Text"] = "No text",
    ["Kein Text."] = "No text.",
    ["Kein Layout-Profil (erwartet "] = "Not a layout profile (expected ",
    ["Kein Forever-Cooldowns-Profil (erwartet "] =
        "Not a Forever Cooldowns profile (expected ",
    ["kein Inhalt"] = "no content",
    ["kein Tabelleninhalt"] = "no table content",
    ["unerwartetes Zeichen an Position "] = "unexpected character at position ",
    ["Keine Sicherung vorhanden"] = "No backup available",
    ["Kategorie-Zuordnung im Blob nicht gefunden"] =
        "Category mapping not found in the blob",
    ["Neu erzeugter Blob ist nicht wieder lesbar: "] =
        "The rebuilt blob cannot be read again: ",
    ["Inhalt weicht ab: "] = "Content differs: ",
    ["keine eigenen Leisten in Benutzung"] = "no own bars in use",

    -- ------------------------------------------ Speicher

    ["noch nichts gelesen"] = "nothing read yet",
    ["Im Layout liegt noch kein Bestand."] = "There is no data in the layout yet.",
    ["kein Bestand"] = "no data",
    ["Bestand im Layout ist unlesbar."] = "The data in the layout is unreadable.",
    ["Bestand aus dem Layout gelesen (%d Zeichen)."] =
        "Data read from the layout (%d characters).",
    ["Bestand im Layout gesichert (%d Zeichen)."] =
        "Data saved into the layout (%d characters).",
    ["im Kampf nicht"] = "not in combat",
    ["nichts zu schreiben"] = "nothing to write",

    -- ------------------------------------------ Client-Fähigkeiten

    ["GetLayoutData fehlt in diesem Client"] = "GetLayoutData is missing in this client",
    ["SetLayoutData fehlt in diesem Client"] = "SetLayoutData is missing in this client",
    ["GetGroupBuffItems fehlt in diesem Client"] =
        "GetGroupBuffItems is missing in this client",
    ["GetLayoutData lieferte keine Zeichenkette"] =
        "GetLayoutData returned no string",
    ["C_EncodingUtil.DecodeBase64 fehlt in diesem Client"] =
        "C_EncodingUtil.DecodeBase64 is missing in this client",
    ["Serialisierung oder Base64 fehlt"] = "Serialisation or Base64 is missing",
    ["Keine Kombination aus Zuschnitt, Kompression und Serialisierung passte"] =
        "No combination of trimming, compression and serialisation matched",
    ["]: nur im neuen Blob vorhanden"] = "]: present only in the new blob",
    ["Keine Zauber-ID"] = "No spell ID",
    ["Der Client kennt diese ID nicht"] = "The client does not know this ID",
    ["Der Wert muss eine Zahl sein."] = "The value has to be a number.",
    ["Kein Einstellungs-Enum in diesem Client."] =
        "No settings enum in this client.",
    ["keine settings-Tabelle"] = "no settings table",

    -- ------------------------------------------ Grafik abschauen

    ["noch nicht gesucht"] = "not searched yet",
    ["abgeschaltet mit  /fcd art off"] = "switched off with  /fcd art off",
    ["noch keine eigenen Symbole zum Abgleichen vorhanden."] =
        "no icons of our own to compare against yet.",
    ["Blizzards Fenster ist zu - ohne offenes Fenster gibt es nichts abzulesen."] =
        "Blizzard's window is closed - with it shut there is nothing to read.",
    ["Die Suche im Rahmenbaum ist abgebrochen."] =
        "The search through the frame tree was aborted.",
    ["Kein Eintrag gefunden, der eines unserer Symbole zeigt."] =
        "No entry found that shows one of our icons.",
    ["kein "] = "no ",
    ["Auswahlrahmen im Bearbeitungsmodus nicht gefunden."] =
        "Selection frame not found in Edit Mode.",
    ["Nachbau des Auswahlrahmens erfolglos (%d Texturen)."] =
        "Rebuilding the selection frame failed (%d textures).",
    ["nicht gefunden"] = "not found",
    ["Blizzards Abklingzeit-Fenster ist gerade nicht offen."] =
        "Blizzard's cooldown window is not open right now.",
    ["Eigene Symbole zum Abgleich: %d"] = "Own icons for comparison: %d",
    ["nicht versucht"] = "not attempted",
    ["noch nicht versucht"] = "not attempted yet",
    ["Sinnbilder der Reiter: %s"] = "Tab glyphs: %s",
    ["keine gefunden"] = "none found",
    ["    Symbol %s (%.0fx%.0f) in Rahmen %s (%.0fx%.0f), Masken: %d"] =
        "    icon %s (%.0fx%.0f) in frame %s (%.0fx%.0f), masks: %d",
    ["Davon in ihrem Fenster sichtbar: %d"] = "Of those visible in their window: %d",
    ["-- alle breiten Treffer --"] = "-- all wide hits --",
    ["-- alle quadratischen Treffer --"] = "-- all square hits --",
    [" mit Symbol"] = " with icon",
    [" ohne Symbol"] = " without icon",

    -- ------------------------------------------ Katalogbericht

    ["Dieser Client bietet keine Funktion, die eine Abklingzeit-ID zu einem"] =
        "This client offers no function that resolves a cooldown ID to a",
    ["Vorhandene IDs je Kategorie stehen in /fcd probe."] =
        "The IDs per category are listed in /fcd probe.",
    ["  Abklingzeit-ID %s -> Zauber %d: kein Name im Client"] =
        "  cooldown ID %s -> spell %d: no name in the client",
    ["  %s (bester Rang %s, Zauber %s, CD %.0fs)"] =
        "  %s (highest rank %s, spell %s, CD %.0fs)",
    ["  ... und %d weitere"] = "  ... and %d more",
    ["    ... und %d weitere"] = "    ... and %d more",
    ["  ... und "] = "  ... and ",
    ["    ... und "] = "    ... and ",

    -- ------------------------------------------ Berichtstitel

    ["Forever Cooldowns - Layout-Daten des Abklingzeit-Managers"] =
        "Forever Cooldowns - layout data of the cooldown manager",
    ["Forever Cooldowns - Suche nach '"] = "Forever Cooldowns - search for '",
    ["Forever Cooldowns - Inhalt von "] = "Forever Cooldowns - contents of ",
    ["Forever Cooldowns - Suche nach laufenden Objekten"] =
        "Forever Cooldowns - search for live objects",
    ["Forever Cooldowns - Abgleich der Kategorien"] =
        "Forever Cooldowns - category comparison",
    ["Forever Cooldowns - Zustand einer Abklingzeit"] =
        "Forever Cooldowns - state of a cooldown",
    ["Forever Cooldowns - Vergleich der Layout-Daten"] =
        "Forever Cooldowns - layout data comparison",
    ["Mitglieder von C_*-Namespaces"] = "Members of C_* namespaces",

    -- ------------------------------------------ Layout-Diagnose

    ["GetLayoutData vorhanden: "] = "GetLayoutData present: ",
    ["SetLayoutData vorhanden: "] = "SetLayoutData present: ",
    ["Ohne GetLayoutData ist hier nichts zu holen."] =
        "Without GetLayoutData there is nothing to get here.",
    ["  Alle Kategorien liefern denselben Blob (Argument wird ignoriert)."] =
        "  All categories return the same blob (the argument is ignored).",
    ["== Selbsttest: eigener Blob mit Blizzards Funktionen =="] =
        "== Self-test: our own blob with Blizzard's functions ==",
    ["  Erste Bytes der Layout-Daten: "] = "  First bytes of the layout data: ",
    ["== Zuordnung Kategorie -> Abklingzeiten =="] =
        "== Mapping category -> cooldowns ==",
    ["  Keine Kategorie-Zuordnung gefunden."] = "  No category mapping found.",
    ["    %d -> Zauber %s, %s%s"] = "    %d -> spell %s, %s%s",
    ["  Zum Vergleich, was GetCooldownViewerCategorySet meldet:"] =
        "  For comparison, what GetCooldownViewerCategorySet reports:",
    ["Kein Objekt unter '"] = "No object under '",
    ["' existiert nicht."] = "' does not exist.",
    ["  %-52s (nicht lesbar, gesperrt)"] = "  %-52s (not readable, locked)",
    ["<- sieht nach laufendem Objekt aus"] = "<- looks like a live object",
    ["(nur Vorlage)"] = "(template only)",
    [" - Objekt fehlt oder gesperrt"] = " - object missing or locked",
    ["Liest Blizzards Datenmodell direkt. Das markiert ihren Viewer als"] =
        "Reads Blizzard's data model directly. That marks their viewer as",
    ["GetOrderedCooldownIDsForCategory fehlt in diesem Client."] =
        "GetOrderedCooldownIDsForCategory is missing in this client.",
    ["== %s (%d) ==  Blizzard: %d, wir: %d%s"] = "== %s (%d) ==  Blizzard: %d, us: %d%s",
    ["bei Blizzard, bei uns nicht"] = "in Blizzard's, not in ours",
    ["bei uns, bei Blizzard nicht"] = "in ours, not in Blizzard's",
    ["aufteilen, wie Blizzards Fenster sie aufteilt."] =
        "the way Blizzard's window splits them.",
    ["Felder mit nur einem Wert sind weggelassen - sie trennen nichts."] =
        "Fields with a single value are left out - they separate nothing.",
    ["kein Cache-Eintrag"] = "no cache entry",
    ["Datenmodell nicht erreichbar"] = "Data model not reachable",
    ["in keiner Kategorie des Modells"] = "in no category of the model",
    ["Format: /fcd state <AbklingzeitID>. Die IDs stehen in /fcd layout."] =
        "Format: /fcd state <cooldownID>. The IDs are listed in /fcd layout.",
    ["Abklingzeit %d: %s%s (Zauber %s)"] = "Cooldown %d: %s%s (spell %s)",
    ["Blob nicht lesbar: "] = "Blob not readable: ",
    ["Im Blob: "] = "In the blob: ",
    ["keine Abweichung vom Standard"] = "no deviation from the default",
    ["nicht gelistet"] = "not listed",
    [" von "] = " of ",
    ["keine"] = "none",
    ["Wirksam: "] = "Effective: ",
    ["Cache-Eintrag:"] = "Cache entry:",
    ["Keine Momentaufnahme vorhanden. Erst  /fcd snapshot  aufrufen,"] =
        "No snapshot available. Run  /fcd snapshot  first,",
    ["Momentaufnahme von "] = "Snapshot from ",
    ["      vorher: nicht vorhanden"] = "      before: not present",
    ["      jetzt:  nicht mehr vorhanden"] = "      now:    no longer present",
    ["  Keine - der Blob unterscheidet sich nur in der Kodierung."] =
        "  None - the blob differs only in its encoding.",
    ["  Globale Namen mit 'secret': "] = "  Global names containing 'secret': ",
    ["  in diesem Client unbekannt: "] = "  unknown in this client: ",
    ["== Inhalt von C_CooldownViewer =="] = "== Contents of C_CooldownViewer ==",
    ["  C_CooldownViewer ist keine Tabelle oder leer."] =
        "  C_CooldownViewer is not a table, or is empty.",
    ["== Abklingzeit-Manager =="] = "== Cooldown manager ==",
    ["  Hinweis: Es gibt keine Funktion, die eine Abklingzeit-ID zu einem"] =
        "  Note: there is no function resolving a cooldown ID to a",
    ["  nicht. Der richtige Name steht vermutlich in der Liste oben."] =
        "  not. The right name is probably in the list above.",
    ["  Enum.CooldownViewerCategory nicht vorhanden."] =
        "  Enum.CooldownViewerCategory is not present.",
    ["keine Antwort"] = "no answer",
    ["    Beispiel-Eintrag "] = "    example entry ",
    ["    GetCooldownViewerCacheInfo lieferte keine Tabelle."] =
        "    GetCooldownViewerCacheInfo returned no table.",
    ["  nicht gelernt"] = "  not learned",
    ["    Entweder hat der Charakter noch keine, oder die Untertitel"] =
        "    Either the character has none yet, or the subtitles",
    ["    werden in diesem Client anders geliefert als 'Rang N'."] =
        "    come in a different form than 'Rank N' in this client.",
    ["Registrierung von '%s' (%d AddOns bekannt):"] =
        "Registration of '%s' (%d addons known):",
    ["X-FCD-Toc (steht in der .toc unter SavedVariables)"] =
        "X-FCD-Toc (it sits in the .toc below SavedVariables)",
    ["Nicht ladbar"] = "Not loadable",
    [" gibt es nicht."] = " does not exist.",
    ["  gibt es nicht."] = "  does not exist.",
    ["Nichts gefunden, das nach einer Layout-Liste aussieht."] =
        "Nothing found that looks like a layout list.",
    ["Ist Blizzards Abklingzeit-Fenster offen?"] =
        "Is Blizzard's cooldown window open?",
    ["' - mit >> markiert."] = "' - marked with >>.",

    -- ------------------------------------------ Bearbeitungsmodus-Bericht

    ["-- Globale Namen mit 'EditMode' --"] = "-- Global names containing 'EditMode' --",
    ["  keine - dieser Client kennt den Bearbeitungsmodus nicht"] =
        "  none - this client does not have Edit Mode",
    ["-- Felder von EditModeManagerFrame --"] = "-- Fields of EditModeManagerFrame --",
    ["  keine"] = "  none",
    ["  dann diesen Befehl erneut absetzen."] = "  then run this command again.",
    ["  keine gefunden."] = "  none found.",
    ["-- EditModeManagerFrame: Methoden mit Setting/Change/Update --"] =
        "-- EditModeManagerFrame: methods containing Setting/Change/Update --",
    ["  keine - dann steht der Setzer in einem Mixin."] =
        "  none - then the setter lives in a mixin.",
    ["EditModeSystemSettingsDialog gibt es nicht."] =
        "EditModeSystemSettingsDialog does not exist.",
    ["Ihr Fenster ist zu - erst eine Leiste im Bearbeitungsmodus anklicken."] =
        "Their window is closed - click a bar in Edit Mode first.",
    ["== Einstellungen der angeklickten Leiste =="] =
        "== Settings of the bar you clicked ==",
    ["Leiste: %s  (%s)"] = "Bar: %s  (%s)",
    ["Kein Einstellungs-Enum gefunden - ohne das sind die"] =
        "No settings enum found - without it the numbers of the",
    ["Nummern der Einstellungen nicht zu benennen."] = "settings cannot be named.",
    ["Aus "] = "From ",
    ["|cff888888(hat diese Leiste nicht)|r"] = "|cff888888(this bar does not have it)|r",
    ["-- Ablage der Werte --"] = "-- Where the values are stored --",
    ["  system.systemInfo vorhanden:"] = "  system.systemInfo present:",
    ["  kein system.systemInfo - dann liegt es woanders."] =
        "  no system.systemInfo - then it lives somewhere else.",
    ["  system.settingMap vorhanden ("] = "  system.settingMap present (",
-- Blizzards eigene Kategorienamen, im Wortlaut ihres Fensters.
    ["Essenzielle Abklingzeiten"] = "Essential Cooldowns",
    ["Strategische Abklingzeiten"] = "Utility Cooldowns",
    ["Verfolgte Leisten"] = "Tracked Bars",
    ["Nicht angezeigt"] = "Hidden",
    ["Nicht angezeigt (passiv)"] = "Hidden (passive)",
["Passive zeigen"] = "Show passives",
    ["Schmale Ansicht"] = "Narrow view",
    ["Breite Ansicht"] = "Wide view",
["Verwerfen"] = "Delete",
    ["Abbrechen"] = "Cancel",
["Ihre Leiste geändert. Blizzards Viewer wirft ab jetzt bei"] =
        "Their bar changed. Blizzard's viewer will now throw an error on",
    ["Ziel- und Aurenereignissen einen Fehler - ein /reload behebt das."] =
        "target and aura events - a /reload fixes that.",
    ["Dauerhaft vermeiden: /fcd editui off - dann bleibt ihr Fenster."] =
        "To avoid it for good: /fcd editui off - then their window stays.",
-- Gespiegelte Kategorien: Blizzards Einordnung auf eigenen Leisten.
    ["Diese Kategorie lässt sich nicht spiegeln."] = "This category cannot be mirrored.",
    ["Kein Profil aktiv."] = "No profile active.",
    ["Leiste spiegeln"] = "Mirror bar",
    ["Spiegelung aufheben"] = "Stop mirroring",
    ["Spiegelung lösen"] = "Detach mirror",
    ["Blizzards eigene Leisten zeigen bis zum nächsten Neuladen noch den"] =
        "Blizzard's own bars still show the old state until the next reload.",
    ["alten Stand. Dauerhaft ausblenden - in ihrem Fenster, damit nichts"] =
        "To hide them for good - in their own window, so that nothing gets",
    ["getaintet wird:"] = "tainted:",
    ["  1. /fcd editui off"] = "  1. /fcd editui off",
    ["  2. Bearbeitungsmodus öffnen und ihre Leiste anklicken"] =
        "  2. Open Edit Mode and click their bar",
    ["  3. Haken bei 'Sichtbar' entfernen, Änderungen speichern"] =
        "  3. Untick \"Visible\", save changes",
    ["  4. /fcd editui on, falls unser Fenster zurück soll"] =
        "  4. /fcd editui on if you want our window back",
    ["spiegeln"] = "mirror",
    ["gespiegelt"] = "mirrored",
    ["Auf eigene Leiste spiegeln"] = "Mirror onto own bar",
    ["Legt eine Leiste an, die genau diese Kategorie zeigt."] =
        "Creates a bar that shows exactly this category.",
    ["Wir zeichnen sie selbst: Verschiebungen sind dort sofort zu"] =
        "We draw it ourselves: moves show up there right away,",
    ["sehen, ohne Neuladen und ohne Blizzards Viewer anzufassen."] =
        "without a reload and without touching Blizzard's viewer.",
    ["Die eigene Leiste für diese Kategorie wird entfernt."] =
        "The own bar for this category is removed.",
    ["Blizzards eigene Leiste bleibt davon unberührt."] =
        "Blizzard's own bar is left untouched.",
    ["%d Abklingzeit(en) nach '%s' - auf den gespiegelten Leisten sofort zu sehen."] =
        "%d cooldown(s) moved to '%s' - visible on the mirrored bars right away.",
    ["Sofort sehen statt neu laden: der Knopf 'spiegeln' an der"] =
        "See it now instead of reloading: the \"mirror\" button on the section",
    ["Abschnittsüberschrift legt eine eigene Leiste an, die diese"] =
        "heading creates an own bar showing that category. We draw it",
    ["Kategorie zeigt. Die zeichnen wir selbst - sofort und ohne Fehler."] =
        "ourselves - instant, and without any error.",
    ["'%s' liegt jetzt auf einer eigenen Leiste - Änderungen daran sind dort sofort zu sehen."] =
        "'%s' now has its own bar - changes to it show up there right away.",
    ["Die neue Leiste steht in der Bildschirmmitte; ziehen verschiebt sie."] =
        "The new bar sits in the middle of the screen; drag it where you want it.",
    ["Die neue Leiste steht in der Bildschirmmitte - /fcd unlock zum Verschieben."] =
        "The new bar sits in the middle of the screen - /fcd unlock to move it.",
    ["Spiegelung von '%s' aufgehoben."] = "Stopped mirroring '%s'.",
    ["Blizzards eigene Leisten nachziehen (Neuladen)"] = "Update Blizzard's own bars (reload)",
    ["Auf den gespiegelten Leisten schon zu sehen"] = "Already visible on the mirrored bars",
    ["Spiegelt Blizzards Kategorie '%s'. Der Inhalt wird nicht gespeichert, sondern bei jeder Änderung neu bestimmt - deshalb ist er hier sofort richtig."] =
        "Mirrors Blizzard's category '%s'. The contents are not stored but worked out afresh on every change - which is why they are correct here immediately.",
    ["Die Leiste behält ihren jetzigen Inhalt und folgt Blizzards"] =
        "The bar keeps its current contents and no longer follows",
    ["Kategorie nicht mehr."] = "Blizzard's category.",
    ["Der jetzige Inhalt wird festgeschrieben und gehört danach dieser"] =
        "The current contents are fixed in place and belong to this bar",
    ["Leiste. Sie folgt Blizzards Kategorie dann nicht mehr - dafür"] =
        "afterwards. It no longer follows Blizzard's category - in exchange",
    ["lassen sich einzelne Symbole herausnehmen."] = "you can take out individual icons.",
    ["/fcd mirror - Blizzards Kategorien auf eigene Leisten spiegeln"] =
        "/fcd mirror - mirror Blizzard's categories onto your own bars",
    ["/fcd instant on|off - über Blizzards Lua schreiben (taintet ihren Viewer)"] =
        "/fcd instant on|off - write through Blizzard's Lua (taints their viewer)",
    ["%d gespiegelte Leiste(n) entfernt."] = "%d mirrored bar(s) removed.",
    ["Nicht angelegt: "] = "Not created: ",
    ["Es wird schon gespiegelt - /fcd mirror zeigt, was."] =
        "Mirroring is already on - /fcd mirror shows what.",
    ["Gespiegelt: "] = "Mirrored: ",
    ["Die Leisten stehen in der Bildschirmmitte übereinander."] =
        "The bars sit stacked in the middle of the screen.",
    ["/fcd unlock zum Verschieben, danach /fcd lock."] =
        "/fcd unlock to move them, /fcd lock when done.",
    ["'%s' wird jetzt gespiegelt."] = "'%s' is now mirrored.",
    ["Es wird nichts gespiegelt."] = "Nothing is being mirrored.",
    ["Eine gespiegelte Leiste zeigt genau das, was in Blizzards"] =
        "A mirrored bar shows exactly what sits in Blizzard's category -",
    ["Kategorie liegt - gezeichnet von uns. Eine Verschiebung im Panel"] =
        "drawn by us. A move in the panel is visible there right away,",
    ["ist dort sofort zu sehen, ohne Neuladen und ohne ihren Viewer"] =
        "without a reload and without touching their viewer. So there is",
    ["anzufassen. Es kann deshalb auch kein Fehler entstehen."] =
        "no way for an error to appear either.",
    ["/fcd mirror on   - essenziell und strategisch spiegeln"] =
        "/fcd mirror on   - mirror essential and utility",
    ["/fcd mirror off  - alle gespiegelten Leisten entfernen"] =
        "/fcd mirror off  - remove all mirrored bars",
    ["/fcd mirror hide - wie man Blizzards eigene Leisten ausblendet"] =
        "/fcd mirror hide - how to hide Blizzard's own bars",
    ["In dieser Kategorie liegt gerade nichts Gelerntes - die Leiste"] =
        "Nothing you have learned sits in this category right now - the bar",
    ["bleibt leer und unsichtbar, bis etwas hineinkommt."] =
        "stays empty and invisible until something lands in it.",
    ["|cffffcc00Hinweis:|r Dieser Client schützt die Abklingzeit-Werte."] =
        "|cffffcc00Note:|r This client protects the cooldown values.",
    ["Auch das Weiterreichen an die Blizzard-Uhr lehnt er ab. Die Symbole"] =
        "It even refuses to pass them on to the Blizzard cooldown widget. The icons",
    ["zeigen deshalb keinen Wischer und keine Restzeit; melden kann davon"] =
        "therefore show no swipe and no remaining time, and nothing among them can",
    ["nichts. Kein AddOn kann das hier anders."] =
        "alert. No addon can do better here.",
    ["Wischer und Restzeit zeichnet die Blizzard-Uhr; eigene Restzeit,"] =
        "The Blizzard cooldown widget draws swipe and remaining time; our own timer,",
    ["GCD-Unterdrückung und das Abdunkeln laufender Abklingzeiten entfallen."] =
        "GCD suppression and dimming of running cooldowns fall away.",
    ["Deine Leisten zeigen Blizzards Kategorien. Was du im Panel"] =
        "Your bars show Blizzard's categories. Whatever you move in the panel",
    ["verschiebst, steht dort sofort - ohne Neuladen und ohne Fehler."] =
        "appears there right away - no reload, no errors.",
    ["Blizzards eigene Leisten bleiben daneben stehen, bis du sie"] =
        "Blizzard's own bars stay alongside until you hide them - in their",
    ["ausblendest - in ihrem Fenster, damit nichts getaintet wird:"] =
        "own window, so that nothing gets tainted:",
    ["Dieser Client hat keinen Schalter für Blizzards Abklingzeit-Anzeige."] =
        "This client has no switch for Blizzard's cooldown display.",
    ["Im Kampf nicht - danach noch einmal."] =
        "Not in combat - try again afterwards.",
    ["Die Einstellung ließ sich nicht setzen."] =
        "The setting could not be applied.",
    ["Dieser Client kann AddOns nicht umschalten."] =
        "This client cannot toggle addons.",
    ["Das AddOn ließ sich nicht umschalten."] =
        "The addon could not be toggled.",
    ["Blizzards eigene Leisten stehen daneben und zeigen bis zum"] =
        "Blizzard's own bars stand alongside and show the old state until the",
    ["Neuladen den alten Stand. /fcd solo schaltet sie ab."] =
        "next reload. /fcd solo switches them off.",
    ["/fcd solo on|off - Blizzards eigene Leisten ab- oder anschalten"] =
        "/fcd solo on|off - switch Blizzard's own bars off or on",
    ["Blizzards eigene Leisten: "] =
        "Blizzard's own bars: ",
    ["/fcd solo on  - nur unsere Leisten, ihre aus"] =
        "/fcd solo on  - our bars only, theirs off",
    ["/fcd solo off - ihre wieder einschalten"] =
        "/fcd solo off - switch theirs back on",
    ["Nicht umgeschaltet: "] =
        "Not switched: ",
    ["Blizzards eigene Leisten sind wieder an."] =
        "Blizzard's own bars are back on.",
    ["Blizzards eigene Leisten sind aus - es zeigt nur noch FCD."] =
        "Blizzard's own bars are off - only FCD is showing now.",
    ["Wirksam nach einem /reload."] =
        "Takes effect after a /reload.",
    ["Abschalten"] =
        "Switch off",
    ["Behalten"] =
        "Keep them",
    ["Blizzards Leisten bleiben. /fcd solo on schaltet sie später ab."] =
        "Blizzard's bars stay. /fcd solo on switches them off later.",
    ["Forever Cooldowns zeigt Blizzards Abklingzeiten jetzt auf eigenen Leisten.\n\nSollen Blizzards eigene Leisten dafür abgeschaltet werden? Sonst steht alles doppelt.\n\nJederzeit umkehrbar mit  /fcd solo off"] =
        "Forever Cooldowns now shows Blizzard's cooldowns on bars of your own.\n\nSwitch Blizzard's own bars off for that? Otherwise everything is shown twice.\n\nReversible at any time with  /fcd solo off",
})

FCD.SetLanguage("auto")
