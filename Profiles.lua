local FCD = ForeverCooldowns
local L = FCD.L

local Profiles = {}
FCD.Profiles = Profiles

local EXPORT_PREFIX = "FCD1:"
local MAX_UNDO = 20

local SETTING_DEFAULTS = {
    locked = true,
    showRankText = true,
    showTimerText = true,
    dimOutOfPower = true,
    hideUnknown = true,
    hideGCD = true,
    gcdThreshold = 1.6,
    updateInterval = 0.1,
    autoSwitch = true,
    -- Der sichere Weg ist die Voreinstellung: geschrieben wird über
    -- SetLayoutData, das taintet nichts, wirkt aber erst beim Neuladen.
    --
    -- Zuerst stand hier der Sofortmodus. Der wirkt ohne Neuladen, taintet
    -- dabei aber Blizzards Viewer - und dann wirft er bei jedem Ziel- und
    -- Aurenereignis einen roten Lua-Fehler. Wer das AddOn neu installiert und
    -- als Erstes einen Eintrag verschiebt, sieht also Fehler und hält sie für
    -- einen Defekt. Diesen Preis darf nur zahlen, wer ihn kennt:
    -- /fcd instant on schaltet den Sofortmodus ein und sagt dabei, was er
    -- kostet.
    allowNativeWrites = false,
    -- Panel automatisch neben Blizzards Einstellungsfenster einblenden
    dockToBlizzard = true,
    -- Abgerundete Symbolecken über eine Maske. Abschaltbar, weil eine
    -- Maske, deren Grafik ein Client nicht lädt, das Symbol ganz
    -- verschwinden ließe - dann hilft /fcd round off und ein Neuladen.
    roundIcons = true,
    -- Blizzards Grafik abschauen: standardmäßig AUS. Jeder Anlauf dafür hat
    -- eine Nebenwirkung erzeugt - falsche Vorlagen, leere Balkenzeilen,
    -- Tooltips über unsichtbaren Fenstern - und der Gewinn war Kosmetik.
    -- Wer es will: /fcd art on.
    useBlizzardArt = false,
    -- FCD tritt an die Stelle von Blizzards Fenster: geht ihres auf, wird es
    -- geschlossen und unseres erscheint. Erreichbar bleibt ihres über den
    -- Knopf in der Werkzeugspalte oder /fcd blizz.
    replaceBlizzardWindow = true,
    -- Auch ihr kleines Fenster im Bearbeitungsmodus durch unseres ersetzen.
    -- Die Werte bleiben ihre; nur die Bedienung ist unsere.
    replaceEditModeDialog = true,
}

local BAR_DEFAULTS = {
    point = "CENTER",
    relativePoint = "CENTER",
    x = 0,
    y = -170,
    columns = 12,
    iconSize = 40,
    spacing = 4,
    growth = "RIGHT",
    scale = 1,
    alpha = 1,
    showRank = true,
    showTimer = true,
    -- Fertig-Meldung ist aus: auf einer vollen Leiste blinkte sonst ständig
    -- etwas. Der Ton hängt daran und ist an, sobald man sie einschaltet.
    alertReady = false,
    alertMode = "both",
    hideGCD = true,
}

local VISIBILITY_DEFAULTS = {
    always = true,
    inCombat = false,
    hasTarget = false,
    never = false,
    onlyOnCooldown = false,
    hideUnknown = true,
}

-- ------------------------------------------------------------ Serialisierung

-- Eigener Schreiber/Leser statt loadstring: ein importierter Profilstring aus
-- dem Forum darf niemals Code ausführen können.
local function quote(text)
    text = tostring(text)
    text = text:gsub("\\", "\\\\")
    text = text:gsub('"', '\\"')
    text = text:gsub("\n", "\\n")
    return '"' .. text .. '"'
end

