local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local Dock = {}
FCD.Dock = Dock

-- Dieses Panel bearbeitet Blizzards eigene Kategorien.
--
-- Es gibt zwei Schreibwege, beide gemessen:
--   * Sofortmodus (Standard): über Blizzards Datenmodell. Wirkt ohne
--     Neuladen, markiert ihre Objekte aber als tainted - ihr Aurenzugriff
--     scheitert dann bis zum nächsten /reload.
--   * Sicherer Modus (/fcd instant off): über die C-Funktion SetLayoutData.
--     Taintet nichts, wirkt aber erst beim Neuladen, weil der Client das
--     Layout nur dann liest.
--
-- Der wirksame Zustand einer Abklingzeit ist: die Zuweisung aus dem Layout,
-- und wo keine steht, die statische Einordnung aus GetCooldownViewerCategorySet.

-- Schmal und breit sind dieselbe Ansicht mit anderen Maßen, nicht zwei
-- Fenster mit eigenen Daten. Genau daran ist die vorige Fassung gescheitert:
-- das große Fenster hatte eine eigene Quelle und zeigte deshalb etwas anderes.
local NARROW_WIDTH, WIDE_WIDTH = 380, 900
local NARROW_COLUMNS, WIDE_COLUMNS = 8, 15
local NARROW_HEIGHT, WIDE_HEIGHT = 620, 700

-- In der breiten Ansicht bleibt rechts eine Spalte für die Werkzeuge frei,
-- die in der schmalen keinen Platz hätten.
local SIDEBAR_WIDTH = 208

-- Eigene Grafik im AddOn-Ordner: rundet quadratische Symbole ab, indem sie
-- deren Ecken in der Farbe des Untergrunds abdeckt. Mitgeliefert, also immer
-- vorhanden - und fehlt sie doch, bleiben die Ecken einfach eckig.
local ROUND_CORNERS = "Interface\\AddOns\\ForeverCooldowns\\Media\\RoundCorners.tga"

local PAD = 10
local TILE_SIZE = 36
local TILE_SPACING = 5
-- Reiterschiene rechts. Groß genug, dass Blizzards Sinnbilder in ihrer
-- eigenen Größe hineinpassen und nicht umgerechnet werden müssen.
local TAB_WIDTH, TAB_HEIGHT, TAB_TOP = 46, 48, 74
local HEADER_HEIGHT = 22
local EMPTY_HEIGHT = 28
local POLL_INTERVAL = 0.2
local DEFAULT_GAP = 58
local HIDDEN_CATEGORY = -1

local panel, ghost
local state = {
    collapsed = {},
    selection = {},
    lastKey = nil,
    tab = "spells",
    stackRanks = true,
    onlyKnown = false,
    onlyWithCooldown = false,
    showPassive = false,
    search = "",
}
Dock.state = state

local function settings()
    return FCD.db and FCD.db.settings or {}
end

local function panelWidth()
    return state.wide and WIDE_WIDTH or NARROW_WIDTH
end

local function panelHeight()
    return state.wide and WIDE_HEIGHT or NARROW_HEIGHT
end

local function contentWidth()
    local width = panelWidth() - 2 * PAD - 24
    if state.wide then
        width = width - SIDEBAR_WIDTH
    end
    return width
end

-- Die Spaltenzahl wird gerechnet, nicht gesetzt: übernehmen wir Blizzards
-- Kachelmaß, ändert sich die Kachelbreite, und eine feste Zahl würde rechts
-- überstehen. Die alten Werte bleiben als Obergrenze.
local function columnCount()
    local step = TILE_SIZE + TILE_SPACING
    local columns = math.floor((contentWidth() + TILE_SPACING) / step)
    local cap = state.wide and WIDE_COLUMNS or NARROW_COLUMNS
    if columns > cap then
        columns = cap
    end
    if columns < 1 then
        columns = 1
    end
    return columns
end

-- ------------------------------------------------------ Blizzards Fenster

local function blizzardWindow()
    local frame = _G.CooldownViewerSettings
    if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then
        return nil
    end
    return frame
end

local function windowIsShown(frame)
    local ok, shown = pcall(frame.IsShown, frame)
    return ok and shown and true or false
end

-- Die Lage von Blizzards Fenster. Ein ausgeblendetes Fenster behält seinen
-- Anker, also ist das die echte Position und nicht geschätzt.
local function blizzardWindowPoint()
    local window = _G.CooldownViewerSettings
    if type(window) ~= "table" or type(window.GetPoint) ~= "function" then
        return nil
    end
    -- Über die Bildschirmlage statt über ihren Anker: ihr Anker ist auf ihre
    -- Fenstergröße gerechnet, und unseres ist höher. Übernähme man ihn roh,
    -- hinge unser Fenster oben über den Rand.
    local left = window.GetLeft and window:GetLeft()
    local top = window.GetTop and window:GetTop()
    if type(left) == "number" and type(top) == "number" then
        return {
            point = "TOPLEFT",
            relativePoint = "BOTTOMLEFT",
            x = math.floor(left + 0.5),
            y = math.floor(top + 0.5),
        }
    end

    local ok, point, _, relativePoint, x, y = pcall(window.GetPoint, window, 1)
    if not ok or type(point) ~= "string" then
        return nil
    end
    return {
        point = point,
        relativePoint = relativePoint or point,
        x = math.floor((x or 0) + 0.5),
        y = math.floor((y or 0) + 0.5),
    }
end

-- Eine gemerkte Lage anlegen. Gibt es keine, wird nicht die Bildschirmmitte
-- genommen, sondern die Stelle, an der Blizzards Fenster stünde - dort
-- erwartet man den Abklingzeit-Manager, und nach einem Neuladen ist noch
-- nichts gemerkt.
local function applySavedPoint(saved)
    saved = saved or blizzardWindowPoint()
    local point = (saved and saved.point) or "CENTER"
    panel:SetPoint(point, UIParent,
        (saved and saved.relativePoint) or point,
        (saved and saved.x) or 0, (saved and saved.y) or 0)
end

-- Blizzards Bearbeitungsmodus legt seine Oberfläche über den Bildschirm.
-- Unser Panel auf "HIGH" liegt darunter - offen, aber unsichtbar. Solange ihr
-- Modus läuft, gehört es eine Ebene höher.
--
-- Zusätzlich kann ihr eigenes Fenster noch höher liegen, wenn es aus dem
-- Bearbeitungsmodus heraus aufgeht. Wir schließen es zwar, aber nicht immer
-- im selben Durchlauf - und solange es steht, lag unseres dahinter: offen,
-- aber unsichtbar. Von außen sah das aus, als ginge unseres gar nicht auf.
local STRATA_ORDER = {
    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8,
}

local function applyStrata()
    if not panel then
        return
    end
    local manager = _G.EditModeManagerFrame
    local editing = false
    if type(manager) == "table" and type(manager.IsShown) == "function" then
        local ok, shown = pcall(manager.IsShown, manager)
        editing = ok and shown and true or false
    end

    local strata = editing and "FULLSCREEN_DIALOG" or "HIGH"

    local window = blizzardWindow()
    if window and windowIsShown(window) and type(window.GetFrameStrata) == "function" then
        local ok, theirs = pcall(window.GetFrameStrata, window)
        if ok and (STRATA_ORDER[theirs] or 0) > (STRATA_ORDER[strata] or 0) then
            strata = theirs
        end
    end

    panel:SetFrameStrata(strata)
    -- Gleiche Ebene entscheidet über die Reihenfolge innerhalb der Ebene.
    pcall(panel.Raise, panel)
end

-- Ihr Fenster hängt an Blizzards Panel-Verwaltung. Geschlossen wird deshalb
-- über HideUIPanel und nicht über Hide: ein direktes Hide geht an der
-- Verwaltung vorbei, die hält es weiter für offen und ignoriert danach jeden
-- Versuch, es erneut zu öffnen - dann passiert beim Klick gar nichts mehr.
local function hideBlizzardWindow(window)
    if not window then
        return
    end
    if type(_G.HideUIPanel) == "function" then
        pcall(_G.HideUIPanel, window)
    end
    if windowIsShown(window) then
        pcall(window.Hide, window)
    end
end

-- Nach der Übernahme nachfassen. Zwei Dinge passieren erst, nachdem wir
-- fertig sind:
--
--   * Ihr Fenster kann wieder aufgehen. Wir laufen mitten in ihrem OnShow,
--     und was in ihrem Aufruf danach noch folgt, stellt es her.
--   * Kommt die Übernahme aus dem Bearbeitungsmodus, kehrt dieser zurück,
--     sobald ihr Fenster zu ist - und ruft dabei CloseAllWindows auf. Unser
--     Panel steht in UISpecialFrames und wird davon mitgeschlossen. Es ging
--     also auf, nur bis zur Rückkehr des Modus: von außen sah es aus, als
--     ginge es gar nicht erst auf.
--
-- Der erste Blick liegt vor dem Zeichnen, es blitzt also nichts auf. Der
-- zweite ist nur das Netz, falls ihr Ablauf über mehrere Durchläufe geht.
-- Danach wird nicht mehr nachgefasst, damit ein Escape des Benutzers das
-- Panel wirklich schließt und nicht dagegen angekämpft wird.
local function settleTakeover(window)
    hideBlizzardWindow(window)
    if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
        return
    end
    local function recheck()
        if not Dock:ShouldReplace() then
            return
        end
        if windowIsShown(window) then
            hideBlizzardWindow(window)
        end
        local manager = _G.EditModeManagerFrame
        local editing = type(manager) == "table" and windowIsShown(manager)
        if editing and panel and not panel:IsShown() then
            panel:Show()
        end
        applyStrata()
    end
    C_Timer.After(0, recheck)
    C_Timer.After(0.1, recheck)
end

local function anchorPanel()
    panel:ClearAllPoints()

    -- Breit passt nicht mehr neben Blizzards Fenster, also mittig
    if state.wide then
        panel:SetPoint("CENTER")
        return
    end

    local config = settings()
    local side = config.dockSide or "RIGHT"

    if side == "FREE" then
        applySavedPoint(config.dockPoint)
        return
    end

    local window = blizzardWindow()
    local gap = config.dockGap or DEFAULT_GAP
    -- An ein ausgeblendetes Fenster andocken hieße, an seiner alten Stelle zu
    -- kleben. Verdrängen wir es, steht unseres dort, wo es zuletzt stand.
    --
    if window and not windowIsShown(window) then
        applySavedPoint(config.dockPoint)
        return
    end
    if window then
        local ok
        if side == "LEFT" then
            ok = pcall(panel.SetPoint, panel, "TOPRIGHT", window, "TOPLEFT", -gap, 0)
        else
            ok = pcall(panel.SetPoint, panel, "TOPLEFT", window, "TOPRIGHT", gap, 0)
        end
        if ok then
            return
        end
    end
    panel:SetPoint("CENTER")
end

-- --------------------------------------------------------- Zustand lesen

-- Die Kategorienamen stehen in Mirror.lua. Zwei Tabellen hätten sich
-- irgendwann unterschieden, und dann hieße dieselbe Kategorie im Panel
-- anders als auf der Leiste, die sie spiegelt.
local CATEGORY_NAMES = FCD.Mirror.CATEGORY_NAMES

-- Blizzard teilt die Kategorien auf zwei Reiter auf, jeder mit eigenem
-- "Nicht angezeigt". Welcher Reiter für einen Eintrag zuständig ist, sagt
-- seine Standardkategorie - auch dann, wenn er gerade ausgeblendet ist.
local TABS = {
    {
        id = "spells",
        label = "Zauber",
        icon = "Interface\\Icons\\Spell_Nature_Lightning",
        categories = { 0, 1, -1 },
    },
    {
        id = "buffs",
        label = "Stärkungseffekte",
        icon = "Interface\\Icons\\Spell_Holy_WordFortitude",
        categories = { 2, 3, 7, 8, -1 },
    },
    -- Blizzards Manager nimmt nur seine eigenen Abklingzeiten auf; benutzbare
    -- Gegenstände kann man ihm nicht unterschieben. Die kommen deshalb auf
    -- unsere eigene Leiste - dieser Reiter verwaltet sie.
    -- Blizzards Liste ist kuratiert: was nicht darauf steht, lässt sich in
    -- ihrem Manager nicht anzeigen. Dieser Reiter hebt genau das auf - jeder
    -- Zauber aus dem Zauberbuch kann auf unsere eigene Leiste.
    {
        id = "ownspells",
        label = "Eigene Zauber",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        categories = {},
        ownBar = true,
        entryKind = "spell",
    },
    {
        id = "items",
        label = "Gegenstände",
        -- Kein Zaubersymbol: das Händler-Sinnbild aus dem Gesprächsfenster ist
        -- freigestellt und wirkt damit wie Blizzards Reiter, nicht wie eine
        -- Kachel. Blizzard selbst hat keinen Gegenstandsreiter, von dem wir
        -- eines abholen könnten.
        icon = "Interface\\GossipFrame\\VendorGossipIcon",
        iconCrop = false,
        categories = {},
        ownBar = true,
    },
}

-- Die Leisten, auf denen unsere eigenen Einträge landen. Sie werden erst
-- angelegt, wenn wirklich etwas daraufgelegt wird.
local SPELL_BAR_NAME = "Zauber verfolgen"
-- Nicht uebersetzt: der Name steht so im Profil und wird zum Wiederfinden
-- der Leiste verglichen. Uebersetzt wuerde ein englischer Client die
-- vorhandene Leiste nicht finden und eine zweite anlegen. Angezeigt wird er
-- uebersetzt, siehe L[bar.name] in den Optionsfenstern.
local ITEM_BAR_NAME = "Gegenstände verfolgen"
-- Die Leiste hieß zuerst nur "Gegenstände". Wer sie schon hat, soll keine
-- zweite bekommen, sondern die vorhandene umbenannt.
local ITEM_BAR_LEGACY = "Gegenstände"

local function ownBar(name, create)
    local profile = FCD.Profiles:GetActive()
    if not profile then
        return nil
    end
    for _, bar in ipairs(profile.bars) do
        -- Eine gespiegelte Leiste trägt den Namen ihrer Kategorie und kann
        -- deshalb genauso heißen wie eine eigene. Sie gehört uns aber nicht:
        -- ihr Inhalt kommt aus Blizzards Zuordnung und ließe sich hier nicht
        -- verändern.
        if bar.name == name and bar.mirrorCategory == nil then
            return bar
        end
    end
    if not create then
        return nil
    end
    return FCD.Profiles:NewBar(profile, name)
end

