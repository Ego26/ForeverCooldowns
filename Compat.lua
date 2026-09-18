local ADDON_NAME = ...
ForeverCooldowns = ForeverCooldowns or {}
local FCD = ForeverCooldowns

FCD.name = ADDON_NAME
FCD.version = "0.1.0-beta"

-- GetBuildInfo liefert Version, Buildnummer, Datum und Interface-Nummer.
-- Die vierte Rückgabe ist nicht der Build, sondern genau der Wert, der in
-- "## Interface" gehört - deshalb wird sie hier getrennt gehalten.
local clientVersion, clientBuild, clientDate, clientToc = GetBuildInfo()
FCD.clientVersion = clientVersion or "?"
FCD.build = clientBuild or "unknown"
FCD.clientDate = clientDate or "?"
FCD.tocVersion = tonumber(clientToc) or 0

local Compat = {}
FCD.Compat = Compat

-- caps hält pro Fähigkeit fest, über welchen API-Pfad sie bedient wird
-- (Zeichenkette) oder dass sie im aktuellen Client fehlt (false).
local caps = {}
Compat.caps = caps

local function method(namespace, key)
    if type(namespace) == "table" and type(namespace[key]) == "function" then
        return namespace[key]
    end
    return nil
end

local function globalFunction(name)
    local value = _G[name]
    if type(value) == "function" then
        return value
    end
    return nil
end

-- Der Forever-Beta-Client liegt zwischen moderner Namespace-API und den alten
-- Globals. Jede Funktion wird deshalb einzeln aufgelöst statt über eine
-- pauschale Versionsabfrage.
local spellInfoNew     = method(C_Spell, "GetSpellInfo")
local spellInfoOld     = globalFunction("GetSpellInfo")
local spellSubtextNew  = method(C_Spell, "GetSpellSubtext")
local spellSubtextOld  = globalFunction("GetSpellSubtext")
local spellCooldownNew = method(C_Spell, "GetSpellCooldown")
local spellCooldownOld = globalFunction("GetSpellCooldown")
local spellChargesNew  = method(C_Spell, "GetSpellCharges")
local spellChargesOld  = globalFunction("GetSpellCharges")
local spellUsableNew   = method(C_Spell, "IsSpellUsable")
local spellUsableOld   = globalFunction("IsUsableSpell")
local spellCostNew     = method(C_Spell, "GetSpellPowerCost")
local spellCostOld     = globalFunction("GetSpellPowerCost")
local spellKnownNew    = method(C_SpellBook, "IsSpellKnown")
local spellKnownOld    = globalFunction("IsSpellKnown")
local playerSpellOld   = globalFunction("IsPlayerSpell")
local baseCooldownNew  = method(C_Spell, "GetSpellBaseCooldown")
local baseCooldownOld  = globalFunction("GetSpellBaseCooldown")

local bookLinesNew   = method(C_SpellBook, "GetNumSpellBookSkillLines")
local bookLineInfo   = method(C_SpellBook, "GetSpellBookSkillLineInfo")
local bookItemNew    = method(C_SpellBook, "GetSpellBookItemInfo")
local bookNameNew    = method(C_SpellBook, "GetSpellBookItemName")
local bookTabsOld    = globalFunction("GetNumSpellTabs")
local bookTabInfoOld = globalFunction("GetSpellTabInfo")
local bookItemOld    = globalFunction("GetSpellBookItemInfo")
local bookNameOld    = globalFunction("GetSpellBookItemName")
local bookPassiveOld = globalFunction("IsPassiveSpell")

local playerBank = "spell"
if type(Enum) == "table" and type(Enum.SpellBookSpellBank) == "table" and Enum.SpellBookSpellBank.Player ~= nil then
    playerBank = Enum.SpellBookSpellBank.Player
end
local futureSpellType
if type(Enum) == "table" and type(Enum.SpellBookItemType) == "table" then
    futureSpellType = Enum.SpellBookItemType.FutureSpell
end

local itemCooldownNew   = method(C_Item, "GetItemCooldown")
local itemCooldownOld   = globalFunction("GetItemCooldown")
local itemInfoNew       = method(C_Item, "GetItemInfo")
local itemInfoOld       = globalFunction("GetItemInfo")
local itemCountNew      = method(C_Item, "GetItemCount")
local itemCountOld      = globalFunction("GetItemCount")
local itemIconNew       = method(C_Item, "GetItemIconByID")
local inventoryCooldown = globalFunction("GetInventoryItemCooldown")
local inventoryItemID   = globalFunction("GetInventoryItemID")

local auraBySpellNew = method(C_UnitAuras, "GetPlayerAuraBySpellID")
local unitAuraOld    = globalFunction("UnitAura")

local cvCategorySet = method(C_CooldownViewer, "GetCooldownViewerCategorySet")
local cvSetCategory = method(C_CooldownViewer, "SetCooldownViewerCategorySet")
local cvIsEnabled   = method(C_CooldownViewer, "IsCooldownViewerAvailable")

