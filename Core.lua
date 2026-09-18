local FCD = ForeverCooldowns

-- Während ein Chatbefehl läuft, werden alle Ausgaben gesammelt und am Ende
-- im kopierbaren Fenster gezeigt. Einzelne Zeilen bleiben im Chat, damit
-- Bestätigungen wie /fcd unlock kein Fenster aufreißen.
local outputBuffer, pendingWindow

-- Alles, was je im Chat stand, bleibt hier erhalten. Die Zeilen beim Anmelden
-- sind sonst weggescrollt, bevor man sie kopieren kann - und genau die sagen,
-- was geladen wurde.
local MAX_LOG = 400
local logLines = {}

local function remember(text)
    logLines[#logLines + 1] = text
    if #logLines > MAX_LOG then
        table.remove(logLines, 1)
    end
end

-- Nur ins Protokoll, nicht in den Chat. Die Zeilen beim Anmelden gehören
-- hierher: sie sind wertvoll, wenn etwas fehlt, aber niemand will sie bei
-- jedem Neuladen lesen. /fcd log holt sie hervor.
local function logMessage(message)
    remember(tostring(message))
end

local function printMessage(message)
    local text = tostring(message)
    remember(text)
    if outputBuffer then
        outputBuffer[#outputBuffer + 1] = text
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForever Cooldowns|r: " .. text)
end

-- Innerhalb eines Befehls wird das Fenster erst am Ende geöffnet, damit die
-- gesammelten Zeilen mit hineinkommen.
local function outputWindow(title, text)
    if outputBuffer then
        pendingWindow = { title = title, text = text }
    else
        FCD:ShowText(title, text)
    end
end

FCD.Print = printMessage
-- Für Spuren, die nur bei der Fehlersuche interessieren: sie landen in
-- /fcd log, nicht im Chat.
FCD.LogOnly = logMessage

-- ------------------------------------------------------------- Chatbefehle

SLASH_FOREVERCOOLDOWNS1 = "/fcd"
SLASH_FOREVERCOOLDOWNS2 = "/forevercooldowns"

local function trim(text)
    return text and text:match("^%s*(.-)%s*$") or ""
end

local function printHelp()
    printMessage("/fcd - Blizzards Abklingzeit-Einstellungen mit unserem Panel öffnen")
    printMessage("/fcd dock - Panel neben Blizzards Fenster ein-/ausblenden")
    printMessage("/fcd wide - zwischen schmaler und breiter Ansicht wechseln")
    printMessage("/fcd instant on|off - sofort wirksam (Standard) oder erst nach /reload")
    printMessage("/fcd log - alle bisherigen Ausgaben zum Kopieren")
    printMessage("/fcd store - Bestand sofort in Blizzards Layout sichern")
    printMessage("/fcd blizz - Blizzards Fenster holen (Layout wechseln)")
    printMessage("/fcd replace on|off - ob FCD an die Stelle ihres Fensters tritt")
    printMessage("/fcd editui on|off - eigenes Fenster im Bearbeitungsmodus")
    printMessage("/fcd lang de|en|auto - Sprache der Oberfläche")
    printMessage("/fcd round on|off - abgerundete Symbolecken (wirkt nach /reload)")
    printMessage("/fcd check - Funktionsprüfung dieses Clients im Chat")
    printMessage("/fcd probe - vollständigen API-Bericht als Text öffnen")
    printMessage("/fcd report - Abgleich mit dem Blizzard-Manager")
    printMessage("/fcd layout - Layout-Daten des Blizzard-Managers anzeigen")
    printMessage("/fcd layouttest - prüfen, ob sie beschreibbar sind (ändert nichts)")
    printMessage("/fcd roundtrip - prüfen, ob ein Blob bitgleich neu erzeugt werden kann")
    printMessage("/fcd snapshot - Layout-Stand sichern, /fcd diff - Änderungen anzeigen")
    printMessage("/fcd hide|show <AbklingzeitID> - im Blizzard-Manager aus-/einblenden")
    printMessage("/fcd state <AbklingzeitID> - Blob- und API-Zustand nebeneinander")
    printMessage("/fcd trace [Filter] | off - Ereignisse mitschneiden")
    printMessage("/fcd find <Text> - Globals, C_*-Namespaces und Enums durchsuchen")
    printMessage("/fcd dump <Name> - Mitglieder eines Objekts auflisten")
    printMessage("/fcd shown - welche benannten Rahmen gerade offen sind")
    printMessage("/fcd layouts - Blizzards Layout-Liste")
    printMessage("/fcd editmode - Rahmen und Schreibwege ihres Bearbeitungsmodus")
    printMessage("/fcd editsettings - Einstellungen der angeklickten Leiste")
    printMessage("/fcd editset <Name> <Wert> - eine davon probeweise setzen")
    printMessage("/fcd instances - laufende Objekte des Managers suchen")
    printMessage("/fcd compare - unsere Kategorien gegen Blizzards halten (taintet)")
    printMessage("/fcd fields - Felderverteilung der Cache-Eintraege je Kategorie")
    printMessage("/fcd art on - Blizzards Grafik abschauen (aus, kosmetisch)")
    printMessage("/fcd backups - Sicherungen auflisten, /fcd restore - letzte zurücknehmen")
    printMessage("/fcd unlock | lock - Leisten bewegen oder festsetzen")
    printMessage("/fcd profiles - Profile auflisten")
    printMessage("/fcd profile <Name> - Profil aktivieren")
    printMessage("/fcd export | import - Profil teilen")
    printMessage("/fcd rule form <FormID> <Profil> - Profilwechsel bei Haltung/Form")
    printMessage("/fcd rule combat <on|off> <Profil> - Profilwechsel im Kampf")
    printMessage("/fcd rules - Regeln auflisten, /fcd rule remove <Nummer>")
    printMessage("/fcd spell <ZauberID> - beliebigen Zauber aufnehmen")
    printMessage("/fcd item <ItemID> - Item dauerhaft in den Katalog aufnehmen")
    printMessage("/fcd form - aktuelle Form-/Haltungs-ID anzeigen")
    printMessage("/fcd rescan - Zauberbuch und Katalog neu einlesen")
    printMessage("/fcd undo - letzte Änderung zurücknehmen")
end

-- Diese Befehle öffnen oder schalten etwas um; ihre Rückmeldung ist eine
-- Bestätigung, kein Bericht.
local UI_COMMANDS = {
    [""] = true,
    ui = true,
    dock = true,
    unlock = true,
    wide = true,
    lock = true,
    import = true,
    snapshot = true,
}

local function dispatch(command, argument)
    if command == "" or command == "ui" then
        FCD:OpenMainUI()
    elseif command == "help" then
        printHelp()
    elseif command == "check" then
        FCD.Probe:PrintFeatureMatrix()
    elseif command == "probe" then
        FCD.Catalog:Rebuild()
        outputWindow("Forever Cooldowns - API-Bericht", FCD.Probe:BuildReport())
    elseif command == "layout" then
        outputWindow("Layout-Daten des Abklingzeit-Managers", FCD.Probe:BuildLayoutReport())
    elseif command == "layouttest" then
        FCD.Probe:TestLayoutWrite()
    elseif command == "roundtrip" then
        FCD.Probe:TestLayoutRoundTrip()
    elseif command == "snapshot" then
        FCD.Probe:SnapshotLayout()
    elseif command == "diff" then
        outputWindow("Vergleich der Layout-Daten", FCD.Probe:BuildLayoutDiff())
    elseif command == "hide" or command == "show" then
        FCD:ChangeVisibility(tonumber(argument), command == "hide")
    elseif command == "trace" then
        local mode = string.lower(argument):match("^(%S*)")
        if mode == "off" then
            FCD:SetTrace(false)
        else
            FCD:SetTrace(true, argument ~= "" and argument or nil)
        end
    elseif command == "instant" then
        local mode = string.lower(trim(argument))
        if mode == "on" or mode == "an" then
            FCD.db.settings.allowNativeWrites = true
            printMessage("Sofortmodus AN.")
            printMessage("")
            printMessage("Änderungen wirken jetzt ohne Neuladen - über Blizzards eigenes")
            printMessage("Datenmodell. Der Preis: sobald AddOn-Code es anfasst, gilt es für")
            printMessage("die restliche Sitzung als tainted, und Blizzards Viewer kann keine")
            printMessage("Auren mehr lesen. Betrifft nur ihre Anzeige, nicht unsere, und ein")
            printMessage("/reload setzt es zurück.")
        elseif mode == "off" or mode == "aus" then
            FCD.db.settings.allowNativeWrites = false
            printMessage("Sofortmodus AUS. Änderungen werden sicher geschrieben und mit dem")
            printMessage("nächsten Neuladen wirksam.")
        else
            printMessage("Sofortmodus ist derzeit " .. (FCD.db.settings.allowNativeWrites and "AN" or "AUS") .. ".")
            printMessage("/fcd instant on   - sofort wirksam, taintet Blizzards Viewer")
            printMessage("/fcd instant off  - sicher, wirkt nach /reload")
        end
    elseif command == "wide" then
        FCD.Dock:Build()
        FCD.Dock:SetWide(not FCD.Dock.state.wide)
        if not FCD.Dock:IsShown() then FCD.Dock:Toggle() end
        printMessage(FCD.Dock.state.wide and "Breite Ansicht." or "Schmale Ansicht.")
    elseif command == "dock" then
        local shown = FCD.Dock:Toggle()
        printMessage(shown and "Panel geöffnet." or "Panel geschlossen.")
        printMessage("Es erscheint sonst automatisch neben Blizzards Abklingzeit-Einstellungen.")
    elseif command == "find" then
        outputWindow("Suche in der Client-API", FCD.Probe:BuildSearchReport(argument))
    elseif command == "fields" then
        outputWindow("Felderanalyse", FCD.Probe:BuildFieldAnalysis())
    elseif command == "spell" then
        local ok, err = FCD.Ranks:AddCustom(trim(argument))
        if ok then
            local id = tonumber(trim(argument):match("%d+"))
            printMessage(string.format("'%s' aufgenommen - steht jetzt im"
                .. " Reiter Eigene Zauber.",
                FCD.Compat.GetSpellName(id) or ("Zauber " .. tostring(id))))
            FCD.Catalog:Rebuild()
            FCD.Dock:Refresh()
        else
            printMessage("Nicht aufgenommen: " .. tostring(err))
        end
    elseif command == "lang" then
        local mode = string.lower(trim(argument))
        if mode == "de" or mode == "deutsch" then
            FCD.db.settings.language = "deDE"
        elseif mode == "en" or mode == "english" or mode == "englisch" then
            FCD.db.settings.language = "enUS"
        elseif mode == "auto" then
            FCD.db.settings.language = nil
        else
            printMessage("Sprache: " .. FCD.GetLanguage()
                .. " - umschalten mit  /fcd lang de|en|auto")
            return
        end
        FCD.SetLanguage(FCD.db.settings.language)
        FCD.Store:Save()
        -- Einige Beschriftungen stehen schon beim Laden in Tabellen; die
        -- wechseln erst beim naechsten Durchlauf.
        printMessage("Sprache: " .. FCD.GetLanguage() .. " - wirkt nach /reload.")
    elseif command == "editui" then
        local mode = string.lower(trim(argument))
        if mode == "off" or mode == "aus" then
            FCD.db.settings.replaceEditModeDialog = false
            FCD.Store:Save()
            FCD.BlizzOptions:Close("abgeschaltet")
            printMessage("Im Bearbeitungsmodus erscheint wieder ihr Fenster.")
        elseif mode == "on" or mode == "an" then
            FCD.db.settings.replaceEditModeDialog = true
            FCD.Store:Save()
            printMessage("Im Bearbeitungsmodus erscheint unser Fenster.")
        else
            printMessage("Eigenes Fenster im Bearbeitungsmodus ist derzeit "
                .. ((FCD.db.settings.replaceEditModeDialog ~= false) and "AN" or "AUS")
                .. ". Umschalten mit  /fcd editui on  bzw.  off")
        end
    elseif command == "round" then
        local mode = string.lower(trim(argument))
        if mode == "off" or mode == "aus" then
            FCD.db.settings.roundIcons = false
            FCD.Store:Save()
            printMessage("Abgerundete Ecken aus - wirkt nach /reload.")
        elseif mode == "on" or mode == "an" then
            FCD.db.settings.roundIcons = true
            FCD.Store:Save()
            printMessage("Abgerundete Ecken an - wirkt nach /reload.")
        else
            printMessage("Abgerundete Symbolecken sind derzeit "
                .. ((FCD.db.settings.roundIcons ~= false) and "AN" or "AUS")
                .. ". Umschalten mit  /fcd round on  bzw.  off")
        end
    elseif command == "blizz" then
        FCD.Dock:OpenBlizzardWindow()
    elseif command == "replace" then
        local mode = string.lower(trim(argument))
        if mode == "off" or mode == "aus" then
            FCD.db.settings.replaceBlizzardWindow = false
            FCD.Store:Save()
            printMessage("Blizzards Fenster geht wieder normal auf.")
        elseif mode == "on" or mode == "an" then
            FCD.db.settings.replaceBlizzardWindow = true
            FCD.Store:Save()
            printMessage("FCD tritt an die Stelle ihres Fensters.")
        else
            printMessage("Verdrängung ist derzeit "
                .. ((FCD.db.settings.replaceBlizzardWindow ~= false) and "AN" or "AUS")
                .. ". Umschalten mit  /fcd replace on  bzw.  off")
        end
    elseif command == "shown" then
        outputWindow("Offene Rahmen", FCD.Probe:BuildShownFrameReport())
    elseif command == "editmode" then
        outputWindow("Bearbeitungsmodus", FCD.Probe:BuildEditModeReport())
    elseif command == "editsettings" then
        outputWindow("Einstellungen der Leiste",
            FCD.Probe:BuildEditModeSettingsReport())
    elseif command == "editset" then
        -- Probeschreiben auf Blizzards Bearbeitungsmodus. Ein Befehl und
        -- keine Oberfläche: erst muss feststehen, ob Schreiben durchgeht und
        -- ob es ihren Code taintet.
        local settingName, value = string.match(trim(argument), "^(%S+)%s+(%S+)$")
        if not settingName then
            printMessage("So: /fcd editset <Name> <Wert>  -  Namen zeigt /fcd editsettings")
        else
            local result, setErr = FCD.Probe:TryEditModeSetting(settingName, value)
            printMessage(result and ("Geschrieben: " .. result)
                or ("Nicht geschrieben: " .. tostring(setErr)))
        end
    elseif command == "layouts" then
        outputWindow("Blizzards Layout-Liste", FCD.Probe:BuildBlizzardLayoutReport())
    elseif command == "store" then
        local ok, err = FCD.Store:Save(true)
        printMessage(ok and "Bestand ins Layout geschrieben."
            or ("Nicht geschrieben: " .. tostring(err)))
        printMessage(tostring(FCD.Store.status))
        -- Sofort gegenlesen: bleibt unser Schlüssel nicht einmal in derselben
        -- Sitzung stehen, verwirft der Client ihn beim Schreiben - dann ist
        -- der Layout-Speicher als Ablage untauglich und ich muss woanders hin.
        if ok then
            local present = FCD.Store:IsPresent()
            printMessage(present
                and "Gegengelesen: der Eintrag steht im Layout."
                or "|cffff6060Gegengelesen: der Eintrag ist sofort wieder weg|r"
                    .. " - der Client verwirft ihn beim Schreiben.")
        end
    elseif command == "log" then
        -- Abschrift vor dieser Ausgabe nehmen, sonst steht der Aufruf selbst
        -- mit darin.
        local snapshot = table.concat(logLines, "\n")
        outputWindow("Bisherige Ausgaben", snapshot ~= "" and snapshot
            or "Noch nichts ausgegeben.")
    elseif command == "art" then
        local mode = string.lower(trim(argument))
        if mode == "off" or mode == "aus" then
            FCD.db.settings.useBlizzardArt = false
            printMessage("Blizzards Grafik wird nicht mehr übernommen.")
            printMessage("Nach einem /reload zeichnet das Panel wieder selbst.")
        elseif mode == "on" or mode == "an" then
            FCD.db.settings.useBlizzardArt = true
            printMessage("Blizzards Grafik wird wieder übernommen, sobald ihr Fenster offen ist.")
        else
            outputWindow("Blizzards Grafik als Vorlage", FCD.Art:Describe())
        end
    elseif command == "compare" then
        outputWindow("Abgleich der Kategorien", FCD.Probe:BuildCategoryComparison())
    elseif command == "instances" then
        outputWindow("Laufende Objekte", FCD.Probe:BuildInstanceReport())
    elseif command == "dump" then
        outputWindow("Inhalt eines Objekts", FCD.Probe:BuildDumpReport(argument))
    elseif command == "state" then
        outputWindow("Zustand einer Abklingzeit", FCD.Probe:BuildCooldownStateReport(tonumber(argument)))
    elseif command == "restore" then
        local ok, info = FCD.Layout:Restore()
        printMessage(ok and ("Sicherung von " .. tostring(info) .. " wiederhergestellt.")
            or ("Wiederherstellen fehlgeschlagen: " .. tostring(info)))
    elseif command == "backups" then
        local backups = FCD.Layout:GetBackups()
        if #backups == 0 then
            printMessage("Keine Sicherungen vorhanden.")
        end
        for index, backup in ipairs(backups) do
            printMessage(string.format("%d. %s - %s (%d Zeichen)", index, backup.taken, backup.label, #backup.raw))
        end
    elseif command == "report" then
        FCD.Catalog:Rebuild()
        outputWindow("Forever Cooldowns - Katalogbericht", FCD.Catalog:BuildReport())
    elseif command == "unlock" then
        FCD.Viewer:SetUnlocked(true)
        printMessage("Leisten können jetzt mit der Maus verschoben werden.")
    elseif command == "lock" then
        FCD.Viewer:SetUnlocked(false)
        printMessage("Leisten festgesetzt.")
    elseif command == "profiles" then
        printMessage("== Leisten-Profile (eigene Leisten) ==")
        for _, name in ipairs(FCD.Profiles:List()) do
            printMessage((name == FCD.Profiles:GetActiveName() and "* " or "  ") .. name)
        end

        -- Getrennt ausweisen, ob die Tabelle leer ist oder nur die Anzeige
        printMessage("")
        printMessage("== Layout-Profile (Blizzards Kategorien) ==")
        local raw = FCD.db.layoutProfiles
        if raw == nil then
            printMessage("  ForeverCooldownsDB.layoutProfiles existiert nicht.")
        else
            local count = 0
            for _ in pairs(raw) do
                count = count + 1
            end
            printMessage("  Tabelle vorhanden, " .. count .. " Eintrag/Einträge.")
            for _, name in ipairs(FCD.Layout:ListProfiles()) do
                local profile = raw[name]
                local assignments = 0
                for _ in pairs(profile and profile.assignments or {}) do
                    assignments = assignments + 1
                end
                printMessage(string.format("  %s%s  (%d Zuweisungen, gesichert %s)",
                    name == FCD.db.settings.activeLayoutProfile and "* " or "  ",
                    name, assignments, tostring(profile and profile.saved or "?")))
            end
        end
        printMessage("")
        printMessage("Aktiv laut Einstellungen: "
            .. tostring(FCD.db.settings.activeLayoutProfile or "keines"))
    elseif command == "profile" then
        if FCD.Profiles:SetActive(argument) then
            printMessage("Profil '" .. argument .. "' aktiv.")
        else
            printMessage("Unbekanntes Profil: " .. argument)
        end
    elseif command == "export" then
        outputWindow("Profil exportieren", FCD.Profiles:Export() or "")
    elseif command == "import" then
        FCD:ShowImport()
    elseif command == "rules" then
        local rules = FCD.Profiles:GetRules()
        if #rules == 0 then
            printMessage("Keine Regeln hinterlegt.")
        end
        for index, rule in ipairs(rules) do
            printMessage(string.format("%d. %s = %s -> %s", index, rule.kind, tostring(rule.value), rule.profile))
        end
    elseif command == "rule" then
        local kind, rest = argument:match("^(%S+)%s*(.-)$")
        kind = string.lower(kind or "")
        if kind == "remove" then
            local index = tonumber(rest)
            if index and FCD.Profiles:RemoveRule(index) then
                printMessage("Regel " .. index .. " entfernt.")
            else
                printMessage("Regel nicht gefunden.")
            end
        elseif kind == "form" or kind == "spec" then
            local value, profileName = rest:match("^(%S+)%s+(.+)$")
            local number = tonumber(value)
            if not number or not profileName then
                printMessage("Format: /fcd rule " .. kind .. " <Nummer> <Profil>")
                return
            end
            local ok, err = FCD.Profiles:AddRule(kind, number, trim(profileName))
            printMessage(ok and "Regel hinzugefügt." or ("Fehler: " .. tostring(err)))
        elseif kind == "combat" then
            local value, profileName = rest:match("^(%S+)%s+(.+)$")
            if not value or not profileName then
                printMessage("Format: /fcd rule combat <on|off> <Profil>")
                return
            end
            local ok, err = FCD.Profiles:AddRule("combat", string.lower(value) == "on", trim(profileName))
            printMessage(ok and "Regel hinzugefügt." or ("Fehler: " .. tostring(err)))
        else
            printMessage("Unbekannte Regelart. /fcd help")
        end
    elseif command == "item" then
        local itemID = tonumber(argument)
        if itemID and FCD.Items:AddCustom(itemID) then
            FCD:RefreshData()
            printMessage("Item " .. itemID .. " aufgenommen.")
        else
            printMessage("Format: /fcd item <ItemID>")
        end
    elseif command == "form" then
        printMessage(string.format("FormID: %s, Index: %s, Formen: %s",
            tostring(FCD.Compat.GetFormID()), tostring(FCD.Compat.GetFormIndex()), tostring(FCD.Compat.GetNumForms())))
    elseif command == "rescan" then
        FCD:RefreshData()
        printMessage(string.format("Neu eingelesen: %d Fähigkeiten, %d mit mehreren Rängen, %d Katalogeinträge.",
            FCD.Ranks.familyCount or 0, FCD.Ranks.rankedFamilyCount or 0, #FCD.Catalog.entries))
    elseif command == "undo" then
        local label = FCD.Profiles:Undo()
        printMessage(label and ("Rückgängig: " .. label) or "Nichts rückgängig zu machen.")
    else
        printMessage("Unbekannter Befehl.")
        printHelp()
    end
end


SlashCmdList.FOREVERCOOLDOWNS = function(message)
    local command, argument = trim(message):match("^(%S*)%s*(.-)$")
    command = string.lower(command or "")

    -- Befehle, die eine Oberfläche öffnen oder umschalten, sagen nur kurz
    -- Bescheid. Für die wäre ein Fenster im Weg - sie bleiben im Chat.
    if UI_COMMANDS[command] then
        local ok, err = pcall(dispatch, command, argument)
        if not ok then
            printMessage("Fehler im Befehl /fcd " .. command .. ": " .. tostring(err))
        end
        return
    end

    -- Sonst wird gepuffert, damit wirklich jede Ausgabe im kopierbaren
    -- Fenster landet - auch Fehlermeldungen und der Ladehinweis unten.
    outputBuffer, pendingWindow = {}, nil

    local ok, err
    if not FCD.db and command ~= "help" then
        -- Schlug die Initialisierung fehl, würde jeder Befehl nur einen
        -- Folgefehler werfen. Lieber klar sagen, woran es liegt.
        ok = true
        printMessage("Nicht vollständig geladen (keine Datenbank). Meist ein Lua-Fehler beim Start:")
        printMessage("Fehlermeldungen einschalten mit  /console scriptErrors 1  und neu laden.")
    else
        ok, err = pcall(dispatch, command, argument)
    end

    local lines, window = outputBuffer, pendingWindow
    outputBuffer, pendingWindow = nil, nil

    if not ok then
        lines[#lines + 1] = "Fehler im Befehl /fcd " .. command .. ":"
        lines[#lines + 1] = tostring(err)
    end

    local parts = {}
    if #lines > 0 then
        parts[#parts + 1] = table.concat(lines, "\n")
    end
    if window then
        parts[#parts + 1] = window.text
    end

    if #parts == 0 then
        return
    end
    FCD:ShowText(window and window.title or ("Forever Cooldowns - /fcd " .. command),
        table.concat(parts, "\n\n"))
end

-- --------------------------------------------------------------- Textfenster

local textWindow

function FCD:ShowText(title, text)
    if not textWindow then
        local window = CreateFrame("Frame", "ForeverCooldownsTextFrame", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(680, 480)
        window:SetPoint("CENTER")
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window:SetFrameStrata("DIALOG")

        window.title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        window.title:SetPoint("TOP", 0, -6)

        local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 16, -34)
        scroll:SetPoint("BOTTOMRIGHT", -34, 42)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("GameFontHighlightSmall")
        edit:SetWidth(600)
        edit:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        scroll:SetScrollChild(edit)
        window.edit = edit

        local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("BOTTOMLEFT", 18, 18)
        hint:SetText("Strg+A markiert alles, Strg+C kopiert.")

        textWindow = window
    end
    textWindow.title:SetText(title or "Forever Cooldowns")
    textWindow.edit:SetText(text or "")
    textWindow.edit:SetCursorPosition(0)
    textWindow:Show()
    return textWindow
end

function FCD:ShowImport()
    local window = self:ShowText("Profil importieren", "")
    window.edit:SetFocus()
    if not window.importButton then
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetSize(120, 22)
        button:SetPoint("BOTTOMRIGHT", -18, 14)
        button:SetText("Importieren")
        button:SetScript("OnClick", function()
            local name, err = FCD.Profiles:Import(window.edit:GetText())
            if not name then
                printMessage("Import fehlgeschlagen: " .. tostring(err))
                return
            end
            printMessage("Profil '" .. name .. "' importiert.")
            window:Hide()
            FCD.Profiles:SetActive(name)
            FCD:RefreshData()
        end)
        window.importButton = button
    end
    window.importButton:Show()
end

-- ------------------------------------------------------------ Leistenoptionen

local barOptions

local function optionEditBox(parent, label, y, getter, setter)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("TOPLEFT", 20, y)
    text:SetText(label)

    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(70, 22)
    edit:SetPoint("TOPLEFT", 170, y + 4)
    edit:SetAutoFocus(false)
    edit:SetNumeric(false)
    edit.Load = function()
        edit:SetText(tostring(getter() or ""))
    end
    edit:SetScript("OnEnterPressed", function(self)
        setter(self:GetText())
        self:ClearFocus()
        FCD.Viewer:RebuildAll()
        edit.Load()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        edit.Load()
    end)
    return edit
end

function FCD:ShowBarOptions(bar)
    if not bar then
        printMessage("Keine Leiste ausgewählt.")
        return
    end

    if not barOptions then
        local window = CreateFrame("Frame", "ForeverCooldownsBarOptions", UIParent, "BasicFrameTemplateWithInset")
        window:SetSize(340, 430)
        window:SetPoint("CENTER", 300, 0)
        window:SetMovable(true)
        window:EnableMouse(true)
        window:RegisterForDrag("LeftButton")
        window:SetScript("OnDragStart", window.StartMoving)
        window:SetScript("OnDragStop", window.StopMovingOrSizing)
        window:SetFrameStrata("DIALOG")
        window.title = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        window.title:SetPoint("TOP", 0, -6)
        window.title:SetText("Leisten-Optionen")
        window.fields = {}

        local function current()
            return window.bar
        end

        window.fields.name = optionEditBox(window, "Name", -40,
            function() return current() and current().name end,
            function(value)
                if current() and value ~= "" then
                    current().name = value
                end
                -- Das alte Fenster gibt es nicht mehr; nichts weiter zu tun.
            end)
        window.fields.name:SetWidth(130)

        local numeric = {
            { key = "columns", label = "Symbole pro Zeile", minimum = 1, maximum = 40 },
            { key = "iconSize", label = "Symbolgröße", minimum = 12, maximum = 90 },
            { key = "spacing", label = "Abstand", minimum = 0, maximum = 30 },
            { key = "scale", label = "Skalierung", minimum = 0.4, maximum = 2 },
            { key = "alpha", label = "Deckkraft", minimum = 0.1, maximum = 1 },
        }
        local offset = -70
        for _, definition in ipairs(numeric) do
            local key = definition.key
            window.fields[key] = optionEditBox(window, definition.label, offset,
                function() return current() and current()[key] end,
                function(value)
                    local number = tonumber(value)
                    if number and current() then
                        current()[key] = math.max(definition.minimum, math.min(definition.maximum, number))
                    end
                end)
            offset = offset - 28
        end

        local growthLabel = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        growthLabel:SetPoint("TOPLEFT", 20, offset)
        growthLabel:SetText("Wachstum")
        local directions = { "RIGHT", "LEFT", "DOWN", "UP" }
        local directionLabels = { RIGHT = "rechts", LEFT = "links", DOWN = "runter", UP = "hoch" }
        window.growthButtons = {}
        for index, direction in ipairs(directions) do
            local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
            button:SetSize(62, 20)
            button:SetPoint("TOPLEFT", 110 + (index - 1) * 55, offset + 4)
            button:SetText(directionLabels[direction])
            button:SetScript("OnClick", function()
                if current() then
                    current().growth = direction
                    FCD.Viewer:RebuildAll()
                end
            end)
            window.growthButtons[index] = button
        end
        offset = offset - 34

        local visibility = {
            { key = "always", label = "immer sichtbar" },
            { key = "inCombat", label = "nur im Kampf" },
            { key = "hasTarget", label = "nur mit Ziel" },
            { key = "onlyOnCooldown", label = "nur laufende Abklingzeiten" },
            { key = "hideUnknown", label = "Ungelerntes ausblenden" },
        }
        window.visibilityChecks = {}
        for index, definition in ipairs(visibility) do
            local key = definition.key
            local check = FCD.Widgets.CreateCheck(window, definition.label,
                function()
                    local bar = current()
                    return bar and bar.visibility[key]
                end,
                function(value)
                    local bar = current()
                    if bar then
                        bar.visibility[key] = value
                        FCD.Viewer:RebuildAll()
                    end
                end)
            check:SetPoint("TOPLEFT", 20, offset - (index - 1) * 24)
            window.visibilityChecks[key] = check
        end

        barOptions = window
    end

    barOptions.bar = bar
    for _, field in pairs(barOptions.fields) do
        field.Load()
    end
    for _, check in pairs(barOptions.visibilityChecks) do
        check.Refresh()
    end
    barOptions:Show()
end

-- ------------------------------------------------------------------ Dialoge

StaticPopupDialogs["FCD_NEW_PROFILE"] = {
    text = "Name des neuen Profils:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local name = editBox and editBox:GetText() or ""
        if FCD.Profiles:Create(name) then
            FCD.Profiles:SetActive(name)
            FCD:RefreshData()
            printMessage("Profil '" .. name .. "' angelegt.")
        else
            printMessage("Profil konnte nicht angelegt werden (Name leer oder vergeben).")
        end
    end,
}

StaticPopupDialogs["FCD_COPY_PROFILE"] = {
    text = "Name der Kopie:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local name = editBox and editBox:GetText() or ""
        if FCD.Profiles:Create(name, FCD.Profiles:GetActiveName()) then
            FCD.Profiles:SetActive(name)
            FCD:RefreshData()
            printMessage("Profil '" .. name .. "' angelegt.")
        else
            printMessage("Profil konnte nicht angelegt werden (Name leer oder vergeben).")
        end
    end,
}

-- ------------------------------------------------------------------ Ablauf

-- Erste echte Schreiboperation auf Blizzards Manager. Bewusst mit
-- vorgeschalteter Rundlaufprüfung: schafft es der Blob nicht verlustfrei
-- durch unsere Kette, wird gar nicht erst geschrieben.
function FCD:ChangeVisibility(cooldownID, hidden)
    if not cooldownID then
        printMessage("Format: /fcd hide <AbklingzeitID>  bzw.  /fcd show <AbklingzeitID>")
        printMessage("Die IDs stehen in /fcd layout.")
        return
    end

    local info = self.Compat.GetCooldownInfo(cooldownID)
    local spellID = info and (info.spellID or info.overrideSpellID)
    local displayName = spellID and self.Compat.GetSpellName(spellID) or ("Abklingzeit " .. cooldownID)

    -- Bevorzugt Blizzards eigene Datenschicht: sie wendet die Änderung an
    -- und speichert sie selbst. Der Weg über den serialisierten Blob bleibt
    -- als Rückfallebene für Clients ohne diese Funktionen.
    -- Der Weg über Blizzards Objekte funktioniert zwar, beschädigt aber
    -- ihren Viewer: nach einem Aufruf von AddOn-Code gilt ihr Objekt als
    -- tainted und ihr eigener Aurenzugriff scheitert bis zum nächsten
    -- /reload. Deshalb ist er aus, solange er nicht ausdrücklich freigegeben
    -- wurde.
    if not self.Layout:NativeWritesAllowed() then
        printMessage("Weg über Blizzards Lua-Objekte ist aus (beschädigt ihren Viewer).")
        printMessage("Stattdessen wird der Layout-Blob über die C-Funktion SetLayoutData")
        printMessage("geschrieben - das taintet nichts.")
        printMessage("")
    end

    if self.Layout:CanWriteNativeNow() then
        local target
        if hidden then
            target = self.Layout.HIDDEN_CATEGORY
        else
            target = self.Layout:GetDefaultCategory(cooldownID)
            if not target then
                printMessage(displayName .. ": keine Standardkategorie bekannt, kann nicht eingeblendet werden.")
                return
            end
        end

        -- Gemessen wird am laufenden Datenmodell. Die C_CooldownViewer-Abfragen
        -- liefern nur die statische Einordnung und bewegen sich ohnehin nicht.
        local liveBefore = self.Probe:GetLiveState(cooldownID)
        local staticBefore = self.Probe:GetEffectiveState(cooldownID)

        self.Layout:CreateNativeRestorePoint()
        local ok, err, applied = self.Layout:SetCategoryNative(cooldownID, target)
        if not ok then
            printMessage("Abgelehnt: " .. tostring(err))
            return
        end

        local liveAfter, liveLines = self.Probe:GetLiveState(cooldownID)
        local staticAfter = self.Probe:GetEffectiveState(cooldownID)

        printMessage(displayName .. " -> Kategorie " .. tostring(target) .. " (über Blizzards Datenschicht)")
        printMessage("  ausgeführt: SetCooldownToCategory, " .. tostring(applied))
        printMessage("")
        printMessage("  Datenmodell vorher: " .. tostring(liveBefore))
        printMessage("  Datenmodell jetzt:  " .. tostring(liveAfter))
        for _, line in ipairs(liveLines or {}) do
            printMessage(line)
        end
        printMessage("")
        printMessage("  Statische Abfrage vorher: " .. tostring(staticBefore))
        printMessage("  Statische Abfrage jetzt:  " .. tostring(staticAfter))

        if liveBefore == liveAfter then
            printMessage("")
            printMessage("Das Datenmodell hat sich nicht bewegt - SetCooldownToCategory erwartet")
            printMessage("vermutlich andere Argumente. /fcd dump CooldownViewerSettings.dataProvider")
            printMessage("zeigt, welchen Zustand es führt.")
        end
        return
    end


    local state, readErr = self.Layout:Read()
    if not state then
        printMessage("Lesen fehlgeschlagen: " .. tostring(readErr))
        return
    end

    local ok, err, note = self.Layout:VerifyRoundTrip(state)
    if not ok then
        printMessage("|cffff4040Abgebrochen:|r " .. tostring(err))
        printMessage("Solange der Rundlauf den Inhalt nicht erhält, wird nichts geschrieben.")
        return
    end
    printMessage("Rundlauf geprüft: " .. tostring(note))

    if not self.Layout:SetHidden(state, cooldownID, hidden) then
        printMessage(displayName .. " ist bereits " .. (hidden and "ausgeblendet" or "eingeblendet") .. ".")
        return
    end

    -- Vorher messen, damit die Wirkung belegbar ist statt geschätzt.
    -- Maßgeblich ist der Cache-Eintrag (isInvisible), nicht die statische
    -- Kategoriezuordnung.
    local before = self.Probe:GetEffectiveState(cooldownID)

    local written, writeErr = self.Layout:Commit(state, (hidden and "Ausgeblendet: " or "Eingeblendet: ") .. displayName)
    if not written then
        printMessage("|cffff4040Schreiben fehlgeschlagen:|r " .. tostring(writeErr))
        return
    end

    local after = self.Probe:GetEffectiveState(cooldownID)
    printMessage(displayName .. ": Blob geschrieben. Mit  /fcd restore  zurücknehmen.")
    printMessage("Ob es wirkt, zeigt Blizzards Fenster nach einem /reload - nicht die")
    printMessage("Abfrage unten, die nur die statische Einordnung meldet.")
    printMessage("  vorher: " .. tostring(before))
    printMessage("  jetzt:  " .. tostring(after))
    if before == after then
        -- Erwartet: diese Abfrage meldet nur die statische Einordnung und
        -- bewegt sich auch dann nicht, wenn das Schreiben gewirkt hat.
        printMessage("Die statische Abfrage bewegt sich erwartungsgemäß nicht.")
        printMessage("Wirkung prüfen: /reload, dann im Blizzard-Fenster den Abschnitt")
        printMessage("'Nicht angezeigt' aufklappen - dort muss der Eintrag stehen.")
    end
end

-- Ereignis-Mitschnitt. Der Client muss beim Anwenden eines Layouts
-- irgendetwas auslösen; welches Ereignis das ist, steht in keiner
-- Dokumentation, also wird mitgehoert.
local tracer = CreateFrame("Frame")
local traceLog = {}
local traceHighlight = "COOLDOWN"

-- Live mitzuschreiben war der Fehler: hätte das gesuchte Ereignis einen
-- anderen Namen, bliebe es unsichtbar. Also alles sammeln und am Ende
-- zusammenfassen - Häufigkeiten statt Spam.
-- Nur Namen und Häufigkeit. Die Argumente wurden ursprünglich mitgeschrieben,
-- doch darunter sind geschützte Werte, die beim Ausgeben fehlschlagen - und
-- für die Frage "welches Ereignis feuert" sind sie ohnehin ohne Belang.
tracer:SetScript("OnEvent", function(_, event)
    traceLog[event] = (traceLog[event] or 0) + 1
end)

function FCD:SetTrace(enabled, filterText)
    if enabled then
        wipe(traceLog)
        traceHighlight = (filterText and filterText ~= "") and string.upper(filterText) or "COOLDOWN"
        tracer:RegisterAllEvents()
        printMessage("Mitschnitt an - es wird alles aufgezeichnet, hervorgehoben wird '"
            .. traceHighlight .. "'.")
        printMessage("Jetzt im Blizzard-Fenster etwas ändern, dann  /fcd trace off.")
        return
    end

    tracer:UnregisterAllEvents()

    local names = {}
    for name in pairs(traceLog) do
        names[#names + 1] = name
    end
    if #names == 0 then
        printMessage("Mitschnitt aus - kein einziges Ereignis aufgezeichnet.")
        return
    end

    -- Ins Textfenster statt in den Chat: nur dort lässt es sich kopieren
    local lines = {
        "Forever Cooldowns - Ereignis-Mitschnitt",
        string.format("%d verschiedene Ereignisse, hervorgehoben: %s", #names, traceHighlight),
        "",
    }

    -- Treffer des Filters zuerst, danach der Rest nach Häufigkeit
    table.sort(names, function(a, b)
        local hitA = string.find(a, traceHighlight, 1, true) ~= nil
        local hitB = string.find(b, traceHighlight, 1, true) ~= nil
        if hitA ~= hitB then
            return hitA
        end
        if traceLog[a] ~= traceLog[b] then
            return traceLog[a] > traceLog[b]
        end
        return a < b
    end)

    local highlighted = 0
    for _, name in ipairs(names) do
        local marked = string.find(name, traceHighlight, 1, true) ~= nil
        if marked then
            highlighted = highlighted + 1
        end
        lines[#lines + 1] = string.format("%s %-48s x%d",
            marked and ">>" or "  ", name, traceLog[name])
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = highlighted > 0
        and (highlighted .. " Ereignis(se) enthalten '" .. traceHighlight .. "' - mit >> markiert.")
        or ("Kein Ereignis enthält '" .. traceHighlight .. "'.")

    outputWindow("Ereignis-Mitschnitt", table.concat(lines, "\n"))
end

-- /fcd öffnet jetzt das, womit man tatsächlich arbeitet: Blizzards
-- Einstellungsfenster, an dem unser Panel von selbst andockt.
function FCD:OpenMainUI()
    -- Im Kampf Blizzards Fenster nicht anfassen: Show/Hide auf einem
    -- geschützten Frame aus getaintetem Code wird blockiert und erzeugt die
    -- Meldung "Interface-Aktion fehlgeschlagen".
    if InCombatLockdown() then
        printMessage("Im Kampf wird Blizzards Fenster nicht angefasst - zeige nur das Panel.")
        self.Dock:Toggle()
        return
    end

    -- Verdrängt FCD Blizzards Fenster, wäre der Umweg über ihres sinnlos:
    -- es würde aufgehen und sofort wieder verschwinden.
    if self.db and self.db.settings.replaceBlizzardWindow ~= false then
        self.Dock:Toggle()
        return
    end

    local window = _G.CooldownViewerSettings
    if type(window) == "table" and type(window.Show) == "function" then
        if window:IsShown() then
            pcall(window.Hide, window)
            printMessage("Geschlossen.")
            return
        end
        local ok = pcall(window.Show, window)
        if ok then
            -- Das Panel folgt über die Sichtbarkeitsprüfung automatisch
            printMessage("Abklingzeit-Einstellungen geöffnet, Panel dockt rechts an.")
            return
        end
    end

    printMessage("Blizzards Fenster lässt sich nicht öffnen - zeige nur das Panel.")
    self.Dock:Toggle()
end

function FCD:ShowLayoutImport()
    local window = self:ShowText("Layout-Profil importieren", "")
    window.edit:SetFocus()
    if not window.layoutImportButton then
        local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        button:SetSize(140, 22)
        button:SetPoint("BOTTOMRIGHT", -18, 14)
        button:SetText("Profil importieren")
        button:SetScript("OnClick", function()
            local name, err = FCD.Layout:ImportProfile(window.edit:GetText())
            if not name then
                printMessage("Import fehlgeschlagen: " .. tostring(err))
                return
            end
            printMessage("Layout-Profil '" .. name .. "' importiert.")
            FCD.db.settings.activeLayoutProfile = name
            window:Hide()
            FCD.Dock:Refresh()
        end)
        window.layoutImportButton = button
    end
    window.layoutImportButton:Show()
end

StaticPopupDialogs["FCD_ADD_SPELL"] = {
    text = "Zauber aufnehmen - ID oder Link einfügen\n(Umschalt-Klick auf einen Zauber fügt den Link ein):",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local text = editBox and editBox:GetText() or ""
        -- Ein eingefügter Link enthält die ID; eine reine Zahl ist sie selbst.
        local spellID = tonumber(text:match("spell:(%d+)")) or tonumber(text:match("%d+"))
        if not spellID then
            printMessage("Keine Zauber-ID erkannt.")
            return
        end
        local ok, err = FCD.Ranks:AddCustom(spellID)
        if not ok then
            printMessage("Nicht aufgenommen: " .. tostring(err))
            return
        end
        printMessage(string.format("'%s' aufgenommen - im Reiter Eigene Zauber"
            .. " anklicken, um ihn auf die Leiste zu legen.",
            FCD.Compat.GetSpellName(spellID) or ("Zauber " .. spellID)))
        FCD.Catalog:Rebuild()
        FCD.Dock:Refresh()
    end,
}

StaticPopupDialogs["FCD_ADD_ITEM"] = {
    text = "Gegenstand aufnehmen - ID oder Link einfügen\n(Shift-Klick auf einen Gegenstand fügt den Link ein):",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local text = editBox and editBox:GetText() or ""
        -- Ein eingefügter Link enthält die ID; eine reine Zahl ist sie selbst.
        local itemID = tonumber(text:match("item:(%d+)")) or tonumber(text:match("%d+"))
        if not itemID then
            printMessage("Keine Gegenstands-ID erkannt.")
            return
        end
        FCD.Items:AddCustom(itemID)
        local name = FCD.Compat.GetItemInfo(itemID)
        printMessage(string.format("'%s' aufgenommen.", name or ("Item " .. itemID)))
        FCD.Dock:Refresh()
    end,
}

StaticPopupDialogs["FCD_DELETE_LAYOUT_PROFILE"] = {
    text = "Layout '%s' wirklich verwerfen?",
    button1 = "Verwerfen",
    button2 = "Abbrechen",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        local name = FCD.Dock.profileToDelete
        if not name then
            return
        end
        FCD.Dock.profileToDelete = nil
        local ok, err = FCD.Layout:DeleteProfile(name)
        if not ok then
            printMessage("Nicht verworfen: " .. tostring(err))
            return
        end
        if FCD.db.settings.activeLayoutProfile == name then
            FCD.db.settings.activeLayoutProfile = nil
        end
        printMessage("Layout '" .. name .. "' verworfen. Die Zuweisungen bleiben,"
            .. " bis ein anderes Layout gewählt wird.")
        FCD.Store:Save(true)
        FCD.Dock:Refresh()
    end,
}

StaticPopupDialogs["FCD_NEW_LAYOUT_PROFILE"] = {
    text = "Name für das Layout-Profil:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        local name = editBox and editBox:GetText() or ""
        local ok, err = FCD.Layout:SaveProfile(name)
        printMessage(ok and ("Layout-Profil '" .. name .. "' gespeichert und aktiv.")
            or ("Nicht gespeichert: " .. tostring(err)))
        if ok then
            -- Wer ein Profil anlegt, will es auch benutzen
            FCD.db.settings.activeLayoutProfile = name
            -- Sofort sichern statt auf den Achter-Takt zu warten: wer gleich
            -- danach neu lädt, hätte es sonst verloren.
            FCD.Store:Save(true)
            FCD.Dock:Refresh()
        end
    end,
}

function FCD:RefreshData()
    self.Catalog:Rebuild()
    self.Viewer:RebuildAll()
end

local pendingRebuild = false
local function scheduleRebuild(delay)
    if pendingRebuild then
        return
    end
    pendingRebuild = true
    local after = C_Timer and C_Timer.After
    if type(after) == "function" then
        after(delay or 0.5, function()
            pendingRebuild = false
            FCD:RefreshData()
        end)
    else
        pendingRebuild = false
        FCD:RefreshData()
    end
end

local loginDone = false

local function onEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name ~= FCD.name then
            return
        end
        FCD.Compat.Detect()
        FCD.Profiles:Initialize()
        return
    end

    if event == "PLAYER_LOGIN" then
        -- Zweiter Blick auf die gespeicherten Daten: kamen sie erst nach
        -- ADDON_LOADED an, werden sie hier übernommen statt überschrieben.
        if FCD.Profiles:AdoptLateData() then
            logMessage("Gespeicherte Daten kamen verspaetet an und wurden"
                .. " nachträglich übernommen.")
        end
        -- Es gibt zwei Quellen: die gespeicherte Datei und Blizzards
        -- Layout-Speicher. Genommen wird die reichhaltigere - sonst
        -- überschreibt ein leerer Vorgabestand aus der Datei den echten
        -- Bestand aus dem Layout.
        local loaded = FCD.dbLoadInfo or {}
        local stored = FCD.Store:Load()
        if stored then
            -- Layout-Profile zählen mit: der Vergleich sah vorher nur die
            -- Leisteneinträge, und ein neu angelegtes Layout ging deshalb
            -- verloren, wenn die Datei gleich viele Einträge hatte.
            local function weigh(profiles, layouts)
                local count = 0
                for _, profile in pairs(profiles or {}) do
                    for _, bar in ipairs(type(profile) == "table" and profile.bars or {}) do
                        count = count + #(bar.entries or {})
                    end
                end
                for _ in pairs(layouts or {}) do
                    count = count + 1
                end
                return count
            end
            local storedEntries = weigh(stored.profiles, stored.layoutProfiles)
            local fileEntries = (loaded.entries or 0)
                + weigh(nil, FCD.db.layoutProfiles)
            loaded.entries = fileEntries
            if storedEntries > fileEntries then
                FCD.Profiles:AdoptStore(stored)
                logMessage(string.format("Bestand aus Blizzards Layout"
                    .. " übernommen (%d Einträge, Datei hatte %d).",
                    storedEntries, loaded.entries or 0))
            else
                logMessage(string.format("Datei ist aktueller als das Layout"
                    .. " (%d gegen %d Einträge).", loaded.entries or 0, storedEntries))
            end
        else
            logMessage("Kein Bestand im Layout: " .. tostring(FCD.Store.status))
        end
        FCD:RefreshData()
        FCD.Viewer:SetUnlocked(not FCD.db.settings.locked)
        FCD.Profiles:EvaluateRules()
        loginDone = true
        logMessage(string.format("geladen. Client %s (Build %s), Interface %d.",
            FCD.clientVersion, tostring(FCD.build), FCD.tocVersion))
        -- Beim Anmelden ohne Nachfragen sagen, was aus der Datenbank kam.
        -- Ob Profile eine Sitzung überleben, war sonst nur zu erraten.
        local layoutNames = FCD.Layout:ListProfiles()
        if #layoutNames > 0 then
            logMessage(string.format("%d Layout-Profil(e): %s. Aktiv: %s.",
                #layoutNames, table.concat(layoutNames, ", "),
                tostring(FCD.db.settings.activeLayoutProfile or "keines")))
        else
            logMessage("Keine Layout-Profile gespeichert.")
        end
        -- Was der Client an gespeicherten Daten übergeben hat, bevor das
        -- AddOn sie anfasst. Weicht das von dem ab, was die Datei enthält,
        -- liegt es am Einlesen und nicht an uns.
        local loadInfo = FCD.dbLoadInfo or {}
        if loadInfo.restoredFromMirror then
            logMessage("Die kontoweite Datei kam leer an - Bestand aus der"
                .. " Zweitablage des Charakters wiederhergestellt.")
        elseif not loadInfo.present and not stored then
            -- Nur beunruhigen, wenn BEIDE Quellen nichts hergaben. Liefert
            -- das Layout den Bestand, ist die leere Datei kein Problem.
            printMessage("|cffff6060Aus der Datei kam nichts an|r - die"
                .. " gespeicherten Daten wurden nicht geladen.")
            printMessage(string.format("  ForeverCooldownsDB: %s, FCDStore: %s",
                loadInfo.viaLong and "da" or "leer",
                loadInfo.viaShort and "da" or "leer"))
            -- Was der Client selbst über unser AddOn weiß. Kennt er die
            -- SavedVariables-Zeile nicht, hat er die .toc nicht so gelesen
            -- wie wir sie geschrieben haben - und dann kann er die Dateien
            -- gar nicht zuordnen.
            for _, line in ipairs(FCD.Probe:BuildRegistrationLines()) do
                printMessage(line)
            end
        else
            logMessage(string.format("Aus der Datei geladen: %d Profil(e),"
                .. " %d Leiste(n), %d Eintrag/Einträge.",
                loadInfo.profiles or 0, loadInfo.bars or 0, loadInfo.entries or 0))
        end
        -- Locale.lua setzt die Sprache beim Laden nach der Clientsprache;
        -- eine eigene Wahl steht erst jetzt zur Verfuegung.
        if FCD.db.settings.language then
            FCD.SetLanguage(FCD.db.settings.language)
        end

        -- Beim Anmelden ungefragt sagen, was auf den eigenen Leisten liegt.
        -- Ob ein Eintrag die Sitzung überlebt, war sonst nur zu erraten.
        local profile = FCD.Profiles:GetActive()
        if profile then
            local parts = {}
            for _, bar in ipairs(profile.bars) do
                if #bar.entries > 0 then
                    parts[#parts + 1] = string.format("%s: %d",
                        bar.name or ("Leiste " .. tostring(bar.id)), #bar.entries)
                end
            end
            -- "Alle Leisten leer" las sich wie ein Verlust, auch wenn nie
            -- etwas angelegt war. Die beiden Fälle gehören auseinander.
            local summary
            if #parts > 0 then
                summary = table.concat(parts, ", ")
            elseif #profile.bars > 0 then
                summary = "Leisten angelegt, aber ohne Einträge"
            else
                summary = "keine eigenen Leisten in Benutzung"
            end
            logMessage(string.format("Profil '%s' - %s.", profile.name or "?", summary))
        else
            logMessage("Kein Profil aktiv - eigene Leisten bleiben leer.")
        end
        local declared = FCD.Compat.GetDeclaredInterface()
        if declared and FCD.tocVersion > 0 and declared ~= FCD.tocVersion then
            logMessage(string.format("Hinweis: .toc meldet Interface %d,"
                .. " der Client %d.", declared, FCD.tocVersion))
        end
        logMessage("/fcd öffnet den Editor, /fcd log zeigt diese Ausgaben"
            .. " zum Kopieren.")
        return
    end

    if not loginDone then
        return
    end

    if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB"
        or event == "LEARNED_SPELL_IN_SKILL_LINE"
        or event == "PLAYER_LEVEL_UP" or event == "PLAYER_TALENT_UPDATE" then
        -- Neuer Rang gelernt: Einträge im Modus "bester Rang" ziehen
        -- automatisch nach, ohne dass die Leiste angefasst werden muss.
        scheduleRebuild(1)
    elseif event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "GET_ITEM_INFO_RECEIVED" then
        -- GET_ITEM_INFO_RECEIVED kommt nach, wenn der Client die Daten eines
        -- Gegenstands nachgeladen hat. Ohne das bliebe ein Eintrag bis zum
        -- nächsten Taschenwechsel namenlos und blass.
        scheduleRebuild(1)
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "ACTIVE_TALENT_GROUP_CHANGED"
        or event == "PLAYER_SPECIALIZATION_CHANGED" then
        FCD.Profiles:EvaluateRules()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        FCD.Profiles:EvaluateRules()
        FCD.Viewer:Update()
    end
end

local events = CreateFrame("Frame")

FCD.registeredEvents = {}
FCD.unavailableEvents = {}

-- Ereignisnamen sind zwischen den Builds nicht stabil: LEARNED_SPELL_IN_TAB
-- heißt in neueren Clients LEARNED_SPELL_IN_SKILL_LINE, und ein unbekannter
-- Name wirft einen Fehler statt ihn zu ignorieren. Deshalb wird jede
-- Registrierung einzeln versucht und festgehalten, welche gegriffen hat.
local function tryRegister(name)
    if pcall(events.RegisterEvent, events, name) then
        FCD.registeredEvents[#FCD.registeredEvents + 1] = name
        return true
    end
    FCD.unavailableEvents[#FCD.unavailableEvents + 1] = name
    return false
end

local WANTED_EVENTS = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "SPELLS_CHANGED",
    "LEARNED_SPELL_IN_TAB",
    "LEARNED_SPELL_IN_SKILL_LINE",
    "PLAYER_LEVEL_UP",
    "BAG_UPDATE_DELAYED",
    "GET_ITEM_INFO_RECEIVED",
    "PLAYER_EQUIPMENT_CHANGED",
    "UPDATE_SHAPESHIFT_FORM",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "PLAYER_TALENT_UPDATE",
}

for _, name in ipairs(WANTED_EVENTS) do
    tryRegister(name)
end

events:SetScript("OnEvent", onEvent)