local function itemBar(create)
    local profile = FCD.Profiles:GetActive()
    if not profile then
        return nil
    end
    -- Wer einen Gegenstand bewusst auf die Leiste legt, will ihn dort auch
    -- dann sehen, wenn gerade keiner mehr in der Tasche ist - sonst sieht ein
    -- leergetrunkener Trank aus wie ein verlorener Eintrag. Deshalb gilt für
    -- diese Leiste "Nicht Gelerntes verbergen" einmalig als aus; wer es im
    -- Optionsfenster wieder einschaltet, behält das.
    local function prepare(bar)
        if not bar.fcdItemDefaults then
            bar.fcdItemDefaults = true
            bar.visibility = bar.visibility or {}
            bar.visibility.hideUnknown = false
        end
        return bar
    end

    for _, bar in ipairs(profile.bars) do
        if bar.name == ITEM_BAR_NAME and bar.mirrorCategory == nil then
            return prepare(bar)
        end
    end
    for _, bar in ipairs(profile.bars) do
        -- Blizzards Kategorie 7 heißt ebenfalls "Gegenstände". Eine
        -- gespiegelte Leiste darf deshalb nicht umbenannt und vereinnahmt
        -- werden, sonst verschwände ihre Spiegelung.
        if bar.name == ITEM_BAR_LEGACY and bar.mirrorCategory == nil then
            bar.name = ITEM_BAR_NAME
            return prepare(bar)
        end
    end
    if not create then
        return nil
    end
    return prepare(FCD.Profiles:NewBar(profile, ITEM_BAR_NAME))
end

local function itemKey(kind, id)
    return tostring(kind) .. ":" .. tostring(id)
end

local function tabOfDefault(defaultCategory)
    if type(defaultCategory) == "number" and defaultCategory >= 2 then
        return "buffs"
    end
    return "spells"
end

local function currentTab()
    for _, tab in ipairs(TABS) do
        if tab.id == state.tab then
            return tab
        end
    end
    return TABS[1]
end

local function categoryName(value)
    -- Der Name in der Tabelle ist der deutsche Schlüssel; übersetzt wird
    -- erst beim Anzeigen, damit ein späterer Sprachwechsel greift.
    return FCD.Mirror:CategoryName(value)
end

