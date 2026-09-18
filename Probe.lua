local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local Probe = {}
FCD.Probe = Probe

-- Jedes geplante Feature hängt an konkreten API-Funktionen. Die Matrix macht
-- sichtbar, was dieser Client wirklich hergibt, statt es zu vermuten.
local FEATURES = {
    { name = L["Eigene Leisten, Layout, Sichtbarkeit"], needs = {} },
    { name = L["Mehrfachauswahl und Sammelaktionen"], needs = {} },
    { name = L["Profile, Import/Export, Rückgängig"], needs = {} },
    { name = L["Rang-Stapelung (immer bester Rang)"], needs = { "spellbook", "spellSubtext" } },
    { name = L["Downranking (fester Rang)"], needs = { "spellbook", "spellSubtext" } },
    { name = L["Rangzahl auf dem Icon"], needs = { "spellSubtext" } },
    { name = L["Abklingzeit-Anzeige"], needs = { "spellCooldown" } },
    { name = L["Aufladungen / Stapel"], needs = { "spellCharges" }, optional = true },
    { name = L["Ressourcen-Abdunklung (zu wenig Wut)"], needs = { "spellUsable" } },
    { name = L["Filter 'nur mit Abklingzeit'"], needs = { "spellBaseCooldown" }, optional = true },
    { name = L["Item- und Schmuckstück-Abklingzeiten"], needs = { "itemCooldown", "inventoryCooldown" } },
    { name = L["Aura-/Buff-Verfolgung"], needs = { "aura" }, optional = true },
    { name = L["Abgleich mit dem Blizzard-Manager"], needs = { "cooldownViewerRead", "cooldownViewerInfo" } },
    -- Umsortieren geht über zwei Wege. Der Layout-Weg ist der tragende; die
    -- Zeile stand vorher auf "fehlt", obwohl das Umsortieren funktioniert -
    -- sie prüfte nur den zweiten, schnelleren Weg.
    { name = L["Blizzards Kategorien umsortieren"], needs = { "layoutRead", "layoutWrite" } },
    { name = L["... ohne Neuladen wirksam"], needs = { "cooldownViewerWrite" }, optional = true },
    { name = L["Fertig-Meldung (Leuchten und Ton)"], forbids = { "secretCooldown" } },
    { name = L["Blizzards Leuchten für 'bereit'"], needs = { "overlayGlow" }, optional = true },
    { name = L["Ihre Leisten im eigenen Fenster einstellen"],
        needs = { "editModeSettings" }, optional = true },
    { name = L["Profilwechsel bei Haltung/Form"], needs = { "shapeshift" }, optional = true },
    { name = L["Profilwechsel bei Spezialisierung"], needs = { "specialization" }, optional = true },
}