-- Die Auflösung Abklingzeit-ID -> Zauber heißt nicht in jedem Build gleich.
-- Der Forever-Client hat die Kategorie-Listen, aber nicht
-- GetCooldownViewerCacheInfo; deshalb werden mehrere Namen probiert.
local CACHE_INFO_NAMES = {
    "GetCooldownViewerCacheInfo",
    "GetCooldownViewerCooldownInfo",
    "GetCooldownViewerSpellInfo",
    "GetCooldownViewerInfo",
    "GetCooldownInfo",
    "GetCooldownData",
}
local cvCacheInfo, cvCacheInfoName
for _, candidateName in ipairs(CACHE_INFO_NAMES) do
    local candidate = method(C_CooldownViewer, candidateName)
    if candidate then
        cvCacheInfo, cvCacheInfoName = candidate, candidateName
        break
    end
end

-- Dieser Build hat kein SetCooldownViewerCategorySet, aber Get/SetLayoutData.
-- Ob darin die Kategorie-Zugehörigkeit steckt und ob Schreiben erlaubt ist,
-- muss der Client beantworten - siehe /fcd layout und /fcd layouttest.
local cvGetLayout = method(C_CooldownViewer, "GetLayoutData")
local cvSetLayout = method(C_CooldownViewer, "SetLayoutData")

local addOnMetadata     = method(C_AddOns, "GetAddOnMetadata") or globalFunction("GetAddOnMetadata")

local shapeshiftFormID  = globalFunction("GetShapeshiftFormID")
local shapeshiftForm    = globalFunction("GetShapeshiftForm")
local numShapeshifts    = globalFunction("GetNumShapeshiftForms")
local specializationNew = method(C_SpecializationInfo, "GetSpecialization")
local specializationOld = globalFunction("GetSpecialization")

-- ------------------------------------------------------ Geschützte Werte

-- Neuere Clients liefern Abklingzeiten als "secret values": der Wert darf an
-- SetCooldown weitergereicht, aber nicht verglichen oder ausgegeben werden,
-- solange die Ausführung von einem AddOn stammt. Ein Vergleich wirft einen
-- Fehler - genau daran lässt sich das erkennen.
local function compareToZero(value)
    return value > 0
end

local function branchOn(value)
    if value then
        return true
    end
    return false
end

-- Wahrheitswert eines möglicherweise geschützten Wertes, mit Rückfall
local function safeBoolean(value, default)
    local ok, result = pcall(branchOn, value)
    if ok then
        return result
    end
    return default
end

-- table.concat ist genau die Stelle, an der ein geschützter Wert auffliegt.
-- Der ".."-Operator reicht als Prüfung nicht: er gibt einen geschützten
-- Wert stillschweigend weiter, und type() meldet trotzdem "string".
local function concatSingle(text)
    return table.concat({ text })
end

-- tostring wirft bei einem geschützten Wert nicht, sondern liefert eine
-- ebenfalls geschützte Zeichenkette. Erst der Versuch, sie wie eine
-- gewöhnliche Zeichenkette zu benutzen, beweist, dass sie benutzbar ist.
local function safeToString(value)
    local ok, text = pcall(tostring, value)
    if not ok or type(text) ~= "string" then
        return "<geschützt>"
    end
    local usable, plain = pcall(concatSingle, text)
    if usable and type(plain) == "string" then
        return plain
    end
    return "<geschützt>"
end
Compat.SafeToString = safeToString

function Compat.IsSecretValue(value)
    return not pcall(compareToZero, value)
end

function Compat.IsSecretBoolean(value)
    return not pcall(branchOn, value)
end

-- "> 0" für Werte, die geschützt sein könnten; geschützt gilt als false.
function Compat.IsPositive(value)
    local ok, result = pcall(compareToZero, value)
    if not ok then
        return false
    end
    return result and true or false
end

-- Einmalige Prüfung anhand eines bekannten Zaubers. Geheimhaltung ist eine
-- Eigenschaft des Clients, nicht des einzelnen Wertes - deshalb reicht ein Test.
function Compat.DetectSecrets(spellID)
    if caps.secretsChecked or not spellID then
        return
    end
    caps.secretsChecked = true

    local _, duration = Compat.GetSpellCooldown(spellID)
    caps.secretCooldown = Compat.IsSecretValue(duration)

    caps.secretCharges = false
    if spellChargesNew then
        local info = spellChargesNew(spellID)
        if type(info) == "table" then
            caps.secretCharges = Compat.IsSecretValue(info.maxCharges)
        end
    end

    caps.secretUsable = false
    local usableGetter = spellUsableNew or spellUsableOld
    if usableGetter then
        local usable = usableGetter(spellID)
        caps.secretUsable = Compat.IsSecretBoolean(usable)
    end

    return caps.secretCooldown
end

-- ---------------------------------------------------------------- Zauberdaten

function Compat.GetSpellInfo(spellID)
    if not spellID then
        return nil
    end
    if spellInfoNew then
        local info = spellInfoNew(spellID)
        if type(info) == "table" then
            return info.name, info.iconID or info.originalIconID, info.spellID or spellID
        end
        return nil
    end
    if spellInfoOld then
        local name, _, icon = spellInfoOld(spellID)
        if name then
            return name, icon, spellID
        end
    end
    return nil
end

function Compat.GetSpellName(spellID)
    local name = Compat.GetSpellInfo(spellID)
    return name
end

function Compat.GetSpellIcon(spellID)
    local _, icon = Compat.GetSpellInfo(spellID)
    return icon
end

