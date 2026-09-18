local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local BarOptions = {}
FCD.BarOptions = BarOptions

-- Blizzards Bearbeitungsmodus zeigt für jede Leiste ein kleines Fenster mit
-- Ausrichtung, Größe, Abstand, Transparenz und Sichtbarkeit. Für unsere
-- Leisten gab es das nicht - man musste dafür den Editor öffnen. Dieses
-- Fenster holt dieselben Einstellungen an dieselbe Stelle: anklicken,
-- solange die Leiste entsperrt ist.
--
-- Alle Werte stehen bereits im Profil; hier wird nichts Neues gespeichert,
-- nur anders erreichbar gemacht.

local WIDTH = 300
local ROW = 26
local PAD = 12

local dialog
local current, currentFrame

-- Blizzard trennt zwei Dinge, die bei uns bisher in einem Wert steckten:
-- "Ausrichtung" (waagerecht oder senkrecht) und "Symbolausrichtung" (in
-- welche Richtung die Symbole laufen). Beides zusammen ergibt unser growth.
local ORIENTATION_OPTIONS = {
    { value = "HORIZONTAL", text = "Horizontal" },
    { value = "VERTICAL", text = "Vertikal" },
}

local DIRECTION_OPTIONS = {
    HORIZONTAL = {
        { value = "RIGHT", text = "Nach rechts" },
        { value = "LEFT", text = "Nach links" },
    },
    VERTICAL = {
        { value = "DOWN", text = "Nach unten" },
        { value = "UP", text = "Nach oben" },
    },
}

local GROWTH_OPTIONS = {
    { value = "RIGHT", text = "Nach rechts" },
    { value = "LEFT", text = "Nach links" },
    { value = "DOWN", text = "Nach unten" },
    { value = "UP", text = "Nach oben" },
}

local function orientationOf(growth)
    if growth == "UP" or growth == "DOWN" then
        return "VERTICAL"
    end
    return "HORIZONTAL"
end

local function orientationText(value)
    for _, option in ipairs(ORIENTATION_OPTIONS) do
        if option.value == value then
            return L[option.text]
        end
    end
    return L[ORIENTATION_OPTIONS[1].text]
end

local VISIBILITY_OPTIONS = {
    { value = "always", text = "Immer sichtbar" },
    { value = "inCombat", text = "Nur im Kampf" },
    { value = "hasTarget", text = "Nur mit Ziel" },
    -- "Nie" blendet die Leiste im Spiel aus, ohne ihren Inhalt zu verlieren.
    -- Erreichbar bleibt sie über den Bearbeitungsmodus, dort wird jede Leiste
    -- gezeigt - sonst käme man an diese Einstellung nie wieder heran.
    { value = "never", text = "Nie" },
}

-- "Keines" steht mit in der Liste, statt als eigener Haken daneben. Vorher
-- gab es beides: einen Schalter "Melden, wenn bereit" und darunter die Art -
-- zwei Bedienelemente für eine Entscheidung, und "Keines" fehlte trotzdem.
-- Die Eintragsliste macht es seit jeher so, jetzt beide gleich.
local ALERT_MODES = {
    { value = "off", text = "Keines" },
    { value = "both", text = "Leuchten und Ton" },
    { value = "glow", text = "Nur Leuchten" },
    { value = "sound", text = "Nur Ton" },
}

-- Der gespeicherte Zustand sind zwei Felder; im Auswahlfeld ist es einer.
local function barAlertValue(bar)
    if not bar or not bar.alertReady then
        return "off"
    end
    return bar.alertMode or "both"
end

local function alertModeText(value)
    for _, option in ipairs(ALERT_MODES) do
        if option.value == value then
            return L[option.text]
        end
    end
    return L[ALERT_MODES[1].text]
end

local function soundLabelFor(id)
    for _, choice in ipairs(FCD.Viewer:GetSoundChoices()) do
        if choice.id == id then
            return choice.label
        end
    end
    return FCD.Viewer:GetSoundChoices()[1].label
end

local function growthText(value)
    for _, option in ipairs(GROWTH_OPTIONS) do
        if option.value == value then
            return L[option.text]
        end
    end
    return L[GROWTH_OPTIONS[1].text]
end

local function visibilityValue(bar)
    local visibility = bar.visibility or {}
    if visibility.never then
        return "never"
    end
    if visibility.inCombat then
        return "inCombat"
    end
    if visibility.hasTarget then
        return "hasTarget"
    end
    return "always"
end

local function visibilityText(value)
    for _, option in ipairs(VISIBILITY_OPTIONS) do
        if option.value == value then
            return L[option.text]
        end
    end
    return L[VISIBILITY_OPTIONS[1].text]
end

