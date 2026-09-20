local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local Layout = {}
FCD.Layout = Layout

-- Empirisch am lebenden Client ermittelt (siehe /fcd snapshot + /fcd diff):
--   * die Schlüssel der Zuordnung sind die Werte aus Enum.CooldownViewerCategory
--   * -1 ist die Liste der ausgeblendeten Einträge
--   * die Nachbarliste hält die Anzeigereihenfolge; neu Eingeblendetes
--     wandert dort ans Ende
-- Der Blob speichert nur Abweichungen vom Standard, nicht den Vollzustand.
local HIDDEN_CATEGORY = -1
local MAX_BACKUPS = 10

Layout.HIDDEN_CATEGORY = HIDDEN_CATEGORY

-- ------------------------------------------------- Blizzards eigene Schicht

-- Der Client legt seine komplette Lua-Implementierung offen. Ihre Funktionen
-- aufzurufen ist verlässlicher, als das serialisierte Layout nachzubauen:
-- sie erledigen das Anwenden und Speichern selbst.
-- Die globalen Tabellen CooldownViewerDataProvider und
-- CooldownViewerLayoutManagerMixin sind bloße Vorlagen ohne Zustand; ein
-- Aufruf darauf verpufft wirkungslos. Die laufenden Objekte hängen am
-- Einstellungsfenster (ermittelt mit /fcd instances).
local function settingsFrame()
    local frame = _G.CooldownViewerSettings
    if type(frame) == "table" then
        return frame
    end
    -- Ihr Addon lädt erst bei Bedarf. Anstoßen statt aufgeben.
    if Compat.EnsureCooldownViewerLoaded() then
        frame = _G.CooldownViewerSettings
        if type(frame) == "table" then
            return frame
        end
    end
    return nil
end

-- Holt ein Objekt über seinen Getter, fällt auf das gleichnamige Feld
-- zurück und prüft, ob es die erwartete Methode wirklich trägt.
local function liveObject(getterName, fieldName, requiredMethod)
    local frame = settingsFrame()
    if not frame then
        return nil
    end

    local getter = frame[getterName]
    if type(getter) == "function" then
        local ok, object = pcall(getter, frame)
        if ok and type(object) == "table" and type(object[requiredMethod]) == "function" then
            return object
        end
    end

    local object = frame[fieldName]
    if type(object) == "table" and type(object[requiredMethod]) == "function" then
        return object
    end
    return nil
end

local function dataProvider()
    return liveObject("GetDataProvider", "dataProvider", "SetCooldownToCategory")
end

local function layoutManager()
    return liveObject("GetLayoutManager", "layoutManager", "SaveLayouts")
end

Layout.GetDataProvider = dataProvider
Layout.GetLayoutManager = layoutManager

-- Die Anzeigedaten des laufenden Modells.
--
-- Die Schicht, aus der ihr Einstellungsfenster zeichnet, und die letzte, die
-- wir gefunden haben. Sie enthält vier Tabellen:
--   orderedCooldownIDs        die 172 Einträge der Klasse, in ihrer Reihenfolge
--   defaultOrderedCooldownIDs dieselben in der Vorgabereihenfolge
--   cooldownInfoByID          je Eintrag die Angaben FÜR DAS AKTIVE LAYOUT
--   cooldownDefaultsByID      je Eintrag die Vorgaben
--
-- cooldownInfoByID ist der Unterschied, an dem alles hing: die C-Funktion
-- GetCooldownViewerCooldownInfo liefert die globale Vorgabe, in der
-- isInvisible immer false ist und die Kategorie die Standardkategorie. Erst
-- hier steht, was im aktiven Layout tatsächlich gilt.
local function displayData()
    local provider = dataProvider()
    if not provider or type(provider.GetDisplayData) ~= "function" then
        return nil
    end
    local ok, data = pcall(provider.GetDisplayData, provider)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

Layout.GetDisplayData = displayData


-- WARNUNG, empirisch belegt: Ruft AddOn-Code diese Objekte auf, bleiben sie
-- für die restliche Sitzung als "tainted" markiert. Danach scheitert
-- Blizzards eigener Cooldown-Viewer beim Lesen von Auren:
--   GetUnitAuras(): Auras cannot be accessed when secret while tainted
-- Das beschädigt genau die Funktion, die wir verbessern wollen. Der Weg ist
-- deshalb standardmäßig aus und nur nach ausdrücklicher Freigabe nutzbar.
function Layout:NativeWritesAllowed()
    return FCD.db and FCD.db.settings and FCD.db.settings.allowNativeWrites == true
end

-- Im Kampf niemals über Blizzards Objekte schreiben. Der Taint blockiert
-- sonst ihre eigenen geschützten Aktionen - unter anderem lässt sich ihr
-- Fenster dann nicht mehr schließen ("Interface-Aktion fehlgeschlagen").
-- Hat sich der Sofortmodus in dieser Sitzung als wirkungslos erwiesen,
-- wird er nicht mehr angeboten - sonst scheitert jeder weitere Versuch auf
-- dieselbe Weise, nur lauter.
function Layout:CanWriteNativeNow()
    if self.nativeIneffective then
        return false
    end
    return self:CanWriteNativeNowInner()