function Compat.GetSpellSubtext(spellID)
    if not spellID then
        return nil
    end
    if spellSubtextNew then
        return spellSubtextNew(spellID)
    end
    if spellSubtextOld then
        return spellSubtextOld(spellID)
    end
    return nil
end

-- Rückgabe immer: start, duration, enabled, modRate
function Compat.GetSpellCooldown(spellID)
    if not spellID then
        return 0, 0, false, 1
    end
    if spellCooldownNew then
        local info = spellCooldownNew(spellID)
        if type(info) == "table" then
            return info.startTime or 0, info.duration or 0, info.isEnabled ~= false, info.modRate or 1
        end
        return 0, 0, false, 1
    end
    if spellCooldownOld then
        local start, duration, enabled, modRate = spellCooldownOld(spellID)
        return start or 0, duration or 0, enabled == 1 or enabled == true, modRate or 1
    end
    return 0, 0, false, 1
end

-- Rückgabe: current, maximum, start, duration  (nil wenn ohne Aufladungen)
function Compat.GetSpellCharges(spellID)
    if not spellID or caps.secretCharges then
        return nil
    end
    if spellChargesNew then
        local info = spellChargesNew(spellID)
        if type(info) == "table" then
            -- Falls DetectSecrets noch nicht lief, hier nachziehen
            if caps.secretCharges == nil then
                caps.secretCharges = Compat.IsSecretValue(info.maxCharges)
            end
            if not caps.secretCharges and info.maxCharges and info.maxCharges > 1 then
                return info.currentCharges, info.maxCharges, info.cooldownStartTime, info.cooldownDuration
            end
        end
        return nil
    end
    if spellChargesOld then
        local current, maximum, start, duration = spellChargesOld(spellID)
        if maximum and maximum > 1 then
            return current, maximum, start, duration
        end
    end
    return nil
end

-- Rückgabe: usable, outOfPower - oder nil, wenn der Client die Werte
-- schützt und sie damit nicht auswertbar sind.
function Compat.IsSpellUsable(spellID)
    if not spellID or caps.secretUsable then
        return nil, nil
    end
    if spellUsableNew then
        local usable, noPower = spellUsableNew(spellID)
        return usable and true or false, noPower and true or false
    end
    if spellUsableOld then
        local usable, noPower = spellUsableOld(spellID)
        return usable and true or false, noPower and true or false
    end
    return true, false
end

function Compat.IsSpellKnown(spellID)
    if not spellID then
        return false
    end
    if spellKnownNew then
        local ok, known = pcall(spellKnownNew, spellID)
        if ok and known then
            return true
        end
    end
    if spellKnownOld and spellKnownOld(spellID) then
        return true
    end
    if playerSpellOld and playerSpellOld(spellID) then
        return true
    end
    return false
end

-- Grundabklingzeit in Sekunden (0 = keine). Wird für den Filter
-- "nur Fähigkeiten mit Abklingzeit" gebraucht, den eine laufende
-- Abfrage von GetSpellCooldown nicht beantworten kann.
function Compat.GetSpellBaseCooldown(spellID)
    if not spellID then
        return 0
    end
    local getter = baseCooldownNew or baseCooldownOld
    if not getter then
        return nil
    end
    local ok, milliseconds = pcall(getter, spellID)
    if ok and type(milliseconds) == "number" then
        return milliseconds / 1000
    end
    return nil
end

-- Rückgabe: cost, name, powerType  (für die Ressourcen-Anzeige auf dem Icon)
function Compat.GetSpellCost(spellID)
    if not spellID then
        return nil
    end
    local costs
    if spellCostNew then
        costs = spellCostNew(spellID)
    elseif spellCostOld then
        costs = spellCostOld(spellID)
    end
    if type(costs) ~= "table" then
        return nil
    end
    -- Die primäre Ressource ist der erste Eintrag mit echten Kosten.
    for _, entry in ipairs(costs) do
        if type(entry) == "table" and Compat.IsPositive(entry.cost) then
            return entry.cost, entry.name, entry.type
        end
    end
    return nil
end

-- --------------------------------------------------------------- Zauberbuch

-- callback(spellID, name, subName, icon, isPassive, known, index)
function Compat.IterateSpellbook(callback)
    if bookLinesNew and bookLineInfo and bookItemNew then
        local lines = bookLinesNew() or 0
        for line = 1, lines do
            local info = bookLineInfo(line)
            if type(info) == "table" and not info.isGuild then
                local offset = info.itemIndexOffset or 0
                local count = info.numSpellBookItems or 0
                for index = offset + 1, offset + count do
                    local item = bookItemNew(index, playerBank)
                    if type(item) == "table" and item.spellID then
                        local name, subName = item.name, item.subName
                        if not name and bookNameNew then
                            name, subName = bookNameNew(index, playerBank)
                        end
                        local known = true
                        if futureSpellType ~= nil and item.itemType == futureSpellType then
                            known = false
                        end
                        callback(item.spellID, name, subName, item.iconID, item.isPassive and true or false, known, index)
                    end
                end
            end
        end
        return true
    end

    if bookTabsOld and bookTabInfoOld and bookItemOld then
        local tabs = bookTabsOld() or 0
        for tab = 1, tabs do
            local _, _, offset, count = bookTabInfoOld(tab)
            offset = offset or 0
            count = count or 0
            for index = offset + 1, offset + count do
                local skillType, spellID = bookItemOld(index, "spell")
                if spellID and (skillType == "SPELL" or skillType == "FUTURESPELL") then
                    local name, subName
                    if bookNameOld then
                        name, subName = bookNameOld(index, "spell")
                    end
                    local isPassive = bookPassiveOld and bookPassiveOld(index, "spell") or false
                    callback(spellID, name, subName, nil, isPassive and true or false, skillType == "SPELL", index)
                end
            end
        end
        return true
    end

    return false
