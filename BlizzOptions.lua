local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local BlizzOptions = {}
FCD.BlizzOptions = BlizzOptions

-- Das Gegenstück zu BarOptions, nur für Blizzards eigene Abklingzeit-Leisten.
-- Ihr Bearbeitungsmodus zeigt dafür ein kleines Fenster; dieses hier tritt an
-- dessen Stelle, damit im Bearbeitungsmodus überall dasselbe Fenster steht -
-- ihre Leisten wie unsere.
--
-- Die Werte gehören weiter ihnen. Gelesen wird über GetSettingValue,
-- geschrieben über EditModeManagerFrame:OnSystemSettingChange. Das ist der
-- Weg, den ihre eigene Oberfläche nimmt: sie zieht danach von selbst nach,
-- ihr "Änderungen speichern" sichert unsere Änderungen mit, und ein Neuladen
-- überlebt es. Gemessen, nicht angenommen - zwei andere Wege liefen
-- wirkungslos ins Leere, ohne dabei einen Fehler zu melden.
--
-- Was hier NICHT passiert: eigene Werte speichern. Dieses Fenster hat keinen
-- eigenen Bestand, es bedient ihren.

local WIDTH = 320
local ROW = 26
local PAD = 12
local CONTENT = WIDTH - 2 * PAD

local dialog
local currentSystem

-- ------------------------------------------------------------ Zugriff

local function manager()
    local frame = _G.EditModeManagerFrame
    if type(frame) == "table" and type(frame.OnSystemSettingChange) == "function" then
        return frame
    end
    return nil
end

local function settingEnum()
    local enums = _G.Enum
    if type(enums) ~= "table" then
        return nil
    end
    local enum = rawget(enums, "EditModeCooldownViewerSetting")
    return type(enum) == "table" and enum or nil
end

-- Eine Einstellung hat diese Leiste nur, wenn sie sie kennt UND ihr eigenes
-- Fenster sie zeigen würde. Balkeninhalt etwa gibt es nur an der
-- Balkenvariante; ohne diese Prüfung stünde er überall.
local function shows(system, settingID)
    local ok, has = pcall(system.HasSetting, system, settingID)
    if not ok or not has then
        return false
    end
    if type(system.ShouldShowSetting) == "function" then
        local okShow, show = pcall(system.ShouldShowSetting, system, settingID)
        if okShow then
            return show and true or false
        end
    end
    return true
end

local function getValue(system, settingID)
    local ok, value = pcall(system.GetSettingValue, system, settingID)
    if ok then
        return value
    end
    return nil
end

local function setValue(system, settingID, value)
    local frame = manager()
    if not frame or not system then
        return false
    end
    local ok, err = pcall(frame.OnSystemSettingChange, frame, system, settingID, value)
    if not ok then
        FCD.LogOnly(L["Einstellung nicht geschrieben: "] .. tostring(err))
        FCD.Print(L["Diese Einstellung ließ sich nicht setzen - Einzelheiten in /fcd log."])
        return false
    end

    -- Wir laufen hier durch ihren Verwalter in ihren Viewer hinein; ab dem
    -- ersten Schreiben gilt er als tainted und wirft bei Ziel- und
    -- Aurenereignissen Fehler. Dieselbe Folge wie beim Sofortmodus, deshalb
    -- dieselbe Markierung: das Panel bietet dann das Neuladen an.
    if FCD.Layout and not FCD.Layout.taintedThisSession then
        FCD.Layout.taintedThisSession = true
        FCD.Print(L["Ihre Leiste geändert. Blizzards Viewer wirft ab jetzt bei"])
        FCD.Print(L["Ziel- und Aurenereignissen einen Fehler - ein /reload behebt das."])
        FCD.Print(L["Dauerhaft vermeiden: /fcd editui off - dann bleibt ihr Fenster."])
    end

    return true
end

-- ------------------------------------------------------- Beschreibung

