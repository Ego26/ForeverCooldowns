local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local Store = {}
FCD.Store = Store

-- Dieser Client legt für unser AddOn keine SavedVariables an. Geschrieben
-- werden sie, zurückgegeben nicht - nachgewiesen über mehrere Sitzungen, mit
-- gültiger Datei, vollständig gelesener .toc und einem Vergleichs-AddOn, bei
-- dem es funktioniert. Was in diesem Client dagegen zuverlässig hält, ist
-- Blizzards eigener Layout-Speicher: dort stehen die Kategorie-Zuweisungen,
-- und die überleben Neuladen und Neustart.
--
-- Also legen wir unseren Bestand dort mit ab. Nebeneffekt, den sich der
-- Benutzer gewünscht hat: die Daten hängen damit am selben Layout wie
-- Blizzards eigene Einstellungen und wandern mit ihm mit.
--
-- Zwei Dinge sind dabei zu beachten:
--   * Schreibt Blizzard das Layout selbst neu, kann unser Schlüssel dabei
--     verlorengehen. Deshalb wird regelmäßig geprüft und nachgetragen.
--   * Geschrieben wird über SetLayoutData, denselben sicheren Weg wie bei den
--     Kategorien - das taintet nichts und legt vorher eine Sicherung an.

local STORE_KEY = "fcdStore"

-- Der Takt bestimmt, wieviel eine Änderung überlebt, die kurz vor einem
-- /reload gemacht wurde. Mit acht Sekunden ging genau das verloren: eine
-- Einstellung umgestellt, neu geladen, alter Stand wieder da. Der Takt kostet
-- fast nichts, weil Save zuerst nur zusammenpackt und vergleicht - an
-- Blizzards Layout geht es erst bei einer echten Abweichung.
local CHECK_INTERVAL = 2

Store.status = L["noch nichts gelesen"]
Store.lastWritten = nil

-- ------------------------------------------------------------- Umwandlung

local function pack()
    local db = FCD.db
    if type(db) ~= "table" then
        return nil
    end
    local out = {}
    FCD.Profiles.Serialize({
        schema = db.schema,
        settings = db.settings,
        profiles = db.profiles,
        characters = db.characters,
        customItems = db.customItems,
        layoutProfiles = db.layoutProfiles,
    }, out)
    return table.concat(out)
end

local function unpack(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    local ok, value = pcall(FCD.Profiles.Deserialize, text, 1)
    if not ok or type(value) ~= "table" then
        return nil
    end
    return value
end

-- ------------------------------------------------------------ Lesen

-- Rückgabe: tabelle, fehlertext
function Store:Load()
    local state, err = FCD.Layout:Read()
    if not state then
        self.status = L["Layout nicht lesbar: "] .. tostring(err)
        return nil, err
    end
    local text = state.data and state.data[STORE_KEY]
    if type(text) ~= "string" or text == "" then
        -- Leeres Layout: hier ist nichts zu verlieren, also darf der Takt
        -- schreiben. Ohne diese Zeile hielte die Herkunftsprüfung unten den
        -- Bestand der vorigen Sitzung fest und verweigerte jedes Schreiben.
        self.lastWritten = nil
        self.status = L["Im Layout liegt noch kein Bestand."]
        return nil, L["kein Bestand"]
    end
    local value = unpack(text)
    if not value then
        self.status = L["Bestand im Layout ist unlesbar."]
        return nil, "unlesbar"
    end
    self.lastWritten = text
    self.status = string.format(L["Bestand aus dem Layout gelesen (%d Zeichen)."], #text)
    return value
end

-- ------------------------------------------------------------ Schreiben

-- Rückgabe: erfolg, fehlertext
function Store:Save(force)
    if InCombatLockdown() then
        return false, L["im Kampf nicht"]
    end
    local text = pack()
    if not text then
        return false, L["nichts zu schreiben"]
    end
    if not force and text == self.lastWritten then
        return true
    end

    local state, err = FCD.Layout:Read()
    if not state then
        return false, err
    end
    -- Nur schreiben, wenn der Blob unsere Kette verlustfrei übersteht; sonst
    -- würde ein Fehler im Codec Blizzards Layout beschädigen.
    local ok, verifyErr = FCD.Layout:VerifyRoundTrip(state)
    if not ok then
        self.status = L["Nicht geschrieben, Blob übersteht die Kette nicht: "]
            .. tostring(verifyErr)
        return false, verifyErr
    end

    -- Nur schreiben, wenn wir wissen, worauf wir schreiben.
    --
    -- Der erste Versuch verglich die Größe: liegt im Layout mehr als hier,
    -- wird nicht geschrieben. Das hat jedes absichtliche Löschen mitblockiert
    -- - ein Gegenstand von der Leiste genommen, ein /reload, und er war
    -- wieder da. Die Größe war das falsche Merkmal.
    --
    -- Es geht nicht um mehr oder weniger, sondern um Herkunft: Steht im
    -- Layout genau der Bestand, den wir in dieser Sitzung gelesen oder zuletzt
    -- geschrieben haben, dann ist unser Stand dessen Nachfolger und darf auch
    -- kleiner sein. Steht dort etwas Fremdes - weil das Layout gewechselt hat
    -- oder ein anderer Charakter geschrieben hat -, wird nicht geschrieben,
    -- bis es beim Anmelden abgeglichen wurde.
    if not force then
        local existing = state.data[STORE_KEY]
        if existing == "" then
            existing = nil
        end
        if existing ~= self.lastWritten then
            self.status = string.format(
                L["Nicht geschrieben: im Layout steht ein fremder Bestand (%d Zeichen)."],
                type(existing) == "string" and #existing or 0)
            if not self.warnedAboutLoss then
                self.warnedAboutLoss = true
                FCD.LogOnly(self.status)
                FCD.Print(L["Im Layout steht ein Bestand, der nicht von dieser Sitzung stammt."])
                FCD.Print(L["Ein /reload gleicht ab, /fcd store schreibt trotzdem."])
            end
            return false, L["fremder Bestand im Layout"]
        end
    end
    self.warnedAboutLoss = nil

    state.data[STORE_KEY] = text
    local written, commitErr = FCD.Layout:Commit(state, L["Bestand"])
    if not written then
        self.status = L["Schreiben fehlgeschlagen: "] .. tostring(commitErr)
        return false, commitErr
    end

    self.lastWritten = text
    self.status = string.format(L["Bestand im Layout gesichert (%d Zeichen)."], #text)
    return true
end

-- Gibt es unseren Schlüssel im Layout überhaupt noch? Blizzard kann ihn beim
-- eigenen Schreiben verworfen haben.
function Store:IsPresent()
    local state = FCD.Layout:Read()
    if not state or type(state.data) ~= "table" then
        return false
    end
    return type(state.data[STORE_KEY]) == "string"
end

-- ------------------------------------------------------------- Takt

local driver = CreateFrame("Frame")
local elapsedSince = 0

driver:SetScript("OnUpdate", function(_, elapsed)
    if not FCD.db then
        return
    end
    elapsedSince = elapsedSince + elapsed
    if elapsedSince < CHECK_INTERVAL then
        return
    end
    elapsedSince = 0
    -- Save vergleicht selbst und schreibt nur bei einer Abweichung.
    pcall(Store.Save, Store)
end)

Store.driver = driver