local function serialize(value, out)
    local valueType = type(value)
    if valueType == "number" then
        -- %.14g hält Ganzzahlen ganz und Kommazahlen kurz
        out[#out + 1] = string.format("%.14g", value)
    elseif valueType == "string" then
        out[#out + 1] = quote(value)
    elseif valueType == "boolean" then
        out[#out + 1] = value and "true" or "false"
    elseif valueType == "table" then
        out[#out + 1] = "{"
        local arrayLength = #value
        for index = 1, arrayLength do
            serialize(value[index], out)
            out[#out + 1] = ","
        end
        local keys = {}
        for key in pairs(value) do
            local isArrayIndex = type(key) == "number" and key >= 1 and key <= arrayLength and math.floor(key) == key
            if not isArrayIndex and (type(key) == "string" or type(key) == "number") then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, key in ipairs(keys) do
            if type(key) == "string" then
                out[#out + 1] = "[" .. quote(key) .. "]="
            else
                out[#out + 1] = "[" .. string.format("%.14g", key) .. "]="
            end
            serialize(value[key], out)
            out[#out + 1] = ","
        end
        out[#out + 1] = "}"
    else
        out[#out + 1] = "nil"
    end
end

local parseValue

local function skipSpace(text, position)
    local _, stop = text:find("^%s*", position)
    return (stop or (position - 1)) + 1
end

local function parseString(text, position)
    local buffer = {}
    local index = position + 1
    while index <= #text do
        local char = text:sub(index, index)
        if char == "\\" then
            local escape = text:sub(index + 1, index + 1)
            if escape == "n" then
                buffer[#buffer + 1] = "\n"
            elseif escape == "\\" then
                buffer[#buffer + 1] = "\\"
            elseif escape == '"' then
                buffer[#buffer + 1] = '"'
            else
                buffer[#buffer + 1] = escape
            end
            index = index + 2
        elseif char == '"' then
            return table.concat(buffer), index + 1
        else
            buffer[#buffer + 1] = char
            index = index + 1
        end
    end
    return nil, position, "Zeichenkette nicht geschlossen"
end

local function parseTable(text, position)
    local result = {}
    local index = skipSpace(text, position + 1)
    local arrayIndex = 1
    while index <= #text do
        local char = text:sub(index, index)
        if char == "}" then
            return result, index + 1
        end
        if char == "," then
            index = skipSpace(text, index + 1)
        elseif char == "[" then
            local key, nextIndex, err = parseValue(text, skipSpace(text, index + 1))
            if err then
                return nil, index, err
            end
            nextIndex = skipSpace(text, nextIndex)
            if text:sub(nextIndex, nextIndex) ~= "]" then
                return nil, nextIndex, "] erwartet"
            end
            nextIndex = skipSpace(text, nextIndex + 1)
            if text:sub(nextIndex, nextIndex) ~= "=" then
                return nil, nextIndex, "= erwartet"
            end
            local value, afterValue, valueErr = parseValue(text, skipSpace(text, nextIndex + 1))
            if valueErr then
                return nil, afterValue, valueErr
            end
            if key ~= nil then
                result[key] = value
            end
            index = skipSpace(text, afterValue)
        else
            local value, afterValue, valueErr = parseValue(text, index)
            if valueErr then
                return nil, afterValue, valueErr
            end
            result[arrayIndex] = value
            arrayIndex = arrayIndex + 1
            index = skipSpace(text, afterValue)
        end
    end
    return nil, position, "Tabelle nicht geschlossen"
end

parseValue = function(text, position)
    position = skipSpace(text, position)
    local char = text:sub(position, position)
    if char == "{" then
        return parseTable(text, position)
    elseif char == '"' then
        return parseString(text, position)
    end
    local literal = text:match("^true", position)
    if literal then
        return true, position + 4
    end
    if text:match("^false", position) then
        return false, position + 5
    end
    if text:match("^nil", position) then
        return nil, position + 3
    end
    local number = text:match("^%-?%d+%.?%d*[eE]?%-?%d*", position)
    if number and number ~= "" and tonumber(number) then
        return tonumber(number), position + #number
    end
    return nil, position, L["unerwartetes Zeichen an Position "] .. position
end

-- ------------------------------------------------------------------ Aufbau

local function copyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

-- Die Vorgabeleisten zeigen Blizzards Kategorien, statt leer zu sein.
--
-- Vorher lagen hier zwei leere Leisten. Ein frisch installiertes AddOn zeigte
-- also nichts, und eine Kategorie zu ändern blieb bis zum Neuladen
-- unsichtbar. Sichtbar wurde es erst, wenn jemand den Knopf "spiegeln"
-- entdeckte - und das kann niemand vorher wissen. Deshalb ist es jetzt der
-- Anfangszustand.
local DEFAULT_MIRRORS = { 0, 1 }

-- So hießen dieselben zwei Leisten, bevor sie Blizzards Kategorien zeigten.
local LEGACY_DEFAULT_NAMES = { [0] = "Essenziell", [1] = "Strategisch" }

local function nextBarID(profile)
    local highest = 0
    for _, bar in ipairs(profile.bars) do
        highest = math.max(highest, bar.id or 0)
    end
    return highest + 1
end

function Profiles:NewBar(profile, name)
    local bar = { id = nextBarID(profile), name = name or (L["Leiste "] .. (#profile.bars + 1)), entries = {}, visibility = {} }
    copyDefaults(bar, BAR_DEFAULTS)
    copyDefaults(bar.visibility, VISIBILITY_DEFAULTS)
    bar.y = BAR_DEFAULTS.y + (#profile.bars * (BAR_DEFAULTS.iconSize + 10))
    profile.bars[#profile.bars + 1] = bar
    return bar
end

function Profiles:RemoveBar(profile, barID)
    for index, bar in ipairs(profile.bars) do
        if bar.id == barID then
            table.remove(profile.bars, index)
            return true
        end
    end
    return false
end

function Profiles:GetBar(profile, barID)
    for _, bar in ipairs(profile.bars) do
        if bar.id == barID then
            return bar
        end
    end
    return nil
end

-- Legt die beiden Vorgabeleisten an. Ihr Name ist der Kategoriename und
-- damit dieselbe Kennung wie überall: deutsch gespeichert, beim Anzeigen
-- übersetzt.
function Profiles:AddDefaultBars(profile)
    for _, category in ipairs(DEFAULT_MIRRORS) do
        local bar = self:NewBar(profile, FCD.Mirror.CATEGORY_NAMES[category])
        bar.mirrorCategory = category
        bar.mirrorEntryOptions = {}
    end
end

-- Bestehende Profile nachrüsten. Angefasst wird nur, was unberührt
-- geblieben ist: eine Vorgabeleiste unter ihrem alten Namen, ohne einen
-- einzigen Eintrag. Wer etwas hineingelegt hat, behält seine Leiste, und wer
-- schon spiegelt, hat ohnehin selbst entschieden.
local function adoptDefaultMirrors(profile)
    if type(profile) ~= "table" or type(profile.bars) ~= "table" then
        return
    end
    for _, category in ipairs(DEFAULT_MIRRORS) do
        -- Wer diese Kategorie schon spiegelt, hat selbst entschieden.
        local already = false
        for _, bar in ipairs(profile.bars) do
            if bar.mirrorCategory == category then
                already = true
                break
            end
        end
        if not already then
            for _, bar in ipairs(profile.bars) do
                if bar.name == LEGACY_DEFAULT_NAMES[category]
                    and bar.mirrorCategory == nil
                    and #(bar.entries or {}) == 0 then
                    bar.name = FCD.Mirror.CATEGORY_NAMES[category]
                    bar.mirrorCategory = category
                    bar.mirrorEntryOptions = {}
                    break
                end
            end
        end
    end
end

local function newProfile(name, class)
    local profile = {
        name = name,
        class = class,
        build = FCD.build,
        bars = {},
    }
    return profile
end

function Profiles:Sanitize(profile)
    if type(profile) ~= "table" then
        return nil
    end
    profile.bars = type(profile.bars) == "table" and profile.bars or {}
    for _, bar in ipairs(profile.bars) do
        bar.entries = type(bar.entries) == "table" and bar.entries or {}
        bar.visibility = type(bar.visibility) == "table" and bar.visibility or {}
        copyDefaults(bar, BAR_DEFAULTS)
        copyDefaults(bar.visibility, VISIBILITY_DEFAULTS)
        -- Einträge ohne Kennung würden später beim Rendern stolpern
        for index = #bar.entries, 1, -1 do
            local entry = bar.entries[index]
            if type(entry) ~= "table" or not entry.kind or not entry.id then
                table.remove(bar.entries, index)
            else
                entry.rankMode = entry.rankMode or "best"
            end
        end
    end
    return profile
end

-- ---------------------------------------------------------------- Zugriff

function Profiles:Initialize()
    -- Was der Client uns übergibt, BEVOR wir etwas anfassen. Ohne diese
    -- Aufnahme lässt sich nicht unterscheiden, ob die gespeicherten Daten gar
    -- nicht ankommen oder ob wir sie später selbst überschreiben.
    -- Zwei Ablagen mit verschiedenen Namen in einer Zeile deklariert, wie es
    -- das AddOn tut, das in diesem Client speichert. Kommt nur eine davon
    -- zurück, liegt es am Namen; kommt keine, am AddOn selbst.
    local incoming = ForeverCooldownsDB
    if type(incoming) ~= "table" and type(FCDStore) == "table" then
        incoming = FCDStore
        ForeverCooldownsDB = FCDStore
    end
    local report = {
        present = type(incoming) == "table",
        viaLong = type(ForeverCooldownsDB) == "table",
        viaShort = type(FCDStore) == "table",
    }
    if report.present then
        report.profiles, report.bars, report.entries = 0, 0, 0
        for _, profile in pairs(incoming.profiles or {}) do
            report.profiles = report.profiles + 1
            for _, bar in ipairs(type(profile) == "table" and profile.bars or {}) do
                report.bars = report.bars + 1
                report.entries = report.entries + #(bar.entries or {})
            end
        end
    end
    report.charPresent = type(ForeverCooldownsCharDB) == "table"
    -- Nur die erste Messung zählt. Initialize läuft später noch einmal, wenn
    -- ein Bestand aus dem Layout übernommen wird - dann misst es den Stand
    -- danach und widerspräche sich selbst.
    if FCD.dbLoadInfo then
        report = FCD.dbLoadInfo
    end
    report.mirror = report.charPresent
        and type(ForeverCooldownsCharDB.mirror) == "string"
        and #ForeverCooldownsCharDB.mirror or 0
    FCD.dbLoadInfo = report

    -- Dieser Client gibt die kontoweite Datei nicht immer zurück, obwohl er
    -- sie schreibt. Damit deswegen nichts verlorengeht, liegt bei jedem
    -- Abmelden eine vollständige Kopie in der charakterbezogenen Datei.
    -- Kommt oben nichts an, wird von dort geholt.
    -- Auch dann holen, wenn zwar eine Tabelle ankommt, darin aber kein
    -- einziges Profil steht: eine leere Tabelle ist genauso wertlos wie keine.
    local incomingEmpty = not report.present or (report.profiles or 0) == 0
    if incomingEmpty and report.mirror > 0 then
        local restored = parseValue(ForeverCooldownsCharDB.mirror, 1)
        if type(restored) == "table" and type(restored.profiles) == "table" then
            ForeverCooldownsDB = restored
            report.restoredFromMirror = true
        end
    end

    ForeverCooldownsDB = ForeverCooldownsDB or {}
    local db = ForeverCooldownsDB
    -- Beide Namen zeigen auf dieselbe Tabelle, damit der Client sie unter
    -- jedem der beiden wieder herausgeben kann.
    FCDStore = db

    -- Die charakterbezogenen Daten liegen jetzt IN der kontoweiten Datei,
    -- nicht mehr in einer zweiten. Dieser Client hat für dieses AddOn gar
    -- keine gespeicherten Daten zurückgegeben, solange zwei Ablagen in der
    -- .toc standen - eine Ablage ist auch sonst weniger, was schiefgehen kann.
    local realm = _G.GetRealmName and _G.GetRealmName() or "?"
    local characterKey = (UnitName("player") or "?") .. " - " .. tostring(realm)
    db.characters = type(db.characters) == "table" and db.characters or {}
    db.characters[characterKey] = type(db.characters[characterKey]) == "table"
        and db.characters[characterKey] or {}
    local charDB = db.characters[characterKey]

    -- Was noch in der alten zweiten Datei liegt, einmalig übernehmen.
    if type(ForeverCooldownsCharDB) == "table" and not charDB.migrated then
        for key, value in pairs(ForeverCooldownsCharDB) do
            if charDB[key] == nil then
                charDB[key] = value
            end
        end
        charDB.migrated = true
    end

    db.schema = db.schema or 1
    -- Schema 2 hat den Sofortmodus nachgereicht, als er die Voreinstellung
    -- war. Die Zeile ist weg, der Schritt bleibt: eine Datenbank von damals
    -- soll nicht zweimal dieselbe Nummer durchlaufen.
    if db.schema < 2 then
        db.settings = db.settings or {}
        db.schema = 2
    end
    -- Und zurück: wer den Sofortmodus über Schema 2 bekommen hat, hat ihn nie
    -- gewählt. Er wird einmalig abgeschaltet, weil er rote Lua-Fehler
    -- verursacht, sobald man einen Eintrag verschiebt. Einschalten geht
    -- weiterhin mit /fcd instant on - dann als bewusste Entscheidung.
    if db.schema < 3 then
        db.settings = db.settings or {}
        db.settings.allowNativeWrites = false
        db.schema = 3
    end
    -- Schema 4: die beiden leeren Vorgabeleisten werden zu Spiegeln von
    -- Blizzards Kategorien. Läuft einmal; wer sie danach entfernt, bekommt
    -- sie nicht wieder.
    if db.schema < 4 then
        for _, profile in pairs(db.profiles or {}) do
            adoptDefaultMirrors(profile)
        end
        db.schema = 4
    end
    db.profiles = db.profiles or {}
    db.settings = db.settings or {}
    db.customItems = db.customItems or {}
    db.customSpells = db.customSpells or {}
    copyDefaults(db.settings, SETTING_DEFAULTS)

    charDB.rules = charDB.rules or {}
    charDB.active = charDB.active

    FCD.db = db
    FCD.charDB = charDB

    local _, class = UnitClass("player")
    self.class = class

    if not charDB.active or not db.profiles[charDB.active] then
        local defaultName = (UnitClass("player")) or "Standard"
        if not db.profiles[defaultName] then
            local profile = newProfile(defaultName, class)
            self:AddDefaultBars(profile)
            db.profiles[defaultName] = profile
        end
        charDB.active = defaultName
    end

    for _, profile in pairs(db.profiles) do
        self:Sanitize(profile)
        -- Die Gegenstandsleiste soll ihre Einträge auch dann zeigen, wenn
        -- gerade keiner mehr im Beutel liegt. Sonst sieht ein ausgetrunkener
        -- Trank aus wie ein verlorener Eintrag. Einmalig, danach entscheidet
        -- das Optionsfenster.
        for _, bar in ipairs(profile.bars) do
            -- Blizzards Kategorie 7 heißt ebenfalls "Gegenstände". Eine
            -- Leiste, die sie spiegelt, ist keine Gegenstandsleiste und darf
            -- deren Vorgaben nicht bekommen.
            if not bar.fcdItemDefaults and bar.mirrorCategory == nil
                and (bar.name == "Gegenstände verfolgen" or bar.name == "Gegenstände") then
                bar.fcdItemDefaults = true
                bar.visibility = bar.visibility or {}
                bar.visibility.hideUnknown = false
            end
        end
    end

    self.undoStack = {}
end

-- Die Fertig-Meldung kann an der Leiste hängen oder am einzelnen Eintrag.
-- Der Eintrag hat Vorrang, wo er etwas sagt; sonst gilt die Leiste. Damit
-- lässt sich eine volle Leiste stumm halten und trotzdem der eine Zauber
-- melden, auf den es ankommt - oder genau einer von zwanzig ausnehmen.
--
-- "Nichts gesagt" ist nil, nicht false: false heißt ausdrücklich aus und
-- schlägt die Leiste. Deshalb wird auf ~= nil geprüft und nicht auf Wahrheit.
--
-- Rückgabe: an, Art, Ton-ID
function Profiles:ResolveAlert(bar, entry)
    if type(bar) ~= "table" then
        return false, "both", nil
    end

    local enabled = bar.alertReady and true or false
    local mode = bar.alertMode or "both"
    local soundID = bar.alertSoundID

    if type(entry) == "table" then
        if entry.alertReady ~= nil then
            enabled = entry.alertReady and true or false
        end
        if entry.alertMode then
            mode = entry.alertMode
        end
        if entry.alertSoundID then
            soundID = entry.alertSoundID
        end
    end

    return enabled, mode, soundID
end

function Profiles:GetSettings()
    return FCD.db.settings
end

function Profiles:GetActive()
    return FCD.db.profiles[FCD.charDB.active]
end

function Profiles:GetActiveName()
    return FCD.charDB.active
end

function Profiles:List()
    local names = {}
    for name in pairs(FCD.db.profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function Profiles:SetActive(name)
    if not FCD.db.profiles[name] then
        return false
    end
    FCD.charDB.active = name
    if FCD.Viewer then
        FCD.Viewer:RebuildAll()
    end
    return true
end

function Profiles:Create(name, copyFromName)
    if not name or name == "" or FCD.db.profiles[name] then
        return nil
    end
    local profile
    local source = copyFromName and FCD.db.profiles[copyFromName]
    if source then
        local out = {}
        serialize(source, out)
        local copy = parseValue(table.concat(out), 1)
        profile = self:Sanitize(copy) or newProfile(name, self.class)
        profile.name = name
    else
        profile = newProfile(name, self.class)
        self:AddDefaultBars(profile)
    end
    FCD.db.profiles[name] = profile
    return profile
end

function Profiles:Delete(name)
    if not FCD.db.profiles[name] then
        return false
    end
    local remaining = 0
    for _ in pairs(FCD.db.profiles) do
        remaining = remaining + 1
    end
    if remaining <= 1 then
        return false, L["Das letzte Profil kann nicht gelöscht werden."]
    end
    FCD.db.profiles[name] = nil
    if FCD.charDB.active == name then
        FCD.charDB.active = (self:List())[1]
    end
    return true
end

-- ------------------------------------------------------------ Import/Export

function Profiles:Export(name)
    local profile = FCD.db.profiles[name or FCD.charDB.active]
    if not profile then
        return nil
    end
    local out = {}
    serialize(profile, out)
    return EXPORT_PREFIX .. table.concat(out)
end

function Profiles:Import(text, overrideName)
    if type(text) ~= "string" then
        return nil, L["Kein Text."]
    end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
        return nil, L["Kein Forever-Cooldowns-Profil (erwartet "] .. EXPORT_PREFIX .. "...)."
    end
    local body = text:sub(#EXPORT_PREFIX + 1)
    local parsed, _, err = parseValue(body, 1)
    if err or type(parsed) ~= "table" then
        return nil, L["Profilstring beschädigt: "] .. tostring(err or L["kein Tabelleninhalt"])
    end
    local profile = self:Sanitize(parsed)
    if not profile then
        return nil, L["Profilstring enthält kein gültiges Profil."]
    end
    local name = overrideName or profile.name or "Import"
    local suffix = 1
    while FCD.db.profiles[name] do
        suffix = suffix + 1
        name = (overrideName or profile.name or "Import") .. " " .. suffix
    end
    profile.name = name
    FCD.db.profiles[name] = profile
    return name
end

-- Übernimmt einen Bestand aus Blizzards Layout-Speicher. Die frisch
-- angelegten Vorgabedaten weichen dabei, aber nur, wenn wirklich etwas
-- Brauchbares kommt - eine leere Tabelle darf nichts überschreiben.
function Profiles:AdoptStore(stored)
    if type(stored) ~= "table" or type(stored.profiles) ~= "table" then
        return false
    end
    local db = FCD.db
    db.schema = stored.schema or db.schema
    db.profiles = stored.profiles
    db.characters = type(stored.characters) == "table" and stored.characters or {}
    db.customItems = type(stored.customItems) == "table" and stored.customItems or {}
    db.layoutProfiles = type(stored.layoutProfiles) == "table"
        and stored.layoutProfiles or {}
    if type(stored.settings) == "table" then
        for key, value in pairs(stored.settings) do
            db.settings[key] = value
        end
    end

    -- Charakterzeiger und Profile neu einhängen
    self:Initialize()
    if FCD.Viewer then
        FCD.Viewer:RebuildAll()
    end
    return true
end

-- ---------------------------------------------------------- Späte Daten

-- Hat der Client die Daten erst nach ADDON_LOADED zugewiesen, steht in der
-- globalen Variablen jetzt eine andere Tabelle als die, mit der wir arbeiten.
-- Dann wird noch einmal von vorn eingerichtet, statt sie zu überschreiben.
function Profiles:AdoptLateData()
    local late = ForeverCooldownsDB
    if type(late) ~= "table" or late == FCD.db then
        return false
    end
    if type(late.profiles) ~= "table" and type(late.settings) ~= "table" then
        return false
    end
    self:Initialize()
    return true
end

-- -------------------------------------------------------------- Rückgängig

local function snapshot(profile)
    local out = {}
    serialize(profile, out)
    return table.concat(out)
end

function Profiles:PushUndo(label)
    local profile = self:GetActive()
    if not profile then
        return
    end
    self.undoStack = self.undoStack or {}
    self.undoStack[#self.undoStack + 1] = { label = label, data = snapshot(profile), name = FCD.charDB.active }
    while #self.undoStack > MAX_UNDO do
        table.remove(self.undoStack, 1)
    end
end

function Profiles:Undo()
    local stack = self.undoStack
    if not stack or #stack == 0 then
        return nil
    end
    local state = table.remove(stack)
    local restored = parseValue(state.data, 1)
    restored = self:Sanitize(restored)
    if not restored then
        return nil
    end
    FCD.db.profiles[state.name] = restored
    if FCD.Viewer then
        FCD.Viewer:RebuildAll()
    end
    return state.label or L["Änderung"]
end

function Profiles:UndoDepth()
    return self.undoStack and #self.undoStack or 0
end

-- ----------------------------------------------------- Automatischer Wechsel

-- Regel: { kind = "form"|"combat"|"spec", value = <Zahl|bool>, profile = "Name" }
function Profiles:AddRule(kind, value, profileName)
    if not FCD.db.profiles[profileName] then
        return false, L["Unbekanntes Profil."]
    end
    FCD.charDB.rules[#FCD.charDB.rules + 1] = { kind = kind, value = value, profile = profileName }
    return true
end

function Profiles:RemoveRule(index)
    if FCD.charDB.rules[index] then
        table.remove(FCD.charDB.rules, index)
        return true
    end
    return false
end

function Profiles:GetRules()
    return FCD.charDB.rules
end

local function ruleMatches(rule)
    local Compat = FCD.Compat
    if rule.kind == "form" then
        return Compat.GetFormID() == rule.value or Compat.GetFormIndex() == rule.value
    elseif rule.kind == "combat" then
        return (InCombatLockdown() and true or false) == (rule.value and true or false)
    elseif rule.kind == "spec" then
        return Compat.GetSpecIndex() == rule.value
    end
    return false
end

-- Erste passende Regel gewinnt; ohne Treffer bleibt das aktive Profil stehen.
function Profiles:EvaluateRules()
    if not FCD.db.settings.autoSwitch then
        return nil
    end
    for _, rule in ipairs(FCD.charDB.rules) do
        if FCD.db.profiles[rule.profile] and ruleMatches(rule) then
            if FCD.charDB.active ~= rule.profile then
                self:SetActive(rule.profile)
                return rule.profile
            end
            return nil
        end
    end
    return nil
end

Profiles.Serialize = serialize
Profiles.Deserialize = parseValue
Profiles.SETTING_DEFAULTS = SETTING_DEFAULTS