end

-- ----------------------------------------------------------------- Items

function Compat.GetItemCooldown(itemID)
    if not itemID then
        return 0, 0, false
    end
    if itemCooldownNew then
        local start, duration, enable = itemCooldownNew(itemID)
        return start or 0, duration or 0, safeBoolean(enable, true)
    end
    if itemCooldownOld then
        local start, duration, enable = itemCooldownOld(itemID)
        return start or 0, duration or 0, safeBoolean(enable, true)
    end
    return 0, 0, false
end

function Compat.GetItemInfo(itemID)
    if not itemID then
        return nil
    end
    local getter = itemInfoNew or itemInfoOld
    local name, icon
    if getter then
        local n, _, _, _, _, _, _, _, _, i = getter(itemID)
        name, icon = n, i
    end
    if not icon and itemIconNew then
        icon = itemIconNew(itemID)
    end
    return name, icon
end

function Compat.GetItemCount(itemID)
    if not itemID then
        return 0
    end
    local getter = itemCountNew or itemCountOld
    if not getter then
        return 0
    end
    return getter(itemID) or 0
end

function Compat.GetInventoryItemID(slot)
    if inventoryItemID then
        return inventoryItemID("player", slot)
    end
    return nil
end

function Compat.GetInventoryCooldown(slot)
    if inventoryCooldown then
        local start, duration, enable = inventoryCooldown("player", slot)
        return start or 0, duration or 0, safeBoolean(enable, true)
    end
    return 0, 0, false
end

-- ------------------------------------------------------------------ Auren

-- Rückgabe: duration, expirationTime, stacks
function Compat.GetPlayerAura(spellID)
    if not spellID then
        return nil
    end
    if auraBySpellNew then
        local aura = auraBySpellNew(spellID)
        if type(aura) == "table" then
            if caps.secretAura == nil then
                caps.secretAura = Compat.IsSecretValue(aura.duration)
            end
            if caps.secretAura then
                return nil
            end
            return aura.duration, aura.expirationTime, aura.applications or aura.charges or 0
        end
        return nil
    end
    if unitAuraOld then
        for filter = 1, 2 do
            local filterName = filter == 1 and "HELPFUL" or "HARMFUL"
            for index = 1, 40 do
                local name, _, stacks, _, duration, expiration, _, _, _, auraSpellID = unitAuraOld("player", index, filterName)
                if not name then
                    break
                end
                if auraSpellID == spellID then
                    return duration, expiration, stacks or 0
                end
            end
        end
    end
    return nil
end


-- ------------------------------------------------------ Blizzards Leuchten

-- Das goldene, pulsierende Leuchten, das Blizzard um eine Aktionsschaltfläche
-- legt, wenn ein Zauber verfügbar wird. Nachbauen hieße ihre Grafik, ihre
-- Animation und ihr Timing raten - abholen ist genauer und sieht überall so
-- aus, wie der Spieler es kennt.
--
-- Der Weg dorthin heißt in jedem Client anders: erst die globalen
-- ActionButton_-Funktionen, später ein Verwalter mit Methoden. Deshalb wird
-- beides gesucht statt eines davon angenommen.
local glowShow, glowHide

local function detectOverlayGlow()
    if caps.overlayGlow ~= nil then
        return caps.overlayGlow
    end

    local manager = _G.ActionButtonSpellAlertManager
    if type(manager) == "table"
        and method(manager, "ShowAlert") and method(manager, "HideAlert") then
        glowShow = function(button) manager:ShowAlert(button) end
        glowHide = function(button) manager:HideAlert(button) end
        caps.overlayGlow = "ActionButtonSpellAlertManager"
        return caps.overlayGlow
    end

    local show = globalFunction("ActionButton_ShowOverlayGlow")
    local hide = globalFunction("ActionButton_HideOverlayGlow")
    if show and hide then
        glowShow, glowHide = show, hide
        caps.overlayGlow = "ActionButton_ShowOverlayGlow"
        return caps.overlayGlow
    end

    caps.overlayGlow = false
    return false
end

Compat.DetectOverlayGlow = detectOverlayGlow

-- Rückgabe: true, wenn Blizzards Leuchten gesetzt wurde. Sonst false - dann
-- nimmt der Aufrufer seinen eigenen Ring.
--
-- Abgesichert, weil wir hier fremden Code auf unseren Rahmen loslassen:
-- scheitert er, soll das Symbol trotzdem stehen. Nach einem Fehlschlag wird
-- es gar nicht mehr versucht, sonst liefe derselbe Fehler bei jedem Symbol
-- und in jedem Durchlauf erneut.
function Compat.ShowOverlayGlow(button)
    if not detectOverlayGlow() or type(button) ~= "table" then
        return false
    end
    if not pcall(glowShow, button) then
        caps.overlayGlow = false
        return false
    end
    return true
end