end

function Layout:CanWriteNativeNowInner()
    return self:NativeWritesAllowed() and not InCombatLockdown() and self:NativeAPIExists()
end

function Layout:HasNativeAPI()
    return dataProvider() ~= nil and self:NativeWritesAllowed()
end

-- Ob die Objekte überhaupt existieren, unabhängig von der Freigabe
function Layout:NativeAPIExists()
    return dataProvider() ~= nil
end

-- Die Standardkategorie steht im Cache-Eintrag selbst und bleibt dort auch
-- dann stehen, wenn der Spieler den Eintrag abweichend zugeordnet hat.
function Layout:GetDefaultCategory(cooldownID)
    local info = Compat.GetCooldownInfo(cooldownID)
    if info and info.category ~= nil then
        return info.category
    end
    -- Rückfall für Builds ohne dieses Feld
    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        if category.value >= 0 then
            for _, id in ipairs(Compat.GetCategorySet(category.value) or {}) do
                if id == cooldownID then
                    return category.value, category.name
                end
            end
        end
    end
    return nil
end

-- Wo eine Abklingzeit wirklich liegt.
--
-- Das hier war der teuerste Irrtum dieser Sitzung: Vorher stand hier
-- info.category aus dem Cache-Eintrag - und das ist die Standardkategorie,
-- die sich nie ändert. Die Prüfung "hat sich etwas bewegt?" konnte einen
-- Erfolg deshalb gar nicht sehen, hat jeden Schreibversuch für wirkungslos
-- erklärt und den Sofortmodus für die restliche Sitzung abgeschaltet.
-- Die wirksame Einordnung steht ausschließlich in ihren Listen.
local function effectiveCategoryOf(provider, cooldownID)
    -- Geprüft wird an derselben Stelle, die auch ihr Fenster zeichnet.
    --
    -- Vorher wurde an GetOrderedCooldownIDsForCategory geprüft. Die nennt
    -- nur die fünfzehn Einträge, die gerade auf den Leisten liegen - eine
    -- Änderung an einem der anderen 157 konnte dort gar nicht auftauchen.
    -- Jeder Schreibversuch galt deshalb als "ohne Wirkung", auch wenn er
    -- gewirkt hat. Das ist derselbe Fehler wie zuvor bei info.category, nur
    -- eine Schicht weiter oben.
    local data = displayData()
    local infoByID = data and data.cooldownInfoByID
    local info = type(infoByID) == "table" and infoByID[cooldownID] or nil
    if type(info) == "table" then
        if info.isInvisible then
            return HIDDEN_CATEGORY
        end
        return info.category
    end
    return false
end