-- Standard-Einordnung je Abklingzeit.
--
-- GetCooldownViewerCategorySet liefert nur eine Handvoll IDs - offenbar die
-- beim Laden aktiven, nicht den Katalog. Der vollständige Bestand steht in der
-- Reihenfolgeliste des Layouts (bei einem Krieger rund 170 Einträge), und die
-- Standardkategorie jedes Eintrags im Cache-Eintrag unter "category".
local function buildStaticMap()
    local map, order, seen, hidden = {}, {}, {}, {}

    local function add(cooldownID)
        if seen[cooldownID] then
            return
        end
        seen[cooldownID] = true
        local info = Compat.GetCooldownInfo(cooldownID)
        local category = info and info.category or nil
        if category ~= nil then
            map[cooldownID] = category
            -- Bit 2 der flags bedeutet "standardmäßig nicht angezeigt".
            -- Am lebenden Client ausgezählt: es trennt die Kategorien genau
            -- so, wie Blizzards Fenster sie aufteilt.
            hidden[cooldownID] = ((info.flags or 0) % 4) >= 2
            order[#order + 1] = cooldownID
        end
    end

    if Dock.layout and Dock.layout.order then
        for _, cooldownID in ipairs(Dock.layout.order) do
            add(cooldownID)
        end
    end
    -- Was die Kategorieabfragen zusätzlich kennen, ergänzen
    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        for _, cooldownID in ipairs(Compat.GetCategorySet(category.value) or {}) do
            add(cooldownID)
        end
    end

    return map, order, hidden
end

-- Für den Abgleich von außen zugänglich
Dock.TabOfDefault = tabOfDefault

function Dock:LoadLayout()
    local layout, err = FCD.Layout:Read()
    self.lastSeenRaw = layout and layout.raw or nil
    self.layout = layout
    self.layoutError = err
    self.staticMap, self.staticOrder, self.staticHidden = buildStaticMap()
    -- Die gespiegelten Leisten lesen dasselbe Layout. Wird es hier neu
    -- geholt, kann ihr Zwischenstand veraltet sein - auch dann, wenn die
    -- Änderung aus Blizzards eigenem Fenster kam.
    FCD.Mirror:Invalidate()
    return layout
end

local function effectiveCategory(cooldownID)
    if Dock.layout then
        local assigned = FCD.Layout:GetAssignedCategory(Dock.layout, cooldownID)
        if assigned ~= nil then
            return assigned
        end
    end
    -- Ohne eigene Zuweisung entscheiden die flags: standardmäßig verborgene
    -- Einträge gehören in "Nicht angezeigt", nicht in ihre Kategorie.
    if Dock.staticHidden and Dock.staticHidden[cooldownID] then
        return HIDDEN_CATEGORY
    end
    return Dock.staticMap and Dock.staticMap[cooldownID] or nil
end

function Dock:EffectiveCategory(cooldownID)
    return effectiveCategory(cooldownID)
end

-- --------------------------------------------------------- Abschnitte

local function spellOf(cooldownID)
    local info = Compat.GetCooldownInfo(cooldownID)
    return info and (info.spellID or info.overrideSpellID) or nil
end

local function matchesSearch(name)
    if state.search == "" then
        return true
    end
    return string.find(string.lower(name or ""), string.lower(state.search), 1, true) ~= nil
end

-- Baut je Kategorie die Eintragsliste. Gestapelt heißt: eine Kachel je
-- Fähigkeit, die alle ihre Ränge zusammenfasst - eine Bewegung verschiebt
-- dann die ganze Rangleiter.
-- Welche Abklingzeiten liegen tatsächlich auf den Leisten? Das sind wenige,
-- und GetCooldownViewerCategorySet nennt sie ohne Taint. Der Rest des Katalogs
-- steht zwar in den Abschnitten, ist aber nicht aktiv - genau wie in Blizzards
-- Fenster, wo nur die aktiven hervorgehoben sind.
local function buildActiveSet()
    local active = {}
    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        for _, cooldownID in ipairs(Compat.GetCategorySet(category.value) or {}) do
            active[cooldownID] = true
        end
    end
    return active
end

-- Alles Benutzbare, das wir finden: ausgerüstete Gegenstände mit Benutzwirkung,
-- Taschenware und selbst eingetragene IDs. Was schon auf der Leiste liegt,
-- steht oben - so sieht man auf einen Blick, was gesetzt ist.
local function buildItemSections()
    local candidates = FCD.Items:Rebuild()
    local bar = itemBar(false)

    -- Was auf der Leiste liegt, kommt aus der Leiste selbst - nicht aus dem
    -- Suchlauf über Taschen und Ausrüstung. Der findet einen Gegenstand kurz
    -- nach dem Anmelden noch nicht, solange der Client seine Daten nicht
    -- nachgeladen hat, und früher sah die Leiste deshalb leer aus, obwohl
    -- alles gespeichert war. Er findet ihn auch dann nicht mehr, wenn der
    -- letzte Trank aufgebraucht ist - auf der Leiste bleiben soll er trotzdem.
    local onBar, barItems = {}, {}
    if bar then
        for position, entry in ipairs(bar.entries) do
            if entry.kind == "item" or entry.kind == "inventory" then
                local key = itemKey(entry.kind, entry.id)
                onBar[key] = true
                local name, icon = FCD.Items:GetDisplay(entry)
                barItems[#barItems + 1] = {
                    key = key,
                    label = name or ("Gegenstand " .. tostring(entry.id)),
                    icon = icon,
                    known = true,
                    onBar = true,
                    itemEntry = { kind = entry.kind, id = entry.id },
                    itemID = (entry.kind == "item") and tonumber(entry.id) or nil,
                    sort = position,
                    cooldownIDs = {},
                }
            end
        end
    end

    local groups = {
        { id = "item:onbar", title = L["Auf der Leiste"] },
        { id = "item:equipped", title = L["Ausgerüstet"] },
        { id = "item:bags", title = L["In Taschen"] },
        { id = "item:manual", title = L["Selbst hinzugefügt"] },
    }
    local buckets = {}
    for _, group in ipairs(groups) do
        buckets[group.id] = {}
    end
    for _, item in ipairs(barItems) do
        if matchesSearch(item.label) then
            local bucket = buckets["item:onbar"]
            bucket[#bucket + 1] = item
        end
    end

    for position, candidate in ipairs(candidates) do
        local key = itemKey(candidate.kind, candidate.id)
        local target
        -- Was auf der Leiste liegt, steht dort schon über die Leiste selbst
        -- in der Liste und wird hier übersprungen.
        if not onBar[key] then
            if candidate.kind == "inventory" then
                target = "item:equipped"
            elseif candidate.subLabel == "manuell" then
                target = "item:manual"
            else
                target = "item:bags"
            end
        end

        local name, icon = FCD.Items:GetDisplay(candidate)
        if target and matchesSearch(name) then
            local bucket = buckets[target]
            bucket[#bucket + 1] = {
                key = key,
                label = name or candidate.name or "?",
                icon = icon or candidate.icon,
                known = true,
                onBar = onBar[key] and true or false,
                itemEntry = { kind = candidate.kind, id = candidate.id },
                itemID = candidate.itemID,
                sort = position,
                cooldownIDs = {},
            }
        end
    end

    -- Ist der Abschnitt leer, soll dort stehen WARUM. "Nichts gesetzt" und
    -- "Leiste nicht gefunden" sehen sonst gleich aus, und genau das hat die
    -- Fehlersuche bisher aufgehalten.
    local emptyReason
    if not bar then
        local profile = FCD.Profiles:GetActive()
        emptyReason = string.format(
            L["Leiste nicht gefunden. Aktives Profil: %s, Leisten: %d."],
            profile and (profile.name or "ohne Namen") or "keines",
            profile and #profile.bars or 0)
    elseif #bar.entries == 0 then
        emptyReason = L["Die Leiste ist leer - unten etwas anklicken."]
    else
        emptyReason = string.format(
            L["Die Leiste hat %d Eintrag/Einträge, aber keiner ist ein Gegenstand."],
            #bar.entries)
    end

    local sections = {}
    for _, group in ipairs(groups) do
        local items = buckets[group.id]
        table.sort(items, function(a, b) return (a.sort or 0) < (b.sort or 0) end)
        sections[#sections + 1] = {
            id = group.id,
            title = group.title,
            category = false,
            items = items,
            headerText = string.format("%s  (%d)", group.title, #items),
            emptyText = (group.id == "item:onbar") and emptyReason
                or L["Nichts gefunden. Gegenstände aus der Tasche hierher ziehen."],
        }
    end
    return sections
end

-- Der Gegenstück zum Gegenstandsreiter, nur für Zauber. Der interessante
-- Abschnitt ist "Nicht in Blizzards Manager": genau das, was ihre kuratierte
-- Liste auslässt und was man sonst nirgends anzeigen kann.
local function buildSpellSections()
    FCD.Catalog:Rebuild()
    local bar = ownBar(SPELL_BAR_NAME, false)

    local onBar, barItems = {}, {}
    if bar then
        for position, entry in ipairs(bar.entries) do
            if entry.kind == "spell" then
                local key = itemKey("spell", entry.familyKey or entry.id)
                onBar[key] = true
                local spellID, rank = FCD.Ranks:Resolve(entry)
                local name, icon = Compat.GetSpellInfo(spellID)
                barItems[#barItems + 1] = {
                    key = key,
                    label = name or (L["Zauber "] .. tostring(entry.id)),
                    icon = icon,
                    known = true,
                    onBar = true,
                    rank = rank,
                    itemEntry = { kind = "spell", id = entry.id,
                        familyKey = entry.familyKey },
                    spellID = spellID,
                    sort = position,
                    cooldownIDs = {},
                }
            end
        end
    end

    local groups = {
        { id = "spell:onbar", title = L["Auf der Leiste"] },
        { id = "spell:missing", title = L["Nicht in Blizzards Manager"] },
        { id = "spell:known", title = L["Im Manager vorhanden"] },
    }
    local buckets = {}
    for _, group in ipairs(groups) do
        buckets[group.id] = {}
    end
    for _, item in ipairs(barItems) do
        if matchesSearch(item.label) then
            local bucket = buckets["spell:onbar"]
            bucket[#bucket + 1] = item
        end
    end

    local filtered = FCD.Catalog:Filter({
        text = state.search ~= "" and state.search or nil,
        showItems = false,
        onlyKnown = state.onlyKnown,
        showPassive = state.showPassive,
        onlyWithCooldown = state.onlyWithCooldown,
    })
    for position, entry in ipairs(filtered) do
        local key = itemKey("spell", entry.familyKey or entry.bestSpellID)
        if not onBar[key] and entry.bestSpellID then
            local target = entry.inViewer and "spell:known" or "spell:missing"
            local bucket = buckets[target]
            bucket[#bucket + 1] = {
                key = key,
                label = entry.name or "?",
                icon = entry.icon,
                known = entry.known,
                onBar = false,
                rank = entry.bestRank,
                stackSize = entry.rankCount,
                itemEntry = { kind = "spell", id = entry.bestSpellID,
                    familyKey = entry.familyKey },
                spellID = entry.bestSpellID,
                sort = position,
                cooldownIDs = {},
            }
        end
    end

    local sections = {}
    for _, group in ipairs(groups) do
        local items = buckets[group.id]
        table.sort(items, function(a, b) return (a.sort or 0) < (b.sort or 0) end)
        sections[#sections + 1] = {
            id = group.id,
            title = group.title,
            category = false,
            items = items,
            headerText = string.format("%s  (%d)", group.title, #items),
            emptyText = (group.id == "spell:onbar")
                and L["Noch nichts gesetzt - unten etwas anklicken."]
                or "Nichts gefunden.",
        }
    end
    return sections
end

local function buildSections()
    local tab = currentTab()
    if tab.ownBar then
        return tab.entryKind == "spell" and buildSpellSections() or buildItemSections()
    end

    local activeSet = buildActiveSet()
    local buckets = {}
    local orderIndex = {}
    if Dock.layout and Dock.layout.order then
        for position, id in ipairs(Dock.layout.order) do
            orderIndex[id] = position
        end
    end

    for _, cooldownID in ipairs(Dock.staticOrder or {}) do
        local category = effectiveCategory(cooldownID)
        -- Der Reiter richtet sich nach der Standardkategorie, nicht nach der
        -- aktuellen: ein ausgeblendeter Buff bleibt beim Buff-Reiter.
        local belongsHere = tabOfDefault(Dock.staticMap and Dock.staticMap[cooldownID]) == state.tab
        if category ~= nil and belongsHere then
            local spellID = spellOf(cooldownID)
            local name, icon = Compat.GetSpellInfo(spellID)
            local subText = spellID and Compat.GetSpellSubtext(spellID)
            local rank = FCD.Ranks:ParseRank(subText)
            local known = spellID and Compat.IsSpellKnown(spellID) or false

            local family = spellID and FCD.Ranks:GetFamilyBySpell(spellID)
            local isPassive = family and family.isPassive or false
            local baseCooldown = spellID and Compat.GetSpellBaseCooldown(spellID)

            local keep = matchesSearch(name)
                and (not state.onlyKnown or known)
                and (state.showPassive or not isPassive)
            -- Ist die Grundabklingzeit nicht abfragbar, wird nicht gefiltert:
            -- lieber zu viel zeigen als etwas verschwinden lassen.
            if keep and state.onlyWithCooldown and baseCooldown ~= nil and baseCooldown <= 0 then
                keep = false
            end

            if keep then
                buckets[category] = buckets[category] or {}
                local bucket = buckets[category]

                if state.stackRanks then
                    local groupKey = family and family.key or ("id:" .. cooldownID)
                    local group = bucket[groupKey]
                    if not group then
                        group = {
                            key = "c" .. category .. ":" .. groupKey,
                            label = name or (L["Abklingzeit "] .. cooldownID),
                            icon = icon,
                            cooldownIDs = {},
                            category = category,
                            sort = orderIndex[cooldownID] or cooldownID,
                            known = false,
                        }
                        bucket[groupKey] = group
                        bucket[#bucket + 1] = group
                    end
                    group.cooldownIDs[#group.cooldownIDs + 1] = cooldownID
                    group.active = group.active or activeSet[cooldownID] or false
                    -- Als Vertreter den höchsten gelernten Rang zeigen
                    if known and (not group.known or (rank or 0) >= (group.rank or 0)) then
                        group.known = true
                        group.rank = rank
                        group.icon = icon or group.icon
                    elseif not group.known and (rank or 0) >= (group.rank or 0) then
                        group.rank = rank
                        group.icon = icon or group.icon
                    end
                else
                    bucket[#bucket + 1] = {
                        key = "c" .. category .. ":" .. cooldownID,
                        label = name or (L["Abklingzeit "] .. cooldownID),
                        icon = icon,
                        rank = rank,
                        known = known,
                        cooldownIDs = { cooldownID },
                        active = activeSet[cooldownID] or false,
                        category = category,
                        sort = orderIndex[cooldownID] or cooldownID,
                    }
                end
            end
        end
    end

    local sections = {}
    local values = {}
    for _, value in ipairs(currentTab().categories) do
        values[#values + 1] = value
    end
    -- Sichtbare Kategorien zuerst, "nicht angezeigt" ans Ende
    table.sort(values, function(a, b)
        local negativeA, negativeB = a < 0, b < 0
        if negativeA ~= negativeB then
            return negativeB
        end
        return a < b
    end)

    for _, value in ipairs(values) do
        local bucket = buckets[value] or {}
        local items = {}
        local knownCount = 0
        for _, item in ipairs(bucket) do
            item.stackSize = #item.cooldownIDs
            if item.known then
                knownCount = knownCount + 1
            end
            items[#items + 1] = item
        end
        table.sort(items, function(a, b) return (a.sort or 0) < (b.sort or 0) end)
        -- Leere Standardkategorien nicht anzeigen, sonst wird die Liste lang
        do
            sections[#sections + 1] = {
                id = "cat:" .. value,
                title = categoryName(value),
                category = value,
                items = items,
                knownCount = knownCount,
                emptyText = L["Symbole hierher ziehen"],
            }
        end
    end

    return sections
end

-- ----------------------------------------------------------- Gegenstände

-- Das Gegenstück zu AssignSelection: dieselbe Bedienung, nur ist das Ziel
-- hier nicht eine Kategorie, sondern die eigene Leiste.
function Dock:AssignItemSelection(onBar)
    local chosen = {}
    for _, item in pairs(state.selection) do
        if item.itemEntry then
            chosen[#chosen + 1] = item
        end
    end
    if #chosen == 0 then
        return
    end

    -- Zauber und Gegenstände liegen auf getrennten Leisten, sonst mischt sich
    -- beides in einer Reihe.
    local spells = chosen[1].itemEntry.kind == "spell"
    local bar = ownBar(spells and SPELL_BAR_NAME or ITEM_BAR_NAME, true)
    if not bar then
        FCD.Print(L["Kein Profil aktiv - ohne Profil gibt es keine Leiste."])
        return
    end
    if not spells then
        itemBar(true)
    end

    FCD.Profiles:PushUndo(L["Eigene Leiste geändert"])
    local changed = 0
    for _, item in ipairs(chosen) do
        local position
        for index, entry in ipairs(bar.entries) do
            local key = (entry.kind == "spell")
                and itemKey("spell", entry.familyKey or entry.id)
                or itemKey(entry.kind, entry.id)
            if key == item.key then
                position = index
                break
            end
        end
        if onBar and not position then
            bar.entries[#bar.entries + 1] = spells
                and FCD.Ranks:MakeEntry(item.itemEntry.id)
                or FCD.Items:MakeEntry(item.itemEntry)
            changed = changed + 1
        elseif not onBar and position then
            table.remove(bar.entries, position)
            changed = changed + 1
        end
    end

    wipe(state.selection)
    FCD.Viewer:RebuildAll()
    self:Refresh()
end

function Dock:ToggleItemOnBar(item)
    if not item or not item.itemEntry then
        return
    end
    wipe(state.selection)
    state.selection[item.key] = item
    self:AssignItemSelection(not item.onBar)
end

-- Nur selbst eingetragene lassen sich vergessen; was in der Tasche liegt oder
-- angelegt ist, findet der Suchlauf beim nächsten Mal ohnehin wieder.
function Dock:ForgetItem(item)
    if not item or not item.itemEntry or item.itemEntry.kind ~= "item" then
        return
    end
    local itemID = tonumber(item.itemEntry.id)
    if not itemID or not (FCD.db.customItems or {})[itemID] then
        FCD.Print(L["Das steht nicht in der eigenen Liste - es kommt aus Tasche"]
            .. L[" oder Ausrüstung."])
        return
    end
    FCD.Items:RemoveCustom(itemID)
    self:Refresh()
end

-- Ein Gegenstand, der auf dem Zeiger liegt, wird beim Loslassen über dem
-- Panel dauerhaft aufgenommen - so, wie man ihn auch auf eine Aktionsleiste
-- ziehen würde.
function Dock:AcceptCursorItem()
    local kind, first, link = GetCursorInfo()

    -- Ein Zauber vom Zauberbuch auf das Panel gezogen wird aufgenommen. Was
    -- der Zeiger dabei liefert, ist zwischen den Clients verschieden: mal die
    -- Zauber-ID, mal ein Platz im Buch mit Link - beides wird ausgewertet.
    if kind == "spell" then
        local spellID = tonumber(first)
        if not spellID and type(link) == "string" then
            spellID = tonumber(link:match("spell:(%d+)"))
        end
        if not spellID then
            return false
        end
        ClearCursor()
        local ok, err = FCD.Ranks:AddCustom(spellID)
        if not ok then
            FCD.Print(L["Nicht aufgenommen: "] .. tostring(err))
            return false
        end
        FCD.Catalog:Rebuild()
        state.tab = "ownspells"
        wipe(state.selection)
        self:Refresh()
        FCD.Print(string.format(L["'%s' aufgenommen."],
            Compat.GetSpellName(spellID) or (L["Zauber "] .. spellID)))
        return true
    end

    if kind ~= "item" then
        return false
    end
    local itemID = tonumber(first)
    if not itemID and type(link) == "string" then
        itemID = tonumber(link:match("item:(%d+)"))
    end
    if not itemID then
        return false
    end
    ClearCursor()
    FCD.Items:AddCustom(itemID)
    state.tab = "items"
    wipe(state.selection)
    self:Refresh()
    local name = Compat.GetItemInfo(itemID)
    return true
end

-- --------------------------------------------------------------- Ändern

local function countSelection()
    local count = 0
    for _ in pairs(state.selection) do
        count = count + 1
    end
    return count
end

-- Weist die Auswahl einer Kategorie zu. Entspricht die Zielkategorie der
-- statischen Einordnung, wird die Abweichung entfernt statt eine
-- gleichlautende einzutragen - so bleibt das Layout so klein wie Blizzards.
function Dock:AssignSelection(category)
    if not self.layout then
        FCD.Print(L["Layout nicht lesbar: "] .. tostring(self.layoutError))
        return
    end

    local ok, err = FCD.Layout:VerifyRoundTrip(self.layout)
    if not ok then
        FCD.Print(L["Abgebrochen, Rundlauf fehlerhaft: "] .. tostring(err))
        return
    end

    -- Sofortmodus: über Blizzards Datenmodell, wirkt ohne Neuladen, markiert
    -- ihre Objekte aber als tainted. Im Kampf gesperrt, weil der Taint dort
    -- ihre geschützten Aktionen blockiert.
    if FCD.Layout:NativeWritesAllowed() and not FCD.Layout:CanWriteNativeNow() then
        FCD.Print(L["Im Kampf wird nicht sofort geschrieben - der Taint würde Blizzards"])
        FCD.Print(L["Fenster blockieren. Die Änderung wird sicher gespeichert und"])
        FCD.Print(L["greift nach dem nächsten Neuladen."])
    end

    if FCD.Layout:CanWriteNativeNow() then
        local changed = 0
        FCD.Layout:CreateNativeRestorePoint()
        for _, item in pairs(state.selection) do
            for _, cooldownID in ipairs(item.cooldownIDs) do
                local ok, err = FCD.Layout:SetCategoryNative(cooldownID, category)
                if ok then
                    changed = changed + 1
                else
                    FCD.Print(L["Abgelehnt: "] .. tostring(err))
                end
            end
        end
        wipe(state.selection)
        self:LoadLayout()
        FCD.Mirror:Refresh()
        self:Refresh()
        FCD.Print(string.format(L["%d Abklingzeit(en) nach '%s' - sofort wirksam."],
            changed, categoryName(category)))
        return
    end

    local moved = 0
    local names = {}
    for _, item in pairs(state.selection) do
        for _, cooldownID in ipairs(item.cooldownIDs) do
            local default = self.staticMap and self.staticMap[cooldownID] or nil
            if category == default then
                FCD.Layout:SetCategory(self.layout, cooldownID, nil)
            else
                FCD.Layout:SetCategory(self.layout, cooldownID, category)
            end
            moved = moved + 1
        end
        names[#names + 1] = item.label
    end

    if moved == 0 then
        return
    end

    local label = string.format("%s -> %s",
        table.concat(names, ", "):sub(1, 60), categoryName(category))
    local written, writeErr = FCD.Layout:Commit(self.layout, label)
    if not written then
        FCD.Print(L["Schreiben fehlgeschlagen: "] .. tostring(writeErr))
        return
    end

    -- Blizzards eigene Leisten lesen das Layout erst beim Neuladen wieder;
    -- für sie steht die Änderung also noch aus.
    self.needsReload = true
    wipe(state.selection)

    -- Unsere gespiegelten Leisten zeichnen wir selbst. Für sie ist dieselbe
    -- Änderung in derselben Sekunde da - ohne dass eine Zeile Blizzard-Lua
    -- gelaufen wäre und damit ohne jeden Taint.
    local mirrored = FCD.Mirror:Refresh()
    self:Refresh()

    if mirrored then
        FCD.Print(string.format(
            L["%d Abklingzeit(en) nach '%s' - auf den gespiegelten Leisten sofort zu sehen."],
            moved, categoryName(category)))
        return
    end

    FCD.Print(string.format(L["%d Abklingzeit(en) nach '%s' - wirksam nach dem Neuladen."],
        moved, categoryName(category)))
    -- Einmal je Sitzung: dass es auch ohne Neuladen geht, sieht man dem
    -- Panel sonst nicht an.
    if not self.mirrorHintShown then
        self.mirrorHintShown = true
        FCD.Print(L["Sofort sehen statt neu laden: der Knopf 'spiegeln' an der"])
        FCD.Print(L["Abschnittsüberschrift legt eine eigene Leiste an, die diese"])
        FCD.Print(L["Kategorie zeigt. Die zeichnen wir selbst - sofort und ohne Fehler."])
    end
end

-- Eine Kategorie auf eine eigene Leiste spiegeln oder die Spiegelung wieder
-- aufheben. Der Knopf dafür sitzt an der Überschrift des Abschnitts.
function Dock:ToggleMirror(category)
    local mirrored, err = FCD.Mirror:Toggle(category)
    if mirrored == nil then
        FCD.Print(L["Nicht angelegt: "] .. tostring(err))
        return
    end
    if mirrored then
        FCD.Print(string.format(
            L["'%s' liegt jetzt auf einer eigenen Leiste - Änderungen daran sind dort sofort zu sehen."],
            categoryName(category)))
        -- Eine leere Leiste wird nicht gezeichnet. Ohne diesen Satz sucht man
        -- sie auf dem Bildschirm und hält das Spiegeln für kaputt.
        local bar = FCD.Mirror:FindBar(category)
        local count = bar and #FCD.Viewer:EntriesOf(bar) or 0
        if count == 0 then
            FCD.Print(L["In dieser Kategorie liegt gerade nichts Gelerntes - die Leiste"])
            FCD.Print(L["bleibt leer und unsichtbar, bis etwas hineinkommt."])
        elseif FCD.Viewer.unlocked then
            FCD.Print(L["Die neue Leiste steht in der Bildschirmmitte; ziehen verschiebt sie."])
        else
            FCD.Print(L["Die neue Leiste steht in der Bildschirmmitte - /fcd unlock zum Verschieben."])
        end
        for _, line in ipairs(FCD.Mirror:GetHideInstructions()) do
            FCD.Print(line)
        end
    else
        FCD.Print(string.format(L["Spiegelung von '%s' aufgehoben."], categoryName(category)))
    end
    self:Refresh()
end

-- ------------------------------------------------------------ Ziehen

local function cursorPosition()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

local function withinFrame(frame, x, y)
    local left, right = frame:GetLeft(), frame:GetRight()
    local bottom, top = frame:GetBottom(), frame:GetTop()
    if not left or not right or not bottom or not top then
        return false
    end
    return x >= left and x <= right and y >= bottom and y <= top
end

function Dock:BeginDrag(item)
    if not item then
        return
    end
    if not state.selection[item.key] then
        wipe(state.selection)
        state.selection[item.key] = item
    end
    self.dragItem = item
    ghost.icon:SetTexture(item.icon or 134400)
    local count = countSelection()
    ghost.count:SetText(count > 1 and count or "")
    ghost:Show()
    self:Refresh()
end

local function sectionUnderCursor()
    local _, y = cursorPosition()
    local best, bestTop
    for _, entry in ipairs(panel.layout or {}) do
        local top = entry.header:GetTop()
        if top and top > y and (not bestTop or top < bestTop) then
            best, bestTop = entry, top
        end
    end
    return best
end

function Dock:EndDrag()
    ghost:Hide()
    local dragged = self.dragItem
    self.dragItem = nil
    if not dragged then
        return
    end
    local target = sectionUnderCursor()
    if not target then
        self:Refresh()
        return
    end
    -- Gegenstände kennen nur zwei Ziele: auf der Leiste oder nicht. Die
    -- gesamte Auswahl zieht mit, genau wie bei den Abklingzeiten.
    if dragged.itemEntry then
        local id = target.section.id or ""
        self:AssignItemSelection(id == "item:onbar" or id == "spell:onbar")
        return
    end
    self:AssignSelection(target.section.category)
end

function Dock:OnTileClick(item, control, shift)
    if not item then
        return
    end
    if shift and state.lastKey then
        local from, to
        for index, tile in ipairs(panel.tiles) do
            if tile.item then
                if tile.item.key == state.lastKey then
                    from = index
                end
                if tile.item.key == item.key then
                    to = index
                end
            end
        end
        if from and to then
            for index = math.min(from, to), math.max(from, to) do
                local tile = panel.tiles[index]
                if tile.item then
                    state.selection[tile.item.key] = tile.item
                end
            end
        else
            state.selection[item.key] = item
        end
    elseif control then
        if state.selection[item.key] then
            state.selection[item.key] = nil
        else
            state.selection[item.key] = item
        end
    else
        wipe(state.selection)
        state.selection[item.key] = item
    end
    state.lastKey = item.key
    self:Refresh()
end

-- Doppelklick schaltet zwischen "angezeigt" und "nicht angezeigt" um
function Dock:ActivateTile(item)
    if not item then
        return
    end
    -- Beim Gegenstand ist das Gegenstück zum Aus-/Einblenden: herunter von
    -- der Leiste oder hinauf.
    if item.itemEntry then
        wipe(state.selection)
        state.selection[item.key] = item
        self:AssignItemSelection(not item.onBar)
        return
    end
    wipe(state.selection)
    state.selection[item.key] = item
    if item.category == HIDDEN_CATEGORY then
        local default = self.staticMap and self.staticMap[item.cooldownIDs[1]] or 0
        self:AssignSelection(default)
    else
        self:AssignSelection(HIDDEN_CATEGORY)
    end
end

-- ------------------------------------------------------------- Widgets

-- Kacheln und Balken tragen dieselben Gesten; die Handler stehen deshalb
-- nur einmal hier.
local function attachItemHandlers(widget)
    widget:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    widget:RegisterForDrag("LeftButton")
    -- Gegenstände werden genauso bedient wie Abklingzeiten: anklicken wählt
    -- aus, Strg und Umschalt erweitern, Ziehen verschiebt, Doppelklick
    -- schaltet um. Nur der Rechtsklick ist zusätzlich - er wirft selbst
    -- eingetragene Gegenstände wieder aus der Liste.
    widget:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.item and self.item.itemEntry then
                Dock:ForgetItem(self.item)
            end
            return
        end
        Dock:OnTileClick(self.item, IsControlKeyDown(), IsShiftKeyDown())
    end)
    widget:SetScript("OnDoubleClick", function(self)
        Dock:ActivateTile(self.item)
    end)
    widget:SetScript("OnDragStart", function(self)
        Dock:BeginDrag(self.item)
    end)
    widget:SetScript("OnDragStop", function()
        Dock:EndDrag()
    end)
    widget:SetScript("OnEnter", function(self)
        local item = self.item
        if not item then
            return
        end
        if item.itemEntry then
            local setter = item.spellID
                and function(tip) tip:SetSpellByID(item.spellID) end
                or (item.itemID and function(tip) tip:SetItemByID(item.itemID) end)
            FCD.Widgets.ShowEntryTooltip(self, "ANCHOR_LEFT", setter, item.label,
                L["Ziehen: in einen anderen Abschnitt"],
                item.onBar and L["Doppelklick: von der Leiste nehmen"]
                    or L["Doppelklick: auf die Leiste legen"],
                (item.itemEntry.kind == "item")
                    and L["Rechtsklick: aus der Liste entfernen"] or nil)
            return
        end

        local spellID = spellOf(item.cooldownIDs[1])
        FCD.Widgets.ShowEntryTooltip(self, "ANCHOR_LEFT",
            spellID and function(tip) tip:SetSpellByID(spellID) end or nil,
            item.label,
            (item.stackSize and item.stackSize > 1)
                and (item.stackSize .. L[" Ränge - bewegen sich gemeinsam"]) or nil,
            L["Ziehen: in einen anderen Abschnitt"],
            L["Doppelklick: ein-/ausblenden"])
    end)
    widget:SetScript("OnLeave", FCD.Widgets.HideTooltip)
end

local function createTile(parent)
    local tile = CreateFrame("Button", nil, parent)
    tile:SetSize(TILE_SIZE, TILE_SIZE)

    tile.icon = tile:CreateTexture(nil, "BACKGROUND")
    tile.icon:SetAllPoints()
    tile.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    tile.selection = tile:CreateTexture(nil, "OVERLAY")
    tile.selection:SetPoint("TOPLEFT", -2, 2)
    tile.selection:SetPoint("BOTTOMRIGHT", 2, -2)
    tile.selection:SetColorTexture(0.25, 0.6, 1, 0.55)
    tile.selection:Hide()

    tile.highlight = tile:CreateTexture(nil, "HIGHLIGHT")
    tile.highlight:SetAllPoints()
    tile.highlight:SetColorTexture(1, 1, 1, 0.2)

    tile.rank = tile:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    tile.rank:SetPoint("TOPLEFT", 1, -1)
    tile.rank:SetTextColor(1, 0.82, 0)
    -- Blizzards kopierte Grafik liegt teils ebenfalls auf OVERLAY. Die Zahlen
    -- gehören darüber, sonst verschwinden sie unter dem Rahmen.
    tile.rank:SetDrawLayer("OVERLAY", 7)

    tile.stack = tile:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    tile.stack:SetPoint("BOTTOMRIGHT", -1, 1)
    tile.stack:SetTextColor(0.7, 0.7, 0.7)
    tile.stack:SetDrawLayer("OVERLAY", 7)

    attachItemHandlers(tile)

    return tile
end

-- "Verfolgte Leisten" zeigt Blizzard nicht als Symbolraster, sondern als
-- Balken mit Symbol und Namen - so, wie der Eintrag später im Spiel aussieht.
local BAR_ROW_HEIGHT = 28
local TRACKED_BAR_CATEGORY = 3

-- Zieht einen dünnen Rahmen aus vier Texturen um eine Fläche. Rundungen
-- gibt es ohne eigene Grafiken nicht, aber Kanten und Tiefe schon.
local function addEdges(parent, anchor, red, green, blue, alpha)
    local edges = {}
    for index = 1, 4 do
        edges[index] = parent:CreateTexture(nil, "OVERLAY")
        edges[index]:SetColorTexture(red, green, blue, alpha)
    end
    edges[1]:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    edges[1]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT")
    edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT")
    edges[2]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT", anchor, "TOPLEFT")
    edges[3]:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT")
    edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT", anchor, "TOPRIGHT")
    edges[4]:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT")
    edges[4]:SetWidth(1)
    return edges
end

-- Übernimmt Blizzards Maße, sobald ihre Grafik abgelesen ist. Vorher bleiben
-- unsere eigenen stehen, damit das Panel auch ohne Vorlage benutzbar ist.
local function adoptArtSizes()
    if not FCD.Art then
        return
    end
    local tileSize = FCD.Art:TileSize()
    if tileSize then
        TILE_SIZE = tileSize
    end
    local barHeight = FCD.Art:BarHeight()
    if barHeight then
        BAR_ROW_HEIGHT = barHeight
    end
end

-- Greift Blizzards Grafik ab, sobald ihr Fenster offen ist. Beim ersten
-- Erfolg verschwindet unsere Notzeichnung, und der Text rückt an das Symbol,
-- das jetzt dort sitzt, wo Blizzard seines hat.
local function decorate(widget, kind)
    if widget.artApplied or not FCD.Art then
        return false
    end
    if not FCD.Art:Decorate(widget, kind) then
        return false
    end
    if widget.fallback then
        for _, piece in ipairs(widget.fallback) do
            piece:Hide()
        end
    end
    if kind == "bar" and widget.text then
        widget.text:ClearAllPoints()
        widget.text:SetPoint("LEFT", widget.icon, "RIGHT", 6, 0)
        widget.text:SetPoint("RIGHT", widget, "RIGHT", -34, 0)
        widget.stack:ClearAllPoints()
        widget.stack:SetPoint("RIGHT", widget, "RIGHT", -8, 0)
        widget.highlight:ClearAllPoints()
        widget.highlight:SetAllPoints()
    end
    return true
end

-- Ein senkrechter Verlauf - oben heller, unten dunkler - ist der Unterschied
-- zwischen "farbige Fläche" und "Leiste". Die API dafür heißt in neueren
-- Clients anders als früher, also werden beide Wege versucht.
local function applyGradient(texture, topR, topG, topB, bottomR, bottomG, bottomB)
    local makeColor = _G.CreateColor
    if texture.SetGradient and makeColor then
        local ok = pcall(texture.SetGradient, texture, "VERTICAL",
            makeColor(bottomR, bottomG, bottomB, 1), makeColor(topR, topG, topB, 1))
        if ok then
            return true
        end
    end
    if texture.SetGradientAlpha then
        local ok = pcall(texture.SetGradientAlpha, texture, "VERTICAL",
            bottomR, bottomG, bottomB, 1, topR, topG, topB, 1)
        if ok then
            return true
        end
    end
    return false
end

local function setBarColor(row, topR, topG, topB, bottomR, bottomG, bottomB)
    row.barFill:SetColorTexture(topR, topG, topB, 1)
    if not applyGradient(row.barFill, topR, topG, topB, bottomR, bottomG, bottomB) then
        -- Ohne Verlauf bleibt die Mischfarbe, das ist immer noch brauchbar.
        row.barFill:SetColorTexture((topR + bottomR) / 2,
            (topG + bottomG) / 2, (topB + bottomB) / 2, 1)
    end
end

-- Blizzards Leiste zeichnen wir selbst; der Nachbau ihrer Grafik hat für die
-- Balkenzeile nie das Richtige erwischt. Was wir von ihnen übernehmen, ist die
-- Eckenmaske - über den Balken gezogen rundet sie dessen Enden, und über dem
-- Symbol macht sie dieselben runden Ecken wie in ihrem Fenster.
local function styleBarRow(row)
    if row.maskTried or not FCD.Art then
        return
    end
    row.maskTried = true
    FCD.Art:ApplyMask(row.barBack)
    FCD.Art:ApplyMask(row.barFill)
    FCD.Art:ApplyMask(row.icon)
end

local function createBarRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(BAR_ROW_HEIGHT)
    row.fallback = {}

    -- Gefasstes Symbol: dunkler Rahmen, Symbol eingerückt
    row.iconFrame = row:CreateTexture(nil, "BACKGROUND")
    row.iconFrame:SetSize(24, 24)
    row.iconFrame:SetPoint("LEFT", 0, 0)
    row.iconFrame:SetColorTexture(0, 0, 0, 0.9)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", row.iconFrame, "TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -2, 2)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local iconEdges = addEdges(row, row.iconFrame, 1, 1, 1, 0.25)

    -- Balken: dunkler Grund, farbige Füllung, heller Streifen oben für Tiefe
    row.barBack = row:CreateTexture(nil, "BACKGROUND")
    row.barBack:SetPoint("LEFT", row.iconFrame, "RIGHT", 5, 0)
    row.barBack:SetPoint("RIGHT", 0, 0)
    row.barBack:SetHeight(22)
    row.barBack:SetColorTexture(0.06, 0.06, 0.08, 0.95)

    row.barFill = row:CreateTexture(nil, "BORDER")
    row.barFill:SetPoint("TOPLEFT", row.barBack, "TOPLEFT", 1, -1)
    row.barFill:SetPoint("BOTTOMRIGHT", row.barBack, "BOTTOMRIGHT", -1, 1)
    row.barFill:SetColorTexture(0.72, 0.40, 0.10, 1)

    row.barGloss = row:CreateTexture(nil, "ARTWORK")
    row.barGloss:SetPoint("TOPLEFT", row.barFill, "TOPLEFT")
    row.barGloss:SetPoint("TOPRIGHT", row.barFill, "TOPRIGHT")
    row.barGloss:SetHeight(9)
    row.barGloss:SetColorTexture(1, 1, 1, 0.13)

    local barEdges = addEdges(row, row.barBack, 0, 0, 0, 0.8)

    -- Alles, was Blizzards Grafik später ersetzt, an einer Stelle gesammelt
    for _, piece in ipairs({ row.iconFrame, row.barBack, row.barFill, row.barGloss }) do
        row.fallback[#row.fallback + 1] = piece
    end
    for _, edge in ipairs(iconEdges) do
        row.fallback[#row.fallback + 1] = edge
    end
    for _, edge in ipairs(barEdges) do
        row.fallback[#row.fallback + 1] = edge
    end

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row.barBack, "LEFT", 8, 0)
    row.text:SetPoint("RIGHT", row.barBack, "RIGHT", -34, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetShadowOffset(1, -1)
    row.text:SetShadowColor(0, 0, 0, 1)
    row.text:SetDrawLayer("OVERLAY", 7)

    row.stack = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.stack:SetPoint("RIGHT", row.barBack, "RIGHT", -8, 0)
    row.stack:SetTextColor(1, 0.92, 0.75)
    row.stack:SetShadowOffset(1, -1)
    row.stack:SetDrawLayer("OVERLAY", 7)

    row.selection = row:CreateTexture(nil, "OVERLAY")
    row.selection:SetPoint("TOPLEFT", -2, 2)
    row.selection:SetPoint("BOTTOMRIGHT", 2, -2)
    row.selection:SetColorTexture(0.25, 0.6, 1, 0.3)
    row.selection:Hide()

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetPoint("TOPLEFT", row.barBack, "TOPLEFT")
    row.highlight:SetPoint("BOTTOMRIGHT", row.barBack, "BOTTOMRIGHT")
    row.highlight:SetColorTexture(1, 1, 1, 0.12)

    attachItemHandlers(row)

    return row
end

local function createHeader(parent)
    local header = CreateFrame("Button", nil, parent)
    header:SetHeight(HEADER_HEIGHT)
    header.background = header:CreateTexture(nil, "BACKGROUND")
    header.background:SetAllPoints()
    header.background:SetColorTexture(1, 1, 1, 0.08)
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.text:SetPoint("LEFT", 8, 0)
    header.text:SetJustifyH("LEFT")
    -- Die Zeile ist 22 Pixel hoch; ein Umbruch würde aus der Überschrift
    -- herauslaufen. Lieber abschneiden, sobald rechts der Knopf steht.
    header.text:SetWordWrap(false)
    header.toggle = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.toggle:SetPoint("RIGHT", -8, 0)

    -- Rechts in der Überschrift: diese Kategorie auf eine eigene Leiste
    -- legen. Der Knopf steht genau dort, wo man die Kategorie ohnehin
    -- ansieht - als Slash-Befehl hätte ihn niemand gefunden.
    header.mirror = CreateFrame("Button", nil, header)
    header.mirror:SetSize(86, 16)
    header.mirror:SetPoint("RIGHT", -24, 0)
    header.mirror.background = header.mirror:CreateTexture(nil, "ARTWORK")
    header.mirror.background:SetAllPoints()
    header.mirror.text = header.mirror:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.mirror.text:SetPoint("CENTER")
    header.mirror:SetScript("OnClick", function(self)
        if self.category ~= nil then
            Dock:ToggleMirror(self.category)
        end
    end)
    header.mirror:SetScript("OnEnter", function(self)
        if self.category == nil then
            return
        end
        if FCD.Mirror:IsMirrored(self.category) then
            FCD.Widgets.ShowTooltip(self, "ANCHOR_LEFT", L["Spiegelung aufheben"],
                L["Die eigene Leiste für diese Kategorie wird entfernt."],
                L["Blizzards eigene Leiste bleibt davon unberührt."])
        else
            FCD.Widgets.ShowTooltip(self, "ANCHOR_LEFT", L["Auf eigene Leiste spiegeln"],
                L["Legt eine Leiste an, die genau diese Kategorie zeigt."],
                L["Wir zeichnen sie selbst: Verschiebungen sind dort sofort zu"],
                L["sehen, ohne Neuladen und ohne Blizzards Viewer anzufassen."])
        end
    end)
    header.mirror:SetScript("OnLeave", FCD.Widgets.HideTooltip)
    header.mirror:Hide()

    header:SetScript("OnClick", function(self)
        state.collapsed[self.sectionID] = not state.collapsed[self.sectionID]
        Dock:Refresh()
    end)
    return header
end

local function createEmptyRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(EMPTY_HEIGHT)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.text:SetPoint("LEFT", 10, 0)
    return row
end

-- ---------------------------------------------------------- Profilauswahl

-- Blizzards Layout-Auswahl ist ein kleines Menü: eine Überschrift, darunter je
-- ein Auswahlpunkt pro Layout, darunter die Aktionen. Das liest sich besser als
-- vier Knöpfe nebeneinander, also bauen wir es nach.
local RADIO_TEXTURE = "Interface\\Buttons\\UI-RadioButton"
local MENU_ROW_HEIGHT = 20
-- Das Menü ist genau so breit wie sein Knopf. Vorher war es breiter und stand
-- rechts über den Fensterrand hinaus.
local PROFILE_BUTTON_WIDTH = 240

local profileMenu

local function menuRow(menu)
    local row = CreateFrame("Button", nil, menu)
    row:SetHeight(MENU_ROW_HEIGHT)

    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 1, 1, 0.12)

    -- Blizzards Auswahlpunkt liegt als Streifen mit vier Zuständen vor:
    -- das erste Viertel ist der leere Ring, das zweite der gefüllte.
    row.radio = row:CreateTexture(nil, "ARTWORK")
    row.radio:SetSize(16, 16)
    row.radio:SetPoint("LEFT", 4, 0)
    row.radio:SetTexture(RADIO_TEXTURE)

    row.mark = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.mark:SetPoint("LEFT", 6, 0)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 26, 0)
    row.text:SetJustifyH("LEFT")

    row.hint = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.hint:SetPoint("LEFT", row.text, "RIGHT", 6, 0)
    row.hint:SetTextColor(1, 0.82, 0)

    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetPoint("LEFT", 2, 0)
    row.line:SetPoint("RIGHT", -2, 0)
    row.line:SetHeight(1)
    row.line:SetColorTexture(1, 1, 1, 0.14)

    return row
end

local function refreshProfileMenu()
    local menu = profileMenu
    if not menu then
        return
    end

    -- Unter der Überschrift und ihrer Trennlinie
    local used, offsetY = 0, -30

    local function addRow(entry)
        used = used + 1
        local row = menu.rows[used]
        if not row then
            row = menuRow(menu)
            menu.rows[used] = row
        end
        local height = entry.separator and 7 or MENU_ROW_HEIGHT
        row:SetHeight(height)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, offsetY)
        row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, offsetY)

        row.radio:SetShown(entry.radio ~= nil)
        if entry.radio then
            row.radio:SetTexCoord(0.25, 0.5, 0, 1)
        else
            row.radio:SetTexCoord(0, 0.25, 0, 1)
        end
        row.mark:SetText(entry.mark or "")
        row.mark:SetTextColor(0.25, 0.9, 0.35)
        row.text:SetText(entry.text or "")
        row.text:SetTextColor(entry.danger and 1 or 1,
            entry.danger and 0.45 or 0.82, entry.danger and 0.4 or 0.6)
        row.hint:SetText(entry.hint or "")
        row.line:SetShown(entry.separator and true or false)
        row.highlight:SetShown(not entry.separator)
        row:SetScript("OnClick", entry.onClick)
        row:EnableMouse(entry.onClick ~= nil)
        row:Show()

        offsetY = offsetY - height
    end

    local active = settings().activeLayoutProfile
    if active and not FCD.Layout:GetProfiles()[active] then
        active = nil
    end

    -- Blizzards eigene Layouts zuerst, damit sichtbar ist, worauf sich unsere
    -- Zuweisungen gerade beziehen. Umschalten geht nur in ihrem Fenster -
    -- ihr Layoutverwalter ist geschützt, ein Aufruf von hier würde die
    -- Sitzung taintieren.
    local blizzardLayouts, activeBlizzard = FCD.Layout:GetBlizzardLayouts()
    if #blizzardLayouts > 0 then
        for _, layout in ipairs(blizzardLayouts) do
            local current = (activeBlizzard ~= nil and layout.id == activeBlizzard)
                or (#blizzardLayouts == 1)
            addRow({
                radio = current,
                text = layout.name,
                hint = current and L["(Blizzard, aktiv)"] or L["(Blizzard)"],
            })
        end
        addRow({ separator = true })
    end

    for _, name in ipairs(FCD.Layout:ListProfiles()) do
        addRow({
            radio = (name == active),
            text = name,
            onClick = function() Dock:SelectProfile(name) end,
        })
    end

    -- Ohne eigene Zuweisungen gilt überall die Standardeinordnung - Blizzard
    -- nennt diesen Zustand "Startlayout", und er ist immer wählbar.
    addRow({
        radio = (active == nil),
        text = L["Startlayout"],
        onClick = function() Dock:SelectProfile(nil) end,
    })

    addRow({ separator = true })

    addRow({
        mark = "+",
        text = L["Neues Layout"],
        onClick = function()
            menu:Hide()
            FCD.ShowPopup("FCD_NEW_LAYOUT_PROFILE")
        end,
    })
    addRow({
        text = L["Importieren"],
        onClick = function()
            menu:Hide()
            FCD:ShowLayoutImport()
        end,
    })
    -- Ein AddOn darf nicht in die Zwischenablage schreiben, anders als
    -- Blizzard. Das Fenster mit vorgewähltem Text ist der nächste Weg dorthin.
    addRow({
        text = L["Zum Kopieren anzeigen"],
        hint = L["(zum Teilen)"],
        onClick = function()
            -- Immer der aktuelle Stand, auch im Startlayout: was man sieht,
            -- ist was man teilt. Ein gespeichertes Profil braucht es dafür nicht.
            local name = active or L["Eigenes Layout"]
            menu:Hide()
            local text, err = FCD.Layout:ExportCurrent(name)
            if not text then
                FCD.Print(L["Nicht lesbar: "] .. tostring(err))
                return
            end
            FCD:ShowText(L["Layout teilen ("] .. name .. ")", text)
        end,
    })
    if active then
        addRow({ separator = true })
        addRow({
            text = L["Verwerfen: "] .. active,
            danger = true,
            onClick = function()
                menu:Hide()
                Dock.profileToDelete = active
                FCD.ShowPopup("FCD_DELETE_LAYOUT_PROFILE", active)
            end,
        })
    end

    for index = used + 1, #menu.rows do
        menu.rows[index]:Hide()
    end
    menu:SetSize(PROFILE_BUTTON_WIDTH, -offsetY + 6)
end

function Dock:SelectProfile(name)
    if profileMenu then
        profileMenu:Hide()
    end
    local ok, err, count
    if name then
        ok, err, count = FCD.Layout:ApplyProfile(name)
    else
        ok, err, count = FCD.Layout:ApplyDefaults()
    end
    if not ok then
        FCD.Print(L["Nicht angewendet: "] .. tostring(err))
        return
    end
    settings().activeLayoutProfile = name
    FCD.Print(string.format(L["%s angewendet (%d Änderungen)."],
        name or L["Startlayout"], count or 0))
    Dock.needsReload = not FCD.Layout:NativeWritesAllowed() and (count or 0) > 0
    Dock:LoadLayout()
    Dock:Refresh()
end

local function buildProfileControl()
    -- Kein UIPanelButtonTemplate: der rote Knopf über die halbe Fensterbreite
    -- hat die Zeile erschlagen. Blizzards Auswahl ist ein dunkles Feld mit
    -- linksbündigem Text und einem kleinen Pfeilkasten rechts.
    local button = CreateFrame("Button", nil, panel)
    button:SetSize(PROFILE_BUTTON_WIDTH, 22)
    button:SetPoint("TOPLEFT", PAD + 42, -66)
    panel.profileButton = button

    -- Die Beschriftung hängt am Feld, nicht an einer eigenen Höhe: nur so
    -- sitzt sie auch dann auf einer Linie, wenn sich die Feldhöhe ändert.
    panel.profileLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.profileLabel:SetPoint("RIGHT", button, "LEFT", -8, 0)
    panel.profileLabel:SetText(L["Profil"])

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetColorTexture(0.06, 0.06, 0.08, 0.95)
    addEdges(button, button, 0.45, 0.40, 0.28, 0.9)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("LEFT", 8, 0)
    button.label:SetPoint("RIGHT", -26, 0)
    button.label:SetJustifyH("LEFT")
    button.label:SetTextColor(1, 0.82, 0)
    -- Damit SetText auf dem Knopf weiterhin diesen Text setzt
    button:SetFontString(button.label)

    button.arrowBox = button:CreateTexture(nil, "ARTWORK")
    button.arrowBox:SetPoint("RIGHT", -2, 0)
    button.arrowBox:SetSize(18, 18)
    button.arrowBox:SetColorTexture(0.17, 0.14, 0.08, 1)

    button.arrow = button:CreateTexture(nil, "OVERLAY")
    button.arrow:SetSize(14, 14)
    button.arrow:SetPoint("CENTER", button.arrowBox, "CENTER", 0, -1)
    button.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    button.arrow:SetVertexColor(1, 0.82, 0)

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetPoint("TOPLEFT", 1, -1)
    button.highlight:SetPoint("BOTTOMRIGHT", -1, 1)
    button.highlight:SetColorTexture(1, 1, 1, 0.09)

    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("DIALOG")
    menu:Hide()
    menu.rows = {}
    menu.background = menu:CreateTexture(nil, "BACKGROUND")
    menu.background:SetAllPoints()
    menu.background:SetColorTexture(0.05, 0.05, 0.07, 0.98)
    addEdges(menu, menu, 0.55, 0.50, 0.35, 1)

    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    menu.title:SetPoint("TOPLEFT", 10, -8)
    menu.title:SetTextColor(0.72, 0.72, 0.76)

    -- Linie unter der Überschrift: trennt sie von den Auswahlpunkten, so wie
    -- in Blizzards Menü.
    menu.titleLine = menu:CreateTexture(nil, "ARTWORK")
    menu.titleLine:SetPoint("TOPLEFT", 8, -24)
    menu.titleLine:SetPoint("TOPRIGHT", -8, -24)
    menu.titleLine:SetHeight(1)
    menu.titleLine:SetColorTexture(1, 1, 1, 0.12)

    -- Klick daneben schließt das Menü; die Sperre liegt unter dem Menü,
    -- damit die Zeilen weiter anklickbar bleiben.
    local blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("DIALOG")
    blocker:SetFrameLevel(1)
    blocker:Hide()
    blocker:SetScript("OnClick", function() menu:Hide() end)
    menu:SetScript("OnShow", function()
        blocker:Show()
        menu:SetFrameLevel(blocker:GetFrameLevel() + 10)
    end)
    menu:SetScript("OnHide", function() blocker:Hide() end)

    button:SetScript("OnClick", function(self)
        if menu:IsShown() then
            menu:Hide()
            return
        end
        menu.title:SetText(L["Für "] .. (UnitName("player") or L["diesen Charakter"]))
        refreshProfileMenu()
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:Show()
    end)

    profileMenu = menu
    panel.profileMenu = menu
end

function Dock:Build()
    if panel then
        return panel
    end

    panel = CreateFrame("Frame", "ForeverCooldownsDock", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(panelWidth(), panelHeight())
    panel:SetFrameStrata("HIGH")
    panel:SetMovable(true)
    -- Nicht über den Bildschirmrand hinaus: eine von Blizzard übernommene
    -- Lage kann für unser höheres Fenster zu weit oben liegen.
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    -- Einen Gegenstand vom Zeiger hier fallen lassen nimmt ihn auf - wie bei
    -- einer Aktionsleiste.
    panel:SetScript("OnReceiveDrag", function()
        Dock:AcceptCursorItem()
    end)
    panel:SetScript("OnMouseUp", function(_, button)
        -- Umschalt + Rechtsklick holt das Panel zurück an Blizzards Fenster.
        -- Wer es einmal in eine Ecke geschoben hat, findet es sonst nur über
        -- den Befehl wieder.
        if button == "RightButton" and IsShiftKeyDown() then
            Dock:ResetPosition()
            return
        end
        Dock:AcceptCursorItem()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        settings().dockSide = "FREE"
        settings().dockPoint = { point = point, relativePoint = relativePoint,
            x = math.floor(x or 0), y = math.floor(y or 0) }
    end)
    panel:Hide()
    -- Escape schließt das Panel, auch wenn Blizzards Fenster im Kampf klemmt
    tinsert(UISpecialFrames, "ForeverCooldownsDock")

    -- Geht unseres zu, soll Blizzards Fenster mitgehen - sonst bleibt die
    -- halbe Oberfläche stehen. Im Kampf unterbleibt es, weil Show/Hide auf
    -- ihrem Frame dort blockiert wird.
    panel:SetScript("OnHide", function()
        -- Aufklappmenüs hängen an UIParent und blieben sonst samt ihrer
        -- bildschirmweiten Klicksperre stehen, wenn Escape das Panel schließt.
        if FCD.Widgets and FCD.Widgets.CloseDropdowns then
            FCD.Widgets.CloseDropdowns()
        end
        if panel.profileMenu then
            panel.profileMenu:Hide()
        end
        if InCombatLockdown() then
            return
        end
        local window = blizzardWindow()
        if window and windowIsShown(window) then
            pcall(window.Hide, window)
        end
    end)

    panel.tiles = {}
    panel.headers = {}
    panel.emptyRows = {}
    panel.barRows = {}
    panel.layout = {}

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.title:SetPoint("TOP", 0, -6)
    panel.title:SetText(L["Forever Cooldowns"])

    -- Neben dem Schließen-Kreuz: aufs große Fenster wechseln, in dem sich
    -- mehr einstellen lässt als in der schmalen Spalte.
    local expand = CreateFrame("Button", nil, panel)
    -- Blizzards Vergrößern-Textur ist 32x32 mit Rand; kleiner gesetzt wirkt
    -- der Pfeil verloren. Ausgerichtet wird am Schließen-Kreuz der Vorlage,
    -- damit beide auf einer Höhe sitzen.
    expand:SetSize(32, 32)
    if panel.CloseButton then
        expand:SetPoint("RIGHT", panel.CloseButton, "LEFT", 6, 0)
    else
        expand:SetPoint("TOPRIGHT", -28, -4)
    end

    -- Derselbe Pfeil, den die Karte zum Vergrößern nutzt. Lädt die Textur
    -- nicht, bleibt darunter ein Zeichen sichtbar statt einer leeren Fläche.
    expand.fallback = expand:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    expand.fallback:SetAllPoints()
    expand.fallback:SetText("+")
    expand:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")

    -- Der Pfeil folgt dem Zustand: nach aussen, solange das Fenster schmal
    -- ist, nach innen, sobald es breit ist. Vorher zeigte er immer nach
    -- aussen und behauptete damit im breiten Fenster das Gegenteil dessen,
    -- was der Klick tut.
    function expand.UpdateArrow()
        local art = state.wide and "UI-Panel-SmallerButton" or "UI-Panel-BiggerButton"
        expand:SetNormalTexture("Interface\\Buttons\\" .. art .. "-Up")
        expand:SetPushedTexture("Interface\\Buttons\\" .. art .. "-Down")
    end
    expand.UpdateArrow()

    expand:SetScript("OnClick", function()
        Dock:SetWide(not state.wide)
    end)
    expand:SetScript("OnEnter", function(self)
        FCD.Widgets.ShowTooltip(self, "ANCHOR_LEFT",
            state.wide and L["Schmale Ansicht"] or L["Breite Ansicht"],
            state.wide and L["Zurück an Blizzards Fenster andocken."]
                or L["Dieselben Daten, nur mit mehr Platz pro Zeile."])
    end)
    expand:SetScript("OnLeave", FCD.Widgets.HideTooltip)
    panel.expandButton = expand

    -- Reiter am rechten Rand, wie in Blizzards Fenster: "Zauber" und
    -- "Stärkungseffekte" mit jeweils eigenen Abschnitten.
    -- Vorher standen sie als eigene Spalte daneben und wirkten wie eine
    -- zweite Leiste. Jetzt sitzen sie auf einer gemeinsamen Schiene und
    -- überlappen den Fensterrahmen, damit sie angesetzt aussehen.
    local rail = panel:CreateTexture(nil, "BACKGROUND")
    rail:SetPoint("TOPLEFT", panel, "TOPRIGHT", -4, -(TAB_TOP - 6))
    rail:SetSize(TAB_WIDTH + 4, #TABS * TAB_HEIGHT + 12)
    rail:SetColorTexture(0.07, 0.07, 0.09, 0.96)
    addEdges(panel, rail, 0, 0, 0, 0.9)
    panel.tabRail = rail

    panel.tabButtons = {}
    for index, tab in ipairs(TABS) do
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(TAB_WIDTH, TAB_HEIGHT)
        button:SetPoint("TOPLEFT", panel, "TOPRIGHT", -2,
            -(TAB_TOP + (index - 1) * TAB_HEIGHT))

        button.background = button:CreateTexture(nil, "BACKGROUND")
        button.background:SetAllPoints()

        -- Goldener Streifen an der Fensterseite: der aktive Reiter zeigt
        -- damit zum Inhalt, statt nur heller zu sein.
        button.accent = button:CreateTexture(nil, "BORDER")
        button.accent:SetPoint("TOPLEFT")
        button.accent:SetPoint("BOTTOMLEFT")
        button.accent:SetWidth(3)

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("CENTER", 2, 0)
        button.icon:SetTexture(tab.icon)
        -- Zaubersymbole haben einen Rand, der weggeschnitten gehört;
        -- freigestellte Sinnbilder verlören dabei ihre Kanten.
        if tab.iconCrop == false then
            button.icon:SetTexCoord(0, 1, 0, 1)
        else
            button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        -- Dünne Trennlinie zwischen den Laschen, damit die Schiene gegliedert
        -- wirkt und nicht wie ein durchgehender Kasten.
        button.divider = button:CreateTexture(nil, "OVERLAY")
        button.divider:SetPoint("BOTTOMLEFT", 5, 0)
        button.divider:SetPoint("BOTTOMRIGHT", -4, 0)
        button.divider:SetHeight(1)
        button.divider:SetColorTexture(1, 1, 1, 0.07)
        button.divider:SetShown(index < #TABS)

        -- Eigene Grafik statt vier Klötzchen: innen durchsichtig, außen
        -- deckend, mit weicher runder Innenkante. Sie wird zur Laufzeit auf
        -- die Farbe des Untergrunds eingefärbt.
        --
        -- Bewusst eine Abdeckung und keine Maske: lädt eine Maske nicht,
        -- verschwindet das ganze Symbol. Fehlt diese Datei, bleiben die Ecken
        -- eckig - mehr passiert nicht.
        button.rounding = button:CreateTexture(nil, "OVERLAY", nil, 1)
        button.rounding:SetAllPoints(button.icon)
        button.rounding:SetTexture(ROUND_CORNERS)

        button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
        button.highlight:SetPoint("TOPLEFT", 3, -1)
        button.highlight:SetPoint("BOTTOMRIGHT", -2, 1)
        button.highlight:SetColorTexture(1, 1, 1, 0.15)

        button.tab = tab
        button:SetScript("OnClick", function(self)
            state.tab = self.tab.id
            wipe(state.selection)
            Dock:Refresh()
        end)
        button:SetScript("OnEnter", function(self)
            FCD.Widgets.ShowTooltip(self, "ANCHOR_RIGHT", L[self.tab.label])
        end)
        button:SetScript("OnLeave", FCD.Widgets.HideTooltip)

        panel.tabButtons[index] = button
    end

    -- Waagerechte Trennlinie zwischen den Kopfzeilen-Gruppen
    local function divider(y)
        local line = panel:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", PAD, y)
        line:SetPoint("TOPRIGHT", -PAD, y)
        line:SetHeight(1)
        line:SetColorTexture(1, 1, 1, 0.12)
        return line
    end

    -- Zeile 1: Suche
    local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(panelWidth() - 2 * PAD - 54, 20)
    search:SetPoint("TOPLEFT", PAD + 8, -32)
    search:SetAutoFocus(false)

    -- InputBoxTemplate kennt keinen Platzhalter; ein eigener FontString, der
    -- verschwindet sobald Text da ist.
    search.placeholder = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    search.placeholder:SetPoint("LEFT", 4, 0)
    search.placeholder:SetText(L["Suchtext eingeben"])

    local function updatePlaceholder(self)
        search.placeholder:SetShown((self:GetText() or "") == "")
    end
    search:SetScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        updatePlaceholder(self)
        Dock:Refresh()
    end)
    search:SetScript("OnEditFocusGained", function()
        search.placeholder:Hide()
    end)
    search:SetScript("OnEditFocusLost", updatePlaceholder)
    search:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    panel.search = search

    -- Aufnehmen gehört neben die Suche, nicht in die Werkzeugspalte: die gibt
    -- es nur in der breiten Ansicht, und etwas hinzuzufügen ist eine
    -- Kernfunktion des Reiters, keine Nebensache.
    local addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addButton:SetSize(26, 20)
    addButton:SetPoint("LEFT", search, "RIGHT", 6, 0)
    addButton:SetText("+")
    addButton:SetScript("OnClick", function()
        FCD.ShowPopup(currentTab().entryKind == "spell"
            and "FCD_ADD_SPELL" or "FCD_ADD_ITEM")
    end)
    addButton:SetScript("OnEnter", function(self)
        local spells = currentTab().entryKind == "spell"
        FCD.Widgets.ShowTooltip(self, "ANCHOR_BOTTOMLEFT",
            spells and L["Zauber aufnehmen"] or "Gegenstand aufnehmen",
            spells and L["Beliebige Zauber-ID oder eingefügten Link - auch was im Zauberbuch nicht steht."]
                or L["Beliebige Gegenstands-ID oder eingefügten Link - auch was gerade nicht im Beutel liegt."],
            L["Ziehen geht auch."])
    end)
    addButton:SetScript("OnLeave", FCD.Widgets.HideTooltip)
    panel.addButton = addButton

    divider(-58)

    -- Zeile 2: Profile
    buildProfileControl()

    divider(-94)

    -- Zeile 3: Filter
    local stackCheck = FCD.Widgets.CreateCheck(panel, L["Ränge stapeln"], function()
        return state.stackRanks
    end, function(value)
        state.stackRanks = value
        wipe(state.selection)
        Dock:Refresh()
    end)
    stackCheck:SetPoint("TOPLEFT", PAD, -102)

    local knownCheck = FCD.Widgets.CreateCheck(panel, L["nur gelernte"], function()
        return state.onlyKnown
    end, function(value)
        state.onlyKnown = value
        Dock:Refresh()
    end)
    knownCheck:SetPoint("TOPLEFT", PAD + 150, -102)

    panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.hint:SetPoint("TOPLEFT", PAD, -128)
    panel.hint:SetWidth(panelWidth() - 2 * PAD)
    panel.hint:SetJustifyH("LEFT")
    panel.hint:SetText(L["Ziehen verschiebt zwischen den Abschnitten,"]
        .. L[" Doppelklick blendet aus."])

    divider(-144)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -152)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 24, 84)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(contentWidth(), 1)
    scroll:SetScrollChild(content)
    panel.scroll = scroll
    panel.content = content

    -- Fußzeile: Modus, Rückgängig, und der Neuladen-Knopf nur dann, wenn
    -- er überhaupt etwas bewirkt.
    panel.instantCheck = FCD.Widgets.CreateCheck(panel, L["sofort wirksam"], function()
        return FCD.Layout:NativeWritesAllowed()
    end, function(value)
        settings().allowNativeWrites = value
        if value then
            FCD.Print(L["Sofortmodus an - Änderungen wirken ohne Neuladen."])
        else
            FCD.Print(L["Sofortmodus aus - Änderungen wirken beim nächsten Neuladen,"])
            FCD.Print(L["dafür bleibt Blizzards Aurenanzeige unberührt."])
        end
        Dock:Refresh()
    end)
    -- Fußzeile als abgesetzter Streifen wie bei Blizzard: eigener Grund, eine
    -- Trennlinie nach oben, und alles darin auf einer Höhe. Vorher standen
    -- Schalter und Knopf an den Fensterkanten und der Zustandstext noch
    -- einmal darunter - drei Zeilen für eine Information.
    local footer = CreateFrame("Frame", nil, panel)
    footer:SetPoint("BOTTOMLEFT", 8, 8)
    footer:SetPoint("BOTTOMRIGHT", -8, 8)
    footer:SetHeight(30)
    footer.background = footer:CreateTexture(nil, "BACKGROUND")
    footer.background:SetAllPoints()
    footer.background:SetColorTexture(0, 0, 0, 0.45)
    footer.line = footer:CreateTexture(nil, "BORDER")
    footer.line:SetPoint("TOPLEFT")
    footer.line:SetPoint("TOPRIGHT")
    footer.line:SetHeight(1)
    footer.line:SetColorTexture(1, 1, 1, 0.14)
    panel.footer = footer

    panel.instantCheck:SetPoint("LEFT", footer, "LEFT", 6, 0)

    local undoButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    undoButton:SetSize(110, 22)
    undoButton:SetPoint("RIGHT", footer, "RIGHT", -6, 0)
    undoButton:SetText(L["Rückgängig"])
    undoButton:SetScript("OnClick", function()
        local ok, info = FCD.Layout:Restore()
        FCD.Print(ok and (L["Sicherung von "] .. tostring(info) .. L[" wiederhergestellt."])
            or (L["Nichts zurückzunehmen: "] .. tostring(info)))
        if ok then
            -- Die Sicherung ist der rohe Blob; der wirkt erst beim Neuladen
            Dock.needsReload = true
            Dock:LoadLayout()
            Dock:Refresh()
        end
    end)

    panel.reloadButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.reloadButton:SetHeight(22)
    panel.reloadButton:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 4)
    panel.reloadButton:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 4)
    panel.reloadButton:SetText(L["Änderungen anwenden (Neuladen)"])
    panel.reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)
    panel.reloadButton:Hide()

    -- ------------------------------------------------- Werkzeugspalte (breit)

    local sidebar = CreateFrame("Frame", nil, panel)
    sidebar:SetWidth(SIDEBAR_WIDTH - PAD)
    sidebar:SetPoint("TOPRIGHT", -PAD, -152)
    sidebar:SetPoint("BOTTOMRIGHT", -PAD, 84)
    sidebar:Hide()
    panel.sidebar = sidebar

    local sidebarTitle = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sidebarTitle:SetPoint("TOPLEFT", 0, 0)
    sidebarTitle:SetText(L["Auswahl"])

    sidebar.detail = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sidebar.detail:SetPoint("TOPLEFT", 0, -20)
    sidebar.detail:SetWidth(SIDEBAR_WIDTH - PAD)
    sidebar.detail:SetJustifyH("LEFT")
    sidebar.detail:SetSpacing(2)

    local moveLabel = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    moveLabel:SetPoint("TOPLEFT", 0, -78)
    moveLabel:SetText(L["Verschieben nach"])

    -- Ein Knopf je Kategorie des aktuellen Reiters; Beschriftung und Ziel
    -- werden beim Aktualisieren gesetzt, weil sie vom Reiter abhängen.
    sidebar.assignButtons = {}
    local offsetY = -96
    for index = 1, 5 do
        local button = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
        button:SetSize(SIDEBAR_WIDTH - PAD, 22)
        button:SetPoint("TOPLEFT", 0, offsetY)
        button:SetScript("OnClick", function(self)
            if self.itemTarget ~= nil then
                Dock:AssignItemSelection(self.itemTarget)
            elseif self.category ~= nil then
                Dock:AssignSelection(self.category)
            end
        end)
        button:Hide()
        sidebar.assignButtons[index] = button
        offsetY = offsetY - 25
    end

    local filterLabel = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterLabel:SetPoint("TOPLEFT", 0, offsetY - 8)
    filterLabel:SetText(L["Weitere Filter"])
    offsetY = offsetY - 28

    local cooldownCheck = FCD.Widgets.CreateCheck(sidebar, L["nur mit Abklingzeit"], function()
        return state.onlyWithCooldown
    end, function(value)
        state.onlyWithCooldown = value
        Dock:Refresh()
    end)
    cooldownCheck:SetPoint("TOPLEFT", 0, offsetY)
    offsetY = offsetY - 24

    local passiveCheck = FCD.Widgets.CreateCheck(sidebar, L["Passive zeigen"], function()
        return state.showPassive
    end, function(value)
        state.showPassive = value
        Dock:Refresh()
    end)
    passiveCheck:SetPoint("TOPLEFT", 0, offsetY)
    offsetY = offsetY - 32

    local addSpellButton = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    addSpellButton:SetSize(SIDEBAR_WIDTH - PAD, 22)
    addSpellButton:SetPoint("TOPLEFT", 0, offsetY)
    addSpellButton:SetText(L["+ Zauber aufnehmen..."])
    addSpellButton:SetScript("OnClick", function()
        FCD.ShowPopup("FCD_ADD_SPELL")
    end)
    offsetY = offsetY - 26

    local addItemButton = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    addItemButton:SetSize(SIDEBAR_WIDTH - PAD, 22)
    addItemButton:SetPoint("TOPLEFT", 0, offsetY)
    addItemButton:SetText(L["+ Gegenstand aufnehmen..."])
    addItemButton:SetScript("OnClick", function()
        FCD.ShowPopup("FCD_ADD_ITEM")
    end)
    offsetY = offsetY - 26

    -- Der Knopf "Eigene Leisten..." ist hier heraus: das alte große Fenster
    -- zeigt dieselben Daten noch einmal anders und stiftet mehr Verwirrung
    -- als es nützt. Erreichbar bleibt es über  /fcd bars.

    local blizzButton = CreateFrame("Button", nil, sidebar, "UIPanelButtonTemplate")
    blizzButton:SetSize(SIDEBAR_WIDTH - PAD, 22)
    blizzButton:SetPoint("TOPLEFT", 0, offsetY)
    blizzButton:SetText(L["Blizzards Fenster..."])
    blizzButton:SetScript("OnClick", function()
        Dock:OpenBlizzardWindow()
    end)
    blizzButton:SetScript("OnEnter", function(self)
        FCD.Widgets.ShowTooltip(self, "ANCHOR_LEFT", L["Blizzards Abklingzeit-Fenster"],
            L["Das Layout wechseln geht nur dort - ihr Layoutverwalter ist"]
                .. L[" geschützt."])
    end)
    blizzButton:SetScript("OnLeave", FCD.Widgets.HideTooltip)
    offsetY = offsetY - 26

    -- Der Zustandstext sitzt in derselben Zeile zwischen Schalter und Knopf,
    -- statt eine eigene Zeile darunter zu belegen.
    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.status:SetPoint("LEFT", panel.instantCheck.text, "RIGHT", 12, 0)
    panel.status:SetPoint("RIGHT", undoButton, "LEFT", -10, 0)
    panel.status:SetJustifyH("LEFT")
    panel.status:SetWordWrap(false)

    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetSize(TILE_SIZE, TILE_SIZE)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:Hide()
    ghost.icon = ghost:CreateTexture(nil, "OVERLAY")
    ghost.icon:SetAllPoints()
    ghost.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    ghost.icon:SetAlpha(0.85)
    ghost.count = ghost:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    ghost.count:SetPoint("BOTTOMRIGHT", 2, -2)
    ghost:SetScript("OnUpdate", function(self)
        local x, y = cursorPosition()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    end)

    return panel
end

local function acquire(pool, factory, index)
    local widget = pool[index]
    if not widget then
        widget = factory(panel.content)
        pool[index] = widget
    end
    return widget
end

-- Der Knopf soll unterscheiden zwischen "es gibt keine Profile" und "es gibt
-- welche, nur ist keines gewählt". Vorher stand in beiden Fällen "kein Profil",
-- und gespeicherte Profile sahen dadurch aus, als wären sie verloren.
local function updateProfileButton()
    if not panel or not panel.profileButton then
        return
    end
    local active = settings().activeLayoutProfile
    if active and FCD.Layout:GetProfiles()[active] then
        panel.profileButton:SetText(active)
        return
    end
    -- Ohne eigenes Profil zeigt der Knopf, auf welchem Blizzard-Layout wir
    -- gerade arbeiten - das ist die Angabe, die mit ihrem Fenster übereinstimmt.
    local layouts, activeID = FCD.Layout:GetBlizzardLayouts()
    for _, layout in ipairs(layouts) do
        if (activeID ~= nil and layout.id == activeID) or #layouts == 1 then
            panel.profileButton:SetText(layout.name)
            return
        end
    end
    panel.profileButton:SetText(L["Startlayout"])
end

function Dock:Refresh()
    if not panel then
        return
    end

    local sections = buildSections()

    -- Der Profilknopf wird zuerst gesetzt, nicht zuletzt: er stand früher am
    -- Ende der Funktion, und jeder Fehler weiter oben ließ ihn auf altem Text
    -- stehen - was wie ein verlorenes Profil aussah.
    updateProfileButton()

    -- Der Bearbeitungsmodus kann zwischen zwei Aufbauten aufgehen; die
    -- Stapelebene muss dann mitziehen.
    applyStrata()

    -- Aufnehmen gibt es nur auf den eigenen Reitern; Blizzards Kategorien
    -- nehmen nichts von außen an.
    if panel.addButton then
        panel.addButton:SetShown(currentTab().ownBar and true or false)
    end

    -- Der Hinweis muss zum Reiter passen: auf dem Gegenstandsreiter gibt es
    -- keine Kategorien, in die man etwas verschieben könnte.
    if panel.hint then
        if currentTab().ownBar then
            -- Kurz halten: der Hinweis hat nur eine Zeile Platz, bei zwei
            -- Zeilen schiebt er sich in den ersten Abschnitt.
            panel.hint:SetText(L["Doppelklick legt auf die Leiste,"]
                .. L[" Rechtsklick entfernt Eigene."])
        else
            panel.hint:SetText(L["Ziehen verschiebt zwischen den Abschnitten,"]
                .. L[" Doppelklick blendet aus."])
        end
    end

    -- Blizzards Grafik wird nur übernommen, wenn wir ihre Vorlage zweifelsfrei
    -- erkennen. Der Beweis sind unsere eigenen Symbole: taucht in ihrem Fenster
    -- ein Eintrag mit genau einem davon auf, ist das ein echter Eintrag.
    -- Die Liste kommt aus allen bekannten Abklingzeiten, nicht aus den gerade
    -- sichtbaren: Blizzards Fenster kann auf einem anderen Reiter stehen oder
    -- etwas zeigen, das unsere Suche gerade herausfiltert.
    if FCD.Art then
        local icons = {}
        for _, cooldownID in ipairs(Dock.staticOrder or {}) do
            local spellID = spellOf(cooldownID)
            local _, icon = Compat.GetSpellInfo(spellID)
            if type(icon) == "number" then
                icons[icon] = true
            end
        end
        FCD.Art:SetIconSet(icons)
    end
    adoptArtSizes()

    local tileIndex, headerIndex, emptyIndex, barIndex, offsetY = 0, 0, 0, 0, 0
    local width = contentWidth()
    local columns = columnCount()
    wipe(panel.layout)

    for _, section in ipairs(sections) do
        headerIndex = headerIndex + 1
        local header = acquire(panel.headers, createHeader, headerIndex)
        header.sectionID = section.id
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offsetY)
        header:SetWidth(width)
        -- Gesamtzahl und gelernte getrennt: erklärt Unterschiede zu
        -- Blizzards Fenster, ohne dass man zählen muss.
        header.text:SetText(section.headerText
            or string.format(L["%s  (%d, davon %d gelernt)"],
                section.title, #section.items, section.knownCount or 0))
        header.toggle:SetText(state.collapsed[section.id] and "+" or "-")

        -- Spiegeln lohnt nur bei einer echten Kategorie: "Nicht angezeigt"
        -- als Leiste wäre ein Widerspruch, und die eigenen Reiter haben
        -- ohnehin schon ihre Leiste.
        local mirrorable = type(section.category) == "number"
            and section.category >= 0
            and FCD.Mirror.CATEGORY_NAMES[section.category] ~= nil
        -- Der Titel endet vor dem, was rechts steht - sonst schöbe sich ein
        -- langer Kategoriename unter den Knopf.
        header.text:ClearAllPoints()
        header.text:SetPoint("LEFT", 8, 0)
        header.text:SetPoint("RIGHT",
            mirrorable and header.mirror or header.toggle, "LEFT", -6, 0)

        if mirrorable then
            local on = FCD.Mirror:IsMirrored(section.category)
            header.mirror.category = section.category
            header.mirror.text:SetText(on and L["gespiegelt"] or L["spiegeln"])
            header.mirror.background:SetColorTexture(
                on and 0.20 or 0.10, on and 0.34 or 0.10, on and 0.20 or 0.12, 0.9)
            header.mirror:Show()
        else
            header.mirror.category = nil
            header.mirror:Hide()
        end
        header:Show()

        panel.layout[#panel.layout + 1] = { header = header, section = section }
        offsetY = offsetY + HEADER_HEIGHT + 2

        if not state.collapsed[section.id] then
            if #section.items == 0 then
                emptyIndex = emptyIndex + 1
                local row = acquire(panel.emptyRows, createEmptyRow, emptyIndex)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offsetY)
                row:SetWidth(width)
                row.text:SetText(section.emptyText or "")
                row:Show()
                offsetY = offsetY + EMPTY_HEIGHT
            elseif section.category == TRACKED_BAR_CATEGORY then
                -- Balken statt Raster: eine Zeile je Eintrag, volle Breite
                for _, item in ipairs(section.items) do
                    barIndex = barIndex + 1
                    local row = acquire(panel.barRows, createBarRow, barIndex)
                    row.item = item
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", panel.content, "TOPLEFT", 0, -offsetY)
                    row:SetWidth(width)
                    styleBarRow(row)
                    row:SetHeight(BAR_ROW_HEIGHT)
                    row.icon:SetTexture(item.icon or 134400)
                    row.icon:SetDesaturated(not item.known)
                    row:SetAlpha(item.known and 1 or 0.5)
                    -- Ungelerntes bekommt einen matten Balken statt eines bunten
                    if item.known then
                        setBarColor(row, 0.86, 0.50, 0.16, 0.58, 0.29, 0.06)
                    else
                        setBarColor(row, 0.40, 0.40, 0.43, 0.22, 0.22, 0.25)
                    end
                    row.text:SetText(item.label or "?")
                    row.stack:SetText((item.stackSize and item.stackSize > 1) and item.stackSize or "")
                    row.selection:SetShown(state.selection[item.key] and true or false)
                    row:Show()
                    offsetY = offsetY + BAR_ROW_HEIGHT + 2
                end
                offsetY = offsetY + 4
            else
                for position, item in ipairs(section.items) do
                    tileIndex = tileIndex + 1
                    local tile = acquire(panel.tiles, createTile, tileIndex)
                    tile.item = item

                    local column = (position - 1) % columns
                    local row = math.floor((position - 1) / columns)
                    tile:ClearAllPoints()
                    tile:SetPoint("TOPLEFT", panel.content, "TOPLEFT",
                        column * (TILE_SIZE + TILE_SPACING),
                        -(offsetY + row * (TILE_SIZE + TILE_SPACING)))

                    decorate(tile, "tile")
                    tile:SetSize(TILE_SIZE, TILE_SIZE)
                    tile.icon:SetTexture(item.icon or 134400)
                    tile.icon:SetDesaturated(not item.known)
                    tile:SetAlpha(item.known and 1 or 0.4)
                    if tile.artApplied then
                        FCD.Art:SetActive(tile, item.known)
                    end
                    if item.rank then
                        tile.rank:SetText(item.rank)
                        tile.rank:Show()
                    else
                        tile.rank:Hide()
                    end
                    if item.stackSize and item.stackSize > 1 then
                        tile.stack:SetText(item.stackSize)
                        tile.stack:Show()
                    else
                        tile.stack:Hide()
                    end
                    if state.selection[item.key] then
                        tile.selection:Show()
                    else
                        tile.selection:Hide()
                    end
                    tile:Show()
                end
                local rows = math.ceil(#section.items / columns)
                offsetY = offsetY + rows * (TILE_SIZE + TILE_SPACING) + 6
            end
        end
    end

    for index = tileIndex + 1, #panel.tiles do
        panel.tiles[index]:Hide()
        panel.tiles[index].item = nil
    end
    for index = headerIndex + 1, #panel.headers do
        panel.headers[index]:Hide()
    end
    for index = emptyIndex + 1, #panel.emptyRows do
        panel.emptyRows[index]:Hide()
    end
    for index = barIndex + 1, #panel.barRows do
        panel.barRows[index]:Hide()
        panel.barRows[index].item = nil
    end

    panel.content:SetHeight(math.max(1, offsetY))

    panel.instantCheck.Refresh()

    -- Aktiver Reiter: heller Rahmen, die anderen abgedunkelt
    for index, button in ipairs(panel.tabButtons) do
        local active = button.tab.id == state.tab

        -- Blizzards Reiter tragen Sinnbilder - Stoppuhr, Blitz -, keine
        -- Zaubersymbole. Ist eines abgeholt, kommt es hierher; solange nicht,
        -- macht das Einfärben aus dem Zaubersymbol wenigstens ein Sinnbild.
        if not button.glyphApplied and FCD.Art then
            local ok, width, height = FCD.Art:ApplyTabIcon(button.icon, index)
            if ok then
                button.glyphApplied = true
                -- In der Größe zeichnen, in der Blizzard es zeichnet. Jedes
                -- Umrechnen auf ein anderes Maß macht die Kanten stufig, und
                -- genau deshalb wirkten die Reiter pixelig.
                local limit = TAB_HEIGHT - 12
                local scale = 1
                if (height or 0) > limit then
                    scale = limit / height
                end
                button.icon:SetSize((width or 24) * scale, (height or 24) * scale)
            end
        end
        -- Eigene Farben statt Goldstich: das Einfärben war nur dazu da, ein
        -- Zaubersymbol wie Blizzards Sinnbilder aussehen zu lassen. Ohne
        -- diesen Vergleich sieht ein Symbol in seinen echten Farben besser aus.
        button.icon:SetDesaturated(false)
        button.icon:SetVertexColor(1, 1, 1)
        if not button.glyphApplied then
            button.icon:SetSize(24, 24)
        end

        local backR, backG, backB
        if active then
            backR, backG, backB = 0.17, 0.14, 0.08
            button.accent:SetColorTexture(1, 0.82, 0, 1)
            button:SetAlpha(1)
        else
            backR, backG, backB = 0.05, 0.05, 0.07
            button.accent:SetColorTexture(0, 0, 0, 0)
            -- Der inaktive Reiter tritt über die Deckkraft zurück, nicht über
            -- die Farbe - so bleibt das Symbol erkennbar.
            button:SetAlpha(0.7)
        end
        button.background:SetColorTexture(backR, backG, backB, active and 1 or 0.9)
        if button.rounding then
            button.rounding:SetVertexColor(backR, backG, backB, 1)
        end
    end

    -- Zielknöpfe der Werkzeugspalte folgen dem Reiter
    if state.wide then
        -- Auf dem Gegenstandsreiter gibt es keine Kategorien, aber dieselbe
        -- Geste: Auswahl treffen, Ziel anklicken.
        local itemTargets = currentTab().ownBar
            and { { label = L["Auf die Leiste"], value = true },
                  { label = L["Von der Leiste nehmen"], value = false } }
            or nil
        local targets = currentTab().categories
        for index, button in ipairs(panel.sidebar.assignButtons) do
            button.category = nil
            button.itemTarget = nil
            if itemTargets then
                local target = itemTargets[index]
                if target then
                    button.itemTarget = target.value
                    button:SetText(target.label)
                    button:Show()
                else
                    button:Hide()
                end
            else
                local category = targets[index]
                button.category = category
                if category == nil then
                    button:Hide()
                else
                    button:SetText(categoryName(category))
                    button:Show()
                end
            end
        end
    end

    -- Zwei Gründe für den Neuladen-Knopf, mit verschiedenem Anlass:
    -- im sicheren Modus, weil die Änderung sonst nicht greift; im
    -- Sofortmodus, weil Blizzards Viewer seit dem Schreibvorgang Fehler wirft.
    local instant = FCD.Layout:NativeWritesAllowed()
    local tainted = FCD.Layout.taintedThisSession
    -- In die Zeile kommt nur, was man sonst nirgends sieht. Der Modus steht
    -- als Häkchen daneben, die Zahl der ausgewählten Symbole sieht man an
    -- deren Rahmen - beides hier zu wiederholen füllt nur Platz.
    local parts = {}

    if instant then
        self.needsReload = false
        if tainted then
            panel.reloadButton:SetText(L["Neu laden - behebt Blizzards Fehlermeldungen"])
            panel.reloadButton:Show()
            parts[#parts + 1] = "Blizzards Viewer wirft Fehler"
        else
            panel.reloadButton:Hide()
        end
    else
        if self.needsReload then
            -- Mit gespiegelten Leisten ist die Änderung längst zu sehen;
            -- offen ist dann nur noch Blizzards eigene Anzeige. Das ist ein
            -- anderer Satz als "Änderungen stehen aus".
            if FCD.Mirror:HasAny() then
                panel.reloadButton:SetText(L["Blizzards eigene Leisten nachziehen (Neuladen)"])
                parts[#parts + 1] = L["Auf den gespiegelten Leisten schon zu sehen"]
            else
                panel.reloadButton:SetText(L["Änderungen anwenden (Neuladen)"])
                parts[#parts + 1] = L["Änderungen stehen aus"]
            end
            panel.reloadButton:Show()
        else
            panel.reloadButton:Hide()
        end
    end

    if self.layoutError then
        parts[#parts + 1] = self.layoutError
    end
    panel.status:SetText(table.concat(parts, L["   |   "]))

    -- Werkzeugspalte: was ist gerade ausgewählt?
    if state.wide then
        local chosen, sample, ranks = 0, nil, 0
        for _, item in pairs(state.selection) do
            chosen = chosen + 1
            sample = sample or item
            ranks = ranks + #item.cooldownIDs
        end
        if chosen == 0 then
            panel.sidebar.detail:SetText(L["Nichts ausgewählt.\nSymbole anklicken, Strg für mehrere."])
        elseif chosen == 1 then
            panel.sidebar.detail:SetText(string.format("%s\n%s\n%d Abklingzeit(en)",
                sample.label or "?", categoryName(sample.category), ranks))
        else
            panel.sidebar.detail:SetText(string.format(L["%d Fähigkeiten\n%d Abklingzeit(en)"],
                chosen, ranks))
        end
    end
end

-- ------------------------------------------------------------- Andocken

local driver = CreateFrame("Frame")
local accumulated = 0

driver:SetScript("OnUpdate", function(_, elapsed)
    if not FCD.db or not settings().dockToBlizzard then
        return
    end
    accumulated = accumulated + elapsed
    if accumulated < POLL_INTERVAL then
        return
    end
    accumulated = 0

    local window = blizzardWindow()
    local shown = window and windowIsShown(window) or false

    -- Ihr Fenster gehört zu einem Addon, das erst bei Bedarf lädt. Der Haken
    -- lässt sich deshalb nicht einmalig beim Start setzen, sondern erst wenn
    -- es da ist - danach kostet der Aufruf nichts mehr.
    if not Dock.windowHooked then
        Dock:HookBlizzardWindow()
    end

    -- Die Ausnahme gilt nur, solange ihr Fenster wirklich offen ist.
    if Dock.allowBlizzardWindow and not shown then
        Dock.allowBlizzardWindow = nil
    end

    -- Der Takt ist nur noch das Netz: das Verdrängen selbst passiert im
    -- OnShow ihres Fensters, bevor gezeichnet wird. Hier landet nur, was der
    -- Haken nicht erwischt hat - etwa wenn ihr Fenster schon offen war, als
    -- der Haken gesetzt wurde.
    if shown and Dock:ShouldReplace() then
        Dock:TakeOverFrom(window)
        return
    end

    -- Solange beide offen sind: mitziehen, wenn im Blizzard-Fenster etwas
    -- geändert wurde. Der rohe Blob wird dafür nur verglichen, entschlüsselt
    -- wird erst bei einer echten Abweichung - und das über die C-Funktion,
    -- also ohne Taint.
    if shown and Dock.blizzardWasShown and panel and panel:IsShown() then
        local raw = Compat.GetLayoutData()
        if type(raw) == "string" and raw ~= Dock.lastSeenRaw then
            Dock.lastSeenRaw = raw
            Dock:LoadLayout()
            Dock:Refresh()
        end
        -- Blizzards Einträge sind erst da, wenn ihr Fenster aufgebaut ist.
        -- Klappt das Abschauen erst jetzt, muss einmal neu gezeichnet werden.
        if FCD.Art and not FCD.Art.learned and FCD.Art:Learn() then
            Dock:Refresh()
        end
    end

    if shown == (Dock.blizzardWasShown and true or false) then
        return
    end
    Dock.blizzardWasShown = shown

    if shown then
        Dock:Build()
        anchorPanel()
        Dock:LoadLayout()
        Dock:Refresh()
        -- Nicht über das große Fenster legen, solange das offen ist
        panel:Show()
    elseif panel then
        panel:Hide()
        -- Beim Schließen einmal erinnern, solange die Sitzung tainted ist
        if FCD.Layout.taintedThisSession and not Dock.reloadReminderShown then
            Dock.reloadReminderShown = true
            FCD.Print(L["Blizzards Viewer wirft seit der Änderung Fehler bei Auren."])
            FCD.Print(L["Ein /reload räumt das auf - die Änderungen bleiben erhalten."])
        end
    end
end)
Dock.driver = driver

-- ------------------------------------------------- Verdrängen ihres Fensters

function Dock:ShouldReplace()
    if not FCD.db or settings().replaceBlizzardWindow == false then
        return false
    end
    -- Im Kampf nicht: Hide auf ihrem Fenster aus getaintetem Code wird dort
    -- blockiert und erzeugt "Interface-Aktion fehlgeschlagen".
    return not self.allowBlizzardWindow and not InCombatLockdown()
end

-- Der eigentliche Ablauf. Steht getrennt, damit TakeOverFrom ihn absichern
-- kann, ohne dass ein Fehler die Sperre stehen lässt.
local function takeOver(self, window)
    self:Build()

    -- Ihres zuerst schließen, dann ausrichten: solange es offen ist, dockt
    -- unseres daran an. Im Bearbeitungsmodus steht es woanders als sonst,
    -- und unseres landete mit - unter Umständen außerhalb des Bildes.
    --
    -- Geschlossen wird über settleTakeover: über den Bearbeitungsmodus ist
    -- mit einem einzelnen Durchlauf weder ihr Fenster zu noch unseres offen.
    settleTakeover(window)

    anchorPanel()
    self:LoadLayout()
    self:Refresh()
    panel:Show()
    -- Erst nach dem Anzeigen: Raise wirkt nur auf einem sichtbaren Rahmen,
    -- und solange ihres noch steht, muss unseres darüber liegen.
    applyStrata()

    -- Nur ins Log, nicht in den Chat. Bleibt ihr Fenster trotzdem stehen,
    -- steht hier hinterher, ob wir überhaupt dran waren und auf welcher
    -- Ebene beide lagen.
    local manager = _G.EditModeManagerFrame
    FCD.LogOnly(string.format(
        L["Verdrängt: Bearbeitungsmodus=%s, ihres noch offen=%s, ihre Ebene=%s, unsere Ebene=%s"],
        tostring(type(manager) == "table" and windowIsShown(manager) or false),
        tostring(window and windowIsShown(window) or false),
        tostring(window and type(window.GetFrameStrata) == "function"
            and select(2, pcall(window.GetFrameStrata, window)) or "-"),
        tostring(panel:GetFrameStrata())))

end

function Dock:TakeOverFrom(window)
    -- Das Schließen ihres Fensters kann auf unser eigenes OnHide laufen, und
    -- das schließt wiederum ihres. Eine Sperre bricht den Kreis.
    if self.takingOver then
        return
    end
    self.takingOver = true

    -- Abgesichert, damit die Sperre auch bei einem Fehler wieder aufgeht.
    -- Vorher blieb sie nach einem einzigen Fehlschlag für den Rest der
    -- Sitzung stehen - und danach tat jeder weitere Versuch stumm nichts:
    -- ihr Fenster zu, unseres nicht auf, keine Meldung. Genau dieses Bild
    -- ist im Bearbeitungsmodus aufgetreten.
    local ok, err = pcall(takeOver, self, window)
    self.takingOver = nil

    -- Der Takt merkt sich, ob ihr Fenster zuletzt offen war, und schließt
    -- unseres mit, sobald es zugeht. Beim Verdrängen ist genau das falsch:
    -- wir haben es ja selbst geschlossen. Ohne diese Zeile ging unseres auf
    -- und einen Takt später wieder zu.
    self.blizzardWasShown = false

    if not ok then
        FCD.LogOnly(L["Verdrängen fehlgeschlagen: "] .. tostring(err))
        FCD.Print(L["Panel ließ sich nicht öffnen - Einzelheiten in /fcd log."])
    end
end

-- Im OnShow abfangen statt im Takt: OnShow läuft mitten im Show-Aufruf, also
-- bevor das Fenster gezeichnet wird. Vorher hat der Takt es bis zu einer
-- Fünftelsekunde stehen lassen - man sah es aufblitzen.
--
-- HookScript hängt sich an ihren Handler an, statt ihn zu ersetzen: ihre
-- eigene Logik läuft unverändert weiter.
function Dock:HookBlizzardWindow()
    if self.windowHooked then
        return true
    end
    local window = blizzardWindow()
    if not window or type(window.HookScript) ~= "function" then
        return false
    end
    local ok = pcall(window.HookScript, window, "OnShow", function(self)
        -- Ins Log, bevor irgendetwas entschieden wird. Nur so lässt sich
        -- hinterher unterscheiden, ob der Haken gar nicht feuert oder ob er
        -- feuert und die Übernahme absagt - von außen sieht beides gleich
        -- aus: ihr Fenster steht offen, unseres nicht.
        FCD.LogOnly(L["Ihr Fenster geht auf."])
        if not Dock:ShouldReplace() then
            FCD.LogOnly(string.format(
                L["Keine Übernahme: Einstellung=%s, Ausnahme=%s, Kampf=%s"],
                tostring(FCD.db and settings().replaceBlizzardWindow),
                tostring(Dock.allowBlizzardWindow and true or false),
                tostring(InCombatLockdown() and true or false)))
            return
        end
        -- Sofort zuschlagen, nicht erst im nächsten Bilddurchlauf: OnShow
        -- läuft, bevor der Rahmen gezeichnet wird. Wer hier schließt, lässt
        -- ihn nie erscheinen - ein Durchlauf später sieht man ihn aufblitzen.
        --
        -- Ein früherer Versuch damit schlug fehl, weil danach unseres
        -- unsichtbar blieb. Das lag aber an der Stapelebene im
        -- Bearbeitungsmodus, nicht am Zeitpunkt.
        --
        -- Ein Fehler von uns würde hier auch ihren Aufruf abbrechen. Deshalb
        -- fängt TakeOverFrom selbst ab; hier kann nichts mehr durchschlagen.
        Dock:TakeOverFrom(self)
    end)
    if not ok then
        FCD.LogOnly(L["Haken auf ihrem Fenster ließ sich nicht setzen."])
        return false
    end
    self.windowHooked = true
    FCD.LogOnly(L["Haken auf ihrem Fenster gesetzt."])
    return true
end

-- Blizzards Fenster auf Wunsch doch holen. Zwei Dinge gehen nur dort: das
-- Layout wechseln (ihr Verwalter ist geschützt) und ihre Grafik abschauen,
-- die unseren Symbolen die runden Rahmen gibt.
function Dock:OpenBlizzardWindow()
    local window = blizzardWindow()
    if not window then
        FCD.Print(L["Blizzards Fenster ist in diesem Client nicht vorhanden."])
        return false
    end
    if InCombatLockdown() then
        FCD.Print(L["Im Kampf wird ihr Fenster nicht angefasst."])
        return false
    end
    -- Die Verdrängung für diesen einen Aufruf aussetzen, sonst schließt der
    -- Takt es sofort wieder.
    self.allowBlizzardWindow = true
    if not pcall(window.Show, window) then
        self.allowBlizzardWindow = nil
        FCD.Print(L["Ihr Fenster ließ sich nicht öffnen."])
        return false
    end
    return true
end

-- Zurück in den Auslieferungszustand der Lage: angedockt rechts an Blizzards
-- Fenster, ohne eigene Merkposition.
function Dock:ResetPosition()
    local config = settings()
    config.dockSide = "RIGHT"

    -- Solange wir ihr Fenster verdrängen, gibt es nichts zum Andocken. Die
    -- sinnvolle Ausgangslage ist dann dessen eigene: FCD steht dort, wo man
    -- den Abklingzeit-Manager erwartet. Ihre Lage wird abgelesen, nicht
    -- geraten - ein ausgeblendetes Fenster behält seinen Anker.
    config.dockPoint = blizzardWindowPoint()

    if panel then
        anchorPanel()
    end
end

function Dock:SetSide(side)
    local config = settings()
    config.dockSide = side
    if side ~= "FREE" then
        config.dockPoint = nil
    end
    if panel then
        anchorPanel()
    end
end

function Dock:Toggle()
    self:Build()
    if panel:IsShown() then
        panel:Hide()
        return false
    end
    self:LoadLayout()
    self:Refresh()
    anchorPanel()
    panel:Show()
    return true
end

-- Setzt alle Maße neu, wenn zwischen schmal und breit gewechselt wird.
-- Alles, was relativ am Panel hängt (Trennlinien, Scrollbereich, Knopfreihen),
-- zieht von selbst mit; nur feste Breiten müssen nachgezogen werden.
function Dock:LayoutChrome()
    if not panel then
        return
    end
    panel:SetSize(panelWidth(), panelHeight())
    panel.search:SetSize(panelWidth() - 2 * PAD - 54, 20)
    panel.hint:SetWidth(panelWidth() - 2 * PAD)
    panel.content:SetWidth(contentWidth())
    -- Knopf und Zustandstext hängen jetzt an der Fußzeile und wachsen mit;
    -- ihre Breite muss hier nicht mehr nachgezogen werden.
    if panel.expandButton then
        panel.expandButton.fallback:SetText(state.wide and "-" or "+")
        if panel.expandButton.UpdateArrow then
            panel.expandButton.UpdateArrow()
        end
    end

    -- Der Scrollbereich endet in der breiten Ansicht vor der Werkzeugspalte
    panel.scroll:ClearAllPoints()
    panel.scroll:SetPoint("TOPLEFT", PAD, -152)
    panel.scroll:SetPoint("BOTTOMRIGHT",
        -PAD - 24 - (state.wide and SIDEBAR_WIDTH or 0), 84)
    panel.sidebar:SetShown(state.wide)
end

function Dock:SetWide(value)
    state.wide = value and true or false
    wipe(state.selection)
    self:LayoutChrome()
    anchorPanel()
    self:Refresh()
end

function Dock:IsShown()
    return panel and panel:IsShown()
end

-- Zurück zur schmalen Ansicht, sobald das große Fenster geschlossen wird -
-- aber nur, solange Blizzards Fenster überhaupt noch offen ist.
-- Blendet das Panel aus, solange das große Fenster offen ist. Blizzards
-- Fenster bleibt dabei stehen - anders als beim Schließen über das Kreuz,
-- wo beide zusammen zugehen sollen.
function Dock:HideForEditor()
    if not panel or not panel:IsShown() then
        return
    end
    local previous = panel:GetScript("OnHide")
    panel:SetScript("OnHide", nil)
    panel:Hide()
    panel:SetScript("OnHide", previous)
    if FCD.Widgets and FCD.Widgets.CloseDropdowns then
        FCD.Widgets.CloseDropdowns()
    end
    if panel.profileMenu then
        panel.profileMenu:Hide()
    end
end

function Dock:ShowIfBlizzardOpen()
    local window = blizzardWindow()
    if not window or not windowIsShown(window) then
        return false
    end
    self:Build()
    anchorPanel()
    self:LoadLayout()
    self:Refresh()
    panel:Show()
    return true
end