-- Eine Gegenstandsleiste braucht andere Schalter als eine Zauberleiste:
-- Gegenstände haben keinen Rang und werden nicht gelernt.
local function isItemBar(bar)
    if type(bar) ~= "table" then
        return false
    end
    if bar.fcdItemDefaults then
        return true
    end
    local entries = bar.entries or {}
    if #entries == 0 then
        return false
    end
    for _, entry in ipairs(entries) do
        if entry.kind ~= "item" and entry.kind ~= "inventory" then
            return false
        end
    end
    return true
end

local function applied()
    FCD.Viewer:RebuildAll()
    FCD.Viewer:ApplyLockState()
    FCD.Viewer:Update()
end

-- --------------------------------------------------------------- Bausteine

local function addEdges(parent, red, green, blue, alpha)
    local edges = {}
    for index = 1, 4 do
        edges[index] = parent:CreateTexture(nil, "OVERLAY")
        edges[index]:SetColorTexture(red, green, blue, alpha)
    end
    edges[1]:SetPoint("TOPLEFT")
    edges[1]:SetPoint("TOPRIGHT")
    edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT")
    edges[2]:SetPoint("BOTTOMRIGHT")
    edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT")
    edges[3]:SetPoint("BOTTOMLEFT")
    edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT")
    edges[4]:SetPoint("BOTTOMRIGHT")
    edges[4]:SetWidth(1)
    return edges
end

