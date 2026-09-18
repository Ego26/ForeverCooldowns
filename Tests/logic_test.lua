local ADDON = "../"

-- Minimal-Stubs für das, was die reine Logik berührt
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
GetBuildInfo = function() return "1.60.1", "69913", "Sep 17 2026", 16001 end
UnitClass = function() return "Krieger", "WARRIOR" end
UnitName = function() return "Testkrieger" end
UnitLevel = function() return 42 end
InCombatLockdown = function() return false end

local passed, failed = 0, 0
local function check(label, condition, detail)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("FEHLT: " .. label .. (detail and ("  -> " .. tostring(detail)) or ""))
    end
end

dofile(ADDON .. "Compat.lua")
dofile(ADDON .. "Profiles.lua")
dofile(ADDON .. "Ranks.lua")

local FCD = ForeverCooldowns
local Profiles = FCD.Profiles

-- ---------------------------------------------------------------- Rangparser
local Ranks = FCD.Ranks
check("Rang 4", Ranks:ParseRank("Rang 4") == 4)
check("Rank 10", Ranks:ParseRank("Rank 10") == 10)
check("Rang 1", Ranks:ParseRank("Rang 1") == 1)
check("Talentname ist kein Rang", Ranks:ParseRank("Feuer") == nil, Ranks:ParseRank("Feuer"))
check("Passiv ist kein Rang", Ranks:ParseRank("Passiv") == nil)
check("leer", Ranks:ParseRank("") == nil)
check("nil", Ranks:ParseRank(nil) == nil)
check("zwei Zahlen sind kein Rang", Ranks:ParseRank("Rang 3 von 7") == nil, Ranks:ParseRank("Rang 3 von 7"))

