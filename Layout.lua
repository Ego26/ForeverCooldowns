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
function Layout:CanWriteNativeNow()
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

-- Rückgabe: erfolg, fehlertext
function Layout:SetCategoryNative(cooldownID, category)
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

    -- Falls der Client die Änderung vorab bewertet, erst fragen
    if manager and type(manager.GetCooldownCategoryChangeStatus) == "function" then
        local ok, status = pcall(manager.GetCooldownCategoryChangeStatus, manager, cooldownID, category)
        if ok and status ~= nil and status ~= 0 then
            return false, L["Der Client lehnt die Änderung ab (Status "] .. Compat.SafeToString(status) .. ")"
        end
    end

    local ok, err = pcall(provider.SetCooldownToCategory, provider, cooldownID, category)
    if not ok then
        return false, Compat.SafeToString(err)
    end

    -- Ab dem ersten Aufruf gilt Blizzards Viewer als tainted und wirft bei
    -- jedem Aurenereignis einen Fehler. Das merken wir uns, damit die
    -- Oberfläche ein Neuladen anbieten kann.
    if not self.taintedThisSession then
        self.taintedThisSession = true
        FCD.Print(L["Sofortmodus: Änderung wirkt. Blizzards Viewer wirft ab jetzt bei"])
        FCD.Print(L["jedem Aurenereignis einen Fehler - ein /reload behebt das."])
        FCD.Print(L["Dauerhaft vermeiden: Häkchen 'sofort wirksam' abschalten."])
    end

    -- Dieselbe Kette, die Blizzards Fenster nach einer Änderung durchläuft:
    -- als verändert markieren, Anzeigedaten neu bauen, speichern, Zuhörer
    -- benachrichtigen. Jeder Schritt ist optional, falls er fehlt.
    local steps = {
        { object = provider, name = "MarkDirty" },
        { object = provider, name = "CheckBuildDisplayData" },
        { object = manager, name = "SaveLayouts" },
        { object = manager, name = "NotifyListeners" },
    }
    local applied = {}
    for _, step in ipairs(steps) do
        local object = step.object
        if object and type(object[step.name]) == "function" then
            local stepOk, stepErr = pcall(object[step.name], object)
            applied[#applied + 1] = step.name .. (stepOk and "" or (" (Fehler: " .. Compat.SafeToString(stepErr) .. ")"))
        end
    end

    return true, nil, table.concat(applied, ", ")
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
function Layout:GetStaticMap()
    local map, order = {}, {}
    for _, category in ipairs(Compat.GetCooldownViewerCategories()) do
        local ids = Compat.GetCategorySet(category.value)
        if ids then
            for _, id in ipairs(ids) do
                if map[id] == nil then
                    map[id] = category.value
                    order[#order + 1] = id
                end
            end
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
                local name = rawget(entry, "name")
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
    local current = assignmentsOf(state)
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

    if self:NativeWritesAllowed() and self:NativeAPIExists() then
        self:CreateNativeRestorePoint()
        for _, change in ipairs(changes) do
            if change.category ~= nil then
                self:SetCategoryNative(change.id, change.category)
            end
        end
        -- Auch hier: die gespiegelten Leisten lesen den Blob, nicht ihr
        -- Datenmodell, und müssen deshalb eigens nachziehen.
        FCD.Mirror:Refresh()
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
    -- Gespiegelte Leisten lesen denselben Stand und zeichnen ihn selbst;
    -- für sie ist ein ganzes Profil damit sofort angewendet.
    if ok then
        FCD.Mirror:Refresh()
    end
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
    FCD.Mirror:Refresh()
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
