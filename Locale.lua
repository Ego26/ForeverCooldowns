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
})

FCD.SetLanguage("auto")