-- ------------------------------------------------------------ Profil-Grundlage
Profiles:Initialize()
check("Profil angelegt", Profiles:GetActive() ~= nil)
check("zwei Leisten", #Profiles:GetActive().bars == 2, #Profiles:GetActive().bars)

local profile = Profiles:GetActive()
local bar = profile.bars[1]
bar.entries[1] = { kind = "spell", id = 1234, familyKey = "heldenhafter stoß", rankMode = "best" }
bar.entries[2] = { kind = "spell", id = 5678, familyKey = "schlachtruf", rankMode = "fixed", fixedRank = 3 }
bar.entries[3] = { kind = "inventory", id = 13, rankMode = "best" }
local BACKSLASH = string.char(92)
bar.name = [[Leiste "A" ]] .. BACKSLASH .. [[ Test]]

-- ------------------------------------------------------------ Export/Import
local exported = Profiles:Export()
check("Export hat Präfix", exported:sub(1, 5) == "FCD1:", exported:sub(1, 12))

local importedName, err = Profiles:Import(exported, "Kopie")
check("Import erfolgreich", importedName ~= nil, err)
local copy = ForeverCooldownsDB.profiles[importedName]
check("Leistenzahl erhalten", copy and #copy.bars == 2)
check("Einträge erhalten", copy and #copy.bars[1].entries == 3, copy and #copy.bars[1].entries)
check("fester Rang erhalten", copy and copy.bars[1].entries[2].fixedRank == 3)
check("familyKey erhalten", copy and copy.bars[1].entries[1].familyKey == "heldenhafter stoß")
check("Sonderzeichen im Namen erhalten", copy and copy.bars[1].name == ([[Leiste "A" ]] .. BACKSLASH .. [[ Test]]), copy and copy.bars[1].name)
check("Item-Eintrag erhalten", copy and copy.bars[1].entries[3].kind == "inventory")

-- Zweiter Import darf den Namen nicht doppelt vergeben
local secondName = Profiles:Import(exported, "Kopie")
check("zweiter Import bekommt eigenen Namen", secondName ~= importedName, secondName)

-- ------------------------------------------------------------ Fehlerfälle
local bad, badErr = Profiles:Import("irgendwas ohne Präfix")
check("Fremdtext abgelehnt", bad == nil and badErr ~= nil)

local broken, brokenErr = Profiles:Import("FCD1:{[\"bars\"]={")
check("kaputter String abgelehnt", broken == nil and brokenErr ~= nil, brokenErr)

-- Der wichtigste Fall: ein Importstring darf keinen Code ausführen
_G.WURDE_AUSGEFUEHRT = false
local evil = Profiles:Import('FCD1:{["bars"]=(function() WURDE_AUSGEFUEHRT = true end)()}')
check("kein Codeaufruf beim Import", _G.WURDE_AUSGEFUEHRT == false)
check("Codeversuch abgelehnt", evil == nil, evil)

-- ------------------------------------------------------------ Rückgängig
local before = #Profiles:GetActive().bars[1].entries
Profiles:PushUndo("Test")
table.remove(Profiles:GetActive().bars[1].entries, 1)
check("Eintrag entfernt", #Profiles:GetActive().bars[1].entries == before - 1)
local label = Profiles:Undo()
check("Undo meldet Label", label == "Test", label)
check("Einträge wiederhergestellt", #Profiles:GetActive().bars[1].entries == before,
    #Profiles:GetActive().bars[1].entries)
check("Undo-Stapel leer", Profiles:UndoDepth() == 0)

-- ------------------------------------------------------------ Rangauflösung
Ranks.families["schlachtruf"] = {
    key = "schlachtruf", name = "Schlachtruf", ranks = {}, byRank = {}, knownCount = 0,
}
local family = Ranks.families["schlachtruf"]
local function addRank(spellID, rank, known)
    local entry = { spellID = spellID, rank = rank, known = known }
    family.ranks[#family.ranks + 1] = entry
    family.byRank[spellID] = entry
    Ranks.spellIndex[spellID] = "schlachtruf"
    if known then family.knownCount = family.knownCount + 1; family.bestSpellID = spellID; family.bestRank = rank end
end
addRank(6673, 1, true)
addRank(5242, 2, true)
addRank(6192, 3, false)

local spellID, rank = Ranks:Resolve({ kind = "spell", familyKey = "schlachtruf", rankMode = "best" })
check("bester Rang ist der höchste gelernte", rank == 2 and spellID == 5242, tostring(rank))

spellID, rank = Ranks:Resolve({ kind = "spell", familyKey = "schlachtruf", rankMode = "fixed", fixedRank = 1 })
check("fester Rang 1 wird genommen", rank == 1 and spellID == 6673, tostring(rank))

spellID, rank = Ranks:Resolve({ kind = "spell", familyKey = "schlachtruf", rankMode = "fixed", fixedRank = 3 })
check("ungelernter fester Rang fällt auf Rang 2 zurück", rank == 2, tostring(rank))


-- ------------------------------------------------------------ Katalogfilter
dofile(ADDON .. "Items.lua")
dofile(ADDON .. "Catalog.lua")
local Catalog = FCD.Catalog
Catalog.entries = {
    { kind = "spell", key = "spell:schlachtruf", familyKey = "schlachtruf", name = "Schlachtruf",
      known = true, hasCooldown = false, isPassive = false, inViewer = true, rankCount = 3, bestSpellID = 5242 },
    { kind = "spell", key = "spell:rekrutierung", familyKey = "rekrutierung", name = "Rekrutierung",
      known = false, hasCooldown = true, isPassive = false, inViewer = false, rankCount = 1, bestSpellID = 99 },
    { kind = "spell", key = "spell:zaehigkeit", familyKey = "zaehigkeit", name = "Zähigkeit",
      known = true, hasCooldown = false, isPassive = true, inViewer = false, rankCount = 1, bestSpellID = 77 },
    { kind = "spell", key = "spell:todeswunsch", familyKey = "todeswunsch", name = "Todeswunsch",
      known = true, hasCooldown = true, isPassive = false, inViewer = false, rankCount = 1, bestSpellID = 12292 },
    { kind = "item", key = "item:13444", id = 13444, name = "Machtiger Zaubertrank",
      known = true, hasCooldown = true, inViewer = false, rankCount = 0 },
}

local function keys(list)
    local out = {}
    for _, e in ipairs(list) do out[#out + 1] = e.key end
    table.sort(out)
    return table.concat(out, ",")
end

check("Standardfilter zeigt Gelerntes ohne Passive",
    keys(Catalog:Filter({ onlyKnown = true })) == "item:13444,spell:schlachtruf,spell:todeswunsch",
    keys(Catalog:Filter({ onlyKnown = true })))
check("Passive einblendbar",
    keys(Catalog:Filter({ onlyKnown = true, showPassive = true })):find("zaehigkeit") ~= nil)
check("nur mit Abklingzeit",
    keys(Catalog:Filter({ onlyKnown = true, onlyWithCooldown = true })) == "item:13444,spell:todeswunsch",
    keys(Catalog:Filter({ onlyKnown = true, onlyWithCooldown = true })))
check("nur im Manager fehlende",
    keys(Catalog:Filter({ onlyKnown = true, onlyMissingFromViewer = true })) == "item:13444,spell:todeswunsch")
check("Items ausblenden",
    keys(Catalog:Filter({ onlyKnown = true, showItems = false })) == "spell:schlachtruf,spell:todeswunsch")
check("Zauber ausblenden",
    keys(Catalog:Filter({ onlyKnown = true, showSpells = false })) == "item:13444")
check("Suche nach Name",
    keys(Catalog:Filter({ text = "todes" })) == "spell:todeswunsch",
    keys(Catalog:Filter({ text = "todes" })))
check("Suche nach Zauber-ID",
    keys(Catalog:Filter({ text = "12292" })) == "spell:todeswunsch")
check("Ungelerntes erscheint ohne onlyKnown",
    keys(Catalog:Filter({})):find("rekrutierung") ~= nil)
check("KeyForEntry für Zauber",
    Catalog:KeyForEntry({ kind = "spell", familyKey = "schlachtruf" }) == "spell:schlachtruf")
check("KeyForEntry für Item",
    Catalog:KeyForEntry({ kind = "inventory", id = 13 }) == "inventory:13")


-- ------------------------------------------------------------- DeepEqual
local Compat = FCD.Compat
check("gleiche Skalare", Compat.DeepEqual(5, 5))
check("verschiedene Skalare", not Compat.DeepEqual(5, 6))
check("gleiche flache Tabellen", Compat.DeepEqual({1,2,3}, {1,2,3}))
check("abweichender Wert erkannt", not Compat.DeepEqual({1,2,3}, {1,9,3}))
check("Schlüsselreihenfolge egal", Compat.DeepEqual({a=1,b=2}, {b=2,a=1}))
check("verschachtelt gleich", Compat.DeepEqual({x={y={1,2}}}, {x={y={1,2}}}))
check("verschachtelt verschieden", not Compat.DeepEqual({x={y={1,2}}}, {x={y={1,3}}}))
check("zusätzlicher Schlüssel rechts", not Compat.DeepEqual({a=1}, {a=1,b=2}))
check("fehlender Schlüssel rechts", not Compat.DeepEqual({a=1,b=2}, {a=1}))
check("negative und 0-Schlüssel", Compat.DeepEqual({[-1]={7},[0]={8}}, {[0]={8},[-1]={7}}))
local _, diffText = Compat.DeepEqual({a={b=1}}, {a={b=2}})
check("Pfad in der Meldung", diffText and diffText:find("[ab]") ~= nil, diffText)

-- Layout-Operationen auf einem nachgebauten Zustand
dofile(ADDON .. "Layout.lua")
local Layout = FCD.Layout
local state = { categories = { [-1] = { 199700, 199702 }, [2] = { 199688 } },
                order = { 199700, 199701, 199702, 199688 } }
check("IsHidden erkennt Ausgeblendetes", Layout:IsHidden(state, 199700))
check("IsHidden bei Sichtbarem falsch", not Layout:IsHidden(state, 199701))
check("zugewiesene Kategorie", Layout:GetAssignedCategory(state, 199688) == 2)

check("Einblenden entfernt aus -1", Layout:SetHidden(state, 199700, false))
check("nicht mehr ausgeblendet", not Layout:IsHidden(state, 199700))
check("Eingeblendetes wandert ans Ende", state.order[#state.order] == 199700, state.order[#state.order])
check("Reihenfolge behält Länge", #state.order == 4, #state.order)

check("Ausblenden fügt wieder hinzu", Layout:SetHidden(state, 199701, true))
check("jetzt ausgeblendet", Layout:IsHidden(state, 199701))
check("doppeltes Ausblenden meldet false", not Layout:SetHidden(state, 199701, true))

Layout:SetHidden(state, 199702, false)
Layout:SetHidden(state, 199701, false)
check("leere -1-Liste wird entfernt", state.categories[-1] == nil)

Layout:SetCategory(state, 199688, 0)
check("Kategorie gewechselt", Layout:GetAssignedCategory(state, 199688) == 0)
check("alte Kategorie geleert", state.categories[2] == nil)
check("MoveTo setzt Position", Layout:MoveTo(state, 199688, 1) and state.order[1] == 199688, state.order[1])


-- SafeToString muss auch bei gewöhnlichen Werten sauber bleiben
check("SafeToString Zahl", Compat.SafeToString(42) == "42")
check("SafeToString Zeichenkette", Compat.SafeToString("abc") == "abc")
check("SafeToString nil", Compat.SafeToString(nil) == "nil")
check("SafeToString bool", Compat.SafeToString(true) == "true")
check("SafeToString Ergebnis verkettbar", (Compat.SafeToString(7) .. "x") == "7x")

-- ------------------------------------------------- Fertig-Meldung auflösen
-- Der Eintrag schlägt die Leiste, aber nur wo er etwas sagt. Entscheidend
-- ist der Unterschied zwischen nil ("nichts gesagt") und false ("aus").
local alertBar = { alertReady = true, alertMode = "both", alertSoundID = 11 }

local on, mode, sound = Profiles:ResolveAlert(alertBar, nil)
check("Leiste allein: an", on == true)
check("Leiste allein: Art", mode == "both", mode)
check("Leiste allein: Ton", sound == 11, sound)

on = Profiles:ResolveAlert(alertBar, {})
check("Eintrag ohne Angabe erbt an", on == true)

on = Profiles:ResolveAlert(alertBar, { alertReady = false })
check("Eintrag false schlaegt Leiste an", on == false)

on = Profiles:ResolveAlert({ alertReady = false }, { alertReady = true })
check("Eintrag true schlaegt Leiste aus", on == true)

on, mode = Profiles:ResolveAlert({ alertReady = false }, { alertReady = true, alertMode = "glow" })
check("Eintrag bringt eigene Art mit", on == true and mode == "glow", mode)

on, mode, sound = Profiles:ResolveAlert(alertBar, { alertSoundID = 22 })
check("Eintrag nur mit eigenem Ton", on == true and mode == "both" and sound == 22, sound)

on, mode, sound = Profiles:ResolveAlert(alertBar, { alertReady = false, alertSoundID = 22 })
check("Aus behaelt den Ton, meldet aber nicht", on == false and sound == 22)

on, mode = Profiles:ResolveAlert({}, nil)
check("Leere Leiste meldet nichts", on == false and mode == "both")

on = Profiles:ResolveAlert(nil, nil)
check("Ohne Leiste meldet nichts", on == false)


print(string.format("\n%d Prüfungen bestanden, %d fehlgeschlagen.", passed, failed))
if failed > 0 then os.exit(1) end