-- Eigener Schieberegler statt OptionsSliderTemplate: die Vorlage ist in
-- neueren Clients mehrfach umgebaut worden, und ohne sie hätte der Regler
-- keinen sichtbaren Griff. Schiene und Griff sind hier Farbflächen, die
-- immer da sind.
local function createSlider(parent, label, minimum, maximum, step, getter, setter, format, apply)
    apply = apply or applied
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize((parent.fcdContentWidth or (WIDTH - 2 * PAD)), ROW)

    holder.label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    holder.label:SetPoint("LEFT", 0, 0)
    holder.label:SetWidth(96)
    holder.label:SetJustifyH("LEFT")
    holder.label:SetText(label)

    holder.value = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    holder.value:SetPoint("RIGHT", 0, 0)
    holder.value:SetWidth(42)
    holder.value:SetJustifyH("RIGHT")

    -- Die Pfeile links und rechts hat Blizzard auch; sie sind der bequemere
    -- Weg für einen einzelnen Schritt.
    local function stepper(text, anchorPoint, offsetX, delta)
        local arrow = CreateFrame("Button", nil, holder)
        arrow:SetSize(14, 18)
        arrow.text = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow.text:SetAllPoints()
        arrow.text:SetText(text)
        arrow.text:SetTextColor(1, 0.82, 0)
        arrow.highlight = arrow:CreateTexture(nil, "HIGHLIGHT")
        arrow.highlight:SetAllPoints()
        arrow.highlight:SetColorTexture(1, 1, 1, 0.12)
        arrow.delta = delta
        return arrow
    end

    holder.down = stepper("<", nil, 0, -step)
    holder.down:SetPoint("LEFT", holder.label, "RIGHT", 4, 0)
    holder.up = stepper(">", nil, 0, step)
    holder.up:SetPoint("RIGHT", holder.value, "LEFT", -4, 0)

    local slider = CreateFrame("Slider", nil, holder)
    slider:SetPoint("LEFT", holder.down, "RIGHT", 4, 0)
    slider:SetPoint("RIGHT", holder.up, "LEFT", -4, 0)
    slider:SetHeight(16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    slider.track = slider:CreateTexture(nil, "BACKGROUND")
    slider.track:SetPoint("LEFT")
    slider.track:SetPoint("RIGHT")
    slider.track:SetHeight(4)
    slider.track:SetColorTexture(0, 0, 0, 0.7)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(10, 16)
    thumb:SetColorTexture(1, 0.82, 0, 1)
    if not pcall(slider.SetThumbTexture, slider, thumb) then
        pcall(slider.SetThumbTexture, slider, "Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    end

    holder.Refresh = function()
        local value = getter()
        slider.updating = true
        slider:SetValue(value)
        slider.updating = false
        holder.value:SetText(format and format(value) or tostring(value))
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if self.updating then
            return
        end
        value = math.floor(value / step + 0.5) * step
        setter(value)
        holder.value:SetText(format and format(value) or tostring(value))
        apply()
    end)

    local function nudge(delta)
        local value = getter() + delta
        if value < minimum then value = minimum end
        if value > maximum then value = maximum end
        setter(value)
        holder.Refresh()
        apply()
    end
    holder.down:SetScript("OnClick", function() nudge(-step) end)
    holder.up:SetScript("OnClick", function() nudge(step) end)

    holder.slider = slider
    holder.thumb = thumb

    -- Blizzards eigenen Griff und ihre Pfeile übernehmen, sobald der
    -- Bearbeitungsmodus sie hergibt. Vorher bleiben unsere Farbflächen.
    holder.BorrowArt = function()
        if holder.artApplied or not FCD.Art then
            return
        end
        local art = FCD.Art:LearnSliderArt()
        if not art then
            return
        end
        if FCD.Art:ApplyTexture(holder.thumb, art.thumb) then
            holder.artApplied = true
        end
        if art.left then
            holder.down.texture = holder.down.texture
                or holder.down:CreateTexture(nil, "ARTWORK")
            if FCD.Art:ApplyTexture(holder.down.texture, art.left) then
                holder.down.texture:SetPoint("CENTER")
                holder.down.text:Hide()
            end
        end
        if art.right then
            holder.up.texture = holder.up.texture
                or holder.up:CreateTexture(nil, "ARTWORK")
            if FCD.Art:ApplyTexture(holder.up.texture, art.right) then
                holder.up.texture:SetPoint("CENTER")
                holder.up.text:Hide()
            end
        end
    end

    return holder
end

-- Geteilt mit dem Fenster für Blizzards eigene Leisten: gleicher Regler,
-- gleiche Pfeile, gleiche übernommene Grafik.
BarOptions.CreateSlider = createSlider
BarOptions.AddEdges = addEdges

-- ----------------------------------------------------------------- Fenster

local function build()
    if dialog then
        return dialog
    end

    -- Blizzards Rahmen statt eines eigenen Kastens: goldene Fassung,
    -- Titelleiste und Schließkreuz sitzen damit genau wie bei ihnen.
    dialog = Compat.CreateFrame("Frame", "ForeverCooldownsBarOptions", UIParent,
        "BasicFrameTemplateWithInset")
    dialog:SetSize(WIDTH, 420)
    -- Über Blizzards Bearbeitungsmodus-Fenster, sonst liegt es davor.
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:SetClampedToScreen(true)
    dialog:Hide()
    tinsert(UISpecialFrames, "ForeverCooldownsBarOptions")

    -- Immer eine deckende Fläche ganz hinten: Blizzards Rahmenvorlage ist
    -- durchscheinend, und ihr Bearbeitungsmodus-Fenster lag darunter deutlich
    -- sichtbar durch.
    dialog.background = dialog:CreateTexture(nil, "BACKGROUND", nil, -8)
    dialog.background:SetAllPoints()
    dialog.background:SetColorTexture(0.04, 0.04, 0.06, 1)

    -- Ohne die Vorlage fehlt jede weitere Grafik; dann zeichnen wir sie selbst.
    if not dialog.TitleBg then
        addEdges(dialog, 0.55, 0.50, 0.35, 1)
        local close = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
    end

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dialog.title:SetPoint("TOP", 0, -6)

    local offsetY = -34
    local function place(widget, height)
        widget:SetPoint("TOPLEFT", PAD, offsetY)
        offsetY = offsetY - (height or ROW)
    end

    dialog.rows = {}
    local function remember(widget)
        dialog.rows[#dialog.rows + 1] = widget
        return widget
    end

    -- Ausrichtung
    local orientationLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    orientationLabel:SetPoint("TOPLEFT", PAD, offsetY - 4)
    orientationLabel:SetText(L["Ausrichtung"])
    dialog.orientation = FCD.Widgets.CreateDropdown(dialog, 150, function()
        local items = {}
        for _, option in ipairs(ORIENTATION_OPTIONS) do
            items[#items + 1] = { text = L[option.text], value = option.value }
        end
        return items
    end, function(value)
        if current then
            -- Beim Wechsel die erste Richtung dieser Ausrichtung nehmen
            current.growth = DIRECTION_OPTIONS[value][1].value
            BarOptions:Refresh()
            applied()
        end
    end)
    dialog.orientation:SetPoint("TOPRIGHT", -PAD, offsetY)
    offsetY = offsetY - ROW - 4

    -- Symbolausrichtung
    local growthLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    growthLabel:SetPoint("TOPLEFT", PAD, offsetY - 4)
    growthLabel:SetText(L["Symbolausrichtung"])
    dialog.growth = FCD.Widgets.CreateDropdown(dialog, 150, function()
        local items = {}
        local orientation = orientationOf(current and current.growth)
        for _, option in ipairs(DIRECTION_OPTIONS[orientation]) do
            items[#items + 1] = { text = L[option.text], value = option.value }
        end
        return items
    end, function(value)
        if current then
            current.growth = value
            dialog.growth:SetText(growthText(value))
            applied()
        end
    end)
    dialog.growth:SetPoint("TOPRIGHT", -PAD, offsetY)
    offsetY = offsetY - ROW - 4

    -- Zahlenwerte
    dialog.columns = remember(createSlider(dialog, L["Spalten"], 1, 24, 1, function()
        return current and current.columns or 12
    end, function(value)
        current.columns = value
    end))
    place(dialog.columns)

    dialog.iconSize = remember(createSlider(dialog, L["Symbolgröße"], 20, 80, 2, function()
        return current and current.iconSize or 40
    end, function(value)
        current.iconSize = value
    end, function(value)
        return string.format("%d%%", math.floor(value / 40 * 100 + 0.5))
    end))
    place(dialog.iconSize)

    dialog.spacing = remember(createSlider(dialog, L["Symbolabstand"], 0, 20, 1, function()
        return current and current.spacing or 4
    end, function(value)
        current.spacing = value
    end))
    place(dialog.spacing)

    dialog.alpha = remember(createSlider(dialog, L["Transparenz"], 10, 100, 5, function()
        return math.floor((current and current.alpha or 1) * 100 + 0.5)
    end, function(value)
        current.alpha = value / 100
    end, function(value)
        return string.format("%d%%", value)
    end))
    place(dialog.alpha)

    offsetY = offsetY - 6

    -- Sichtbarkeit
    local visibilityLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    visibilityLabel:SetPoint("TOPLEFT", PAD, offsetY - 4)
    visibilityLabel:SetText(L["Sichtbarkeit"])
    dialog.visibility = FCD.Widgets.CreateDropdown(dialog, 150, function()
        local items = {}
        for _, option in ipairs(VISIBILITY_OPTIONS) do
            items[#items + 1] = { text = L[option.text], value = option.value }
        end
        return items
    end, function(value)
        if current then
            current.visibility = current.visibility or {}
            current.visibility.always = (value == "always")
            current.visibility.inCombat = (value == "inCombat")
            current.visibility.hasTarget = (value == "hasTarget")
            current.visibility.never = (value == "never")
            dialog.visibility:SetText(visibilityText(value))
            applied()
        end
    end)
    dialog.visibility:SetPoint("TOPRIGHT", -PAD, offsetY)
    offsetY = offsetY - ROW - 6

    local function addCheck(text, getter, setter)
        local check = FCD.Widgets.CreateCheck(dialog, text, getter, function(value)
            setter(value)
            applied()
        end)
        check:SetPoint("TOPLEFT", PAD, offsetY)
        offsetY = offsetY - 24
        dialog.rows[#dialog.rows + 1] = check
        return check
    end

    addCheck(L["Bei Inaktivität verbergen"], function()
        return current and (current.visibility or {}).onlyOnCooldown
    end, function(value)
        current.visibility = current.visibility or {}
        current.visibility.onlyOnCooldown = value
    end)

    addCheck(L["Timer anzeigen"], function()
        return current and current.showTimer
    end, function(value)
        current.showTimer = value
    end)

    -- Ohne Angabe an, wie bei Blizzard. Steht er aus, nehmen die Symbole die
    -- Maus gar nicht erst an - Klicks gehen dann durch die Leiste hindurch.
    addCheck(L["Tooltips anzeigen"], function()
        return current and current.showTooltips ~= false
    end, function(value)
        current.showTooltips = value
    end)

    -- Fertig-Meldung: standardmäßig "Keines". Auf einer Leiste mit zwanzig
    -- Symbolen würde sonst dauernd etwas leuchten.
    local alertLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alertLabel:SetPoint("TOPLEFT", PAD, offsetY - 4)
    alertLabel:SetText(L["Melden, wenn bereit"])
    dialog.alertMode = FCD.Widgets.CreateDropdown(dialog, 150, function()
        local items = {}
        for _, option in ipairs(ALERT_MODES) do
            items[#items + 1] = { text = L[option.text], value = option.value }
        end
        return items
    end, function(value)
        if not current then
            return
        end
        if value == "off" then
            current.alertReady = false
        else
            current.alertReady = true
            current.alertMode = value
        end
        dialog.alertMode:SetText(alertModeText(value))
        BarOptions:Refresh()
        applied()

        if value ~= "off" and Compat.caps.secretCooldown then
            FCD.Print(L["Dieser Client schützt die Abklingzeit-Werte -"])
            FCD.Print(L["das Ende lässt sich damit nicht erkennen."])
        else
            -- Wie beim Ton: sofort zeigen, was gewählt wurde.
            FCD.Viewer:PreviewAlert(current, nil)
        end
    end)
    dialog.alertMode:SetPoint("TOPRIGHT", -PAD, offsetY)
    offsetY = offsetY - ROW - 2
    dialog.alertModeLabel = alertLabel

    local soundLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    soundLabel:SetPoint("TOPLEFT", PAD + 18, offsetY - 4)
    soundLabel:SetText(L["Ton"])
    dialog.alertSound = FCD.Widgets.CreateDropdown(dialog, 132, function()
        local items = {}
        for _, choice in ipairs(FCD.Viewer:GetSoundChoices()) do
            items[#items + 1] = { text = choice.label, value = choice.id }
        end
        return items
    end, function(value)
        if current then
            current.alertSoundID = value
            dialog.alertSound:SetText(soundLabelFor(value))
            -- Sofort vorspielen: nur so hört man, ob der Ton in diesem Client
            -- überhaupt etwas hergibt.
            FCD.Viewer:PlayAlertSound(value)
        end
    end)
    dialog.alertSound:SetPoint("TOPRIGHT", -PAD, offsetY)
    offsetY = offsetY - ROW - 2
    dialog.alertSoundLabel = soundLabel

    -- Einzelne Symbole dürfen abweichen. Das braucht eine Liste und damit ein
    -- eigenes Fenster. Der Knopf bleibt auch dann bedienbar, wenn die Leiste
    -- selbst nichts meldet: genau dann ist der häufigste Fall, dass einer der
    -- Einträge trotzdem melden soll.
    dialog.entryAlerts = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    dialog.entryAlerts:SetSize(WIDTH - 2 * PAD - 18, 20)
    dialog.entryAlerts:SetPoint("TOPLEFT", PAD + 18, offsetY)
    dialog.entryAlerts:SetText(L["Je Eintrag festlegen"])
    dialog.entryAlerts:SetScript("OnClick", function()
        if current then
            BarOptions:OpenEntries(current)
        end
    end)
    dialog.entryAlerts:SetScript("OnEnter", function(self)
        FCD.Widgets.ShowTooltip(self, "ANCHOR_RIGHT", L["Fertig-Meldung je Eintrag"],
            L["Einzelne Symbole dürfen von der Leiste abweichen -"],
            L["melden, obwohl die Leiste stumm ist, oder umgekehrt."])
    end)
    dialog.entryAlerts:SetScript("OnLeave", FCD.Widgets.HideTooltip)
    offsetY = offsetY - 26

    -- Die Belegung läuft über Blizzards sichere Vorlage; im Kampf ist sie
    -- nicht änderbar, also wird sie außerhalb gesetzt und bleibt dann stehen.
    addCheck(L["Beim Anklicken benutzen"], function()
        return current and current.clickToUse
    end, function(value)
        current.clickToUse = value
        if value and InCombatLockdown() then
            FCD.Print(L["Im Kampf lässt sich die Belegung nicht setzen -"]
                .. L[" sie greift nach dem Kampf."])
        end
    end)

    -- Derselbe Schalter, zwei Bedeutungen: bei Zaubern der Rang, bei
    -- Gegenständen die Stückzahl. Die Beschriftung wechselt mit der Leiste.
    dialog.rankCheck = addCheck(L["Rang anzeigen"], function()
        if isItemBar(current) then
            return current and current.showCount ~= false
        end
        return current and current.showRank
    end, function(value)
        if isItemBar(current) then
            current.showCount = value
        else
            current.showRank = value
        end
    end)

    dialog.unknownCheck = addCheck(L["Nicht Gelerntes verbergen"], function()
        return current and (current.visibility or {}).hideUnknown
    end, function(value)
        current.visibility = current.visibility or {}
        current.visibility.hideUnknown = value
    end)

    offsetY = offsetY - 8

    local function addButton(text, onClick)
        local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        button:SetSize(WIDTH - 2 * PAD, 22)
        button:SetPoint("TOPLEFT", PAD, offsetY)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        offsetY = offsetY - 25
        return button
    end

    addButton(L["Änderungen verwerfen"], function()
        FCD.Profiles:Undo()
        applied()
        BarOptions:Refresh()
    end)

    addButton(L["Auf Standardposition zurücksetzen"], function()
        if not current then
            return
        end
        current.point = "CENTER"
        current.relativePoint = "CENTER"
        current.x = 0
        current.y = -170
        applied()
    end)

    addButton(L["Abklingzeitmanager-Optionen"], function()
        dialog:Hide()
        FCD:OpenMainUI()
    end)

    dialog:SetHeight(-offsetY + PAD)
    return dialog
end

function BarOptions:Refresh()
    if not dialog or not current then
        return
    end
    local items = isItemBar(current)
    dialog.rankCheck.text:SetText(items and L["Anzahl anzeigen"] or L["Rang anzeigen"])
    -- Art und Ton hängen an der Meldung; ohne sie sind sie wirkungslos. Und
    -- der Ton hängt zusätzlich an der Art: bei "Nur Leuchten" gibt es keinen.
    local value = barAlertValue(current)
    local withSound = (value == "both" or value == "sound")
    dialog.alertMode:SetText(alertModeText(value))
    dialog.alertSound:SetText(soundLabelFor(current.alertSoundID))
    for widget, enabled in pairs({
        [dialog.alertSound] = withSound, [dialog.alertSoundLabel] = withSound,
    }) do
        widget:SetAlpha(enabled and 1 or 0.35)
        if widget.EnableMouse then
            widget:EnableMouse(enabled)
        end
    end
    -- Gegenstände werden nicht gelernt; der Schalter hätte keine Wirkung.
    dialog.unknownCheck:SetShown(not items)

    -- Der gespeicherte Name ist die Kennung der Leiste und bleibt deutsch;
    -- fuer die Anzeige wird er uebersetzt, sofern es eine Uebersetzung gibt.
    dialog.title:SetText(current.name and L[current.name]
        or (L["Leiste "] .. tostring(current.id)))
    dialog.orientation:SetText(orientationText(orientationOf(current.growth)))
    dialog.growth:SetText(growthText(current.growth))
    dialog.visibility:SetText(visibilityText(visibilityValue(current)))
    for _, row in ipairs(dialog.rows) do
        if row.BorrowArt then
            row.BorrowArt()
        end
        if row.Refresh then
            row.Refresh()
        end
    end
end

function BarOptions:Open(bar, barFrame)
    if type(bar) ~= "table" then
        return
    end
    build()
    -- Beim Öffnen einmal sichern, damit "Änderungen verwerfen" genau auf den
    -- Stand zurückgeht, den die Leiste vor dem Bearbeiten hatte.
    if current ~= bar then
        FCD.Profiles:PushUndo("Leisteneinstellungen")
    end
    -- Bei einem Leistenwechsel wandert das Eintragsfenster mit, statt weiter
    -- die alte Leiste zu zeigen.
    if current ~= bar then
        self:CloseEntries()
    end
    current, currentFrame = bar, barFrame

    -- Dasselbe in die andere Richtung: ein Klick auf unsere Leiste schließt
    -- das Fenster für ihre - und hebt ihre Markierung auf. Ohne das Zweite
    -- standen zwei Leisten golden umrandet da, während nur ein Fenster offen
    -- war, und man sah nicht mehr, welche gerade bearbeitet wird.
    if FCD.BlizzOptions then
        FCD.BlizzOptions:Close(L["unsere Leiste angeklickt"])
        FCD.BlizzOptions:ClearBlizzardSelection()
    end

    self:Refresh()

    -- Dieselbe Regel wie beim Fenster für ihre Leisten: daneben, nicht
    -- darunter. Unter der Leiste verdeckte es genau das, was man gerade
    -- einstellt. Erst nach Refresh, weil die Regel die Höhe braucht.
    if barFrame then
        FCD.Widgets.PlaceBeside(dialog, barFrame)
    else
        dialog:ClearAllPoints()
        dialog:SetPoint("CENTER")
    end
    dialog:Show()
end

function BarOptions:Close()
    if dialog then
        dialog:Hide()
    end
    -- Das Eintragsfenster gehört zu einer bestimmten Leiste. Bleibt es allein
    -- stehen, bezieht es sich auf etwas, das niemand mehr bearbeitet.
    self:CloseEntries()
end

function BarOptions:IsShown()
    return dialog and dialog:IsShown() and true or false
end

function BarOptions:CurrentBar()
    return current
end

-- ------------------------------------------- Fertig-Meldung je Eintrag

-- Die Leiste gibt den Grundton vor, der einzelne Eintrag darf abweichen.
-- Damit lässt sich eine volle Leiste stumm halten und trotzdem der eine
-- Zauber melden, auf den es ankommt - oder umgekehrt genau einer von zwanzig
-- ausnehmen.
--
-- An- und Ausschalten steckt im selben Auswahlfeld wie die Art. So ist "Wie
-- Leiste" ein Wert wie jeder andere und nicht ein dritter Zustand, den man
-- erst über einen Haken daneben erreicht.
local INHERIT = "inherit"

local ENTRY_ALERT_OPTIONS = {
    { value = INHERIT, text = "Wie Leiste" },
    { value = "off", text = "Aus" },
    { value = "both", text = "Leuchten und Ton" },
    { value = "glow", text = "Nur Leuchten" },
    { value = "sound", text = "Nur Ton" },
}

local ENTRY_WIDTH = 460
local ENTRY_ROW_HEIGHT = 28
local ENTRY_VISIBLE_ROWS = 9

local entryDialog, entryBar

-- nil heißt "nichts gesagt", false heißt ausdrücklich aus. Deshalb wird auf
-- ~= nil geprüft und nicht auf Wahrheit - sonst wäre "Aus" nicht von "Wie
-- Leiste" zu unterscheiden.
local function entryAlertValue(entry)
    if entry.alertReady == nil then
        return INHERIT
    end
    if not entry.alertReady then
        return "off"
    end
    return entry.alertMode or "both"
end

local function entryAlertText(entry)
    local value = entryAlertValue(entry)
    for _, option in ipairs(ENTRY_ALERT_OPTIONS) do
        if option.value == value then
            return L[option.text]
        end
    end
    return L[ENTRY_ALERT_OPTIONS[1].text]
end

local function setEntryAlert(entry, value)
    if value == INHERIT then
        entry.alertReady, entry.alertMode = nil, nil
    elseif value == "off" then
        entry.alertReady, entry.alertMode = false, nil
    else
        entry.alertReady, entry.alertMode = true, value
    end
end

local function entrySoundText(entry)
    if entry.alertSoundID == nil then
        return L["Wie Leiste"]
    end
    return soundLabelFor(entry.alertSoundID)
end

-- Name und Symbol für die Zeile. Zauber laufen über die Rangauflösung, damit
-- dort derselbe Rang steht wie auf der Leiste.
local function entryDisplay(entry)
    if entry.kind == "spell" then
        local spellID = FCD.Ranks:Resolve(entry)
        if spellID then
            local name, icon = Compat.GetSpellInfo(spellID)
            return name or (L["Zauber "] .. tostring(spellID)), icon
        end
        return L["Zauber "] .. tostring(entry.id or "?"), nil
    end
    local name, icon = FCD.Items:GetDisplay(entry)
    return name or ("Gegenstand " .. tostring(entry.id or "?")), icon
end

-- Was "Wie Leiste" an dieser Leiste bedeutet. Ohne diese Zeile müsste man
-- das Fenster wechseln, um die Vorgabe nachzusehen.
local function barAlertSummary(bar)
    local value = barAlertValue(bar)
    if value == "off" then
        return L["Diese Leiste meldet nichts."]
    end
    if value == "glow" then
        return L["Diese Leiste meldet: "] .. alertModeText(value) .. "."
    end
    return string.format(L["Diese Leiste meldet: %s (%s)."],
        alertModeText(value), soundLabelFor(bar.alertSoundID))
end

local function acquireEntryRow(index)
    local row = entryDialog.entryRows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, entryDialog.content)
    row:SetHeight(ENTRY_ROW_HEIGHT)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT")
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.label:SetWidth(110)
    row.label:SetJustifyH("LEFT")
    if row.label.SetWordWrap then
        row.label:SetWordWrap(false)
    end

    row.mode = FCD.Widgets.CreateDropdown(row, 128, function()
        local items = {}
        for _, option in ipairs(ENTRY_ALERT_OPTIONS) do
            items[#items + 1] = { text = L[option.text], value = option.value }
        end
        return items
    end, function(value)
        if row.entry then
            setEntryAlert(row.entry, value)
            BarOptions:RefreshEntries()
            applied()
            -- applied() baut die Leisten neu auf; die Vorschau muss danach
            -- laufen, sonst leuchtet ein Symbol, das es nicht mehr gibt.
            FCD.Viewer:PreviewAlert(entryBar, row.entry)
        end
    end)
    row.mode:SetPoint("LEFT", row.label, "RIGHT", 6, 0)

    row.sound = FCD.Widgets.CreateDropdown(row, 128, function()
        local items = { { text = L["Wie Leiste"], value = INHERIT } }
        for _, choice in ipairs(FCD.Viewer:GetSoundChoices()) do
            items[#items + 1] = { text = choice.label, value = choice.id }
        end
        return items
    end, function(value)
        if row.entry then
            row.entry.alertSoundID = (value ~= INHERIT) and value or nil
            BarOptions:RefreshEntries()
            -- Wie im Leistenfenster: sofort vorspielen, sonst wählt man einen
            -- Namen und weiß nicht, was er hergibt.
            if value ~= INHERIT then
                FCD.Viewer:PlayAlertSound(value)
            end
        end
    end)
    row.sound:SetPoint("LEFT", row.mode, "RIGHT", 6, 0)

    entryDialog.entryRows[index] = row
    return row
end

local function buildEntries()
    if entryDialog then
        return entryDialog
    end

    entryDialog = Compat.CreateFrame("Frame", "ForeverCooldownsEntryAlerts",
        UIParent, "BasicFrameTemplateWithInset")
    entryDialog:SetSize(ENTRY_WIDTH, 300)
    entryDialog:SetFrameStrata("FULLSCREEN_DIALOG")
    entryDialog:SetMovable(true)
    entryDialog:EnableMouse(true)
    entryDialog:RegisterForDrag("LeftButton")
    entryDialog:SetScript("OnDragStart", entryDialog.StartMoving)
    entryDialog:SetScript("OnDragStop", entryDialog.StopMovingOrSizing)
    entryDialog:SetClampedToScreen(true)
    entryDialog:Hide()
    tinsert(UISpecialFrames, "ForeverCooldownsEntryAlerts")

    entryDialog.background = entryDialog:CreateTexture(nil, "BACKGROUND", nil, -8)
    entryDialog.background:SetAllPoints()
    entryDialog.background:SetColorTexture(0.04, 0.04, 0.06, 1)

    if not entryDialog.TitleBg then
        addEdges(entryDialog, 0.55, 0.50, 0.35, 1)
        local close = CreateFrame("Button", nil, entryDialog, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
    end

    entryDialog.title = entryDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    entryDialog.title:SetPoint("TOP", 0, -6)

    entryDialog.hint = entryDialog:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    entryDialog.hint:SetPoint("TOPLEFT", PAD, -30)
    entryDialog.hint:SetPoint("TOPRIGHT", -PAD, -30)
    entryDialog.hint:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", nil, entryDialog, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", PAD, -48)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 24, PAD)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(ENTRY_WIDTH - 2 * PAD - 24, 1)
    scroll:SetScrollChild(content)
    entryDialog.scroll = scroll
    entryDialog.content = content
    entryDialog.entryRows = {}

    -- Geht dieses Fenster zu, gilt keine Leiste mehr als bearbeitet. Sonst
    -- bezöge sich ein späteres Refresh auf eine Leiste, die niemand mehr
    -- offen hat.
    entryDialog:SetScript("OnHide", function()
        entryBar = nil
    end)

    return entryDialog
end

function BarOptions:RefreshEntries()
    if not entryDialog or not entryBar then
        return
    end

    local entries = entryBar.entries or {}
    entryDialog.title:SetText(L["Fertig-Meldung: "]
        .. (entryBar.name and L[entryBar.name]
            or (L["Leiste "] .. tostring(entryBar.id))))
    -- Schützt der Client die Abklingzeit-Werte, ist das Ende nicht zu
    -- erkennen und es meldet von selbst gar nichts. Das gehört hierhin und
    -- nicht nur als Chatzeile beim Einschalten - sonst sucht man den Fehler
    -- bei den Einstellungen.
    if Compat.caps.secretCooldown then
        entryDialog.hint:SetText(L["|cffff6060Dieser Client schützt die"]
            .. L[" Abklingzeit-Werte - es meldet nichts von selbst.|r"])
    else
        entryDialog.hint:SetText(barAlertSummary(entryBar))
    end

    local shown = 0
    for index, entry in ipairs(entries) do
        local row = acquireEntryRow(index)
        row.entry = entry
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * ENTRY_ROW_HEIGHT)
        row:SetPoint("TOPRIGHT", 0, -(index - 1) * ENTRY_ROW_HEIGHT)

        local name, icon = entryDisplay(entry)
        row.icon:SetTexture(icon or 134400)
        row.label:SetText(name)
        row.mode:SetText(entryAlertText(entry))
        row.sound:SetText(entrySoundText(entry))

        -- Der Ton ist nur zu wählen, wenn bei diesem Eintrag überhaupt einer
        -- fällt. "Nur Leuchten" oder gar nichts heißt: kein Ton.
        local enabled, mode = FCD.Profiles:ResolveAlert(entryBar, entry)
        local withSound = enabled and mode ~= "glow"
        row.sound:SetAlpha(withSound and 1 or 0.35)
        row.sound:EnableMouse(withSound)

        row:Show()
        shown = index
    end

    for index = shown + 1, #entryDialog.entryRows do
        entryDialog.entryRows[index].entry = nil
        entryDialog.entryRows[index]:Hide()
    end

    entryDialog.content:SetHeight(math.max(1, shown * ENTRY_ROW_HEIGHT))
    local rows = math.max(1, math.min(shown, ENTRY_VISIBLE_ROWS))
    entryDialog:SetHeight(48 + rows * ENTRY_ROW_HEIGHT + PAD)
end

function BarOptions:OpenEntries(bar)
    if type(bar) ~= "table" then
        return
    end
    buildEntries()

    if entryBar ~= bar then
        FCD.Profiles:PushUndo(L["Fertig-Meldung je Eintrag"])
    end
    entryBar = bar

    entryDialog:ClearAllPoints()
    if dialog and dialog:IsShown() then
        local ok = pcall(entryDialog.SetPoint, entryDialog, "TOPLEFT", dialog, "TOPRIGHT", 8, 0)
        if not ok then
            entryDialog:SetPoint("CENTER")
        end
    else
        entryDialog:SetPoint("CENTER")
    end

    self:RefreshEntries()
    entryDialog:Show()
end

function BarOptions:CloseEntries()
    if entryDialog then
        entryDialog:Hide()
    end
end