function Compat.HideOverlayGlow(button)
    if not caps.overlayGlow or type(button) ~= "table" then
        return false
    end
    return pcall(glowHide, button) and true or false
end

-- -------------------------------------------------------- Abklingzeit-Manager

-- Kategorie-Listen lesbar (IDs pro Kategorie)
function Compat.HasCooldownViewer()
    return cvCategorySet ~= nil
end

-- Auflösung einer Abklingzeit-ID zu einem Zauber möglich
function Compat.HasCooldownInfo()
    return cvCacheInfo ~= nil
end

-- Listet auf, was ein Namespace tatsächlich enthält. Der einzige
-- zuverlässige Weg, die Funktionsnamen eines fremden Builds zu erfahren.
-- Rückgabe: sortierte Liste von { name, kind }
function Compat.DumpNamespace(namespace)
    local members = {}
    if type(namespace) ~= "table" then
        return members
    end
    for key, value in pairs(namespace) do
        members[#members + 1] = { name = tostring(key), kind = type(value) }
    end
    table.sort(members, function(a, b) return a.name < b.name end)
    return members
end

function Compat.GetCooldownViewerCategories()
    local categories = {}
    if type(Enum) == "table" and type(Enum.CooldownViewerCategory) == "table" then
        for name, value in pairs(Enum.CooldownViewerCategory) do
            if type(value) == "number" then
                categories[#categories + 1] = { name = name, value = value }
            end
        end
        table.sort(categories, function(a, b) return a.value < b.value end)
    end
    return categories
end

function Compat.GetCategorySet(category)
    if not cvCategorySet then
        return nil
    end
    local ok, result = pcall(cvCategorySet, category)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

function Compat.GetCooldownInfo(cooldownID)
    if not cvCacheInfo then
        return nil
    end
    local ok, result = pcall(cvCacheInfo, cooldownID)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

function Compat.CanWriteCategorySet()
    return cvSetCategory ~= nil
end

-- Mögliche Nutzlasten eines Blobs. Der Zeilentrenner vor der Base64-Nutzlast
-- ist nicht vorhersagbar, deshalb werden mehrere Zuschnitte durchprobiert
-- statt einer geratenen Trennung.
local function payloadCandidates(text)
    local candidates, seen = {}, {}
    local function add(label, value)
        if type(value) == "string" and #value > 0 and not seen[value] then
            seen[value] = true
            candidates[#candidates + 1] = { label = label, text = value }
        end
    end
    -- Der hintere zusammenhängende Base64-Block: jedes Präfix fällt weg,
    -- weil der Zeilentrenner den Lauf unterbricht.
    add("letzter Base64-Block", string.match(text, "([A-Za-z0-9+/=]+)%s*$"))
    add("ohne Versionszeile", string.match(text, "^%d+[%s%c]+(.+)$"))
    add("vollständig", text)
    add("ohne Leerraum", (string.gsub(text, "%s", "")))
    return candidates
end

local function compressionMethods()
    local methods = { { name = "ohne", value = nil } }
    if type(Enum) == "table" and type(Enum.CompressionMethod) == "table" then
        local named = {}
        for name, value in pairs(Enum.CompressionMethod) do
            named[#named + 1] = { name = safeToString(name), value = value }
        end
        table.sort(named, function(a, b) return a.name < b.name end)
        for _, entry in ipairs(named) do
            methods[#methods + 1] = entry
        end
    end
    return methods
end

-- Sucht die Kombination aus Zuschnitt, Kompressionsverfahren und
-- Serialisierung, die den Blob öffnet. Rückgabe: daten, fehlertext,
-- schritte, rezept
function Compat.DecodeLayoutString(text)
    local steps = {}
    if type(text) ~= "string" then
        return nil, "GetLayoutData lieferte keine Zeichenkette", steps
    end

    local decodeBase64 = method(C_EncodingUtil, "DecodeBase64")
    if not decodeBase64 then
        return nil, "C_EncodingUtil.DecodeBase64 fehlt in diesem Client", steps
    end
    local decompress = method(C_EncodingUtil, "DecompressString")
    local deserializers = {
        { name = "CBOR", fn = method(C_EncodingUtil, "DeserializeCBOR") },
        { name = "JSON", fn = method(C_EncodingUtil, "DeserializeJSON") },
    }

    steps[#steps + 1] = string.format("Blob: %d Zeichen", #text)

    for _, candidate in ipairs(payloadCandidates(text)) do
        local ok, binary = pcall(decodeBase64, candidate.text)
        if not ok or type(binary) ~= "string" then
            steps[#steps + 1] = string.format("%s (%d Zeichen): Base64 fehlgeschlagen",
                candidate.label, #candidate.text)
        else
            steps[#steps + 1] = string.format("%s (%d Zeichen) -> %d Bytes",
                candidate.label, #candidate.text, #binary)

            for _, compression in ipairs(compressionMethods()) do
                local payload = binary
                local usable = true
                if compression.value ~= nil then
                    if not decompress then
                        usable = false
                    else
                        local okDecompress, result = pcall(decompress, binary, compression.value)
                        if okDecompress and type(result) == "string" and #result > 0 then
                            payload = result
                        else
                            usable = false
                        end
                    end
                end

                if usable then
                    for _, deserializer in ipairs(deserializers) do
                        if deserializer.fn then
                            local okDeserialize, value = pcall(deserializer.fn, payload)
                            if okDeserialize and type(value) == "table" then
                                local recipe = string.format("%s + %s + %s",
                                    candidate.label, compression.name, deserializer.name)
                                steps[#steps + 1] = "Erfolg: " .. recipe
                                return value, nil, steps, {
                                    candidate = candidate.label,
                                    compression = compression.value,
                                    compressionName = compression.name,
                                    deserializer = deserializer.name,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    return nil, "Keine Kombination aus Zuschnitt, Kompression und Serialisierung passte", steps
end

-- Sucht in den entschlüsselten Daten die Zuordnung Kategorie -> ID-Liste.
-- Der Pfad dorthin enthält einen profilabhängigen Schlüssel, deshalb wird
-- nach der Form gesucht statt ihn fest zu verdrahten: ganzzahlige Schlüssel
-- im Kategoriebereich, deren Werte reine Zahlenlisten sind.
-- Rückgabe: tabelle, pfad
function Compat.FindLayoutCategories(root)
    local found, foundPath

    local function looksLikeCategoryMap(value)
        local count = 0
        for key, list in pairs(value) do
            if type(key) ~= "number" or key ~= math.floor(key) or key < -4 or key > 20 then
                return false
            end
            if type(list) ~= "table" then
                return false
            end
            for _, id in ipairs(list) do
                if type(id) ~= "number" then
                    return false
                end
            end
            count = count + 1
        end
        return count > 0
    end

    local function walk(value, path, depth)
        if found or type(value) ~= "table" or depth > 10 then
            return
        end
        if looksLikeCategoryMap(value) then
            found, foundPath = value, path
            return
        end
        for key, child in pairs(value) do
            walk(child, path .. "[" .. safeToString(key) .. "]", depth + 1)
        end
    end

    walk(root, "layout", 1)
    return found, foundPath
end

-- Tiefenvergleich zweier entschlüsselter Bäume.
-- Rückgabe: gleich, beschreibung der ersten Abweichung
function Compat.DeepEqual(a, b, path)
    path = path or "layout"
    if type(a) ~= type(b) then
        return false, string.format("%s: %s statt %s", path, type(b), type(a))
    end
    if type(a) ~= "table" then
        if a ~= b then
            return false, string.format("%s: %s statt %s", path, safeToString(b), safeToString(a))
        end
        return true
    end
    for key, value in pairs(a) do
        local ok, difference = Compat.DeepEqual(value, b[key], path .. "[" .. safeToString(key) .. "]")
        if not ok then
            return false, difference
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false, path .. "[" .. safeToString(key) .. "]: nur im neuen Blob vorhanden"
        end
    end
    return true
end

-- Liefert die beiden Teile, auf die es ankommt: die Kategorie-Zuordnung und
-- daneben die Reihenfolgeliste. Beide hängen unter demselben Elternknoten,
-- dessen Pfad profilabhängig ist - deshalb wird gesucht, nicht verdrahtet.
-- Rückgabe: { categories, order, parent, path }
function Compat.FindLayoutSections(root)
    local categories, categoryPath = Compat.FindLayoutCategories(root)
    if not categories then
        return nil
    end

    local parent
    local function findParent(value, depth)
        if parent or type(value) ~= "table" or depth > 10 then
            return
        end
        for _, child in pairs(value) do
            if child == categories then
                parent = value
                return
            end
        end
        for _, child in pairs(value) do
            findParent(child, depth + 1)
        end
    end
    findParent(root, 1)

    local order
    if parent then
        for _, child in pairs(parent) do
            if child ~= categories and type(child) == "table" and #child > 0 then
                local numbersOnly = true
                for _, value in ipairs(child) do
                    if type(value) ~= "number" then
                        numbersOnly = false
                        break
                    end
                end
                if numbersOnly then
                    order = child
                end
            end
        end
    end

    return { categories = categories, order = order, parent = parent, path = categoryPath }
end

-- Zerlegt den Blob in unveränderliches Präfix und Base64-Nutzlast.
-- Das Präfix ("1|") wird später wortwörtlich wiederverwendet, statt seine
-- Bedeutung zu raten.
function Compat.SplitLayoutString(text)
    if type(text) ~= "string" then
        return nil, nil
    end
    local trimmed = string.gsub(text, "%s+$", "")
    local payload = string.match(trimmed, "([A-Za-z0-9+/=]+)$")
    if not payload then
        return "", trimmed
    end
    return string.sub(trimmed, 1, #trimmed - #payload), payload
end

-- Baut aus Daten und Rezept wieder einen Blob. Rückgabe: text, fehlertext
function Compat.EncodeLayoutString(prefix, data, recipe)
    local serialize = method(C_EncodingUtil, "Serialize" .. tostring(recipe and recipe.deserializer or "CBOR"))
    local compress = method(C_EncodingUtil, "CompressString")
    local encodeBase64 = method(C_EncodingUtil, "EncodeBase64")
    if not serialize or not encodeBase64 then
        return nil, "Serialisierung oder Base64 fehlt"
    end

    local ok, payload = pcall(serialize, data)
    if not ok or type(payload) ~= "string" then
        return nil, "Serialisieren fehlgeschlagen: " .. safeToString(payload)
    end

    if recipe and recipe.compression ~= nil then
        if not compress then
            return nil, "CompressString fehlt"
        end
        local okCompress, compressed = pcall(compress, payload, recipe.compression)
        if not okCompress or type(compressed) ~= "string" then
            return nil, "Komprimieren fehlgeschlagen: " .. safeToString(compressed)
        end
        payload = compressed
    end

    local okEncode, encoded = pcall(encodeBase64, payload)
    if not okEncode or type(encoded) ~= "string" then
        return nil, "Base64 fehlgeschlagen: " .. safeToString(encoded)
    end

    return (prefix or "") .. encoded
end

-- Erzeugt mit Blizzards eigenen Funktionen einen Blob aus bekannten Daten.
-- Sieht das Ergebnis aus wie die Layout-Daten, ist die Pipeline gefunden.
-- Rückgabe: liste von zeilen
function Compat.EncodingSelfTest()
    local lines = {}
    local serializeCBOR = method(C_EncodingUtil, "SerializeCBOR")
    local compress = method(C_EncodingUtil, "CompressString")
    local encodeBase64 = method(C_EncodingUtil, "EncodeBase64")
    if not (serializeCBOR and encodeBase64) then
        lines[#lines + 1] = "SerializeCBOR oder EncodeBase64 fehlt - Selbsttest nicht möglich."
        return lines
    end

    local sample = { version = 1, categories = { [0] = { 199700 }, [2] = { 199688 } } }
    local okSerialize, cbor = pcall(serializeCBOR, sample)
    if not okSerialize or type(cbor) ~= "string" then
        lines[#lines + 1] = "SerializeCBOR fehlgeschlagen: " .. safeToString(cbor)
        return lines
    end
    lines[#lines + 1] = string.format("CBOR: %d Bytes", #cbor)

    for _, compression in ipairs(compressionMethods()) do
        local payload, label = cbor, compression.name
        if compression.value ~= nil then
            if not compress then
                payload = nil
            else
                local okCompress, result = pcall(compress, cbor, compression.value)
                payload = (okCompress and type(result) == "string") and result or nil
            end
        end
        if payload then
            local okEncode, encoded = pcall(encodeBase64, payload)
            if okEncode and type(encoded) == "string" then
                lines[#lines + 1] = string.format("  %-12s -> %d Bytes -> Base64 %d Zeichen, Anfang: %s",
                    label, #payload, #encoded, string.sub(encoded, 1, 32))
            else
                lines[#lines + 1] = string.format("  %-12s -> Base64 fehlgeschlagen", label)
            end
        else
            lines[#lines + 1] = string.format("  %-12s -> Komprimieren fehlgeschlagen", label)
        end
    end

    return lines
end

local cvGroupBuffItems = method(C_CooldownViewer, "GetGroupBuffItems")

-- Rückgabe: daten, fehlertext
function Compat.GetGroupBuffItems(...)
    if not cvGroupBuffItems then
        return nil, "GetGroupBuffItems fehlt in diesem Client"
    end
    local ok, result = pcall(cvGroupBuffItems, ...)
    if not ok then
        return nil, safeToString(result)
    end
    return result
end

function Compat.HasLayoutData()
    return cvGetLayout ~= nil
end

function Compat.CanWriteLayoutData()
    return cvSetLayout ~= nil
end

-- Rückgabe: daten, fehlertext
function Compat.GetLayoutData(...)
    if not cvGetLayout then
        return nil, "GetLayoutData fehlt in diesem Client"
    end
    local ok, result = pcall(cvGetLayout, ...)
    if not ok then
        return nil, safeToString(result)
    end
    return result
end

-- Rückgabe: erfolg, fehlertext. Schreibt nur, was der Aufrufer übergibt -
-- geschützte Funktionen quittieren das mit einem Fehler statt zu wirken.
function Compat.SetLayoutData(...)
    if not cvSetLayout then
        return false, "SetLayoutData fehlt in diesem Client"
    end
    local ok, err = pcall(cvSetLayout, ...)
    if not ok then
        return false, safeToString(err)
    end
    return true
end

-- CreateFrame wirft bei unbekannter Vorlage einen Fehler, statt sie zu
-- ignorieren. Damit eine fehlende Blizzard-Vorlage nicht das ganze AddOn
-- abschießt, ist sie hier optional.
-- Rückgabe: frame, vorlageGenutzt
function Compat.CreateFrame(frameType, name, parent, template)
    if template then
        local ok, frame = pcall(CreateFrame, frameType, name, parent, template)
        if ok and frame then
            return frame, true
        end
    end
    return CreateFrame(frameType, name, parent), false
end

-- ------------------------------------------------------------ Spielerzustand

-- Was der Client selbst über ein AddOn weiß. Ist hier etwas leer, hat er die
-- .toc anders gelesen als wir sie geschrieben haben.
function Compat.GetAddOnMetadata(name, key)
    if not addOnMetadata then
        return nil, "GetAddOnMetadata fehlt"
    end
    local ok, value = pcall(addOnMetadata, name, key)
    if not ok then
        return nil, safeToString(value)
    end
    return value
end

local addOnInfo = method(C_AddOns, "GetAddOnInfo") or globalFunction("GetAddOnInfo")
local numAddOns = method(C_AddOns, "GetNumAddOns") or globalFunction("GetNumAddOns")

-- Rückgabe: name, titel, laedtNicht, grund
function Compat.GetAddOnInfo(name)
    if not addOnInfo then
        return nil, nil, nil, "GetAddOnInfo fehlt"
    end
    local ok, a, b, _, loadable, reason = pcall(addOnInfo, name)
    if not ok then
        return nil, nil, nil, safeToString(a)
    end
    return a, b, loadable, reason
end

function Compat.GetNumAddOns()
    if not numAddOns then
        return 0
    end
    local ok, count = pcall(numAddOns)
    return ok and count or 0
end

function Compat.GetFormID()
    if shapeshiftFormID then
        return shapeshiftFormID() or 0
    end
    if shapeshiftForm then
        return shapeshiftForm() or 0
    end
    return 0
end

function Compat.GetFormIndex()
    if shapeshiftForm then
        return shapeshiftForm() or 0
    end
    return 0
end

function Compat.GetNumForms()
    if numShapeshifts then
        return numShapeshifts() or 0
    end
    return 0
end

-- Die in der .toc deklarierte Interface-Nummer; weicht sie von der des
-- Clients ab, versteckt der Client das AddOn ohne "Veraltete AddOns laden".
function Compat.GetDeclaredInterface()
    if not addOnMetadata then
        return nil
    end
    local ok, value = pcall(addOnMetadata, FCD.name, "Interface")
    if ok then
        return tonumber(value)
    end
    return nil
end

function Compat.GetSpecIndex()
    local getter = specializationNew or specializationOld
    if not getter then
        return nil
    end
    local ok, index = pcall(getter)
    if ok and type(index) == "number" then
        return index
    end
    return nil
end

-- ------------------------------------------------------------- Erkennung

local function record(key, value)
    caps[key] = value or false
end

function Compat.Detect()
    record("spellInfo", spellInfoNew and "C_Spell.GetSpellInfo" or (spellInfoOld and "GetSpellInfo"))
    record("spellSubtext", spellSubtextNew and "C_Spell.GetSpellSubtext" or (spellSubtextOld and "GetSpellSubtext"))
    record("spellCooldown", spellCooldownNew and "C_Spell.GetSpellCooldown" or (spellCooldownOld and "GetSpellCooldown"))
    record("spellCharges", spellChargesNew and "C_Spell.GetSpellCharges" or (spellChargesOld and "GetSpellCharges"))
    record("spellUsable", spellUsableNew and "C_Spell.IsSpellUsable" or (spellUsableOld and "IsUsableSpell"))
    record("spellCost", spellCostNew and "C_Spell.GetSpellPowerCost" or (spellCostOld and "GetSpellPowerCost"))
    record("spellBaseCooldown", baseCooldownNew and "C_Spell.GetSpellBaseCooldown" or (baseCooldownOld and "GetSpellBaseCooldown"))
    record("spellKnown", spellKnownNew and "C_SpellBook.IsSpellKnown" or (spellKnownOld and "IsSpellKnown") or (playerSpellOld and "IsPlayerSpell"))
    record("spellbook", (bookLinesNew and bookItemNew) and "C_SpellBook.*" or (bookTabsOld and bookItemOld and "GetSpellBookItemInfo"))
    record("spellbookBank", tostring(playerBank))
    record("itemCooldown", itemCooldownNew and "C_Item.GetItemCooldown" or (itemCooldownOld and "GetItemCooldown"))
    record("itemInfo", itemInfoNew and "C_Item.GetItemInfo" or (itemInfoOld and "GetItemInfo"))
    record("inventoryCooldown", inventoryCooldown and "GetInventoryItemCooldown")
    record("aura", auraBySpellNew and "C_UnitAuras.GetPlayerAuraBySpellID" or (unitAuraOld and "UnitAura"))
    record("cooldownViewerRead", cvCategorySet and "C_CooldownViewer.GetCooldownViewerCategorySet")
    record("cooldownViewerInfo", cvCacheInfoName and ("C_CooldownViewer." .. cvCacheInfoName))
    record("cooldownViewerWrite", cvSetCategory and "C_CooldownViewer.SetCooldownViewerCategorySet")
    record("layoutRead", cvGetLayout and "C_CooldownViewer.GetLayoutData")
    record("layoutWrite", cvSetLayout and "C_CooldownViewer.SetLayoutData")
    record("addOnMetadata", addOnMetadata and "GetAddOnMetadata")
    -- Der einzige Weg, ihre Leisteneinstellungen zu setzen; zwei andere
    -- liefen wirkungslos ins Leere, ohne einen Fehler zu melden.
    record("editModeSettings", method(_G.EditModeManagerFrame, "OnSystemSettingChange")
        and "EditModeManagerFrame:OnSystemSettingChange")
    record("overlayGlow", detectOverlayGlow() or nil)
    record("cooldownViewerEnum", (#Compat.GetCooldownViewerCategories() > 0) and "Enum.CooldownViewerCategory")
    record("shapeshift", shapeshiftFormID and "GetShapeshiftFormID" or (shapeshiftForm and "GetShapeshiftForm"))
    record("specialization", specializationNew and "C_SpecializationInfo.GetSpecialization" or (specializationOld and "GetSpecialization"))
    if cvIsEnabled then
        local ok, available = pcall(cvIsEnabled)
        record("cooldownViewerAvailable", ok and tostring(available))
    else
        record("cooldownViewerAvailable", false)
    end
    return caps
end
