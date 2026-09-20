local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local Mirror = {}
FCD.Mirror = Mirror

-- Blizzards Kategorien auf unseren eigenen Leisten.
--
-- Der Anlass: eine Kategorie zu ändern soll sofort zu sehen sein. Es gibt
-- dafür zwei Wege, und beide hatten bisher einen Haken.
--
--   * Über Blizzards Lua-Objekte. Wirkt ohne Neuladen - markiert ihren
--     Viewer aber als tainted, und der wirft danach bei jedem Ziel- und
--     Aurenereignis einen roten Fehler.
--   * Über SetLayoutData. Taintet nichts, wirkt aber erst beim Neuladen,
--     weil der Client das Layout nur dann liest.
--
-- Die C-Funktion, die beides könnte - SetCooldownViewerCategorySet - gibt es
-- in diesem Client nicht (/fcd check sagt es).
--
-- Also der dritte Weg: Wir zeichnen die Kategorie selbst. Eine gespiegelte
-- Leiste hat keine eigene Eintragsliste; sie fragt, welche Abklingzeiten
-- gerade in dieser Kategorie liegen, und zeigt genau die. Das ist dieselbe
-- Auskunft, die das Panel für seine Abschnitte benutzt - eine Verschiebung
-- steht also in derselben Sekunde auf der Leiste, ohne dass eine einzige
-- Zeile Blizzard-Lua gelaufen wäre.
--
-- Ihre eigenen Leisten ziehen weiterhin erst beim Neuladen nach. Wer beides
-- nebeneinander stehen lässt, sieht bis dahin zweierlei; deshalb sagt das
-- Panel es und /fcd mirror erklärt, wie man ihre ausblendet.

local HIDDEN_CATEGORY = -1
Mirror.HIDDEN_CATEGORY = HIDDEN_CATEGORY

-- Die Namen sind Kennungen wie überall sonst: deutsch gespeichert, beim
-- Anzeigen übersetzt. Das Panel benutzt dieselbe Tabelle, damit eine
-- Kategorie nicht an zwei Stellen verschieden heißen kann.
local CATEGORY_NAMES = {
    [-2] = "Nicht angezeigt (passiv)",
    [-1] = "Nicht angezeigt",
    [0] = "Essenzielle Abklingzeiten",
    [1] = "Strategische Abklingzeiten",
    [2] = "Verfolgte Stärkungseffekte",
    [3] = "Verfolgte Leisten",
    [4] = "Gruppenstärkungseffekte",
    [7] = "Gegenstände",
    [8] = "Gegenstände (verfolgt)",
}
Mirror.CATEGORY_NAMES = CATEGORY_NAMES

-- "Nicht angezeigt" lässt sich nicht spiegeln: eine Leiste, die genau das
-- zeigt, was man nicht sehen will, wäre ein Widerspruch.
local MIRRORABLE = { 0, 1, 2, 3, 4, 7, 8 }
Mirror.MIRRORABLE = MIRRORABLE

-- Was bei einem Neuaufbau aus dem alten Eintrag erhalten bleibt. Die
-- Eintragsliste wird jedes Mal neu gebaut, die Einstellungen daran nicht -
-- sonst verlöre eine Fertig-Meldung ihre Gültigkeit, sobald man irgendwo
-- anders etwas verschiebt.
local OPTION_FIELDS = { "alertReady", "alertMode", "alertSoundID",
    "rankMode", "fixedRank", "trackAura" }

-- ------------------------------------------------------------ Zwischenstand

-- Blizzards Layout einmal auflösen und aufheben: Lesen heißt base64,
-- entpacken und CBOR: zu teuer, um es je Bild zu tun. Jede Stelle, die etwas
-- ändert, wirft den Stand weg.
local resolved
-- Der Schlüssel ist die Leistentabelle selbst, nicht ihre Nummer: Nummern
-- werden nach dem Löschen wieder vergeben, und dann bekäme eine neue Leiste
-- den Bestand einer alten.
local entriesByBar = {}

