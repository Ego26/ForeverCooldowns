local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local Ranks = {}
FCD.Ranks = Ranks

-- familyKey -> { key, name, icon, ranks = { {spellID, rank, subText, known} }, bestSpellID, ... }
local families = {}
-- spellID -> familyKey
local spellIndex = {}

Ranks.families = families
Ranks.spellIndex = spellIndex

local function normalizeKey(name)
    return string.lower(name or ""):gsub("%s+", " "):gsub("^%s", ""):gsub("%s$", "")
end

-- "Rang 4" / "Rank 4" ergibt 4; "Feuer" oder "Passiv" ergibt nil.
-- So werden Talent-Untertitel nicht fälschlich als Rang gewertet.
function Ranks:ParseRank(subText)
    if type(subText) ~= "string" or subText == "" then
        return nil
    end
    local digits = subText:match("^%D*(%d+)%D*$")
    return digits and tonumber(digits) or nil
end

local function getFamily(key, name)
    local family = families[key]
    if not family then
        family = { key = key, name = name, ranks = {}, byRank = {}, knownCount = 0, hasRanks = false }
        families[key] = family
    end
    if name and (not family.name or family.name == "") then
        family.name = name
    end
    return family
end

local function addRank(family, spellID, rank, subText, known, icon, isPassive)
    if family.byRank[spellID] then
        local existing = family.byRank[spellID]
        existing.known = existing.known or known
        existing.rank = existing.rank or rank
        existing.subText = existing.subText or subText
        return existing
    end
    local entry = {
        spellID = spellID,
        rank = rank,
        subText = subText,
        known = known and true or false,
        icon = icon,
        isPassive = isPassive and true or false,
    }
    family.ranks[#family.ranks + 1] = entry
    family.byRank[spellID] = entry
    spellIndex[spellID] = family.key
    if rank then
        family.hasRanks = true
    end
    if isPassive then
        family.isPassive = true
    end
    if icon and not family.icon then
        family.icon = icon
    end
    return entry
end

local function finalize(family)
    table.sort(family.ranks, function(a, b)
        local rankA = a.rank or 0
        local rankB = b.rank or 0
        if rankA == rankB then
            return (a.spellID or 0) < (b.spellID or 0)
        end
        return rankA < rankB
    end)
    family.knownCount = 0
    family.bestSpellID = nil
    family.bestRank = nil
    for _, entry in ipairs(family.ranks) do
        if entry.known then
            family.knownCount = family.knownCount + 1
            family.bestSpellID = entry.spellID
            family.bestRank = entry.rank
        end
    end
    -- Nichts gelernt: höchster bekannter Eintrag dient als Anzeigevorlage
    if not family.bestSpellID and family.ranks[1] then
        family.bestSpellID = family.ranks[#family.ranks].spellID
        family.bestRank = family.ranks[#family.ranks].rank
    end
    if not family.icon and family.bestSpellID then
        family.icon = Compat.GetSpellIcon(family.bestSpellID)
    end
end

-- Nimmt einen Zauber auf, der nicht im Zauberbuch steht (z. B. aus dem
-- Abklingzeit-Manager oder einem importierten Profil).
function Ranks:Observe(spellID)
    if not spellID or spellIndex[spellID] then
        return spellIndex[spellID] and families[spellIndex[spellID]] or nil
    end
    local name, icon = Compat.GetSpellInfo(spellID)
    if not name then
        return nil
    end
    local subText = Compat.GetSpellSubtext(spellID)
    local key = normalizeKey(name)
    local family = getFamily(key, name)
    addRank(family, spellID, self:ParseRank(subText), subText, Compat.IsSpellKnown(spellID), icon, false)
    finalize(family)
    return family
end

-- Zauber, die nicht im Zauberbuch stehen: von Hand aufgenommene IDs. Damit
-- lässt sich alles verfolgen, was eine Zauber-ID hat - auch was Blizzards
-- Manager nicht anbietet und was der Suchlauf über das Zauberbuch nicht
-- findet, etwa Gegenstandszauber oder Volksfähigkeiten.
function Ranks:AddCustom(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return false, L["Keine Zauber-ID"]
    end
    if not Compat.GetSpellInfo(spellID) then
        return false, L["Der Client kennt diese ID nicht"]
    end
    FCD.db.customSpells = FCD.db.customSpells or {}
    FCD.db.customSpells[spellID] = true
    self:Observe(spellID)
    return true
end

function Ranks:RemoveCustom(spellID)
    spellID = tonumber(spellID)
    if not spellID or not (FCD.db.customSpells or {})[spellID] then
        return false
    end
    FCD.db.customSpells[spellID] = nil
    return true
end

function Ranks:Rebuild()
    wipe(families)
    wipe(spellIndex)

    local scanned = 0
    local ok = Compat.IterateSpellbook(function(spellID, name, subText, icon, isPassive, known)
        if not name then
            name = Compat.GetSpellName(spellID)
        end
        if not name then
            return
        end
        if not subText then
            subText = Compat.GetSpellSubtext(spellID)
        end
        scanned = scanned + 1
        local key = normalizeKey(name)
        local family = getFamily(key, name)
        addRank(family, spellID, self:ParseRank(subText), subText, known, icon, isPassive)
    end)

    -- Von Hand aufgenommene Zauber nach dem Zauberbuch: sie sollen dieselbe
    -- Rangbehandlung bekommen wie alles andere.
    for spellID in pairs(FCD.db and FCD.db.customSpells or {}) do
        local id = tonumber(spellID)
        if id and not spellIndex[id] then
            local name, icon = Compat.GetSpellInfo(id)
            if name then
                local subText = Compat.GetSpellSubtext(id)
                local family = getFamily(normalizeKey(name), name)
                addRank(family, id, self:ParseRank(subText), subText,
                    Compat.IsSpellKnown(id), icon, false)
            end
        end
    end

    for _, family in pairs(families) do
        finalize(family)
    end

    self.scanned = scanned
    self.available = ok and true or false
    self.familyCount = 0
    self.rankedFamilyCount = 0
    for _, family in pairs(families) do
        self.familyCount = self.familyCount + 1
        if family.hasRanks and #family.ranks > 1 then
            self.rankedFamilyCount = self.rankedFamilyCount + 1
        end
    end
    return ok
end

function Ranks:GetFamily(key)
    return families[key]
end

function Ranks:GetFamilyBySpell(spellID)
    local key = spellIndex[spellID]
    if key then
        return families[key]
    end
    return self:Observe(spellID)
end

function Ranks:SortedFamilies()
    local list = {}
    for _, family in pairs(families) do
        list[#list + 1] = family
    end
    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

-- Löst einen Leisteneintrag zum tatsächlich anzuzeigenden Zauber auf.
-- Rückgabe: spellID, rank, family, known
function Ranks:Resolve(entry)
    if not entry then
        return nil
    end
    local family = entry.familyKey and families[entry.familyKey] or nil
    if not family and entry.id then
        family = self:GetFamilyBySpell(entry.id)
    end
    if not family then
        return entry.id, nil, nil, Compat.IsSpellKnown(entry.id)
    end

    if entry.rankMode == "fixed" and entry.fixedRank then
        -- family.ranks ist aufsteigend sortiert, fallback endet also auf dem
        -- höchsten gelernten Rang unterhalb des gewünschten.
        local exact, fallback
        for _, rank in ipairs(family.ranks) do
            if rank.rank == entry.fixedRank then
                exact = rank
            end
            if rank.known and rank.rank and rank.rank <= entry.fixedRank then
                fallback = rank
            end
        end
        if exact and exact.known then
            return exact.spellID, exact.rank, family, true
        end
        -- Fester Rang noch nicht gelernt: nächstniedrigeren gelernten nehmen,
        -- damit ein importiertes Maxlevel-Profil beim Leveln nicht leer bleibt.
        if fallback then
            return fallback.spellID, fallback.rank, family, true
        end
        if exact then
            return exact.spellID, exact.rank, family, false
        end
    end

    if family.bestSpellID then
        local known = false
        local best = family.byRank[family.bestSpellID]
        if best then
            known = best.known
        end
        return family.bestSpellID, family.bestRank, family, known
    end

    return entry.id, nil, family, false
end

-- Liste für die Rangauswahl im Editor
function Ranks:GetRankChoices(familyKey)
    local family = families[familyKey]
    if not family then
        return {}
    end
    local choices = {}
    for _, rank in ipairs(family.ranks) do
        if rank.rank then
            choices[#choices + 1] = { rank = rank.rank, spellID = rank.spellID, known = rank.known, subText = rank.subText }
        end
    end
    return choices
end

-- Baut einen Leisteneintrag aus einem Zauber; familyKey macht ihn levelfest.
function Ranks:MakeEntry(spellID)
    local family = self:GetFamilyBySpell(spellID)
    return {
        kind = "spell",
        id = spellID,
        familyKey = family and family.key or nil,
        rankMode = "best",
    }
end
