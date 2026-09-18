local ADDON_NAME = ...
ForeverCooldowns = ForeverCooldowns or {}
local FCD = ForeverCooldowns

-- Sprachen.
--
-- Die Schluessel sind die deutschen Zeichenketten selbst, nicht erfundene
-- Kuerzel wie L.ALIGNMENT. Das hat zwei Gruende: der Code bleibt lesbar - man
-- sieht beim Lesen, was auf dem Schirm steht, statt ein Kuerzel nachschlagen
-- zu muessen - und eine fehlende Uebersetzung faellt auf Deutsch zurueck
-- statt auf nil oder auf einen Platzhalter.
--
-- Diese Datei wird als erste geladen, weil einige Module ihre Beschriftungen
-- schon beim Laden in Tabellen ablegen.

local translations = {}

-- Leer heisst Deutsch: dann liefert der Nachschlag den Schluessel selbst.
local active = {}

local L = setmetatable({}, {
    __index = function(_, key)
        return active[key] or key
    end,
})
FCD.L = L

-- Rueckgabe: der Sprachcode, der tatsaechlich gilt ("deDE" oder "enUS")
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

-- Damit spaetere Dateien nachtragen koennen, ohne diese hier zu veraendern.
function FCD.AddTranslations(code, entries)
    translations[code] = translations[code] or {}
    for key, value in pairs(entries) do
        translations[code][key] = value
    end
    -- Wird nachgetragen, waehrend diese Sprache schon aktiv ist, muss der
    -- Nachschlag die neuen Eintraege sehen.
    if FCD.language == code then
        active = translations[code]
    end
end

-- ------------------------------------------------------------- Englisch

FCD.AddTranslations("enUS", {
    -- Leistenfenster: Ausrichtung und Masse
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

    -- Toene
    ["Schlachtzugswarnung"] = "Raid warning",
    ["Bereitschaftsprüfung"] = "Ready check",
    ["Wecker"] = "Alarm clock",
    ["Quest erledigt"] = "Quest complete",
    ["Sieg"] = "Victory",
    ["Klick"] = "Click",
    ["Standardton"] = "Default sound",

    -- Knoepfe im Leistenfenster
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

    -- Bearbeitungsmodus-Fenster fuer Blizzards Leisten
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

    -- Log-Zeilen. Sie stehen nur in /fcd log, gehoeren aber genauso
    -- uebersetzt: wer das AddOn auf Englisch benutzt, schickt auch ein
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
})

FCD.SetLanguage("auto")
