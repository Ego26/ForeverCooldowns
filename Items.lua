local FCD = ForeverCooldowns
local Compat = FCD.Compat

local Items = {}
FCD.Items = Items

-- Slots, die in Classic regelmäßig eine benutzbare Wirkung tragen.
-- Slot-Einträge folgen der Ausrüstung, statt eine feste Item-ID zu binden.
local WATCHED_SLOTS = {
    { slot = 13, label = "Schmuckstück 1" },
    { slot = 14, label = "Schmuckstück 2" },
    { slot = 10, label = "Handschuhe" },
    { slot = 6,  label = "Gürtel" },
    { slot = 1,  label = "Kopf" },
    { slot = 8,  label = "Füße" },
    { slot = 15, label = "Umhang" },
    { slot = 2,  label = "Hals" },
    { slot = 11, label = "Ring 1" },
    { slot = 12, label = "Ring 2" },
}

Items.WATCHED_SLOTS = WATCHED_SLOTS

local function pick(namespace, key, globalName)
    if type(namespace) == "table" and type(namespace[key]) == "function" then
        return namespace[key]
    end
    local value = _G[globalName or key]
    if type(value) == "function" then
        return value
    end
    return nil
end

local containerSlots = pick(C_Container, "GetContainerNumSlots", "GetContainerNumSlots")
local containerItemID = pick(C_Container, "GetContainerItemID", "GetContainerItemID")
local itemSpell = pick(C_Item, "GetItemSpell", "GetItemSpell")

Items.candidates = {}

local function slotLabel(slot)
    for _, entry in ipairs(WATCHED_SLOTS) do
        if entry.slot == slot then
            return entry.label
        end
    end
    return "Slot " .. tostring(slot)
end

local function hasUseEffect(itemID)
    if not itemSpell then
        -- Ohne GetItemSpell kann eine Benutzwirkung nicht erkannt werden;
        -- dann wird jedes Item als Kandidat angeboten.
        return true
    end
    local spellName = itemSpell(itemID)
    return spellName ~= nil
end

function Items:Rebuild()
    local candidates = {}
    local seen = {}

    for _, watched in ipairs(WATCHED_SLOTS) do
        local itemID = Compat.GetInventoryItemID(watched.slot)
        if itemID and hasUseEffect(itemID) then
            local name, icon = Compat.GetItemInfo(itemID)
            candidates[#candidates + 1] = {
                kind = "inventory",
                id = watched.slot,
                itemID = itemID,
                name = name or watched.label,
                subLabel = watched.label,
                icon = icon,
            }
        end
    end

    if containerSlots and containerItemID then
        for bag = 0, 4 do
            local slots = containerSlots(bag) or 0
            for slot = 1, slots do
                local itemID = containerItemID(bag, slot)
                if itemID and not seen[itemID] and hasUseEffect(itemID) then
                    seen[itemID] = true
                    local name, icon = Compat.GetItemInfo(itemID)
                    candidates[#candidates + 1] = {
                        kind = "item",
                        id = itemID,
                        itemID = itemID,
                        name = name or ("Item " .. itemID),
                        subLabel = "Tasche",
                        icon = icon,
                    }
                end
            end
        end
    end

    for itemID in pairs(FCD.db and FCD.db.customItems or {}) do
        itemID = tonumber(itemID)
        if itemID and not seen[itemID] then
            seen[itemID] = true
            local name, icon = Compat.GetItemInfo(itemID)
            candidates[#candidates + 1] = {
                kind = "item",
                id = itemID,
                itemID = itemID,
                name = name or ("Item " .. itemID),
                subLabel = "manuell",
                icon = icon,
            }
        end
    end

    table.sort(candidates, function(a, b) return (a.name or "") < (b.name or "") end)
    self.candidates = candidates
    return candidates
end

function Items:AddCustom(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end
    FCD.db.customItems[itemID] = true
    self:Rebuild()
    return true
end

function Items:RemoveCustom(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end
    FCD.db.customItems[itemID] = nil
    self:Rebuild()
    return true
end

-- Rückgabe: start, duration, enabled
function Items:GetCooldown(entry)
    if entry.kind == "inventory" then
        return Compat.GetInventoryCooldown(entry.id)
    end
    return Compat.GetItemCooldown(entry.id)
end

-- Rückgabe: name, icon, count, vorhanden, geladen
--
-- "vorhanden" und "geladen" sind zweierlei: kurz nach dem Anmelden kennt der
-- Client die Daten eines Gegenstands noch nicht, und dann sieht ein
-- vorhandener wie ein fehlender aus. Wer beides gleich behandelt, blendet
-- nach jedem Neuladen die halbe Leiste aus - und es sieht aus, als wäre nichts
-- gespeichert worden.
function Items:GetDisplay(entry)
    if entry.kind == "inventory" then
        local itemID = Compat.GetInventoryItemID(entry.id)
        if not itemID then
            return slotLabel(entry.id), 134400, 0, false, true
        end
        local name, icon = Compat.GetItemInfo(itemID)
        return name or slotLabel(entry.id), icon, 0, true, name ~= nil
    end
    local name, icon = Compat.GetItemInfo(entry.id)
    local count = Compat.GetItemCount(entry.id)
    return name or ("Item " .. tostring(entry.id)), icon, count,
        Compat.IsPositive(count), name ~= nil
end

function Items:MakeEntry(candidate)
    return {
        kind = candidate.kind,
        id = candidate.id,
        rankMode = "best",
    }
end

Items.SlotLabel = slotLabel