-- Die Auswahlwerte stehen in einem Enum, dessen Name je Build anders lauten
-- kann. Deshalb wird gesucht statt angenommen, und die deutschen Namen hängen
-- am Schlüssel, nicht an der Zahl - eine Zahl könnte in einem anderen Build
-- etwas anderes bedeuten.
local function findEnum(entry)
    local enums = _G.Enum
    if type(enums) ~= "table" then
        return nil
    end

    for _, name in ipairs(entry.enums or {}) do
        local enum = rawget(enums, name)
        if type(enum) == "table" then
            return enum, name
        end
    end

    -- Gesucht statt geraten: welcher Name in diesem Build gilt, weiß nur der
    -- Client. "CooldownViewer" schlägt "EditMode" schlägt alles andere -
    -- sonst fischte man sich für "Orientation" das Enum einer Aktionsleiste.
    local best, bestName, bestScore
    for name, value in pairs(enums) do
        if type(name) == "string" and type(value) == "table"
            and name:find(entry.key, 1, true)
            and name:sub(-4) ~= "Meta" then
            local score = 0
            if name:find("CooldownViewer", 1, true) then
                score = 2
            elseif name:find("EditMode", 1, true) then
                score = 1
            end
            if not best or score > bestScore then
                best, bestName, bestScore = value, name, score
            end
        end
    end
    return best, bestName
end

local SETTINGS = {
    { key = "Orientation", label = "Ausrichtung", kind = "dropdown",
        enums = { "CooldownViewerOrientation" },
        names = { Horizontal = "Horizontal", Vertical = "Vertikal" } },
    { key = "IconDirection", label = "Symbolausrichtung", kind = "dropdown",
        enums = { "CooldownViewerIconDirection" },
        -- Hoch und Runter kennt dieser Client bei Abklingzeit-Leisten nicht;
        -- die Namen stehen trotzdem hier, falls ein Build sie nachreicht.
        names = { Left = "Nach links", Right = "Nach rechts",
            Up = "Nach oben", Down = "Nach unten" } },
    { key = "BarContent", label = "Balkeninhalt", kind = "dropdown",
        enums = { "CooldownViewerBarContent" },
        names = { IconAndName = "Symbol und Name", IconOnly = "Nur Symbol",
            NameOnly = "Nur Name" } },
    { key = "IconLimit", label = "Symbole je Reihe", kind = "slider",
        minimum = 1, maximum = 20, step = 1 },
    { key = "IconSize", label = "Symbolgröße", kind = "slider",
        minimum = 50, maximum = 200, step = 5, percent = true },
    { key = "IconPadding", label = "Symbolabstand", kind = "slider",
        minimum = 0, maximum = 20, step = 1 },
    { key = "BarWidthScale", label = "Balkenbreite", kind = "slider",
        minimum = 50, maximum = 200, step = 5, percent = true },
    { key = "Opacity", label = "Transparenz", kind = "slider",
        minimum = 10, maximum = 100, step = 5, percent = true },
    { key = "VisibleSetting", label = "Sichtbarkeit", kind = "dropdown",
        enums = { "CooldownViewerVisibleSetting" },
        names = { Always = "Immer sichtbar", InCombat = "Nur im Kampf",
            OutOfCombat = "Außerhalb des Kampfes", Hidden = "Nie" } },
    { key = "HideWhenInactive", label = "Bei Inaktivität verbergen", kind = "check" },
    { key = "ShowTimer", label = "Timer anzeigen", kind = "check" },
    { key = "ShowTooltips", label = "Tooltips anzeigen", kind = "check" },
}

-- Auswahlliste eines Dropdowns: Schlüssel des Enums, deutsch benannt. Fehlt
-- ein Schlüssel in unserer Liste, steht sein englischer Name da - besser als
-- ein leeres Feld, und es fällt beim Ansehen sofort auf.
local function optionsFor(entry)
    local enum, enumName = findEnum(entry)
    if not enum then
        FCD.LogOnly(L["Kein Enum für "] .. entry.key .. L[" - Feld bleibt weg."])
        return nil
    end
    if entry.enumName ~= enumName then
        entry.enumName = enumName
        FCD.LogOnly(entry.key .. L[" nutzt Enum "] .. tostring(enumName))
    end
    local items = {}
    for key, value in pairs(enum) do
        if type(key) == "string" and type(value) == "number" then
            items[#items + 1] = {
                value = value,
                text = L[(entry.names and entry.names[key]) or key],
            }
        end
    end
    table.sort(items, function(a, b) return a.value < b.value end)
    return items
end

local function optionText(entry, value)
    for _, item in ipairs(entry.items or {}) do
        if item.value == value then
            return item.text
        end
    end
    return tostring(value)