function Mirror:Invalidate()
    resolved = nil
    wipe(entriesByBar)
end

local function resolve()
    if resolved then
        return resolved
    end

    local layout = FCD.Layout:Read()
    local map, hidden, order, seen = {}, {}, {}, {}

    local function add(cooldownID)
        if seen[cooldownID] then
            return
        end
        seen[cooldownID] = true
        local info = Compat.GetCooldownInfo(cooldownID)
        local category = info and info.category or nil
        if category ~= nil then
            map[cooldownID] = category
            -- Bit 2 der flags heißt "standardmäßig nicht angezeigt" - am
            -- lebenden Client ausgezählt, dieselbe Regel wie im Panel.
            hidden[cooldownID] = ((info.flags or 0) % 4) >= 2
            order[#order + 1] = cooldownID
        end
    end

    -- Die Reihenfolgeliste des Layouts ist der vollständige Bestand; die
    -- Kategorieabfragen kennen nur die gerade aktiven.
    if layout and layout.order then
        for _, cooldownID in ipairs(layout.order) do
            add(cooldownID)
        end
    end
    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        for _, cooldownID in ipairs(Compat.GetCategorySet(category.value) or {}) do
            add(cooldownID)
        end
    end

    local assigned, position = {}, {}
    if layout then
        for category, list in pairs(layout.categories or {}) do
            for _, cooldownID in ipairs(list) do
                assigned[cooldownID] = category
            end
        end
        for index, cooldownID in ipairs(layout.order or {}) do
            position[cooldownID] = index
        end
    end

    resolved = {
        map = map,
        hidden = hidden,
        order = order,
        assigned = assigned,
        position = position,
        readable = layout ~= nil,
    }
    return resolved
end

-- Wo liegt diese Abklingzeit gerade? Die Zuweisung aus dem Layout schlägt
-- die Standardeinordnung; ohne Zuweisung entscheiden die flags.
function Mirror:EffectiveCategory(cooldownID)
    local state = resolve()
    local assigned = state.assigned[cooldownID]
    if assigned ~= nil then
        return assigned
    end
    if state.hidden[cooldownID] then
        return HIDDEN_CATEGORY
    end
    return state.map[cooldownID]
end

function Mirror:CategoryName(category)
    local name = CATEGORY_NAMES[category]
    if name then
        return L[name]
    end
    return L["Kategorie "] .. tostring(category)
end

-- Ist Blizzards Layout überhaupt lesbar? Ohne das kann eine gespiegelte
-- Leiste nur die Standardeinordnung zeigen, nicht die eingestellte.
function Mirror:IsReadable()
    return resolve().readable
end

-- ------------------------------------------------------------- Einträge

-- Mehrere Abklingzeiten gehören oft zur selben Fähigkeit - je ein Rang. Auf
-- der Leiste soll davon ein Symbol stehen, so wie Blizzards Viewer es zeigt,
-- und zwar der beste gelernte Rang. Deshalb wird nach Rangfamilie
-- zusammengefasst.
function Mirror:BuildEntries(category, includeUnknown)
    if category == nil then
        return {}
    end

    local state = resolve()
    local records, byKey = {}, {}

    for _, cooldownID in ipairs(state.order) do
        if self:EffectiveCategory(cooldownID) == category then
            local info = Compat.GetCooldownInfo(cooldownID)
            local spellID = info and (info.spellID or info.overrideSpellID) or nil
            if spellID then
                local family = FCD.Ranks:GetFamilyBySpell(spellID)
                local key = family and family.key or ("id:" .. tostring(spellID))
                -- Die Anzeigereihenfolge steht im Layout; was dort nicht
                -- vorkommt, hängt sich hinten an, nach ID sortiert.
                local sort = state.position[cooldownID] or (100000 + cooldownID)
                local record = byKey[key]
                if record then
                    if sort < record.sort then
                        record.sort = sort
                    end
                else
                    record = { entry = FCD.Ranks:MakeEntry(spellID), sort = sort }
                    byKey[key] = record
                    records[#records + 1] = record
                end
            end
        end
    end

    table.sort(records, function(a, b)
        if a.sort == b.sort then
            return false
        end
        return a.sort < b.sort
    end)

    -- Ungelerntes fliegt schon hier heraus und nicht erst beim Zeichnen:
    -- ein Symbol, das erst einen Platz bekommt und dann ausgeblendet wird,
    -- hinterlässt eine Lücke in der Reihe.
    local entries = {}
    for _, record in ipairs(records) do
        local entry = record.entry
        entry.fcdMirror = true
        if includeUnknown then
            entries[#entries + 1] = entry
        else
            local _, _, _, known = FCD.Ranks:Resolve(entry)
            if known then
                entries[#entries + 1] = entry
            end
        end
    end
    return entries
end

local function optionKey(entry)
    return entry.familyKey or ("id:" .. tostring(entry.id))
end

local function applyOptions(bar, entries)
    local stored = bar.mirrorEntryOptions
    if type(stored) ~= "table" then
        return
    end
    for _, entry in ipairs(entries) do
        local options = stored[optionKey(entry)]
        if type(options) == "table" then
            for _, field in ipairs(OPTION_FIELDS) do
                if options[field] ~= nil then
                    entry[field] = options[field]
                end
            end
        end
    end
end

-- Eine Einstellung an einem einzelnen Symbol festhalten. Ohne das wäre sie
-- beim nächsten Neuaufbau weg, und der kommt schon beim nächsten gelernten
-- Rang.
function Mirror:RememberEntry(bar, entry)
    if type(bar) ~= "table" or bar.mirrorCategory == nil or type(entry) ~= "table" then
        return false
    end
    bar.mirrorEntryOptions = bar.mirrorEntryOptions or {}
    local options = {}
    for _, field in ipairs(OPTION_FIELDS) do
        options[field] = entry[field]
    end
    bar.mirrorEntryOptions[optionKey(entry)] = options
    return true
end

local function includeUnknownOf(bar)
    return (bar.visibility or {}).hideUnknown == false
end

-- Die Einträge einer gespiegelten Leiste. Sie werden nie gespeichert: was
-- sich aus Blizzards Kategorie ergibt, gehört nicht in unsere Datei, sonst
-- steht dort morgen ein Stand von gestern.
function Mirror:EntriesFor(bar)
    if type(bar) ~= "table" or bar.mirrorCategory == nil then
        return (type(bar) == "table" and bar.entries) or {}
    end

    local unknown = includeUnknownOf(bar)
    local cached = entriesByBar[bar]
    if cached and cached.category == bar.mirrorCategory and cached.unknown == unknown then
        return cached.list
    end

    local list = self:BuildEntries(bar.mirrorCategory, unknown)
    applyOptions(bar, list)
    entriesByBar[bar] = {
        list = list,
        category = bar.mirrorCategory,
        unknown = unknown,
    }
    return list
end

-- ---------------------------------------------------------------- Leisten

function Mirror:IsMirror(bar)
    return type(bar) == "table" and bar.mirrorCategory ~= nil
end

function Mirror:FindBar(category, profile)
    profile = profile or FCD.Profiles:GetActive()
    if not profile then
        return nil
    end
    for _, bar in ipairs(profile.bars) do
        if bar.mirrorCategory == category then
            return bar
        end
    end
    return nil
end

function Mirror:IsMirrored(category)
    return self:FindBar(category) ~= nil
end

function Mirror:HasAny(profile)
    profile = profile or FCD.Profiles:GetActive()
    if not profile then
        return false
    end
    for _, bar in ipairs(profile.bars) do
        if bar.mirrorCategory ~= nil then
            return true
        end
    end
    return false
end

function Mirror:List(profile)
    profile = profile or FCD.Profiles:GetActive()
    local found = {}
    for _, bar in ipairs(profile and profile.bars or {}) do
        if bar.mirrorCategory ~= nil then
            found[#found + 1] = bar
        end
    end
    return found
end

-- Rückgabe: leiste, fehlertext
function Mirror:Enable(category)
    if CATEGORY_NAMES[category] == nil or category < 0 then
        return nil, L["Diese Kategorie lässt sich nicht spiegeln."]
    end
    local profile = FCD.Profiles:GetActive()
    if not profile then
        return nil, L["Kein Profil aktiv."]
    end

    local existing = self:FindBar(category, profile)
    if existing then
        return existing
    end

    FCD.Profiles:PushUndo(L["Leiste spiegeln"])
    local bar = FCD.Profiles:NewBar(profile, CATEGORY_NAMES[category])
    bar.mirrorCategory = category
    bar.entries = {}
    bar.mirrorEntryOptions = {}
    self:Invalidate()
    FCD.Viewer:RebuildAll()
    return bar
end

function Mirror:Disable(category)
    local profile = FCD.Profiles:GetActive()
    local bar = self:FindBar(category, profile)
    if not bar then
        return false
    end
    FCD.Profiles:PushUndo(L["Spiegelung aufheben"])
    entriesByBar[bar] = nil
    FCD.Profiles:RemoveBar(profile, bar.id)
    FCD.Viewer:RebuildAll()
    return true
end

-- Rückgabe: true (wird jetzt gespiegelt), false (nicht mehr) oder
-- nil plus Grund. Drei Ausgänge, weil "nicht angelegt" etwas anderes ist als
-- "abgeschaltet" - ohne die Unterscheidung meldete eine abgelehnte Kategorie
-- fälschlich Erfolg.
function Mirror:Toggle(category)
    if self:IsMirrored(category) then
        self:Disable(category)
        return false
    end
    local bar, err = self:Enable(category)
    if not bar then
        return nil, err
    end
    return true
end

-- Aus der Spiegelung eine gewöhnliche Leiste machen: der aktuelle Bestand
-- wird festgeschrieben und gehört danach uns. Gedacht für den, der mit dem
-- Ergebnis zufrieden ist und nur noch zwei Symbole herausnehmen will.
function Mirror:Release(bar)
    if not self:IsMirror(bar) then
        return false
    end
    FCD.Profiles:PushUndo(L["Spiegelung lösen"])
    local entries = self:EntriesFor(bar)
    local copy = {}
    for index, entry in ipairs(entries) do
        copy[index] = entry
    end
    entriesByBar[bar] = nil
    bar.entries = copy
    bar.mirrorCategory = nil
    bar.mirrorEntryOptions = nil
    FCD.Viewer:RebuildAll()
    return true
end

-- Nach jeder Änderung an Blizzards Kategorien: Zwischenstand wegwerfen und
-- neu zeichnen. Das ist der ganze Sofortmodus dieses Weges.
function Mirror:Refresh()
    self:Invalidate()
    if not self:HasAny() then
        return false
    end
    if FCD.Viewer then
        FCD.Viewer:RebuildAll()
    end
    return true
end

-- Wie man Blizzards eigene Leisten loswird. Wir fassen ihre Fenster dafür
-- nicht an: jeder Aufruf auf ihren Objekten ist genau der Taint, den dieser
-- Weg vermeiden soll. Ausblenden muss deshalb der Spieler, in ihrem eigenen
-- Fenster - dort kostet es nichts.
function Mirror:GetHideInstructions()
    return {
        L["Blizzards eigene Leisten zeigen bis zum nächsten Neuladen noch den"],
        L["alten Stand. Dauerhaft ausblenden - in ihrem Fenster, damit nichts"],
        L["getaintet wird:"],
        L["  1. /fcd editui off"],
        L["  2. Bearbeitungsmodus öffnen und ihre Leiste anklicken"],
        L["  3. Haken bei 'Sichtbar' entfernen, Änderungen speichern"],
        L["  4. /fcd editui on, falls unser Fenster zurück soll"],
    }
end