-- Die Kette, die ihr Fenster nach einer Änderung durchläuft.
-- Die Kette, die ihr Fenster nach einer Änderung durchläuft - in zwei Teilen.
--
-- Beim Suchen der richtigen Methode wird sie nach JEDEM Versuch gebraucht,
-- sonst sieht man die Wirkung nicht. SaveLayouts serialisiert dabei aber das
-- ganze Layout, und bei vierzig ausgewählten Abklingzeiten mal vierundzwanzig
-- Versuchen stand das Spiel. Zum Prüfen genügen die beiden billigen Schritte;
-- gespeichert wird einmal am Ende.
local function applyChain(provider, manager, full)
    local steps = {
        { object = provider, name = "MarkDirty" },
        { object = provider, name = "CheckBuildDisplayData" },
    }
    if full then
        steps[#steps + 1] = { object = manager, name = "SaveLayouts" }
        steps[#steps + 1] = { object = manager, name = "NotifyListeners" }
    end
    local applied = {}
    for _, step in ipairs(steps) do
        local object = step.object
        if object and type(object[step.name]) == "function" then
            local ok, err = pcall(object[step.name], object)
            applied[#applied + 1] = step.name
                .. (ok and "" or (" (Fehler: " .. Compat.SafeToString(err) .. ")"))
        end
    end
    return table.concat(applied, ", ")
end

-- Rückgabe: erfolg, fehlertext, angewandte Schritte
function Layout:SetCategoryNative(cooldownID, category)
    -- Hat sich in dieser Sitzung schon gezeigt, dass keine der Methoden
    -- wirkt, wird die Suche nicht für jede weitere Abklingzeit wiederholt.
    -- Ohne das lief sie vierzig Mal - mit vierundzwanzig Aufrufen und ebenso
    -- vielen Neuaufbauten der Anzeigedaten je Durchlauf.
    if self.nativeIneffective then
        return false, L["Der Client nimmt die Änderung an, führt sie aber nicht aus"]
    end
    local provider = dataProvider()
    if not provider then
        return false, L["CooldownViewerDataProvider steht nicht zur Verfügung"]
    end

    local manager = layoutManager()
    if manager and type(manager.AreChangesAllowed) == "function" then
        local ok, allowed = pcall(manager.AreChangesAllowed, manager)
        if ok and allowed == false then
            return false, L["Der Client erlaubt derzeit keine Änderungen (im Kampf?)"]
        end
    end

    local before = effectiveCategoryOf(provider, cooldownID)

    -- Welcher Aufruf in diesem Build wirkt, ist nicht vorhersagbar, und
    -- geraten wurde in dieser Sache genug. Also der Reihe nach probieren und
    -- nach jedem nachsehen, ob sich etwas bewegt hat. Der erste, der wirkt,
    -- wird für die restliche Sitzung gemerkt.
    -- Das aktive Layout, falls eine der Methoden es als erstes Argument
    -- erwartet. Genau daran ist WriteCooldownCategoryToLayout gescheitert:
    -- "bad argument #1 to 'pairs' (table expected, got nil)" - der Aufruf
    -- bekam die Abklingzeit-ID, wo das Layout hingehört.
    local activeLayout, activeLayoutID
    if manager and type(manager.GetActiveLayout) == "function" then
        local ok, value = pcall(manager.GetActiveLayout, manager)
        if ok and type(value) == "table" then
            activeLayout = value
        end
    end
    if manager and type(manager.GetActiveLayoutID) == "function" then
        local ok, value = pcall(manager.GetActiveLayoutID, manager)
        if ok and type(value) == "number" then
            activeLayoutID = value
        end
    end

    -- Vier Methoden, drei mögliche Argumentformen.
    --
    -- Die Fehlermeldungen des Clients sagen, dass jede von ihnen etwas
    -- anderes erwartet: WriteCooldownInfo_Category reicht das erste Argument
    -- an GetCooldownViewerCooldownInfo weiter, will also die Abklingzeit-ID;
    -- WriteCooldownCategoryToLayout ruft darauf pairs() auf, will also eine
    -- Tabelle. Statt das weiter zu erraten, werden die Formen durchprobiert
    -- und nach jedem Versuch nachgesehen, ob sich etwas bewegt hat. Die
    -- Kombination, die wirkt, gilt für den Rest der Sitzung - danach ist es
    -- ein einziger Aufruf je Abklingzeit.
    local shapes = {
        { name = "id" },
        { name = "layout", value = activeLayout },
        { name = "layoutID", value = activeLayoutID },
    }
    local methods = {
        { object = provider, name = "ChangeCooldownInfoCategoryByID" },
        { object = provider, name = "SetCooldownToCategory" },
        { object = manager, name = "WriteCooldownInfo_Category" },
        { object = manager, name = "WriteCooldownCategoryToLayout" },
    }
    local candidates = {}
    for _, method in ipairs(methods) do
        for _, shape in ipairs(shapes) do
            if shape.name == "id" or shape.value ~= nil then
                candidates[#candidates + 1] = {
                    object = method.object,
                    name = method.name,
                    shape = shape.name,
                    prefix = shape.value,
                }
            end
        end
    end
    -- Was schon einmal gewirkt hat, zuerst.
    if self.workingWrite then
        table.insert(candidates, 1, self.workingWrite)
    end

    -- "Nicht angezeigt" ist bei Blizzard nicht eine Kategorie, sondern zwei:
    -- HiddenActive (-1) und HiddenPassive (-2). Unser Fenster hat dafür
    -- einen Abschnitt, also muss beim Schreiben die richtige der beiden
    -- getroffen werden - welche, hängt am Eintrag. Statt das zu bestimmen,
    -- werden beide probiert; die falsche bleibt wirkungslos.
    local targets = { category }
    if category == HIDDEN_CATEGORY then
        targets[#targets + 1] = -2
    end

    local tried = {}
    for _, target in ipairs(targets) do
        for _, candidate in ipairs(candidates) do
            local object = candidate.object
            if object and type(object[candidate.name]) == "function" then
                local ok, err
                if candidate.prefix ~= nil then
                    ok, err = pcall(object[candidate.name], object,
                        candidate.prefix, cooldownID, target)
                else
                    ok, err = pcall(object[candidate.name], object, cooldownID, target)
                end
                local label = candidate.name .. "[" .. tostring(candidate.shape or "id")
                    .. "](" .. target .. ")"
                if not ok then
                    tried[#tried + 1] = label .. " wirft: " .. Compat.SafeToString(err)
                else
                    local steps = applyChain(provider, manager, false)
                    local after = effectiveCategoryOf(provider, cooldownID)
                    if after ~= before then
                        self.workingWrite = candidate
                        self.nativeIneffective = nil
                        if not self.taintedThisSession then
                            self.taintedThisSession = true
                            FCD.LogOnly(L["Sofortmodus wirkt über "] .. label)
                        end
                        return true, nil, label .. " -> " .. steps
                    end
                    tried[#tried + 1] = label .. L[" ohne Wirkung"]
                end
            end
        end
    end

    -- Keiner hat gewirkt. Einmal reicht: der Rest der Sitzung nimmt den
    -- sicheren Weg, statt es jedes Mal erneut zu versuchen.
    -- Die ganze Kette gehört ins Protokoll, nicht in den Chat: dort wird sie
    -- abgeschnitten, und gerade das abgeschnittene Ende enthielt beim letzten
    -- Mal die Begründung.
    self.nativeIneffective = true
    FCD.LogOnly(L["Sofortmodus, alle Versuche für Abklingzeit "] .. cooldownID
        .. ": " .. table.concat(tried, "; "))
    return false, L["Der Client nimmt die Änderung an, führt sie aber nicht aus"]
        .. L[" (/fcd log zeigt jeden Versuch)"]
end

-- Nach einer Reihe von Änderungen einmal speichern und die Zuhörer wecken.
-- Während der Reihe wäre das je Eintrag ein vollständiges Serialisieren des
-- Layouts.
function Layout:FinishNativeBatch()
    local provider = dataProvider()
    if not provider then
        return false
    end
    applyChain(provider, layoutManager(), true)
    return true
end

-- Legt einen Wiederherstellungspunkt an, falls der Client das anbietet.
function Layout:CreateNativeRestorePoint()
    local manager = layoutManager()
    if manager and type(manager.CreateRestorePoint) == "function" then
        local ok = pcall(manager.CreateRestorePoint, manager)
        return ok
    end
    return false
end

function Layout:ResetToNativeRestorePoint()
    local manager = layoutManager()
    if manager and type(manager.ResetToRestorePoint) == "function" then
        local ok, err = pcall(manager.ResetToRestorePoint, manager)
        return ok, not ok and Compat.SafeToString(err) or nil
    end
    return false, L["Kein Wiederherstellungspunkt verfügbar"]
end

-- --------------------------------------------------------------- Blob-Ebene

local function indexOf(list, value)
    if type(list) ~= "table" then
        return nil
    end
    for index, entry in ipairs(list) do
        if entry == value then
            return index
        end
    end
    return nil
end

local function removeValue(list, value)
    local index = indexOf(list, value)
    if index then
        table.remove(list, index)
        return true
    end
    return false
end

-- ------------------------------------------------------------------ Lesen

-- Rückgabe: zustand, fehlertext
function Layout:Read()
    local raw, err = Compat.GetLayoutData()
    if err or type(raw) ~= "string" then
        return nil, err or L["GetLayoutData lieferte keine Zeichenkette"]
    end

    local data, decodeErr, _, recipe = Compat.DecodeLayoutString(raw)
    if not data then
        return nil, L["Entschlüsseln fehlgeschlagen: "] .. tostring(decodeErr)
    end

    local sections = Compat.FindLayoutSections(data)
    if not sections or not sections.categories then
        return nil, L["Kategorie-Zuordnung im Blob nicht gefunden"]
    end

    local prefix = Compat.SplitLayoutString(raw)
    return {
        raw = raw,
        prefix = prefix,
        data = data,
        recipe = recipe,
        categories = sections.categories,
        order = sections.order,
    }
end

-- Welche Kategorie ist für diese Abklingzeit hinterlegt? nil heißt
-- "keine Abweichung", also Standard.
function Layout:GetAssignedCategory(state, cooldownID)
    for category, list in pairs(state.categories) do
        if indexOf(list, cooldownID) then
            return category
        end
    end
    return nil
end

function Layout:IsHidden(state, cooldownID)
    local hidden = state.categories[HIDDEN_CATEGORY]
    return indexOf(hidden, cooldownID) ~= nil
end

-- ---------------------------------------------------------------- Ändern

-- Alle Änderungen arbeiten auf dem gelesenen Zustand und schreiben nicht
-- selbst; erst Commit überträgt sie. So bleibt ein Abbruch folgenlos.

function Layout:SetHidden(state, cooldownID, hidden)
    state.categories[HIDDEN_CATEGORY] = state.categories[HIDDEN_CATEGORY] or {}
    local list = state.categories[HIDDEN_CATEGORY]

    if hidden then
        if indexOf(list, cooldownID) then
            return false
        end
        list[#list + 1] = cooldownID
        return true
    end

    local removed = removeValue(list, cooldownID)
    if removed and state.order then
        -- Der Client schiebt neu Eingeblendetes ans Ende der Reihenfolge
        if removeValue(state.order, cooldownID) then
            state.order[#state.order + 1] = cooldownID
        end
    end
    -- Leere Listen entfernt der Client ebenfalls
    if #list == 0 then
        state.categories[HIDDEN_CATEGORY] = nil
    end
    return removed
end

function Layout:SetCategory(state, cooldownID, category)
    for key, list in pairs(state.categories) do
        if key ~= category then
            removeValue(list, cooldownID)
            if #list == 0 then
                state.categories[key] = nil
            end
        end
    end
    if category == nil then
        return true
    end
    state.categories[category] = state.categories[category] or {}
    local list = state.categories[category]
    if not indexOf(list, cooldownID) then
        list[#list + 1] = cooldownID
    end
    return true
end

-- Verschiebt einen Eintrag innerhalb der Anzeigereihenfolge.
function Layout:MoveTo(state, cooldownID, position)
    if not state.order then
        return false
    end
    if not removeValue(state.order, cooldownID) then
        return false
    end
    position = math.max(1, math.min(position, #state.order + 1))
    table.insert(state.order, position, cooldownID)
    return true
end

-- ------------------------------------------------------------- Profile

-- Ein Profil hält die Abweichungen vom Standard fest: cooldownID -> Kategorie.
-- Das ist genau der Teil, den der Spieler eingestellt hat, und bleibt damit
-- klein genug zum Teilen.

local PROFILE_PREFIX = "FCDL1:"

-- Statische Einordnung aller Abklingzeiten: cooldownID -> Kategorie
-- Die Standardeinordnung je Abklingzeit: wohin ein Eintrag gehört, wenn
-- niemand ihn verschoben hat.
--
-- Vorher kamen Menge und Wert aus GetCooldownViewerCategorySet. Beides war
-- falsch: die Abfragen nennen nur die gerade aktiven, und sie nennen deren
-- Ist-Zustand, nicht die Vorgabe. Wer eine Zuweisung zurücknahm, bekam
-- damit den Zustand zurückgeschrieben, den er gerade loswerden wollte.
-- Die Vorgabe steht im Cache-Eintrag unter "category".
function Layout:GetStaticMap()
    local map, order = {}, {}
    local function add(cooldownID)
        if map[cooldownID] ~= nil then
            return
        end
        local info = Compat.GetCooldownInfo(cooldownID)
        if info and info.category ~= nil then
            map[cooldownID] = info.category
            order[#order + 1] = cooldownID
        end
    end
    for _, cooldownID in ipairs(self:GetBlizzardCatalog() or {}) do
        add(cooldownID)
    end
    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        for _, cooldownID in ipairs(Compat.GetCategorySet(category.value) or {}) do
            add(cooldownID)
        end
    end
    return map, order
end

local function assignmentsOf(state)
    local assignments = {}
    for category, list in pairs(state.categories) do
        for _, cooldownID in ipairs(list) do
            assignments[cooldownID] = category
        end
    end
    return assignments
end

-- Blizzards eigene Layouts. Der Pfad ist nicht dokumentiert, aber gemessen:
-- CooldownViewerSettings.dataSerialization.layoutManager.layouts. Gelesen wird
-- nur - geschrieben wird dort nichts, das wäre ihr geschütztes Objekt.
-- Rückgabe: liste aus {id, name}, aktiveID
function Layout:GetBlizzardLayouts()
    local settings = _G.CooldownViewerSettings
    if type(settings) ~= "table" then
        return {}, nil
    end
    local manager
    pcall(function()
        manager = settings.dataSerialization and settings.dataSerialization.layoutManager
    end)
    if type(manager) ~= "table" then
        return {}, nil
    end

    local list = {}
    pcall(function()
        for _, entry in pairs(manager.layouts or {}) do
            if type(entry) == "table" then
                -- Die Feldnamen sind gemessen, nicht geraten (/fcd provider):
                -- layoutName und layoutID. Vorher stand hier "name", und
                -- deshalb blieb die Liste in unserem Auswahlfeld leer,
                -- obwohl der Verwalter zwei Layouts führte.
                local name = rawget(entry, "layoutName") or rawget(entry, "name")
                local id = rawget(entry, "layoutID") or rawget(entry, "ID")
                    or rawget(entry, "id")
                if type(name) == "string" and name ~= "" then
                    list[#list + 1] = { id = id, name = name }
                end
            end
        end
    end)
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)

    local active
    pcall(function()
        active = rawget(manager, "activeLayoutID") or rawget(manager, "activeLayout")
            or rawget(manager, "selectedLayoutID")
    end)
    if type(active) == "table" then
        active = rawget(active, "layoutID") or rawget(active, "id")
    end
    return list, active
end

-- Blizzards vollständiger, nach Klasse gefilterter Katalog.
--
-- Die lange Suche danach, festgehalten damit sie sich nicht wiederholt:
--   * GetCooldownViewerCategorySet nennt nur die aktiven (hier 15)
--   * GetCooldownViewerCooldownInfo kennt alle 880 - aber aller Klassen,
--     und ein Klassenmerkmal trägt der Eintrag nicht
--   * die Reihenfolgeliste im Layout ist in einem frischen Layout leer
--   * GetOrderedCooldownIDsForCategory nennt ebenfalls nur die aktiven
-- Erst GetOrderedCooldownIDs liefert die 172, die ein Krieger hat - genau
-- die Menge, die auch in einem gewachsenen Layout stand.
--
-- Das ist ein Aufruf auf Blizzards Objekt. Schreibende Aufrufe dort taintet
-- der Client nachweislich; ob reines Lesen dasselbe tut, ist nicht belegt.
-- Deshalb abschaltbar: /fcd catalog voll nimmt stattdessen den Durchlauf
-- über alle IDs, der nichts anfasst, dafür alle Klassen zeigt.
-- Rückgabe: liste von AbklingzeitIDs, oder nil
function Layout:GetBlizzardCatalog()
    if FCD.db and FCD.db.settings and FCD.db.settings.catalogSource == "scan" then
        return nil
    end
    local provider = dataProvider()
    if not provider then
        return nil
    end
    -- Aus den Anzeigedaten, denn die führen dieselbe Reihenfolge wie ihr
    -- Fenster.
    local data = displayData()
    if data and type(data.orderedCooldownIDs) == "table" and #data.orderedCooldownIDs > 0 then
        return data.orderedCooldownIDs
    end

    -- Die aktuelle Reihenfolge zuerst, die Vorgabe als Rückfall: beide
    -- liefern dieselbe Menge, die erste aber in der Reihenfolge, die der
    -- Spieler in ihrem Fenster hergestellt hat.
    for _, name in ipairs({ "GetOrderedCooldownIDs", "GetDefaultOrderedCooldownIDs" }) do
        if type(provider[name]) == "function" then
            local ok, ids = pcall(provider[name], provider)
            if ok and type(ids) == "table" and #ids > 0 then
                return ids
            end
        end
    end
    return nil
end

-- Die wirksame Einordnung, wie ihr Datenmodell sie führt.
--
-- Nötig für den Abschnitt "Nicht angezeigt". Der Cache-Eintrag meldet
-- isInvisible = false für alle 880, ihr Modell führt aber sechs passive und
-- eine aktive Abklingzeit als ausgeblendet - der Zustand steht also nicht im
-- Eintrag, sondern in ihren Listen. Ohne das blieb unser Abschnitt leer,
-- während in ihrem Fenster etwas darin stand.
--
-- Beide verborgenen Kategorien landen auf einer: Blizzards Fenster hat auch
-- nur einen Abschnitt dafür.
-- Rückgabe: tabelle AbklingzeitID -> Kategorie, oder nil
function Layout:GetProviderCategoryMap()
    if FCD.db and FCD.db.settings and FCD.db.settings.catalogSource == "scan" then
        return nil
    end

    -- Die Einordnung steht in cooldownInfoByID, nicht in den Kategorielisten.
    --
    -- GetOrderedCooldownIDsForCategory nennt nur, was gerade auf den Leisten
    -- liegt - bei diesem Krieger fünfzehn Einträge. Ihr Einstellungsfenster
    -- zeigt aber alle 172 verteilt auf die Abschnitte, und woher es das
    -- nimmt, stand lange nicht fest. Es nimmt es von hier: je Eintrag eine
    -- Kategorie und ein isInvisible, gültig für das aktive Layout.
    local data = displayData()
    local infoByID = data and data.cooldownInfoByID
    if type(infoByID) == "table" then
        local map, any, signature, knownMap = {}, false, {}, {}
        for _, cooldownID in ipairs(data.orderedCooldownIDs or {}) do
            local info = infoByID[cooldownID]
            if type(info) == "table" then
                knownMap[cooldownID] = info.isKnown and true or false
                -- Blizzard trennt verborgen-passiv (-2) von verborgen-aktiv
                -- (-1); ihr Fenster zeigt beides in einem Abschnitt, unseres
                -- auch. Ohne diese Zusammenfassung landeten 61 Einträge in
                -- einem Eimer, den kein Reiter zeichnet - sie wären
                -- verschwunden.
                local category = info.category
                if info.isInvisible or (type(category) == "number" and category < 0) then
                    category = HIDDEN_CATEGORY
                end
                if category ~= nil then
                    map[cooldownID] = category
                    signature[#signature + 1] = cooldownID .. "=" .. category .. ","
                    any = true
                end
            end
        end
        if any then
            return map, table.concat(signature), knownMap
        end
    end

    -- Rückfall auf die Kategorielisten, falls es die Anzeigedaten nicht gibt.
    local provider = dataProvider()
    if not provider or type(provider.GetOrderedCooldownIDsForCategory) ~= "function" then
        return nil
    end
    local map, any, signature = {}, false, {}
    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        local ok, ids = pcall(provider.GetOrderedCooldownIDsForCategory, provider, category.value)
        if ok and type(ids) == "table" then
            local value = (category.value < 0) and HIDDEN_CATEGORY or category.value
            signature[#signature + 1] = category.value .. "="
            for _, cooldownID in ipairs(ids) do
                map[cooldownID] = value
                signature[#signature + 1] = cooldownID .. ","
                any = true
            end
        end
    end
    if not any then
        return nil
    end
    return map, table.concat(signature)
end

function Layout:GetProfiles()
    FCD.db.layoutProfiles = FCD.db.layoutProfiles or {}
    return FCD.db.layoutProfiles
end

function Layout:ListProfiles()
    local names = {}
    for name in pairs(self:GetProfiles()) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function Layout:SaveProfile(name)
    if not name or name == "" then
        return false, L["Kein Name angegeben"]
    end
    local state, err = self:Read()
    if not state then
        return false, err
    end
    self:GetProfiles()[name] = {
        name = name,
        assignments = assignmentsOf(state),
        saved = date("%Y-%m-%d %H:%M:%S"),
    }
    return true
end

function Layout:DeleteProfile(name)
    local profiles = self:GetProfiles()
    if not profiles[name] then
        return false, L["Unbekanntes Profil"]
    end
    profiles[name] = nil
    return true
end

-- Wendet ein Profil an, indem nur die Unterschiede gesetzt werden. Im
-- Sofortmodus wirkt das ohne Neuladen, sonst als ein einziger Schreibvorgang.
-- Rückgabe: erfolg, fehlertext, anzahl
function Layout:ApplyProfile(name)
    local profile = self:GetProfiles()[name]
    if not profile then
        return false, L["Unbekanntes Profil"]
    end
    return self:ApplyAssignments(profile.assignments or {}, L["Profil "] .. name)
end

-- Ohne Zuweisungen bleibt überall die Standardeinordnung stehen - das ist
-- genau Blizzards "Startlayout".
function Layout:ApplyDefaults()
    return self:ApplyAssignments({}, "Startlayout")
end

function Layout:ApplyAssignments(assignments, label)
    local state, err = self:Read()
    if not state then
        return false, err
    end

    local staticMap = self:GetStaticMap()

    -- Wogegen wird verglichen?
    --
    -- Gegen das, worauf auch geschrieben wird - sonst geht beides
    -- auseinander. Genau das war der Fehler: verglichen wurde immer gegen
    -- den Blob, geschrieben im Sofortmodus aber ins laufende Modell. Nach
    -- dem ersten Profilwechsel stand im Blob noch der alte Stand, und beim
    -- Zurückschalten sah der Vergleich deshalb keinen Unterschied - das
    -- Umschalten tat dann schlicht nichts.
    local native = self:NativeWritesAllowed() and self:NativeAPIExists()
    local current
    local live = native and self:GetProviderCategoryMap() or nil
    if live then
        -- Das Modell nennt die wirksame Kategorie jedes Eintrags. Eine
        -- Zuweisung ist nur, was von der Vorgabe abweicht - dieselbe
        -- Bedeutung, die assignmentsOf für den Blob hat.
        current = {}
        for cooldownID, category in pairs(live) do
            if staticMap[cooldownID] ~= category then
                current[cooldownID] = category
            end
        end
    else
        current = assignmentsOf(state)
    end

    local changes = {}

    for cooldownID, category in pairs(assignments) do
        if current[cooldownID] ~= category then
            changes[#changes + 1] = { id = cooldownID, category = category }
        end
    end
    for cooldownID in pairs(current) do
        if assignments[cooldownID] == nil then
            changes[#changes + 1] = { id = cooldownID, category = staticMap[cooldownID] }
        end
    end

    if #changes == 0 then
        return true, nil, 0
    end

    if native then
        self:CreateNativeRestorePoint()
        for _, change in ipairs(changes) do
            if change.category ~= nil then
                self:SetCategoryNative(change.id, change.category)
            end
        end
        return true, nil, #changes
    end

    for _, change in ipairs(changes) do
        if change.category == staticMap[change.id] then
            self:SetCategory(state, change.id, nil)
        else
            self:SetCategory(state, change.id, change.category)
        end
    end
    local ok, commitErr = self:Commit(state, label or "Zuweisungen")
    return ok, commitErr, #changes
end

-- Teilen soll man den Stand, den man gerade sieht - nicht einen gespeicherten
-- Schnappschuss. Sonst müsste man erst ein Profil anlegen, nur um es zu
-- verschicken, und hätte beim aktiven Profil womöglich einen veralteten Stand
-- exportiert, weil seither weiter verschoben wurde.
function Layout:ExportCurrent(name)
    local state, err = self:Read()
    if not state then
        return nil, err
    end
    local profile = {
        name = name or "Eigenes Layout",
        assignments = assignmentsOf(state),
        saved = date("%Y-%m-%d %H:%M:%S"),
    }
    local out = {}
    FCD.Profiles.Serialize(profile, out)
    return PROFILE_PREFIX .. table.concat(out)
end

function Layout:ExportProfile(name)
    local profile = self:GetProfiles()[name]
    if not profile then
        return nil, L["Unbekanntes Profil"]
    end
    local out = {}
    FCD.Profiles.Serialize(profile, out)
    return PROFILE_PREFIX .. table.concat(out)
end

function Layout:ImportProfile(text)
    if type(text) ~= "string" then
        return nil, L["Kein Text"]
    end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text:sub(1, #PROFILE_PREFIX) ~= PROFILE_PREFIX then
        return nil, L["Kein Layout-Profil (erwartet "] .. PROFILE_PREFIX .. "...)"
    end
    local parsed, _, err = FCD.Profiles.Deserialize(text:sub(#PROFILE_PREFIX + 1), 1)
    if err or type(parsed) ~= "table" or type(parsed.assignments) ~= "table" then
        return nil, L["Profilstring beschädigt: "] .. tostring(err or L["kein Inhalt"])
    end

    local name = parsed.name or "Import"
    local profiles = self:GetProfiles()
    local suffix = 1
    while profiles[name] do
        suffix = suffix + 1
        name = (parsed.name or "Import") .. " " .. suffix
    end
    parsed.name = name
    profiles[name] = parsed
    return name
end

-- ------------------------------------------------------- Sicherung/Schreiben

function Layout:Backup(raw, label)
    FCD.db.layoutBackups = FCD.db.layoutBackups or {}
    local backups = FCD.db.layoutBackups
    backups[#backups + 1] = {
        raw = raw,
        label = label or L["Änderung"],
        taken = date("%Y-%m-%d %H:%M:%S"),
    }
    while #backups > MAX_BACKUPS do
        table.remove(backups, 1)
    end
end

function Layout:GetBackups()
    return FCD.db.layoutBackups or {}
end

-- Stellt eine Sicherung bitgenau wieder her. Weil der Rohtext aufgehoben
-- wird, ist das Zurücknehmen exakt und nicht von meinem Modell abhängig.
function Layout:Restore(index)
    local backups = self:GetBackups()
    local backup = backups[index or #backups]
    if not backup then
        return false, L["Keine Sicherung vorhanden"]
    end
    local ok, err = Compat.SetLayoutData(backup.raw)
    if not ok then
        return false, err
    end
    table.remove(backups, index or #backups)
    return true, backup.taken
end

-- Schreibt den geänderten Zustand zurück. Vorher wird der unveränderte
-- Rohtext gesichert, damit jede Änderung exakt rücknehmbar bleibt.
-- Rückgabe: erfolg, fehlertext
function Layout:Commit(state, label)
    if not Compat.CanWriteLayoutData() then
        return false, L["SetLayoutData fehlt in diesem Client"]
    end

    local rebuilt, encodeErr = Compat.EncodeLayoutString(state.prefix, state.data, state.recipe)
    if not rebuilt then
        return false, encodeErr
    end

    self:Backup(state.raw, label)

    local ok, err = Compat.SetLayoutData(rebuilt)
    if not ok then
        -- Sicherung wieder verwerfen, es wurde ja nichts geändert
        local backups = self:GetBackups()
        table.remove(backups)
        return false, err
    end

    state.raw = rebuilt
    return true
end

-- Prüft ohne zu schreiben, ob der aktuelle Blob verlustfrei durch unsere
-- Kette läuft. Wird vor jeder Bearbeitung aufgerufen.
--
-- Bitgleichheit wäre schön, ist aber kein taugliches Kriterium: CBOR-Maps
-- sind ungeordnet, und Luas Tabellenordnung ist eine andere als die des
-- Clients. Entscheidend ist, dass der neu erzeugte Blob wieder denselben
-- Inhalt ergibt.
-- Rückgabe: erfolg, fehlertext, hinweis
function Layout:VerifyRoundTrip(state)
    local err
    if not state then
        state, err = self:Read()
        if not state then
            return false, err
        end
    end

    local rebuilt, encodeErr = Compat.EncodeLayoutString(state.prefix, state.data, state.recipe)
    if not rebuilt then
        return false, encodeErr
    end

    local trimmed = string.gsub(state.raw, "%s+$", "")
    if rebuilt == trimmed then
        return true, nil, string.format("bitgleich, %d Zeichen", #rebuilt)
    end

    local redecoded, decodeErr = Compat.DecodeLayoutString(rebuilt)
    if not redecoded then
        return false, L["Neu erzeugter Blob ist nicht wieder lesbar: "] .. tostring(decodeErr)
    end

    local same, difference = Compat.DeepEqual(state.data, redecoded)
    if same then
        return true, nil, string.format(
            L["inhaltlich gleich, %d statt %d Zeichen (Schlüsselreihenfolge weicht ab)"],
            #rebuilt, #trimmed)
    end

    return false, L["Inhalt weicht ab: "] .. tostring(difference)
end
