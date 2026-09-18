local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local Catalog = {}
FCD.Catalog = Catalog

Catalog.entries = {}
Catalog.byKey = {}
Catalog.viewerEntries = {}
Catalog.viewerAvailable = false

local function spellIDFromCacheInfo(info)
    -- Feldnamen sind zwischen Client-Builds nicht stabil, daher der Reihe nach
    -- die bekannten Varianten abklopfen.
    if type(info) ~= "table" then
        return nil
    end
    local candidates = { "spellID", "spellId", "overrideSpellID", "linkedSpellID" }
    for _, field in ipairs(candidates) do
        if type(info[field]) == "number" then
            return info[field]
        end
    end
    if type(info.linkedSpellIDs) == "table" and type(info.linkedSpellIDs[1]) == "number" then
        return info.linkedSpellIDs[1]
    end
    return nil
end

-- Liest den Blizzard-Abklingzeit-Manager aus. Rückgabe: Liste von
-- { cooldownID, spellID, category, categoryName }
function Catalog:ReadViewer()
    local result = {}
    if not Compat.HasCooldownViewer() then
        self.viewerAvailable = false
        self.viewerEntries = result
        return result
    end
    local categories = Compat.GetCooldownViewerCategories()
    if #categories == 0 then
        -- Ohne Enum die ersten Kategorie-Indizes abtasten
        for value = 0, 5 do
            categories[#categories + 1] = { name = "Kategorie " .. value, value = value }
        end
    end
    for _, category in ipairs(categories) do
        local ids = Compat.GetCategorySet(category.value)
        if ids then
            for _, cooldownID in ipairs(ids) do
                local info = Compat.GetCooldownInfo(cooldownID)
                result[#result + 1] = {
                    cooldownID = cooldownID,
                    spellID = spellIDFromCacheInfo(info),
                    category = category.value,
                    categoryName = category.name,
                    info = info,
                }
            end
        end
    end
    self.viewerAvailable = true
    self.viewerEntries = result
    return result
end

local function baseCooldownOf(spellID)
    local seconds = Compat.GetSpellBaseCooldown(spellID)
    if seconds == nil then
        -- API fehlt: laufende Abklingzeit als schwaches Indiz verwenden
        local _, duration = Compat.GetSpellCooldown(spellID)
        return duration or 0
    end
    return seconds
end

function Catalog:Rebuild()
    FCD.Ranks:Rebuild()
    FCD.Items:Rebuild()

    -- Einmalig prüfen, ob dieser Client Abklingzeit-Werte schützt. Dafür
    -- wird irgendein bekannter Zauber gebraucht, also erst nach dem Scan.
    for _, family in pairs(FCD.Ranks.families) do
        if family.bestSpellID then
            Compat.DetectSecrets(family.bestSpellID)
            break
        end
    end

    local viewer = self:ReadViewer()

    -- Zauber, die nur der Manager kennt, ins Rang-Register aufnehmen
    local viewerBySpell = {}
    local viewerByFamily = {}
    for _, entry in ipairs(viewer) do
        -- linkedSpellIDs enthält alle Ränge einer Fähigkeit, auch die noch
        -- nicht gelernten. Das ist die vollständige Rangleiter, die das
        -- Zauberbuch auf niedriger Stufe noch nicht hergibt.
        local info = entry.info
        if type(info) == "table" and type(info.linkedSpellIDs) == "table" then
            for _, linkedID in ipairs(info.linkedSpellIDs) do
                if type(linkedID) == "number" then
                    FCD.Ranks:Observe(linkedID)
                end
            end
        end
        if entry.spellID then
            local family = FCD.Ranks:GetFamilyBySpell(entry.spellID)
            viewerBySpell[entry.spellID] = entry
            if family then
                viewerByFamily[family.key] = viewerByFamily[family.key] or {}
                viewerByFamily[family.key][#viewerByFamily[family.key] + 1] = entry
            end
        end
    end

    local entries = {}
    local byKey = {}

    for _, family in ipairs(FCD.Ranks:SortedFamilies()) do
        local best = family.bestSpellID
        local baseCooldown = best and baseCooldownOf(best) or 0
        local viewerHits = viewerByFamily[family.key]
        local entry = {
            kind = "spell",
            key = "spell:" .. family.key,
            familyKey = family.key,
            name = family.name,
            icon = family.icon,
            bestSpellID = best,
            bestRank = family.bestRank,
            rankCount = #family.ranks,
            knownRanks = family.knownCount,
            known = family.knownCount > 0,
            isPassive = family.isPassive and true or false,
            baseCooldown = baseCooldown,
            hasCooldown = baseCooldown and baseCooldown > 0,
            inViewer = viewerHits ~= nil,
            viewerCount = viewerHits and #viewerHits or 0,
            viewerCategory = viewerHits and viewerHits[1].categoryName or nil,
            -- Der Manager weiß selbst, ob ein Eintrag eine Aura trägt
            hasAura = (viewerHits and viewerHits[1].info and viewerHits[1].info.hasAura) or false,
        }
        entries[#entries + 1] = entry
        byKey[entry.key] = entry
    end

    for _, candidate in ipairs(FCD.Items.candidates) do
        local entry = {
            kind = candidate.kind,
            key = candidate.kind .. ":" .. tostring(candidate.id),
            id = candidate.id,
            itemID = candidate.itemID,
            name = candidate.name,
            subLabel = candidate.subLabel,
            icon = candidate.icon,
            known = true,
            hasCooldown = true,
            rankCount = 0,
            knownRanks = 0,
            inViewer = false,
        }
        entries[#entries + 1] = entry
        byKey[entry.key] = entry
    end

    self.entries = entries
    self.byKey = byKey
    self.viewerBySpell = viewerBySpell
    return entries
end

function Catalog:Get(key)
    return self.byKey[key]
end

-- Liefert den Katalogschlüssel zu einem Leisteneintrag
function Catalog:KeyForEntry(entry)
    if not entry then
        return nil
    end
    if entry.kind == "spell" then
        local familyKey = entry.familyKey
        if not familyKey then
            local family = FCD.Ranks:GetFamilyBySpell(entry.id)
            familyKey = family and family.key or nil
        end
        return familyKey and ("spell:" .. familyKey) or nil
    end
    return entry.kind .. ":" .. tostring(entry.id)
end

local function matchesText(entry, needle)
    if not needle or needle == "" then
        return true
    end
    if string.find(string.lower(entry.name or ""), needle, 1, true) then
        return true
    end
    if entry.bestSpellID and string.find(tostring(entry.bestSpellID), needle, 1, true) then
        return true
    end
    if entry.id and string.find(tostring(entry.id), needle, 1, true) then
        return true
    end
    return false
end

-- options: text, onlyKnown, onlyWithCooldown, onlyMissingFromViewer,
--          showSpells, showItems, showPassive
function Catalog:Filter(options)
    options = options or {}
    local needle = options.text and string.lower(options.text) or nil
    local result = {}
    for _, entry in ipairs(self.entries) do
        local keep = true
        if entry.kind == "spell" then
            if options.showSpells == false then
                keep = false
            end
            if keep and entry.isPassive and not options.showPassive then
                keep = false
            end
        else
            if options.showItems == false then
                keep = false
            end
        end
        if keep and options.onlyKnown and not entry.known then
            keep = false
        end
        if keep and options.onlyWithCooldown and not entry.hasCooldown then
            keep = false
        end
        if keep and options.onlyMissingFromViewer and entry.inViewer then
            keep = false
        end
        if keep and not matchesText(entry, needle) then
            keep = false
        end
        if keep then
            result[#result + 1] = entry
        end
    end
    return result
end

-- ------------------------------------------------------------ Beta-Bericht

-- Vergleicht Zauberbuch und Abklingzeit-Manager und listet auf, was im
-- Manager fehlt, kaputt ist oder nur teilweise vorhanden ist. Gedacht als
-- Sammelmeldung statt vierzig Einzelmeldungen über F6.
function Catalog:BuildReport()
    local lines = {
        "Forever Cooldowns - Katalogbericht",
        string.format("AddOn %s, Client %s (Build %s), Interface %d",
            FCD.version, FCD.clientVersion, tostring(FCD.build), FCD.tocVersion),
        string.format("Charakter: %s (%s, Stufe %s)", UnitName("player") or "?", UnitClass("player") or "?", tostring(UnitLevel("player") or "?")),
        "",
    }

    if not self.viewerAvailable then
        lines[#lines + 1] = L["C_CooldownViewer ist in diesem Client nicht lesbar - kein Abgleich möglich."]
        lines[#lines + 1] = L["Forever Cooldowns läuft dann rein aus dem Zauberbuch."]
        return table.concat(lines, "\n")
    end

    lines[#lines + 1] = string.format(L["Manager-Einträge gesamt: %d"], #self.viewerEntries)

    -- Ohne Auflösungsfunktion sind die Einträge bloße Zahlen; sie als
    -- "kaputt" zu melden wäre irreführend.
    if not Compat.HasCooldownInfo() then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Dieser Client bietet keine Funktion, die eine Abklingzeit-ID zu einem"
        lines[#lines + 1] = L["Zauber auflöst. Die Kategorien sind lesbar, die Zuordnung nicht -"]
        lines[#lines + 1] = L["ein inhaltlicher Abgleich ist damit nicht möglich."]
        lines[#lines + 1] = "Vorhandene IDs je Kategorie stehen in /fcd probe."
        return table.concat(lines, "\n")
    end

    local broken, missing, partial, unknownToPlayer = {}, {}, {}, {}

    for _, entry in ipairs(self.viewerEntries) do
        if not entry.spellID then
            broken[#broken + 1] = string.format(L["  Abklingzeit-ID %s (%s): kein Zauber auflösbar"],
                tostring(entry.cooldownID), tostring(entry.categoryName))
        else
            local name = Compat.GetSpellName(entry.spellID)
            if not name then
                broken[#broken + 1] = string.format("  Abklingzeit-ID %s -> Zauber %d: kein Name im Client",
                    tostring(entry.cooldownID), entry.spellID)
            elseif not Compat.IsSpellKnown(entry.spellID) then
                unknownToPlayer[#unknownToPlayer + 1] = string.format("  %s (%d, %s)", name, entry.spellID, tostring(entry.categoryName))
            end
        end
    end

    for _, entry in ipairs(self.entries) do
        if entry.kind == "spell" and entry.known and not entry.isPassive and entry.hasCooldown and not entry.inViewer then
            missing[#missing + 1] = string.format("  %s (bester Rang %s, Zauber %s, CD %.0fs)",
                entry.name, tostring(entry.bestRank or "-"), tostring(entry.bestSpellID), entry.baseCooldown or 0)
        end
        if entry.kind == "spell" and entry.inViewer and entry.rankCount > 1 and entry.viewerCount < entry.rankCount then
            partial[#partial + 1] = string.format(L["  %s: %d von %d Rängen im Manager"],
                entry.name, entry.viewerCount, entry.rankCount)
        end
    end

    local function section(title, list)
        lines[#lines + 1] = ""
        lines[#lines + 1] = string.format("%s (%d)", title, #list)
        if #list == 0 then
            lines[#lines + 1] = "  keine"
            return
        end
        for index = 1, math.min(#list, 200) do
            lines[#lines + 1] = list[index]
        end
        if #list > 200 then
            lines[#lines + 1] = string.format("  ... und %d weitere", #list - 200)
        end
    end

    section(L["Gelernte Fähigkeiten mit Abklingzeit, die im Manager fehlen"], missing)
    section(L["Manager-Einträge ohne auflösbaren Zauber"], broken)
    section(L["Fähigkeiten mit unvollständiger Rangabdeckung"], partial)
    section(L["Manager-Einträge, die dieser Charakter nicht kennt"], unknownToPlayer)

    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format(L["Zauberbuch: %d Einträge, %d Fähigkeiten, davon %d mit mehreren Rängen."],
        FCD.Ranks.scanned or 0, FCD.Ranks.familyCount or 0, FCD.Ranks.rankedFamilyCount or 0)

    return table.concat(lines, "\n")
end