local function statusFor(feature)
    local caps = Compat.caps
    local missing = {}

    -- Manche Merkmale scheitern nicht an einer fehlenden Funktion, sondern an
    -- einer vorhandenen Einschränkung - geschützte Abklingzeit-Werte etwa.
    for _, key in ipairs(feature.forbids or {}) do
        if caps[key] then
            return "fehlt", key .. L[" (Client-Einschränkung)"]
        end
    end

    for _, key in ipairs(feature.needs or {}) do
        if not caps[key] then
            missing[#missing + 1] = key
        end
    end
    if #missing == 0 then
        return "ok", nil
    end
    if #missing < #(feature.needs or {}) then
        return "teilweise", table.concat(missing, ", ")
    end
    return feature.optional and "fehlt-optional" or "fehlt", table.concat(missing, ", ")
end

local STATUS_TEXT = {
    ["ok"] = "|cff40dd40[geht]|r     ",
    ["teilweise"] = "|cffffcc00[teilweise]|r",
    ["fehlt-optional"] = "|cffff9933[fehlt]|r    ",
    ["fehlt"] = "|cffff4040[fehlt]|r    ",
}

function Probe:PrintFeatureMatrix()
    Compat.Detect()
    FCD.Print(L["Funktionsprüfung für Client-Build "] .. tostring(FCD.build) .. ":")
    for _, feature in ipairs(FEATURES) do
        local status, missing = statusFor(feature)
        local line = (STATUS_TEXT[status] or "") .. " " .. feature.name
        if missing then
            line = line .. " |cff888888(" .. missing .. ")|r"
        end
        FCD.Print(line)
    end
    if Compat.caps.secretCooldown then
        FCD.Print(L["|cffffcc00Hinweis:|r Dieser Client schützt Abklingzeit-Werte. Wischer und Restzeit"]
            .. L[" zeichnet die Blizzard-Uhr; eigene Restzeit, GCD-Unterdrückung und das Abdunkeln"]
            .. L[" laufender Abklingzeiten entfallen."])
    end
end

local function describeValue(value)
    local valueType = type(value)
    if valueType == "table" then
        -- Listeninhalte ausschreiben: bei linkedSpellIDs stehen dort die
        -- Ränge, und genau die sind die interessante Information.
        local shown, count = {}, 0
        for _, item in ipairs(value) do
            count = count + 1
            if count <= 12 then
                shown[#shown + 1] = tostring(item)
            end
        end
        if count > 0 then
            return string.format("table(%d) { %s%s }", count,
                table.concat(shown, ", "), count > 12 and ", ..." or "")
        end
        local keys = 0
        for _ in pairs(value) do
            keys = keys + 1
        end
        return string.format("table(%d)", keys)
    elseif valueType == "string" then
        return string.format("string %q", value)
    end
    return valueType .. " " .. tostring(value)
end

-- Schreibt eine verschachtelte Tabelle lesbar aus. Werte können geschützt
-- sein, deshalb geht jede Ausgabe über SafeToString.
local function dumpTable(lines, indent, label, value, depth)
    local prefix = string.rep("  ", indent)
    if type(value) ~= "table" then
        lines[#lines + 1] = prefix .. label .. " = " .. type(value) .. " " .. Compat.SafeToString(value)
        return
    end
    if depth <= 0 then
        lines[#lines + 1] = prefix .. label .. " = table (Tiefe erreicht)"
        return
    end

    lines[#lines + 1] = prefix .. label .. " = {"
    local arrayLength = #value
    for index = 1, math.min(arrayLength, 40) do
        dumpTable(lines, indent + 1, "[" .. index .. "]", value[index], depth - 1)
    end
    if arrayLength > 40 then
        lines[#lines + 1] = prefix .. "  ... und " .. (arrayLength - 40) .. " weitere"
    end

    local keys = {}
    for key in pairs(value) do
        local isArrayIndex = type(key) == "number" and key >= 1 and key <= arrayLength and math.floor(key) == key
        if not isArrayIndex then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b) return Compat.SafeToString(a) < Compat.SafeToString(b) end)
    for _, key in ipairs(keys) do
        dumpTable(lines, indent + 1, Compat.SafeToString(key), value[key], depth - 1)
    end
    lines[#lines + 1] = prefix .. "}"
end

-- Beantwortet die Frage, ob sich Blizzards Kategorien überhaupt bearbeiten
-- lassen: was GetLayoutData liefert und ob das Schreiben erlaubt wäre.
function Probe:BuildLayoutReport()
    local lines = {
        "Forever Cooldowns - Layout-Daten des Abklingzeit-Managers",
        string.format("Client %s, Build %s", FCD.clientVersion, tostring(FCD.build)),
        "",
        "GetLayoutData vorhanden: " .. tostring(Compat.HasLayoutData()),
        "SetLayoutData vorhanden: " .. tostring(Compat.CanWriteLayoutData()),
        "",
    }

    if not Compat.HasLayoutData() then
        lines[#lines + 1] = "Ohne GetLayoutData ist hier nichts zu holen."
        return table.concat(lines, "\n")
    end

    lines[#lines + 1] = L["== Werkzeuge zum Entschlüsseln =="]
    local encodingMembers = Compat.DumpNamespace(C_EncodingUtil)
    if #encodingMembers == 0 then
        lines[#lines + 1] = L["  C_EncodingUtil fehlt - der Blob lässt sich nicht öffnen."]
    end
    for _, member in ipairs(encodingMembers) do
        lines[#lines + 1] = string.format("  %-40s %s", member.name, member.kind)
    end

    -- Beim Umschalten im Blizzard-Fenster feuern HIDDEN_GROUP_BUFFS_CHANGED
    -- und GROUP_BUFF_VISUAL_ALERTS_CHANGED, aber kein COOLDOWN-Ereignis.
    -- Deshalb interessiert, was GetGroupBuffItems liefert.
    lines[#lines + 1] = ""
    lines[#lines + 1] = "== GetGroupBuffItems() =="
    local groupBuffs, groupErr = Compat.GetGroupBuffItems()
    if groupErr then
        lines[#lines + 1] = "  " .. groupErr
    elseif groupBuffs == nil then
        lines[#lines + 1] = "  nil"
    else
        dumpTable(lines, 1, "groupBuffs", groupBuffs, 5)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "== GetLayoutData() =="
    local data, err = Compat.GetLayoutData()
    if err then
        lines[#lines + 1] = "  Fehler: " .. err
        return table.concat(lines, "\n")
    end

    if type(data) == "string" then
        lines[#lines + 1] = string.format("  Zeichenkette, %d Zeichen", #data)
        lines[#lines + 1] = "  Anfang: " .. string.sub(data, 1, 120)

        -- Liefert die Funktion je Kategorie etwas anderes? Sonst nicht wiederholen.
        local differing = {}
        for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
            local perCategory = Compat.GetLayoutData(category.value)
            if perCategory ~= data then
                differing[#differing + 1] = category.name
            end
        end
        lines[#lines + 1] = #differing > 0
            and ("  Abweichend je Kategorie: " .. table.concat(differing, ", "))
            or "  Alle Kategorien liefern denselben Blob (Argument wird ignoriert)."
    else
        dumpTable(lines, 1, "layout", data, 6)
    end

    -- Zeigt, wie ein Blob aussieht, den dieser Client selbst erzeugt.
    -- Stimmt die Form mit den Layout-Daten überein, ist die Kette gefunden.
    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Selbsttest: eigener Blob mit Blizzards Funktionen =="
    for _, line in ipairs(Compat.EncodingSelfTest()) do
        lines[#lines + 1] = "  " .. line
    end

    -- Wie fangen die Layout-Daten an? Bytewerte verraten den Zeilentrenner.
    if type(data) == "string" then
        local prefix = {}
        for index = 1, math.min(8, #data) do
            prefix[#prefix + 1] = string.byte(data, index)
        end
        lines[#lines + 1] = "  Erste Bytes der Layout-Daten: " .. table.concat(prefix, " ")
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = L["== Entschlüsselt =="]
    local decoded, decodeErr, steps = Compat.DecodeLayoutString(data)
    for _, step in ipairs(steps or {}) do
        lines[#lines + 1] = "  " .. step
    end
    if decoded then
        lines[#lines + 1] = ""
        dumpTable(lines, 1, "layout", decoded, 8)

        -- Der eigentlich interessante Teil, mit aufgelösten Namen: nur so
        -- wird sichtbar, ob die Schlüssel den Kategorie-Werten entsprechen.
        local categories, path = Compat.FindLayoutCategories(decoded)
        lines[#lines + 1] = ""
        lines[#lines + 1] = "== Zuordnung Kategorie -> Abklingzeiten =="
        if not categories then
            lines[#lines + 1] = "  Keine Kategorie-Zuordnung gefunden."
        else
            lines[#lines + 1] = "  Gefunden unter: " .. tostring(path)
            local keys = {}
            for key in pairs(categories) do
                keys[#keys + 1] = key
            end
            table.sort(keys)
            for _, key in ipairs(keys) do
                local list = categories[key]
                lines[#lines + 1] = string.format(L["  Schlüssel %s (%d Einträge):"], tostring(key), #list)
                for _, cooldownID in ipairs(list) do
                    local info = Compat.GetCooldownInfo(cooldownID)
                    local spellID = info and (info.spellID or info.overrideSpellID)
                    local name = spellID and Compat.GetSpellName(spellID) or "?"
                    local subText = spellID and Compat.GetSpellSubtext(spellID)
                    lines[#lines + 1] = string.format("    %d -> Zauber %s, %s%s",
                        cooldownID, tostring(spellID or "?"), name,
                        (subText and subText ~= "") and (" [" .. subText .. "]") or "")
                end
            end
            lines[#lines + 1] = ""
            lines[#lines + 1] = "  Zum Vergleich, was GetCooldownViewerCategorySet meldet:"
            for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
                local ids = Compat.GetCategorySet(category.value)
                if ids and #ids > 0 then
                    local parts = {}
                    for _, id in ipairs(ids) do
                        parts[#parts + 1] = tostring(id)
                    end
                    lines[#lines + 1] = string.format("    %s (%d): %s",
                        category.name, category.value, table.concat(parts, ", "))
                end
            end
        end
        lines[#lines + 1] = ""
        lines[#lines + 1] = L["Wenn hier die Zuordnung Kategorie -> Abklingzeit-IDs steht, lässt"]
        lines[#lines + 1] = L["sich Blizzards Manager direkt bearbeiten: ändern, neu serialisieren,"]
        lines[#lines + 1] = L["mit SetLayoutData zurückschreiben."]
    else
        lines[#lines + 1] = L["  Nicht entschlüsselbar: "] .. tostring(decodeErr)
    end

    return table.concat(lines, "\n")
end

-- Durchsucht Globals, C_*-Namespaces und Enums nach einem Textstück.
-- Der verlässlichste Weg, unbekannte Schnittstellen eines fremden Builds zu
-- finden - das Raten von Funktionsnamen hat uns bisher jedes Mal aufgehalten.
function Probe:BuildSearchReport(needle)
    if not needle or needle == "" then
        return "Format: /fcd find <Text>\nBeispiel: /fcd find groupbuff"
    end
    local lower = string.lower(needle)
    local lines = {
        "Forever Cooldowns - Suche nach '" .. needle .. "'",
        "",
    }

    local globals, members, enumTypes, enumValues = {}, {}, {}, {}

    for name, value in pairs(_G) do
        if type(name) == "string" then
            if string.find(string.lower(name), lower, 1, true) then
                globals[#globals + 1] = string.format("  %s  (%s)", name, type(value))
            end

            if type(value) == "table" and string.sub(name, 1, 2) == "C_" then
                for member, memberValue in pairs(value) do
                    if type(member) == "string" and string.find(string.lower(member), lower, 1, true) then
                        members[#members + 1] = string.format("  %s.%s  (%s)", name, member, type(memberValue))
                    end
                end
            end
        end
    end

    if type(Enum) == "table" then
        for enumName, enumTable in pairs(Enum) do
            if type(enumName) == "string" then
                if string.find(string.lower(enumName), lower, 1, true) then
                    enumTypes[#enumTypes + 1] = "  Enum." .. enumName
                end
                if type(enumTable) == "table" then
                    for constant, constantValue in pairs(enumTable) do
                        if type(constant) == "string"
                            and string.find(string.lower(constant), lower, 1, true) then
                            enumValues[#enumValues + 1] = string.format("  Enum.%s.%s = %s",
                                enumName, constant, Compat.SafeToString(constantValue))
                        end
                    end
                end
            end
        end
    end

    local function section(title, list)
        table.sort(list)
        lines[#lines + 1] = string.format("== %s (%d) ==", title, #list)
        if #list == 0 then
            lines[#lines + 1] = "  keine"
        end
        for index = 1, math.min(#list, 80) do
            lines[#lines + 1] = list[index]
        end
        if #list > 80 then
            lines[#lines + 1] = "  ... und " .. (#list - 80) .. " weitere"
        end
        lines[#lines + 1] = ""
    end

    section("Globale Namen", globals)
    section("Mitglieder von C_*-Namespaces", members)
    section("Enum-Typen", enumTypes)
    section("Enum-Konstanten", enumValues)

    return table.concat(lines, "\n")
end

-- Listet die Mitglieder eines Objekts auf, das über seinen Namen erreichbar
-- ist - auch verschachtelt ("A.B.C"). Blizzards eigene Mixins liegen als
-- globale Tabellen vor; ihre Methodennamen sagen, wie ihr Fenster arbeitet.
function Probe:BuildDumpReport(pathText)
    if not pathText or pathText == "" then
        return "Format: /fcd dump <Name>\nBeispiel: /fcd dump CooldownViewerLayoutManagerMixin"
    end

    local target, walked = _G, {}
    for part in string.gmatch(pathText, "[^%.]+") do
        if type(target) ~= "table" then
            return "Kein Objekt unter '" .. table.concat(walked, ".") .. "'."
        end
        target = target[part]
        walked[#walked + 1] = part
        if target == nil then
            return "'" .. table.concat(walked, ".") .. "' existiert nicht."
        end
    end

    local lines = {
        "Forever Cooldowns - Inhalt von " .. pathText,
        "Typ: " .. type(target),
    }

    if type(target) == "table" and type(target.GetObjectType) == "function" then
        local ok, objectType = pcall(target.GetObjectType, target)
        if ok then
            lines[#lines + 1] = "Frame-Typ: " .. Compat.SafeToString(objectType)
        end
        local shown, isShown = pcall(target.IsShown, target)
        if shown then
            lines[#lines + 1] = "Sichtbar: " .. Compat.SafeToString(isShown)
        end
    end

    if type(target) ~= "table" then
        lines[#lines + 1] = "Wert: " .. Compat.SafeToString(target)
        return table.concat(lines, "\n")
    end

    local functions, tables, values = {}, {}, {}
    for key, value in pairs(target) do
        local name = Compat.SafeToString(key)
        local kind = type(value)
        if kind == "function" then
            functions[#functions + 1] = "  " .. name
        elseif kind == "table" then
            local count = 0
            for _ in pairs(value) do
                count = count + 1
            end
            tables[#tables + 1] = string.format(L["  %s  (table, %d Einträge)"], name, count)
        else
            values[#values + 1] = string.format("  %s = %s  (%s)", name, Compat.SafeToString(value), kind)
        end
    end

    -- Geerbte Methoden stehen oft in der Metatabelle
    local metatable = getmetatable(target)
    local inherited = {}
    if type(metatable) == "table" and type(metatable.__index) == "table" then
        for key, value in pairs(metatable.__index) do
            if type(value) == "function" then
                inherited[#inherited + 1] = "  " .. Compat.SafeToString(key)
            end
        end
    end

    local function section(title, list)
        table.sort(list)
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("== %s (%d) ==", title, #list)
        if #list == 0 then
            lines[#lines + 1] = "  keine"
        end
        for index = 1, math.min(#list, 150) do
            lines[#lines + 1] = list[index]
        end
        if #list > 150 then
            lines[#lines + 1] = "  ... und " .. (#list - 150) .. " weitere"
        end
    end

    section("Funktionen", functions)
    section("Geerbte Funktionen (Metatabelle)", inherited)
    section("Tabellen", tables)
    section("Werte", values)

    return table.concat(lines, "\n")
end

-- Manche Tabellen sind für AddOn-Code gesperrt ("cannot be accessed while
-- tainted"); jeder Zugriff muss deshalb abgesichert sein.
local function safeIndex(object, key)
    local ok, value = pcall(function()
        return object[key]
    end)
    if ok then
        return value
    end
    return nil
end

-- Rückgabe: Liste von { key, value } oder nil, wenn nicht zugreifbar
local function safePairs(object)
    local entries = {}
    local ok = pcall(function()
        for key, value in pairs(object) do
            entries[#entries + 1] = { key = key, value = value }
        end
    end)
    if not ok then
        return nil
    end
    return entries
end

-- Eine Vorlage (Mixin) hat nur Funktionen; ein laufendes Objekt hat
-- zusätzlich Zustandsfelder. Genau daran lassen sich beide unterscheiden -
-- und der Aufruf auf einer Vorlage verpufft wirkungslos.
local function describeCandidate(path, object)
    local entries = safePairs(object)
    if not entries then
        return string.format("  %-52s (nicht lesbar, gesperrt)", path)
    end
    local functions, values = 0, 0
    for _, entry in ipairs(entries) do
        if type(entry.value) == "function" then
            functions = functions + 1
        else
            values = values + 1
        end
    end
    return string.format("  %-52s %d Funktionen, %d Werte  %s",
        path, functions, values,
        values > 0 and "<- sieht nach laufendem Objekt aus" or "(nur Vorlage)")
end

-- Sucht Objekte, die die gesuchten Methoden tragen - in _G und eine Ebene
-- tiefer in allen Tabellen, deren Name auf den Abklingzeit-Manager deutet.
function Probe:BuildInstanceReport()
    local SIGNATURES = {
        { label = L["Datenmodell"], methods = { "SetCooldownToCategory", "GetOrderedCooldownIDs" } },
        { label = L["Layout-Verwaltung"], methods = { "SaveLayouts", "GetActiveLayout" } },
    }

    local lines = {
        "Forever Cooldowns - Suche nach laufenden Objekten",
        "",
        L["Eine Vorlage trägt nur Funktionen. Erst ein Objekt mit Zustandsfeldern"],
        L["kann Änderungen wirklich ausführen."],
        "",
    }

    local function matches(object, methods)
        if type(object) ~= "table" then
            return false
        end
        for _, method in ipairs(methods) do
            if type(safeIndex(object, method)) ~= "function" then
                return false
            end
        end
        return true
    end

    -- Momentaufnahme von _G, damit die Iteration selbst nicht mitten in
    -- einem gesperrten Zugriff abbricht
    local globals = safePairs(_G) or {}
    local blocked = 0

    for _, signature in ipairs(SIGNATURES) do
        local found = {}
        for _, global in ipairs(globals) do
            local name, value = global.key, global.value
            if type(name) == "string" and type(value) == "table" then
                if matches(value, signature.methods) then
                    found[#found + 1] = describeCandidate(name, value)
                end
                -- Eine Ebene tiefer: Felder wie CooldownViewerSettings.dataProvider
                if string.find(name, "Cooldown", 1, true) then
                    local children = safePairs(value)
                    if children then
                        for _, child in ipairs(children) do
                            if type(child.key) == "string" and type(child.value) == "table"
                                and matches(child.value, signature.methods) then
                                found[#found + 1] = describeCandidate(name .. "." .. child.key, child.value)
                            end
                        end
                    else
                        blocked = blocked + 1
                    end
                end
            end
        end
        table.sort(found)
        lines[#lines + 1] = string.format("== %s (%d Treffer) ==", signature.label, #found)
        if #found == 0 then
            lines[#lines + 1] = "  keine"
        end
        for index = 1, math.min(#found, 60) do
            lines[#lines + 1] = found[index]
        end
        lines[#lines + 1] = ""
    end

    if blocked > 0 then
        lines[#lines + 1] = string.format(L["%d Tabelle(n) waren für AddOn-Code gesperrt und wurden übersprungen."], blocked)
        lines[#lines + 1] = ""
    end

    -- Liefern die bekannten Einstiegspunkte ein Objekt zurück?
    lines[#lines + 1] = L["== Rückgabe bekannter Einstiegspunkte =="]
    local entryPoints = {
        { "CooldownViewerSettings", "GetDataProvider" },
        { "CooldownViewerSettings", "GetLayoutManager" },
        { "CooldownViewerDataProvider", "GetLayoutManager" },
    }
    for _, entry in ipairs(entryPoints) do
        local owner = safeIndex(_G, entry[1])
        local label = entry[1] .. ":" .. entry[2] .. "()"
        local method = type(owner) == "table" and safeIndex(owner, entry[2]) or nil
        if type(owner) ~= "table" then
            lines[#lines + 1] = "  " .. label .. " - Objekt fehlt oder gesperrt"
        elseif type(method) ~= "function" then
            lines[#lines + 1] = "  " .. label .. " - Methode fehlt"
        else
            local ok, result = pcall(method, owner)
            if not ok then
                lines[#lines + 1] = "  " .. label .. " - Fehler: " .. Compat.SafeToString(result)
            elseif type(result) ~= "table" then
                lines[#lines + 1] = "  " .. label .. " -> " .. Compat.SafeToString(result)
            else
                lines[#lines + 1] = "  " .. label .. " ->"
                lines[#lines + 1] = describeCandidate("    (Ergebnis)", result)
            end
        end
    end

    return table.concat(lines, "\n")
end

-- Stellt Blizzards eigene Kategorielisten unseren gegenüber. Bisher habe ich
-- ihre Anzeige aus indirekten Daten zurückgerechnet und lag mehrfach daneben;
-- hier wird ihr Datenmodell direkt gefragt.
--
-- Achtung: das liest über ihre Lua-Schicht und markiert sie als tainted.
-- Deshalb ein eigener Befehl und keine Nebenwirkung der Oberfläche.
function Probe:BuildCategoryComparison()
    local lines = {
        "Forever Cooldowns - Abgleich der Kategorien",
        "",
        "Liest Blizzards Datenmodell direkt. Das markiert ihren Viewer als",
        L["tainted - ein /reload danach räumt das auf."],
        "",
    }

    local provider = FCD.Layout.GetDataProvider()
    if not provider then
        lines[#lines + 1] = L["Datenmodell nicht erreichbar. Blizzards Fenster einmal öffnen."]
        return table.concat(lines, "\n")
    end
    if type(provider.GetOrderedCooldownIDsForCategory) ~= "function" then
        lines[#lines + 1] = "GetOrderedCooldownIDsForCategory fehlt in diesem Client."
        return table.concat(lines, "\n")
    end

    FCD.Dock:LoadLayout()

    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        local ok, ids = pcall(provider.GetOrderedCooldownIDsForCategory, provider, category.value)
        local theirs, theirSet = {}, {}
        if ok and type(ids) == "table" then
            for _, id in ipairs(ids) do
                theirs[#theirs + 1] = id
                theirSet[id] = true
            end
        end

        local ours, ourSet = {}, {}
        for _, cooldownID in ipairs(FCD.Dock.staticOrder or {}) do
            if FCD.Dock:EffectiveCategory(cooldownID) == category.value then
                ours[#ours + 1] = cooldownID
                ourSet[cooldownID] = true
            end
        end

        lines[#lines + 1] = string.format("== %s (%d) ==  Blizzard: %d, wir: %d%s",
            category.name, category.value, #theirs, #ours,
            (#theirs == #ours) and "  gleich" or "  ABWEICHUNG")

        if #theirs ~= #ours then
            local missing, extra = {}, {}
            for _, id in ipairs(theirs) do
                if not ourSet[id] then
                    missing[#missing + 1] = id
                end
            end
            for _, id in ipairs(ours) do
                if not theirSet[id] then
                    extra[#extra + 1] = id
                end
            end

            local function describe(list, label)
                if #list == 0 then
                    return
                end
                lines[#lines + 1] = string.format("  %s (%d):", label, #list)
                for index = 1, math.min(#list, 8) do
                    local cooldownID = list[index]
                    local info = Compat.GetCooldownInfo(cooldownID)
                    local spellID = info and (info.spellID or info.overrideSpellID)
                    lines[#lines + 1] = string.format("    %d -> %s (Standard %s, unsere Zuweisung %s)",
                        cooldownID,
                        spellID and Compat.GetSpellName(spellID) or "?",
                        Compat.SafeToString(info and info.category),
                        Compat.SafeToString(FCD.Dock:EffectiveCategory(cooldownID)))
                end
                if #list > 8 then
                    lines[#lines + 1] = "    ... und " .. (#list - 8) .. " weitere"
                end
            end

            describe(missing, "bei Blizzard, bei uns nicht")
            describe(extra, "bei uns, bei Blizzard nicht")
        end
        lines[#lines + 1] = ""
    end

    return table.concat(lines, "\n")
end

-- Sucht das Feld, das Blizzards Aufteilung erklärt.
--
-- Ihre Abschnitte enthalten deutlich weniger Einträge als der Katalog einer
-- Kategorie. Irgendein Feld im Cache-Eintrag muss die beiden Gruppen trennen.
-- Statt weiter einzelne Felder zu raten, wird hier für jede Kategorie die
-- Werteverteilung aller Felder ausgezählt: Ein Feld, das die Menge in zwei
-- passende Hälften teilt, ist der gesuchte Schalter.
function Probe:BuildFieldAnalysis()
    local lines = {
        L["Forever Cooldowns - Felderanalyse der Cache-Einträge"],
        "",
        L["Gesucht ist ein Feld, dessen Werte die Einträge einer Kategorie so"],
        "aufteilen, wie Blizzards Fenster sie aufteilt.",
        "",
    }

    FCD.Dock:LoadLayout()

    -- Einträge nach Standardkategorie sammeln
    local byCategory = {}
    for _, cooldownID in ipairs(FCD.Dock.staticOrder or {}) do
        local info = Compat.GetCooldownInfo(cooldownID)
        local category = info and info.category
        if category ~= nil then
            byCategory[category] = byCategory[category] or {}
            table.insert(byCategory[category], { id = cooldownID, info = info })
        end
    end

    local categories = {}
    for category in pairs(byCategory) do
        categories[#categories + 1] = category
    end
    table.sort(categories)

    for _, category in ipairs(categories) do
        local entries = byCategory[category]
        lines[#lines + 1] = string.format(L["== Kategorie %d: %d Einträge =="], category, #entries)

        -- Welche Felder gibt es, und wie verteilen sich ihre Werte?
        local fields = {}
        for _, entry in ipairs(entries) do
            for field, value in pairs(entry.info) do
                if field ~= "linkedSpellIDs" and type(value) ~= "table" then
                    fields[field] = fields[field] or {}
                    local key = Compat.SafeToString(value)
                    fields[field][key] = (fields[field][key] or 0) + 1
                end
            end
        end

        local names = {}
        for field in pairs(fields) do
            names[#names + 1] = field
        end
        table.sort(names)

        for _, field in ipairs(names) do
            local values = {}
            for value, count in pairs(fields[field]) do
                values[#values + 1] = { value = value, count = count }
            end
            -- Felder mit nur einem Wert trennen nichts und sind uninteressant
            if #values > 1 then
                table.sort(values, function(a, b) return a.count > b.count end)
                local parts = {}
                for index = 1, math.min(#values, 6) do
                    parts[#parts + 1] = string.format("%s=%d", values[index].value, values[index].count)
                end
                lines[#lines + 1] = string.format("  %-16s %s", field, table.concat(parts, ", "))
            end
        end
        lines[#lines + 1] = ""
    end

    lines[#lines + 1] = "Felder mit nur einem Wert sind weggelassen - sie trennen nichts."
    return table.concat(lines, "\n")
end

-- Der tatsächliche Zustand steht im Cache-Eintrag selbst: isInvisible sagt,
-- ob der Eintrag ausgeblendet ist, category die wirksame Einordnung.
-- GetCooldownViewerCategorySet liefert dagegen nur die statische Zuordnung.
-- Rückgabe: kurzbeschreibung, infotabelle
function Probe:GetEffectiveState(cooldownID)
    local info = Compat.GetCooldownInfo(cooldownID)
    if type(info) ~= "table" then
        return "kein Cache-Eintrag", nil
    end
    return string.format("Kategorie %s, isInvisible=%s, isKnown=%s",
        tostring(info.category), tostring(info.isInvisible), tostring(info.isKnown)), info
end

-- Der wirklich wirksame Zustand steht im laufenden Datenmodell, nicht in den
-- C_CooldownViewer-Abfragen: die liefern die statische Einordnung und ändern
-- sich nicht, wenn der Spieler etwas umstellt.
-- Rückgabe: kurzbeschreibung, zeilenliste
function Probe:GetLiveState(cooldownID)
    local provider = FCD.Layout.GetDataProvider()
    if not provider then
        return "Datenmodell nicht erreichbar", {}
    end

    local lines, categories = {}, {}

    if type(provider.GetOrderedCooldownIDsForCategory) == "function" then
        for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
            local ok, ids = pcall(provider.GetOrderedCooldownIDsForCategory, provider, category.value)
            if ok and type(ids) == "table" then
                for position, id in ipairs(ids) do
                    if id == cooldownID then
                        categories[#categories + 1] = string.format("%s (%d), Platz %d",
                            category.name, category.value, position)
                    end
                end
            end
        end
    else
        lines[#lines + 1] = "GetOrderedCooldownIDsForCategory fehlt"
    end

    if type(provider.GetCooldownInfoForID) == "function" then
        local ok, info = pcall(provider.GetCooldownInfoForID, provider, cooldownID)
        if ok and type(info) == "table" then
            local fields = {}
            for field in pairs(info) do
                fields[#fields + 1] = field
            end
            table.sort(fields)
            for _, field in ipairs(fields) do
                if field ~= "linkedSpellIDs" then
                    lines[#lines + 1] = string.format("    %-20s %s", field, describeValue(info[field]))
                end
            end
        elseif ok then
            lines[#lines + 1] = "GetCooldownInfoForID liefert " .. Compat.SafeToString(info)
        else
            lines[#lines + 1] = "GetCooldownInfoForID wirft: " .. Compat.SafeToString(info)
        end
    end

    local summary = #categories > 0 and table.concat(categories, "; ") or "in keiner Kategorie des Modells"
    return summary, lines
end

-- In welchen Kategoriemengen meldet die API diese Abklingzeit?
function Probe:FindInCategorySets(cooldownID)
    local hits = {}
    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        local ids = Compat.GetCategorySet(category.value)
        if ids then
            for _, id in ipairs(ids) do
                if id == cooldownID then
                    hits[#hits + 1] = string.format("%s (%d)", category.name, category.value)
                end
            end
        end
    end
    return hits
end

-- Stellt Blob-Zustand und API-Zustand nebeneinander. Damit lässt sich eine
-- Änderung messen, statt sie im Blizzard-Fenster zu erraten - dort sind
-- ohnehin alle Einträge sichtbar, aktive nur hervorgehoben.
-- Als Text statt in den Chat: nur im Textfenster lässt es sich kopieren.
function Probe:BuildCooldownStateReport(cooldownID)
    if not cooldownID then
        return "Format: /fcd state <AbklingzeitID>. Die IDs stehen in /fcd layout."
    end

    local info = Compat.GetCooldownInfo(cooldownID)
    local spellID = info and (info.spellID or info.overrideSpellID)
    local name = spellID and Compat.GetSpellName(spellID) or "unbekannt"
    local subText = spellID and Compat.GetSpellSubtext(spellID)

    local lines = {
        "Forever Cooldowns - Zustand einer Abklingzeit",
        string.format("Client %s, Build %s", FCD.clientVersion, tostring(FCD.build)),
        "",
        string.format("Abklingzeit %d: %s%s (Zauber %s)", cooldownID, name,
            (subText and subText ~= "") and (", " .. subText) or "", tostring(spellID or "?")),
        "",
    }

    local state, err = FCD.Layout:Read()
    if not state then
        lines[#lines + 1] = "Blob nicht lesbar: " .. tostring(err)
    else
        local assigned = FCD.Layout:GetAssignedCategory(state, cooldownID)
        lines[#lines + 1] = "Im Blob: " .. (FCD.Layout:IsHidden(state, cooldownID)
            and "ausgeblendet (-1)"
            or (assigned and ("Kategorie " .. assigned) or "keine Abweichung vom Standard"))
        local position
        for index, id in ipairs(state.order or {}) do
            if id == cooldownID then
                position = index
            end
        end
        lines[#lines + 1] = "Reihenfolge-Position: " .. tostring(position or "nicht gelistet")
            .. " von " .. #(state.order or {})
    end

    local hits = self:FindInCategorySets(cooldownID)
    lines[#lines + 1] = "Statische Zuordnung: " .. (#hits > 0 and table.concat(hits, ", ") or "keine")

    -- Der wirksame Zustand, auf den es ankommt
    local summary, cacheInfo = self:GetEffectiveState(cooldownID)
    lines[#lines + 1] = "Wirksam: " .. summary
    if cacheInfo then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Cache-Eintrag:"
        local fields = {}
        for field in pairs(cacheInfo) do
            fields[#fields + 1] = field
        end
        table.sort(fields)
        for _, field in ipairs(fields) do
            lines[#lines + 1] = string.format("  %-18s %s", field, describeValue(cacheInfo[field]))
        end
    end

    return table.concat(lines, "\n")
end


-- Sichert den aktuellen Layout-Blob, damit sich nach einer Änderung im
-- Blizzard-Fenster genau ablesen lässt, was sich bewegt hat.
function Probe:SnapshotLayout()
    local data, err = Compat.GetLayoutData()
    if err or type(data) ~= "string" then
        FCD.Print(L["GetLayoutData lieferte nichts ("] .. tostring(err) .. ").")
        return false
    end
    FCD.db.layoutSnapshot = { raw = data, taken = date("%Y-%m-%d %H:%M:%S") }
    FCD.Print(L["Momentaufnahme gespeichert ("] .. #data .. L[" Zeichen). Jetzt im Blizzard-Fenster"])
    FCD.Print(L["etwas ändern, dann  /fcd diff  aufrufen."])
    return true
end

local function describeCooldownID(value)
    if type(value) ~= "number" or value < 100000 then
        return Compat.SafeToString(value)
    end
    local info = Compat.GetCooldownInfo(value)
    local spellID = info and (info.spellID or info.overrideSpellID)
    local name = spellID and Compat.GetSpellName(spellID)
    if not name then
        return tostring(value)
    end
    local subText = Compat.GetSpellSubtext(spellID)
    return string.format("%d (%s%s)", value, name,
        (subText and subText ~= "") and (", " .. subText) or "")
end

-- Allgemeiner Tabellenvergleich über Pfade. Bewusst ohne Annahme über die
-- Struktur, damit auch Änderungen auffallen, die ich nicht erwarte.
local function diffTables(before, after, path, out)
    local keys = {}
    for key in pairs(before) do
        keys[key] = true
    end
    for key in pairs(after) do
        keys[key] = true
    end
    local sorted = {}
    for key in pairs(keys) do
        sorted[#sorted + 1] = key
    end
    table.sort(sorted, function(a, b) return Compat.SafeToString(a) < Compat.SafeToString(b) end)

    for _, key in ipairs(sorted) do
        local valueBefore, valueAfter = before[key], after[key]
        local childPath = path .. "[" .. Compat.SafeToString(key) .. "]"
        if type(valueBefore) == "table" and type(valueAfter) == "table" then
            diffTables(valueBefore, valueAfter, childPath, out)
        elseif type(valueBefore) == "table" or type(valueAfter) == "table" then
            -- Ein ganzer Teilbaum kam dazu oder fiel weg. Die Tabellenadresse
            -- auszugeben wäre wertlos, also den Inhalt ausschreiben.
            out[#out + 1] = { path = childPath, subtreeBefore = valueBefore, subtreeAfter = valueAfter }
        elseif valueBefore ~= valueAfter then
            out[#out + 1] = { path = childPath, before = valueBefore, after = valueAfter }
        end
    end
end

function Probe:BuildLayoutDiff()
    local lines = { "Forever Cooldowns - Vergleich der Layout-Daten", "" }

    local snapshot = FCD.db.layoutSnapshot
    if not snapshot or not snapshot.raw then
        lines[#lines + 1] = "Keine Momentaufnahme vorhanden. Erst  /fcd snapshot  aufrufen,"
        lines[#lines + 1] = L["dann im Blizzard-Fenster etwas ändern, dann  /fcd diff."]
        return table.concat(lines, "\n")
    end
    lines[#lines + 1] = "Momentaufnahme von " .. tostring(snapshot.taken)

    local current, err = Compat.GetLayoutData()
    if err or type(current) ~= "string" then
        lines[#lines + 1] = "GetLayoutData lieferte nichts: " .. tostring(err)
        return table.concat(lines, "\n")
    end

    if current == snapshot.raw then
        lines[#lines + 1] = ""
        lines[#lines + 1] = L["Der Blob ist unverändert - im Blizzard-Fenster hat sich nichts bewegt,"]
        lines[#lines + 1] = L["oder die Änderung wird erst beim Schließen des Fensters gespeichert."]
        return table.concat(lines, "\n")
    end

    lines[#lines + 1] = string.format("Blob vorher %d Zeichen, jetzt %d Zeichen.", #snapshot.raw, #current)

    local before = Compat.DecodeLayoutString(snapshot.raw)
    local after = Compat.DecodeLayoutString(current)
    if not before or not after then
        lines[#lines + 1] = L["Mindestens einer der beiden Blobs ließ sich nicht entschlüsseln."]
        return table.concat(lines, "\n")
    end

    local differences = {}
    diffTables(before, after, "layout", differences)

    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("== %d Unterschiede ==", #differences)
    -- Schreibt einen Teilbaum flach aus, damit ein neu entstandener Zweig
    -- lesbar ist statt als Tabellenadresse zu erscheinen.
    local function flatten(value, path, target, indent)
        if type(value) ~= "table" then
            target[#target + 1] = string.format("%s%s = %s", indent, path, describeCooldownID(value))
            return
        end
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = key
        end
        table.sort(keys, function(a, b) return Compat.SafeToString(a) < Compat.SafeToString(b) end)
        for _, key in ipairs(keys) do
            flatten(value[key], path .. "[" .. Compat.SafeToString(key) .. "]", target, indent)
        end
    end

    for _, difference in ipairs(differences) do
        lines[#lines + 1] = string.format("  %s", difference.path)
        if difference.subtreeBefore ~= nil or difference.subtreeAfter ~= nil then
            if difference.subtreeBefore == nil then
                lines[#lines + 1] = "      vorher: nicht vorhanden"
            else
                lines[#lines + 1] = "      vorher:"
                flatten(difference.subtreeBefore, "", lines, "        ")
            end
            if difference.subtreeAfter == nil then
                lines[#lines + 1] = "      jetzt:  nicht mehr vorhanden"
            else
                lines[#lines + 1] = "      jetzt:"
                flatten(difference.subtreeAfter, "", lines, "        ")
            end
        else
            lines[#lines + 1] = string.format("      vorher: %s", describeCooldownID(difference.before))
            lines[#lines + 1] = string.format("      jetzt:  %s", describeCooldownID(difference.after))
        end
    end

    if #differences == 0 then
        lines[#lines + 1] = "  Keine - der Blob unterscheidet sich nur in der Kodierung."
    end

    return table.concat(lines, "\n")
end

-- Der entscheidende Sicherheitsnachweis vor jedem Schreiben: lässt sich der
-- gelesene Blob entschlüsseln und bitgleich wieder zusammensetzen? Erst wenn
-- das stimmt, darf das AddOn Einstellungen verändern - sonst würde ein
-- Schreibvorgang die Einstellungen des Spielers zerstören.
-- Rückgabe: erfolg
function Probe:TestLayoutRoundTrip()
    if not Compat.HasLayoutData() then
        FCD.Print(L["GetLayoutData gibt es in diesem Client nicht."])
        return false
    end

    local original, err = Compat.GetLayoutData()
    if err or type(original) ~= "string" then
        FCD.Print(L["GetLayoutData lieferte nichts ("] .. tostring(err) .. ").")
        return false
    end

    local decoded, decodeErr, _, recipe = Compat.DecodeLayoutString(original)
    if not decoded then
        FCD.Print(L["|cffff4040Entschlüsseln fehlgeschlagen:|r "] .. tostring(decodeErr))
        return false
    end
    FCD.Print(L["Entschlüsselt nach Rezept: "] .. tostring(recipe and recipe.candidate)
        .. L[" + "] .. tostring(recipe and recipe.compressionName)
        .. L[" + "] .. tostring(recipe and recipe.deserializer))

    local prefix, payload = Compat.SplitLayoutString(original)
    local rebuilt, encodeErr = Compat.EncodeLayoutString(prefix, decoded, recipe)
    if not rebuilt then
        FCD.Print(L["|cffff4040Neu zusammensetzen fehlgeschlagen:|r "] .. tostring(encodeErr))
        return false
    end

    local trimmed = string.gsub(original, "%s+$", "")
    if rebuilt == trimmed then
        FCD.Print(L["|cff40dd40Rundlauf bitgleich.|r "] .. #rebuilt .. L[" Zeichen, identisch zum Original."])
        FCD.Print(L["Blizzards Kategorien können damit gefahrlos bearbeitet werden."])
        return true
    end

    FCD.Print(L["Bytes weichen ab ("] .. #rebuilt .. L[" statt "] .. #trimmed .. L[" Zeichen), prüfe den Inhalt..."])
    FCD.Print(L["Präfix: "] .. #(prefix or "") .. L[" Zeichen, Nutzlast: "] .. #(payload or "") .. L[" Zeichen."])

    -- CBOR-Maps sind ungeordnet; entscheidend ist nicht die Bytefolge,
    -- sondern ob der neu erzeugte Blob denselben Inhalt ergibt.
    local redecoded, redecodeErr = Compat.DecodeLayoutString(rebuilt)
    if not redecoded then
        FCD.Print(L["|cffff4040Neu erzeugter Blob ist nicht wieder lesbar:|r "] .. tostring(redecodeErr))
        return false
    end

    local same, difference = Compat.DeepEqual(decoded, redecoded)
    if same then
        FCD.Print(L["|cff40dd40Inhaltlich gleich.|r Nur die Schlüsselreihenfolge unterscheidet sich,"])
        FCD.Print(L["was bei CBOR-Maps bedeutungslos ist. Bearbeiten ist damit sicher."])
        return true
    end

    FCD.Print(L["|cffff4040Inhalt weicht ab:|r "] .. tostring(difference))
    FCD.Print(L["Solange das so ist, wird nichts geschrieben."])
    return false
end

-- Schreibt die unveränderten Daten zurück. Ändert nichts an den
-- Einstellungen, zeigt aber, ob der Client den Aufruf überhaupt zulässt.
function Probe:TestLayoutWrite()
    if not Compat.CanWriteLayoutData() then
        FCD.Print(L["SetLayoutData gibt es in diesem Client nicht - Blizzards Kategorien sind nicht beschreibbar."])
        return false
    end
    local data, err = Compat.GetLayoutData()
    if err or data == nil then
        FCD.Print(L["GetLayoutData lieferte nichts ("] .. tostring(err) .. L[") - Schreibtest nicht möglich."])
        return false
    end

    local ok, writeErr = Compat.SetLayoutData(data)
    if ok then
        FCD.Print(L["|cff40dd40SetLayoutData wurde angenommen.|r Unverändert zurückgeschrieben, es hat sich nichts geändert."])
    else
        FCD.Print(L["|cffff4040SetLayoutData abgelehnt:|r "] .. tostring(writeErr))
        FCD.Print(L["Die Funktion ist vermutlich geschützt und nur für Blizzard-Code aufrufbar."])
    end
    return ok
end

function Probe:BuildReport()
    Compat.Detect()
    local lines = {
        "Forever Cooldowns - API-Bericht",
        "AddOn " .. FCD.version,
        string.format("Client %s, Build %s, %s", FCD.clientVersion, tostring(FCD.build), FCD.clientDate),
        string.format("Interface: Client erwartet %d, .toc meldet %s",
            FCD.tocVersion, tostring(Compat.GetDeclaredInterface() or "unbekannt")),
        string.format("Charakter: %s, %s, Stufe %s",
            UnitName("player") or "?", UnitClass("player") or "?", tostring(UnitLevel("player") or "?")),
        "",
        "== Erkannte Schnittstellen ==",
    }

    local keys = {}
    for key in pairs(Compat.caps) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local value = Compat.caps[key]
        lines[#lines + 1] = string.format("  %-22s %s", key, value and tostring(value) or "FEHLT")
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = L["== Geschützte Werte (secret values) =="]
    lines[#lines + 1] = L["  Abklingzeiten geschützt: "] .. tostring(Compat.caps.secretCooldown)
    lines[#lines + 1] = L["  Aufladungen geschützt:   "] .. tostring(Compat.caps.secretCharges)
    lines[#lines + 1] = L["  Benutzbarkeit geschützt: "] .. tostring(Compat.caps.secretUsable)
    lines[#lines + 1] = L["  Auren geschützt:         "] .. tostring(Compat.caps.secretAura)
    -- Gibt es eine offizielle Schnittstelle dafür? Globale Namen absuchen.
    local secretGlobals = {}
    for name, value in pairs(_G) do
        if type(name) == "string" and string.find(string.lower(name), "secret", 1, true) then
            secretGlobals[#secretGlobals + 1] = name .. " (" .. type(value) .. ")"
        end
    end
    table.sort(secretGlobals)
    lines[#lines + 1] = "  Globale Namen mit 'secret': "
        .. (#secretGlobals > 0 and table.concat(secretGlobals, ", ") or "keine")

    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Ereignisse =="
    lines[#lines + 1] = "  registriert: " .. table.concat(FCD.registeredEvents or {}, ", ")
    local unknownEvents = FCD.unavailableEvents or {}
    lines[#lines + 1] = "  in diesem Client unbekannt: "
        .. (#unknownEvents > 0 and table.concat(unknownEvents, ", ") or "keine")

    lines[#lines + 1] = ""
    lines[#lines + 1] = L["== Funktionsprüfung =="]
    for _, feature in ipairs(FEATURES) do
        local status, missing = statusFor(feature)
        lines[#lines + 1] = string.format("  %-14s %s%s", status, feature.name,
            missing and ("  (fehlt: " .. missing .. ")") or "")
    end

    -- Der einzige verlässliche Weg an die echten Funktionsnamen dieses Builds
    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Inhalt von C_CooldownViewer =="
    local members = Compat.DumpNamespace(C_CooldownViewer)
    if #members == 0 then
        lines[#lines + 1] = "  C_CooldownViewer ist keine Tabelle oder leer."
    end
    for _, member in ipairs(members) do
        lines[#lines + 1] = string.format("  %-44s %s", member.name, member.kind)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Abklingzeit-Manager =="
    if not Compat.HasCooldownInfo() then
        lines[#lines + 1] = "  Hinweis: Es gibt keine Funktion, die eine Abklingzeit-ID zu einem"
        lines[#lines + 1] = L["  Zauber auflöst. Die Kategorie-Listen sind lesbar, die Zuordnung"]
        lines[#lines + 1] = "  nicht. Der richtige Name steht vermutlich in der Liste oben."
    end
    local categories = Compat.GetCooldownViewerCategories()
    if #categories == 0 then
        lines[#lines + 1] = "  Enum.CooldownViewerCategory nicht vorhanden."
    end
    for _, category in ipairs(categories) do
        local ids = Compat.GetCategorySet(category.value)
        lines[#lines + 1] = string.format(L["  %s (%d): %s Einträge"],
            category.name, category.value, ids and #ids or "keine Antwort")
        if ids and #ids > 0 then
            local shown = {}
            for index = 1, math.min(#ids, 20) do
                shown[#shown + 1] = tostring(ids[index])
            end
            lines[#lines + 1] = "    IDs: " .. table.concat(shown, ", ")
                .. (#ids > 20 and (" ... (+" .. (#ids - 20) .. ")") or "")
        end
        if ids and ids[1] then
            local info = Compat.GetCooldownInfo(ids[1])
            if type(info) == "table" then
                local fields = {}
                for field in pairs(info) do
                    fields[#fields + 1] = field
                end
                table.sort(fields)
                lines[#lines + 1] = "    Beispiel-Eintrag " .. tostring(ids[1]) .. ":"
                for _, field in ipairs(fields) do
                    lines[#lines + 1] = string.format("      %s = %s", field, describeValue(info[field]))
                end
            else
                lines[#lines + 1] = "    GetCooldownViewerCacheInfo lieferte keine Tabelle."
            end
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Zauberbuch =="
    lines[#lines + 1] = string.format(L["  Einträge gelesen: %d"], FCD.Ranks.scanned or 0)
    lines[#lines + 1] = string.format(L["  Fähigkeiten (Rangfamilien): %d"], FCD.Ranks.familyCount or 0)
    lines[#lines + 1] = string.format(L["  davon mit mehreren Rängen: %d"], FCD.Ranks.rankedFamilyCount or 0)

    -- Rohdaten: nur daran lässt sich sehen, ob die Untertitel überhaupt als
    -- "Rang N" geliefert werden - auch dann, wenn der Charakter noch zu
    -- niedrigstufig für mehrere Ränge ist.
    lines[#lines + 1] = L["  Einträge im Zauberbuch:"]
    local listed = 0
    Compat.IterateSpellbook(function(spellID, name, subText, _, isPassive, known)
        listed = listed + 1
        if listed <= 30 then
            lines[#lines + 1] = string.format("    %-7s %-26s Untertitel=%-16s Rang=%s%s%s",
                tostring(spellID),
                tostring(name),
                subText and ('"' .. subText .. '"') or "(keiner)",
                tostring(FCD.Ranks:ParseRank(subText) or "-"),
                isPassive and "  passiv" or "",
                known and "" or "  nicht gelernt")
        end
    end)
    if listed > 30 then
        lines[#lines + 1] = string.format("    ... und %d weitere", listed - 30)
    end

    -- Stichprobe: die Familien mit den meisten Rängen zeigen, ob die
    -- Untertitel im Client überhaupt als Rang lesbar sind.
    local sample = {}
    for _, family in pairs(FCD.Ranks.families) do
        if #family.ranks > 1 then
            sample[#sample + 1] = family
        end
    end
    table.sort(sample, function(a, b) return #a.ranks > #b.ranks end)
    lines[#lines + 1] = "  Stichprobe:"
    for index = 1, math.min(8, #sample) do
        local family = sample[index]
        local parts = {}
        for _, rank in ipairs(family.ranks) do
            parts[#parts + 1] = string.format("%s%s", rank.rank and ("R" .. rank.rank) or "?", rank.known and "" or "-")
        end
        lines[#lines + 1] = string.format("    %s: %s  (Untertitel: %s)",
            family.name, table.concat(parts, " "), tostring(family.ranks[1].subText))
    end
    if #sample == 0 then
        lines[#lines + 1] = L["    Keine Fähigkeit mit mehreren Rängen gefunden."]
        lines[#lines + 1] = "    Entweder hat der Charakter noch keine, oder die Untertitel"
        lines[#lines + 1] = "    werden in diesem Client anders geliefert als 'Rang N'."
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "== Items =="
    lines[#lines + 1] = string.format(L["  Kandidaten (Ausrüstung + Taschen): %d"], #(FCD.Items.candidates or {}))
    for index = 1, math.min(10, #(FCD.Items.candidates or {})) do
        local candidate = FCD.Items.candidates[index]
        lines[#lines + 1] = string.format("    %s [%s]", candidate.name, candidate.subLabel or candidate.kind)
    end

    return table.concat(lines, "\n")
end

-- Was der Client über unser AddOn weiß. Steht hier bei SavedVariables nichts,
-- hat er die .toc nicht so gelesen wie sie auf der Platte liegt - dann kann er
-- die gespeicherten Dateien auch nicht zuordnen.
function Probe:BuildRegistrationLines()
    local lines = {}
    local function show(label, value)
        lines[#lines + 1] = string.format("  %s: %s", label,
            (value ~= nil and value ~= "") and tostring(value) or "|cffff6060leer|r")
    end

    local name, title, loadable, reason = Compat.GetAddOnInfo(FCD.name)
    lines[#lines + 1] = string.format("Registrierung von '%s' (%d AddOns bekannt):",
        tostring(FCD.name), Compat.GetNumAddOns())
    show("Name laut Client", name)
    show("Titel", title)
    show("Version", Compat.GetAddOnMetadata(FCD.name, "Version"))
    -- Nach SavedVariables oder Interface zu fragen bringt nichts: die gibt
    -- GetAddOnMetadata grundsätzlich nicht heraus, nur Title, Notes, Author,
    -- Version und eigene X-Felder. Ein eigenes X-Feld ist deshalb die einzige
    -- Möglichkeit zu prüfen, wie weit der Client unsere .toc gelesen hat -
    -- es steht dort UNTER der SavedVariables-Zeile.
    show("X-FCD-Toc (steht in der .toc unter SavedVariables)",
        Compat.GetAddOnMetadata(FCD.name, "X-FCD-Toc"))
    if loadable == false then
        show("Nicht ladbar", reason)
    end
    return lines
end

-- Sucht Blizzards eigene Layout-Liste. Sie steht nicht in einer dokumentierten
-- Funktion, sondern irgendwo an ihrem Einstellungsfenster - deshalb wird
-- gesucht statt geraten: eine Tabelle, deren Einträge einen Namen und eine
-- Kennung tragen, ist eine Layout-Liste.
function Probe:BuildBlizzardLayoutReport()
    local lines = { "== Blizzards Layout-Liste ==", "" }

    local function isLayoutEntry(value)
        if type(value) ~= "table" then
            return false
        end
        local name = rawget(value, "name") or rawget(value, "layoutName")
        local id = rawget(value, "layoutID") or rawget(value, "ID")
            or rawget(value, "id")
        return type(name) == "string" and name ~= "" and id ~= nil
    end

    local seen = {}
    local found = 0

    local function walk(node, path, depth)
        if depth > 4 or type(node) ~= "table" or seen[node] then
            return
        end
        seen[node] = true

        -- Eine Liste aus Layout-Einträgen?
        local count = 0
        for _, value in pairs(node) do
            if isLayoutEntry(value) then
                count = count + 1
            end
        end
        if count >= 1 then
            found = found + 1
            lines[#lines + 1] = string.format(L["%s  (%d Eintrag/Einträge)"], path, count)
            for key, value in pairs(node) do
                if isLayoutEntry(value) then
                    lines[#lines + 1] = string.format("    [%s] name=%s  id=%s",
                        tostring(key),
                        tostring(rawget(value, "name") or rawget(value, "layoutName")),
                        tostring(rawget(value, "layoutID") or rawget(value, "ID")
                            or rawget(value, "id")))
                end
            end
            lines[#lines + 1] = ""
        end

        for key, value in pairs(node) do
            if type(value) == "table" and type(key) == "string" then
                walk(value, path .. "." .. key, depth + 1)
            end
        end
    end

    for _, name in ipairs({ "CooldownViewerSettings", "EditModeManagerFrame" }) do
        local root = _G[name]
        if type(root) == "table" then
            pcall(walk, root, name, 0)
        else
            lines[#lines + 1] = name .. " gibt es nicht."
        end
    end

    if found == 0 then
        lines[#lines + 1] = "Nichts gefunden, das nach einer Layout-Liste aussieht."
        lines[#lines + 1] = "Ist Blizzards Abklingzeit-Fenster offen?"
    end
    return table.concat(lines, "\n")
end


-- Alles über Blizzards Bearbeitungsmodus an einer Stelle. Gedacht für die
-- Frage, die uns bei ihrem Hauptfenster drei Runden gekostet hat: wie heißt
-- der Rahmen wirklich, und woran hängt er?
--
-- Gesammelt wird dreierlei:
--   * jeder globale Name, in dem "EditMode" vorkommt - so heißt der Rahmen
--     auch dann, wenn er in diesem Build anders benannt ist als erwartet
--   * die Felder des Verwalters, die selbst Rahmen sind
--   * der Inhalt eines offenen Einstellungsfensters: seine Bedienelemente
--     samt Beschriftung, damit klar ist, was wir nachbauen müssten
function Probe:BuildEditModeReport()
    local lines = { "== Blizzards Bearbeitungsmodus ==", "" }

    local function describeFrame(frame)
        if type(frame) ~= "table" then
            return tostring(frame)
        end
        local kind = "?"
        pcall(function() kind = frame:GetObjectType() end)
        local shown = false
        pcall(function() shown = frame:IsShown() and true or false end)
        local width, height = 0, 0
        pcall(function() width, height = frame:GetSize() end)
        return string.format("%s, %s, %.0fx%.0f",
            kind, shown and "offen" or "zu", width or 0, height or 0)
    end

    -- 1. Globale Namen
    lines[#lines + 1] = "-- Globale Namen mit 'EditMode' --"
    -- Nur Namen, die mit "EditMode" beginnen. Die Gamepad-Rahmen tragen es
    -- mitten im Namen und machten neun Zehntel der Ausgabe aus, ohne etwas
    -- beizutragen. Mixins ebenfalls weg: das sind Bauvorlagen, keine Rahmen.
    local names = {}
    for key, value in pairs(_G) do
        if type(key) == "string" and key:sub(1, 8) == "EditMode"
            and not key:find("Mixin", 1, true) and type(value) == "table" then
            names[#names + 1] = key
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        lines[#lines + 1] = string.format("  %s  (%s)", name, describeFrame(_G[name]))
    end
    if #names == 0 then
        lines[#lines + 1] = "  keine - dieser Client kennt den Bearbeitungsmodus nicht"
    end
    lines[#lines + 1] = ""

    -- 2. Felder des Verwalters, die selbst Rahmen sind
    local manager = _G.EditModeManagerFrame
    if type(manager) == "table" then
        lines[#lines + 1] = "-- Felder von EditModeManagerFrame --"
        local fields = {}
        for key, value in pairs(manager) do
            if type(key) == "string" and type(value) == "table" then
                local isFrame = false
                pcall(function() isFrame = type(value.GetObjectType) == "function" end)
                if isFrame then
                    fields[#fields + 1] = key
                end
            end
        end
        table.sort(fields)
        for _, key in ipairs(fields) do
            lines[#lines + 1] = string.format("  .%s  (%s)", key, describeFrame(manager[key]))
        end
        if #fields == 0 then
            lines[#lines + 1] = "  keine"
        end
        lines[#lines + 1] = ""
    end

    -- 3. Inhalt eines offenen Einstellungsfensters
    lines[#lines + 1] = "-- Bedienelemente eines offenen Einstellungsfensters --"
    local reported = 0

    local function walk(frame, depth)
        if depth > 3 then
            return
        end
        local ok, children = pcall(function() return { frame:GetChildren() } end)
        if not ok then
            return
        end
        for _, child in ipairs(children) do
            local shown = false
            pcall(function() shown = child:IsShown() and true or false end)
            if shown then
                local kind = "?"
                pcall(function() kind = child:GetObjectType() end)
                local text
                pcall(function()
                    if type(child.GetText) == "function" then
                        text = child:GetText()
                    end
                end)
                -- Nur Bedienbares melden; reine Rahmen blähen die Liste auf,
                -- ohne zu sagen, was das Fenster kann.
                if kind == "Button" or kind == "CheckButton" or kind == "Slider"
                    or kind == "DropdownButton" or kind == "EditBox" then
                    local name
                    pcall(function() name = child:GetName() end)
                    lines[#lines + 1] = string.format("%s%s  %s%s",
                        string.rep("  ", depth), kind,
                        (text and text ~= "") and ('"' .. text .. '"') or "(ohne Text)",
                        name and ("  [" .. name .. "]") or "")
                    reported = reported + 1
                end
                walk(child, depth + 1)
            end
        end
    end

    for _, name in ipairs(names) do
        local frame = _G[name]
        local shown = false
        pcall(function() shown = frame:IsShown() and true or false end)
        -- Der Verwalter selbst ist die Modus-Oberfläche, nicht das Fenster
        -- einer einzelnen Leiste - der interessiert hier nicht.
        if shown and name ~= "EditModeManagerFrame" then
            lines[#lines + 1] = ""
            lines[#lines + 1] = name .. ":"
            pcall(walk, frame, 1)
        end
    end

    if reported == 0 then
        lines[#lines + 1] = "  nichts offen."
        lines[#lines + 1] = L["  Bearbeitungsmodus öffnen, eine ihrer Leisten anklicken,"]
        lines[#lines + 1] = "  dann diesen Befehl erneut absetzen."
    end

    -- Abfangen können wir ihr Fenster. Die offene Frage ist, ob sich ihre
    -- Werte auch schreiben lassen - und über welchen Weg. Deshalb hier, was
    -- der Client dafür überhaupt anbietet.
    local function listMembers(title, namespace)
        lines[#lines + 1] = ""
        lines[#lines + 1] = "-- " .. title .. " --"
        if type(namespace) ~= "table" then
            lines[#lines + 1] = "  gibt es nicht."
            return
        end
        local members = {}
        for key, value in pairs(namespace) do
            if type(key) == "string" then
                members[#members + 1] = string.format("  %s  (%s)", key, type(value))
            end
        end
        table.sort(members)
        for _, line in ipairs(members) do
            lines[#lines + 1] = line
        end
        if #members == 0 then
            lines[#lines + 1] = "  leer."
        end
    end

    listMembers("C_EditMode", _G.C_EditMode)

    -- Die Auswahlwerte der Leisteneinstellungen. Ohne diese Schlüssel lassen
    -- sich die Felder nicht benennen - geratene Enum-Namen waren falsch.
    do
        lines[#lines + 1] = ""
        lines[#lines + 1] = L["-- Enums für Leisteneinstellungen --"]
        local enums = _G.Enum
        local names = {}
        if type(enums) == "table" then
            for name, value in pairs(enums) do
                if type(name) == "string" and type(value) == "table"
                    and (name:find("Orientation", 1, true)
                        or name:find("IconDirection", 1, true)
                        or name:find("VisibleSetting", 1, true)
                        or name:find("BarContent", 1, true)) then
                    names[#names + 1] = name
                end
            end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            local parts = {}
            for key, value in pairs(enums[name]) do
                if type(key) == "string" then
                    parts[#parts + 1] = string.format("%s=%s", key, tostring(value))
                end
            end
            table.sort(parts)
            lines[#lines + 1] = "  " .. name .. ":  " .. table.concat(parts, ", ")
        end
        if #names == 0 then
            lines[#lines + 1] = "  keine gefunden."
        end
    end

    -- Nur die Namen, die nach Setzen aussehen: die volle Methodenliste des
    -- Verwalters ist mehrere hundert Zeilen lang.
    do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "-- EditModeManagerFrame: Methoden mit Setting/Change/Update --"
        local manager = _G.EditModeManagerFrame
        local hits = {}
        if type(manager) == "table" then
            for key, value in pairs(manager) do
                if type(key) == "string" and type(value) == "function"
                    and (key:find("Setting", 1, true) or key:find("Change", 1, true)
                        or key:find("Dirty", 1, true)) then
                    hits[#hits + 1] = "  " .. key
                end
            end
        end
        table.sort(hits)
        for _, line in ipairs(hits) do
            lines[#lines + 1] = line
        end
        if #hits == 0 then
            lines[#lines + 1] = "  keine - dann steht der Setzer in einem Mixin."
        end
    end
    listMembers("EditModeCooldownViewerSystemMixin", _G.EditModeCooldownViewerSystemMixin)
    listMembers("EditModeSystemMixin", _G.EditModeSystemMixin)

    -- An welcher Leiste hängt das offene Fenster gerade? Daran erkennen wir
    -- später, ob es einer ihrer Abklingzeit-Viewer ist oder etwas anderes.
    local dialog = _G.EditModeSystemSettingsDialog
    if type(dialog) == "table" then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "-- EditModeSystemSettingsDialog: eigene Felder --"
        local fields = {}
        for key, value in pairs(dialog) do
            if type(key) == "string" and type(value) ~= "function" then
                local extra = ""
                if type(value) == "table" then
                    local name
                    pcall(function()
                        if type(value.GetName) == "function" then
                            name = value:GetName()
                        end
                    end)
                    extra = name and ("  -> " .. name) or ""
                else
                    extra = "  = " .. tostring(value)
                end
                fields[#fields + 1] = string.format("  %s  (%s)%s", key, type(value), extra)
            end
        end
        table.sort(fields)
        for _, line in ipairs(fields) do
            lines[#lines + 1] = line
        end
    end

    return table.concat(lines, "\n")
end


-- Die Einstellungen der Leiste, an der ihr Fenster gerade hängt - mit den
-- Werten, die dort stehen. Erst damit ist entscheidbar, ob ein eigenes
-- Fenster echte Regler bekommen kann oder nur eine Anzeige wird.
local function attachedSystem()
    local dialog = _G.EditModeSystemSettingsDialog
    if type(dialog) ~= "table" then
        return nil, "EditModeSystemSettingsDialog gibt es nicht."
    end
    local system = rawget(dialog, "attachedToSystem")
    if type(system) ~= "table" then
        return nil, "Ihr Fenster ist zu - erst eine Leiste im Bearbeitungsmodus anklicken."
    end
    return system
end

Probe.AttachedEditModeSystem = attachedSystem

-- Der Name der Einstellung steht in einem Enum; welches, weiß erst der
-- Client. Deshalb wird gesucht statt angenommen.
local function settingEnum()
    local enums = _G.Enum
    if type(enums) ~= "table" then
        return nil
    end
    for _, key in ipairs({ "EditModeCooldownViewerSetting", "EditModeUnitFrameSetting" }) do
        if type(rawget(enums, key)) == "table" then
            return rawget(enums, key), key
        end
    end
    return nil
end

function Probe:BuildEditModeSettingsReport()
    local lines = { "== Einstellungen der angeklickten Leiste ==", "" }

    local system, err = attachedSystem()
    if not system then
        lines[#lines + 1] = err
        return table.concat(lines, "\n")
    end

    local name = "?"
    pcall(function() name = system:GetSystemName() end)
    local frameName = "?"
    pcall(function() frameName = system:GetName() end)
    lines[#lines + 1] = string.format("Leiste: %s  (%s)", tostring(name), tostring(frameName))
    lines[#lines + 1] = ""

    local enum, enumName = settingEnum()
    if not enum then
        lines[#lines + 1] = "Kein Einstellungs-Enum gefunden - ohne das sind die"
        lines[#lines + 1] = "Nummern der Einstellungen nicht zu benennen."
        return table.concat(lines, "\n")
    end
    lines[#lines + 1] = "Aus " .. enumName .. ":"
    lines[#lines + 1] = ""

    local entries = {}
    for key, value in pairs(enum) do
        if type(key) == "string" and type(value) == "number" then
            entries[#entries + 1] = { key = key, value = value }
        end
    end
    table.sort(entries, function(a, b) return a.value < b.value end)

    for _, entry in ipairs(entries) do
        local has = false
        pcall(function() has = system:HasSetting(entry.value) and true or false end)
        local current
        pcall(function() current = system:GetSettingValue(entry.value) end)
        lines[#lines + 1] = string.format("  %-28s = %-6s %s",
            entry.key, tostring(current),
            has and "" or "|cff888888(hat diese Leiste nicht)|r")
    end

    -- Wo die Zahlen liegen. Der Setzer muss genau hierhin schreiben,
    -- sonst liest GetSettingValue weiter den alten Wert - genau das ist beim
    -- ersten Versuch passiert.
    lines[#lines + 1] = ""
    lines[#lines + 1] = "-- Ablage der Werte --"
    local info = rawget(system, "systemInfo")
    if type(info) == "table" then
        lines[#lines + 1] = "  system.systemInfo vorhanden:"
        for key, value in pairs(info) do
            lines[#lines + 1] = string.format("    .%s  (%s)", tostring(key), type(value))
        end
        local settings = rawget(info, "settings")
        if type(settings) == "table" then
            lines[#lines + 1] = "  systemInfo.settings:"
            for key, value in pairs(settings) do
                lines[#lines + 1] = string.format("    [%s] = %s",
                    tostring(key), tostring(type(value) == "table"
                        and (tostring(rawget(value, "value")) .. " (Tabelle)") or value))
            end
        end
    else
        lines[#lines + 1] = "  kein system.systemInfo - dann liegt es woanders."
    end

    local map = rawget(system, "settingMap")
    if type(map) == "table" then
        lines[#lines + 1] = "  system.settingMap vorhanden (" .. tostring(#map) .. L[" Einträge)"]
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Probeschreiben:  /fcd editset <Name> <Wert>"
    lines[#lines + 1] = "Beispiel:        /fcd editset Opacity 60"
    return table.concat(lines, "\n")
end

-- Ein einzelner Schreibversuch. Absichtlich ein Befehl und keine Oberfläche:
-- wir wollen zuerst wissen, ob Schreiben überhaupt durchgeht und ob es
-- Blizzards Code taintet - nicht schon ein Fenster voller Regler bauen, das
-- am Ende nichts bewirken darf.
--
-- Rückgabe: erfolgstext oder nil, fehlertext
function Probe:TryEditModeSetting(settingName, value)
    local system, err = attachedSystem()
    if not system then
        return nil, err
    end

    local enum = settingEnum()
    if not enum then
        return nil, "Kein Einstellungs-Enum in diesem Client."
    end

    local settingID = rawget(enum, settingName)
    if type(settingID) ~= "number" then
        return nil, "Unbekannte Einstellung: " .. tostring(settingName)
    end

    local number = tonumber(value)
    if not number then
        return nil, "Der Wert muss eine Zahl sein."
    end

    local function currentValue()
        local value
        pcall(function() value = system:GetSettingValue(settingID) end)
        return value
    end

    local before = currentValue()

    -- Mehrere Wege, weil der naheliegende ins Leere lief: UpdateSystemSetting
    -- nahm den Wert gar nicht entgegen und meldete trotzdem keinen Fehler.
    -- Deshalb wird nach jedem Versuch nachgelesen, ob sich etwas bewegt hat,
    -- statt dem ausbleibenden Fehler zu glauben.
    local attempts = {
        { name = "EditModeManagerFrame:OnSystemSettingChange", run = function()
            local manager = _G.EditModeManagerFrame
            manager:OnSystemSettingChange(system, settingID, number)
        end },
        { name = "system:UpdateSystemSettingValue", run = function()
            system:UpdateSystemSettingValue(settingID, number)
        end },
        { name = "systemInfo.settings + UpdateSystemSetting", run = function()
            local info = rawget(system, "systemInfo")
            local settings = info and rawget(info, "settings")
            if type(settings) ~= "table" then
                error("keine settings-Tabelle", 0)
            end
            -- Zwei Ablageformen sind möglich: Wert direkt, oder in einer
            -- Tabelle mit .setting und .value.
            local written = false
            for _, entry in pairs(settings) do
                if type(entry) == "table" and rawget(entry, "setting") == settingID then
                    entry.value = number
                    written = true
                end
            end
            if not written then
                settings[settingID] = number
            end
            system:UpdateSystemSetting(settingID)
        end },
    }

    local tried = {}
    for _, attempt in ipairs(attempts) do
        local ok, attemptErr = pcall(attempt.run)
        local after = currentValue()
        if ok and after ~= before then
            return string.format(L["%s über %s: %s -> %s"],
                settingName, attempt.name, tostring(before), tostring(after))
        end
        tried[#tried + 1] = string.format("%s: %s", attempt.name,
            ok and L["kein Fehler, aber Wert unverändert"] or tostring(attemptErr))
    end

    return nil, "kein Weg hat gewirkt.\n  " .. table.concat(tried, "\n  ")
end

-- Welche benannten Rahmen gerade offen sind. Gedacht für die Frage "was geht
-- da eigentlich auf?": Fenster öffnen, Befehl absetzen, in der Liste nachsehen.
-- Nur oberste Ebene und eine darunter - tiefer wird es unlesbar.
function Probe:BuildShownFrameReport()
    local lines = { "== Offene benannte Rahmen ==", "" }
    local seen = {}

    local function look(parent, label, depth)
        local ok, children = pcall(function() return { parent:GetChildren() } end)
        if not ok then
            return
        end
        for _, child in ipairs(children) do
            local shownOk, shown = pcall(child.IsShown, child)
            if shownOk and shown then
                local nameOk, name = pcall(child.GetName, child)
                if nameOk and type(name) == "string" and name ~= "" and not seen[name] then
                    seen[name] = true
                    local width, height = 0, 0
                    pcall(function() width, height = child:GetSize() end)
                    lines[#lines + 1] = string.format("%s%s  (%.0fx%.0f)",
                        string.rep("  ", depth), name, width or 0, height or 0)
                end
                if depth < 2 then
                    look(child, label, depth + 1)
                end
            end
        end
    end

    pcall(look, UIParent, "UIParent", 0)
    if #lines == 2 then
        lines[#lines + 1] = "Nichts gefunden."
    end
    return table.concat(lines, "\n")
end