end

-- ------------------------------------------------------------- Fenster

local function settings()
    return (FCD.db and FCD.db.settings) or {}
end

local function isCooldownViewer(system)
    if type(system) ~= "table" or type(system.GetName) ~= "function" then
        return false
    end
    local ok, name = pcall(system.GetName, system)
    return ok and type(name) == "string" and name:find("CooldownViewer", 1, true) and true or false
end

local function systemTitle(system)
    local ok, name = pcall(system.GetSystemName, system)
    if ok and type(name) == "string" and name ~= "" then
        return name
    end
    local okFrame, frameName = pcall(system.GetName, system)
    return okFrame and frameName or L["Leiste"]
end

local function build()
    if dialog then
        return dialog
    end

    dialog = Compat.CreateFrame("Frame", "ForeverCooldownsBlizzOptions", UIParent,
        "BasicFrameTemplateWithInset")
    dialog:SetSize(WIDTH, 400)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetClampedToScreen(true)
    dialog:Hide()
    dialog:SetScript("OnHide", function()
        FCD.LogOnly(L["Leistenfenster zu: "] .. (BlizzOptions.closeReason or L["von außen"]))
        BlizzOptions.closeReason = nil
    end)

    -- Die Rahmenvorlage ist durchscheinend; ihr Bearbeitungsmodus läge sonst
    -- deutlich sichtbar darunter durch.
    dialog.background = dialog:CreateTexture(nil, "BACKGROUND", nil, -8)
    dialog.background:SetAllPoints()
    dialog.background:SetColorTexture(0.04, 0.04, 0.06, 1)

    if not dialog.TitleBg and FCD.BarOptions.AddEdges then
        FCD.BarOptions.AddEdges(dialog, 0.55, 0.50, 0.35, 1)
        local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
    end

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.title:SetPoint("TOP", 0, -6)

    -- Der geteilte Regler misst seine Breite am Elternrahmen.
    dialog.fcdContentWidth = CONTENT

    dialog.controls = {}
    for _, entry in ipairs(SETTINGS) do
        local control = { entry = entry }

        if entry.kind == "check" then
            control.widget = FCD.Widgets.CreateCheck(dialog, L[entry.label], function()
                if not currentSystem then
                    return false
                end
                -- Ihre Wahrheitswerte sind Zahlen; 0 ist in Lua wahr.
                return (getValue(currentSystem, control.id) or 0) ~= 0
            end, function(value)
                setValue(currentSystem, control.id, value and 1 or 0)
            end)

        elseif entry.kind == "dropdown" then
            control.label = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            control.label:SetText(L[entry.label])
            control.widget = FCD.Widgets.CreateDropdown(dialog, 150, function()
                return entry.items or {}
            end, function(value)
                if setValue(currentSystem, control.id, value) then
                    control.widget:SetText(optionText(entry, value))
                    -- Die Richtung hängt an der Ausrichtung: nach einem
                    -- Wechsel zeigt ihre Liste andere Werte.
                    BlizzOptions:Refresh()
                end
            end)

        else
            control.widget = FCD.BarOptions.CreateSlider(dialog, L[entry.label],
                entry.minimum, entry.maximum, entry.step,
                function()
                    return getValue(currentSystem, control.id) or entry.minimum
                end,
                function(value)
                    setValue(currentSystem, control.id, value)
                end,
                entry.percent and function(value)
                    return string.format("%d%%", value)
                end or nil,
                -- Nachziehen tut ihr eigener Code; unsere Leisten neu
                -- aufzubauen wäre hier nur verlorene Arbeit.
                function() end)
        end

        dialog.controls[#dialog.controls + 1] = control
    end

    local function addButton(text, onClick)
        local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        button:SetSize(CONTENT, 22)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end

    dialog.resetButton = addButton(L["Auf Standardposition zurücksetzen"], function()
        if currentSystem then
            pcall(currentSystem.ResetToDefaultPosition, currentSystem)
        end
    end)

    dialog.managerButton = addButton(L["Abklingzeitmanager-Optionen"], function()
        FCD:OpenMainUI()
    end)

    -- Fluchtweg: zeigt eine Einstellung dieser Client anders an, als wir sie
    -- nachgebaut haben, kommt man so an ihr Original heran.
    dialog.blizzButton = addButton(L["Blizzards Fenster öffnen"], function()
        BlizzOptions:OpenBlizzardDialog()
    end)

    return dialog
end

-- Sichtbare Bedienelemente neu anordnen. Welche das sind, hängt an der
-- Leiste - die Balkenvariante hat Felder, die die Symbolvariante nicht hat.
function BlizzOptions:Refresh()
    if not dialog or not currentSystem then
        return
    end

    local enum = settingEnum()
    if not enum then
        return
    end

    dialog.title:SetText(systemTitle(currentSystem))

    local offsetY = -34
    for _, control in ipairs(dialog.controls) do
        local entry = control.entry
        control.id = rawget(enum, entry.key)

        local visible = control.id and shows(currentSystem, control.id) or false
        if visible and entry.kind == "dropdown" then
            entry.items = optionsFor(entry)
            -- Ohne Auswahlwerte wäre das Feld leer und stumm; dann lieber
            -- weglassen und auf ihr Fenster verweisen.
            visible = entry.items and #entry.items > 0 or false
        end

        if not visible then
            control.widget:Hide()
            if control.label then
                control.label:Hide()
            end
        else
            control.widget:ClearAllPoints()
            if entry.kind == "dropdown" then
                control.label:ClearAllPoints()
                control.label:SetPoint("TOPLEFT", PAD, offsetY - 4)
                control.label:Show()
                control.widget:SetPoint("TOPRIGHT", -PAD, offsetY)
                control.widget:SetText(optionText(entry, getValue(currentSystem, control.id)))
                offsetY = offsetY - ROW - 4
            elseif entry.kind == "check" then
                control.widget:SetPoint("TOPLEFT", PAD, offsetY)
                control.widget.Refresh()
                offsetY = offsetY - 24
            else
                control.widget:SetPoint("TOPLEFT", PAD, offsetY)
                control.widget.Refresh()
                if control.widget.BorrowArt then
                    control.widget.BorrowArt()
                end
                offsetY = offsetY - ROW
            end
            control.widget:Show()
        end
    end

    offsetY = offsetY - 8
    for _, button in ipairs({ dialog.resetButton, dialog.managerButton, dialog.blizzButton }) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", PAD, offsetY)
        offsetY = offsetY - 25
    end

    dialog:SetHeight(-offsetY + PAD)
end

function BlizzOptions:Open(system)
    if not isCooldownViewer(system) then
        return false
    end
    if not settingEnum() or not manager() then
        return false
    end

    build()
    currentSystem = system

    -- Blizzards eigener Dialog ist "exclusive": es steht immer nur einer
    -- offen. Unsere zwei Fenster wussten nichts voneinander und lagen
    -- deshalb übereinander. Ihres schlägt unseres, weil der Klick auf ihre
    -- Leiste die jüngere Absicht ist.
    if FCD.BarOptions then
        FCD.BarOptions:Close()
    end
    if FCD.Viewer then
        FCD.Viewer:SelectBar(nil)
    end

    -- Erst füllen, dann ausrichten: die Höhe steht erst nach Refresh fest,
    -- und an ihr hängt, ob das Fenster unten aus dem Bild läuft.
    self:Refresh()

    FCD.Widgets.PlaceBeside(dialog, system)
    dialog:Show()
    pcall(dialog.Raise, dialog)
    return true
end

function BlizzOptions:Close(reason)
    if dialog then
        self.closeReason = reason or "ohne Angabe"
        dialog:Hide()
    end
    currentSystem = nil
end

function BlizzOptions:Strata()
    return dialog and dialog:GetFrameStrata() or "-"
end

function BlizzOptions:Height()
    return dialog and dialog:GetHeight() or 0
end

function BlizzOptions:Alpha()
    return dialog and dialog:GetAlpha() or 0
end

function BlizzOptions:Edge(getter)
    if not dialog or type(dialog[getter]) ~= "function" then
        return nil
    end
    return dialog[getter](dialog)
end

-- Ihre Auswahl aufheben. Welchen Namen ihr Verwalter dafür trägt, ist je
-- Build verschieden, deshalb werden die üblichen der Reihe nach versucht;
-- greift keiner, bleibt der Weg über die Leiste selbst.
function BlizzOptions:ClearBlizzardSelection()
    local frame = _G.EditModeManagerFrame
    if type(frame) == "table" then
        for _, name in ipairs({ "ClearSelectedSystem", "ClearSelection", "DeselectSystem" }) do
            if type(frame[name]) == "function" and pcall(frame[name], frame) then
                return true
            end
        end
    end

    local blizzard = _G.EditModeSystemSettingsDialog
    local system = type(blizzard) == "table" and rawget(blizzard, "attachedToSystem") or nil
    if type(system) ~= "table" then
        return false
    end

    local cleared = false
    if type(system.SetSelectionShown) == "function" then
        cleared = pcall(system.SetSelectionShown, system, false) or cleared
    end
    if type(system.ClearHighlight) == "function" then
        cleared = pcall(system.ClearHighlight, system) or cleared
    end
    return cleared
end

function BlizzOptions:IsShown()
    return dialog and dialog:IsShown() and true or false
end

-- ------------------------------------------------------- Verdrängen

function BlizzOptions:ShouldReplace()
    if settings().replaceEditModeDialog == false then
        return false
    end
    return not self.allowBlizzardDialog
end

-- Ihr Fenster für diesen einen Aufruf stehen lassen.
function BlizzOptions:OpenBlizzardDialog()
    local system = currentSystem
    local blizzard = _G.EditModeSystemSettingsDialog
    if type(blizzard) ~= "table" or not system then
        return false
    end
    self:Close()
    self.allowBlizzardDialog = true
    -- Ihr Fenster hängt sich selbst an die angeklickte Leiste; der reguläre
    -- Weg dorthin ist, die Leiste erneut auszuwählen.
    local ok = pcall(function()
        local frame = manager()
        if frame and type(frame.SelectSystem) == "function" then
            frame:SelectSystem(system)
        else
            blizzard:Show()
        end
    end)
    if not ok then
        self.allowBlizzardDialog = nil
        FCD.Print(L["Ihr Fenster ließ sich nicht öffnen."])
        return false
    end
    return true
end

local function takeOver(blizzard)
    local system = rawget(blizzard, "attachedToSystem")
    FCD.LogOnly(L["Ihr Leistenfenster geht auf: "]
        .. tostring(isCooldownViewer(system) and systemTitle(system) or L["keine Abklingzeit-Leiste"]))

    if not isCooldownViewer(system) then
        return
    end
    if not BlizzOptions:ShouldReplace() then
        FCD.LogOnly(L["Keine Übernahme: Einstellung="] ..
            tostring(settings().replaceEditModeDialog))
        return
    end

    -- Erst unseres öffnen, dann ihres schließen: schlägt das Öffnen fehl,
    -- soll wenigstens ihr Fenster stehen bleiben.
    local ok, err = pcall(BlizzOptions.Open, BlizzOptions, system)
    if not ok then
        FCD.LogOnly(L["Eigenes Leistenfenster fehlgeschlagen: "] .. tostring(err))
        FCD.Print(L["Unser Fenster ließ sich nicht öffnen - Einzelheiten in /fcd log."])
        return
    end
    if not BlizzOptions:IsShown() then
        FCD.LogOnly(L["Eigenes Leistenfenster hat abgelehnt (Enum oder Verwalter fehlt)."])
        return
    end

    -- Die Sperre muss stehen, bevor ihr Fenster zugeht: das Ausblenden läuft
    -- auf unseren eigenen OnHide-Handler, und der schloss unseres mit. Ihr
    -- Fenster verliert beim Ausblenden seine Zuordnung, die Prüfung dort
    -- schlug also fehl - unseres ging auf und im selben Moment wieder zu.
    BlizzOptions.takingOver = true
    pcall(blizzard.Hide, blizzard)
    BlizzOptions.takingOver = nil

    -- Wie bei ihrem Hauptfenster: ein Schließen mitten im eigenen OnShow
    -- kommt nicht immer durch, was danach in ihrem Aufruf folgt, stellt es
    -- wieder her. Deshalb in den nächsten Durchläufen nachsehen.
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        local function recheck()
            if not BlizzOptions:ShouldReplace() then
                return
            end
            local stillOpen = false
            pcall(function() stillOpen = blizzard:IsShown() and true or false end)
            if stillOpen then
                BlizzOptions.takingOver = true
                pcall(blizzard.Hide, blizzard)
                BlizzOptions.takingOver = nil
            end

            -- Unseres kann zwischenzeitlich geschlossen worden sein: es steht
            -- in UISpecialFrames, und der Bearbeitungsmodus ruft
            -- CloseAllWindows auf. Genau daran ist das Hauptpanel schon
            -- einmal gescheitert - offen, richtig platziert, und einen
            -- Bruchteil später zu.
            if not BlizzOptions:IsShown() then
                FCD.LogOnly(L["Eigenes Leistenfenster war zu - erneut geöffnet."]
                    .. L[" (Sollte nicht mehr vorkommen, seit es nicht mehr in"]
                    .. L[" UISpecialFrames steht.)"])
                pcall(BlizzOptions.Open, BlizzOptions, system)
            end
        end
        C_Timer.After(0, recheck)
        C_Timer.After(0.1, recheck)
        C_Timer.After(0.3, recheck)
    end

    FCD.LogOnly(string.format(
        L["Übernommen: Ebene=%s, Höhe=%.0f, links=%s, oben=%s, Deckkraft=%s, offen=%s"],
        tostring(BlizzOptions:Strata()), BlizzOptions:Height(),
        tostring(BlizzOptions:Edge("GetLeft")), tostring(BlizzOptions:Edge("GetTop")),
        tostring(BlizzOptions:Alpha()), tostring(BlizzOptions:IsShown())))
end

function BlizzOptions:HookDialog()
    if self.hooked then
        return true
    end
    local blizzard = _G.EditModeSystemSettingsDialog
    if type(blizzard) ~= "table" or type(blizzard.HookScript) ~= "function" then
        return false
    end

    local ok = pcall(blizzard.HookScript, blizzard, "OnShow", function(self)
        -- Die Ausnahme gilt für genau einen Aufruf.
        if BlizzOptions.allowBlizzardDialog then
            BlizzOptions.allowBlizzardDialog = nil
            return
        end
        -- Abgesichert, weil wir hier in ihrem Handler laufen: ein Fehler von
        -- uns würde sonst auch ihren Aufruf abbrechen - dann steht weder ihr
        -- Fenster noch unseres offen, ohne jede Meldung.
        local okTake, takeErr = pcall(takeOver, self)
        if not okTake then
            FCD.LogOnly(L["Übernahme fehlgeschlagen: "] .. tostring(takeErr))
            FCD.Print(L["Leistenfenster ließ sich nicht übernehmen - /fcd log."])
        end
    end)
    if not ok then
        return false
    end

    -- Geht ihr Fenster zu, weil die Auswahl aufgehoben wurde, gehört unseres
    -- mit zu. Beim Verdrängen schließen wir es selbst - dann steht unseres
    -- gerade erst offen und darf nicht mitgerissen werden.
    pcall(blizzard.HookScript, blizzard, "OnHide", function()
        -- Während der Übernahme blenden wir ihres selbst aus; unseres steht
        -- dann gerade erst offen und darf nicht mitgerissen werden.
        if BlizzOptions.takingOver or not BlizzOptions:IsShown() then
            return
        end
        local system = rawget(blizzard, "attachedToSystem")
        if not isCooldownViewer(system) then
            BlizzOptions:Close(L["ihr Fenster ging zu"])
        end
    end)

    local editManager = _G.EditModeManagerFrame
    if type(editManager) == "table" and type(editManager.HookScript) == "function" then
        pcall(editManager.HookScript, editManager, "OnHide", function()
            if type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then
                BlizzOptions:Close(L["Bearbeitungsmodus zu"])
                return
            end
            -- Einen Durchlauf warten: ihr Verwalter blendet sich zwischendurch
            -- aus, ohne dass der Modus endet. Sofort zu schließen hätte unser
            -- Fenster bei jeder solchen Zwischenlage mitgerissen.
            C_Timer.After(0, function()
                local stillHidden = true
                pcall(function()
                    stillHidden = not _G.EditModeManagerFrame:IsShown()
                end)
                if stillHidden then
                    BlizzOptions:Close(L["Bearbeitungsmodus zu"])
                end
            end)
        end)
    end

    self.hooked = true
    FCD.LogOnly(L["Haken auf ihrem Bearbeitungsmodus-Fenster gesetzt."])
    return true
end
