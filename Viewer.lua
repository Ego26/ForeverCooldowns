local FCD = ForeverCooldowns
local Compat = FCD.Compat
local L = FCD.L

local Viewer = {}
FCD.Viewer = Viewer

-- barID -> Frame
local barFrames = {}

Viewer.barFrames = barFrames
Viewer.unlocked = false

local UNKNOWN_ALPHA = 0.25
local READY_GLOW = { 0.2, 1.0, 0.2 }
local NO_POWER_TINT = { 0.5, 0.5, 1.0 }
local UNUSABLE_TINT = { 0.4, 0.4, 0.4 }

-- Cooldown:Clear() gibt es erst in neueren Clients
local function clearCooldown(cooldown)
    if cooldown.Clear then
        cooldown:Clear()
    else
        cooldown:SetCooldown(0, 0)
    end
end

local function formatTime(seconds)
    if seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600 + 0.5))
    elseif seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60 + 0.5))
    elseif seconds >= 10 then
        return string.format("%d", math.floor(seconds + 0.5))
    end
    return string.format("%.1f", seconds)
end

-- ------------------------------------------------------------------ Icons

-- Mit der sicheren Vorlage lässt sich ein Symbol per Klick benutzen. Das geht
-- nur so: eigener Code darf im Kampf nichts auslösen, die Vorlage dagegen
-- schon. Ihre Kehrseite: die Belegung ist im Kampf nicht änderbar, deshalb
-- wird sie außerhalb gesetzt.
local iconCounter = 0

-- Abgerundete Ecken wie bei Blizzard.
--
-- Der erste Versuch deckte die Ecken mit einer Grafik ab. Im Panel genügt
-- das, weil dort ein bekannter dunkler Untergrund liegt. Über der Weltkulisse
-- nicht: Schwarz auf einer dunklen Symbolkante bleibt optisch ein Quadrat.
-- Blizzard schneidet die Ecken echt weg, und genau das macht eine Maske.
--
-- Der Rand kommt als eigene abgerundete Grafik dazu. Die vier geraden Kanten
-- hätten an den Ecken wieder Quadrate ergeben.
--
-- Kann der Client keine Masken, bleiben die geraden Kanten stehen - dann sieht
-- es aus wie bisher, aber nichts verschwindet.
local ICON_MASK = "Interface\\AddOns\\ForeverCooldowns\\Media\\IconMask.tga"
local ICON_OUTLINE = "Interface\\AddOns\\ForeverCooldowns\\Media\\IconOutline.tga"

local function applyRounding(button)
    if FCD.db and FCD.db.settings.roundIcons == false then
        return false
    end
    if type(button.CreateMaskTexture) ~= "function" then
        return false
    end

    local ok, mask = pcall(button.CreateMaskTexture, button)
    if not ok or type(mask) ~= "table" then
        return false
    end
    -- Die Form mit Wiederholungsmodus kennt nicht jeder Client; ohne sie
    -- bliebe alles außerhalb der Maske sichtbar statt weggeschnitten.
    if not pcall(mask.SetTexture, mask, ICON_MASK,
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") then
        if not pcall(mask.SetTexture, mask, ICON_MASK) then
            return false
        end
    end
    mask:SetAllPoints(button.icon)

    if not pcall(button.icon.AddMaskTexture, button.icon, mask) then
        return false
    end
    -- Das Aufleuchten liegt über dem Symbol; ohne dieselbe Maske stünden
    -- während des Meldens vier grüne Ecken vor.
    pcall(button.glow.AddMaskTexture, button.glow, mask)

    button.mask = mask
    for _, edge in ipairs(button.edges) do
        edge:Hide()
    end

    button.outline = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.outline:SetAllPoints(button.icon)
    button.outline:SetTexture(ICON_OUTLINE)
    return true
end

local function createIcon(parent)
    iconCounter = iconCounter + 1
    local button, secure = Compat.CreateFrame("Button",
        "ForeverCooldownsIcon" .. iconCounter, parent, "SecureActionButtonTemplate")
    button.secure = secure
    button:SetSize(40, 40)
    -- Neuere Clients lösen je nach Einstellung beim Drücken statt beim
    -- Loslassen aus; beides anzumelden deckt beide Fälle ab. Ältere kennen
    -- nur ein Argument, deshalb der zweite Versuch.
    if not pcall(button.RegisterForClicks, button, "AnyUp", "AnyDown") then
        pcall(button.RegisterForClicks, button, "AnyUp")
    end

    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.edges = {}
    for index = 1, 4 do
        local edge = button:CreateTexture(nil, "ARTWORK")
        edge:SetColorTexture(0, 0, 0, 0.85)
        button.edges[index] = edge
    end
    button.edges[1]:SetPoint("TOPLEFT", 1, 0)
    button.edges[1]:SetPoint("TOPRIGHT", -1, 0)
    button.edges[1]:SetHeight(1)
    button.edges[2]:SetPoint("BOTTOMLEFT", 1, 0)
    button.edges[2]:SetPoint("BOTTOMRIGHT", -1, 0)
    button.edges[2]:SetHeight(1)
    button.edges[3]:SetPoint("TOPLEFT", 0, -1)
    button.edges[3]:SetPoint("BOTTOMLEFT", 0, 1)
    button.edges[3]:SetWidth(1)
    button.edges[4]:SetPoint("TOPRIGHT", 0, -1)
    button.edges[4]:SetPoint("BOTTOMRIGHT", 0, 1)
    button.edges[4]:SetWidth(1)

    -- "Bereit" dauerhaft zeigen: ein Ring in der Form des Randes, nicht
    -- eine Fläche über dem Symbol. Eine Fläche färbte jedes bereite
    -- Symbol grün ein und machte die Leiste unleserlich.
    button.ready = button:CreateTexture(nil, "ARTWORK", nil, 3)
    button.ready:SetTexture(ICON_OUTLINE)
    button.ready:SetVertexColor(READY_GLOW[1], READY_GLOW[2], READY_GLOW[3], 0.9)
    button.ready:SetAllPoints(button.icon)
    button.ready:Hide()

    button.glow = button:CreateTexture(nil, "BORDER")
    button.glow:SetPoint("TOPLEFT", -3, 3)
    button.glow:SetPoint("BOTTOMRIGHT", 3, -3)
    button.glow:SetColorTexture(1, 1, 1, 0.35)
    button.glow:Hide()

    applyRounding(button)

    button.cooldown = Compat.CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    if button.cooldown.SetDrawEdge then
        button.cooldown:SetDrawEdge(false)
    end
    if button.cooldown.SetHideCountdownNumbers then
        button.cooldown:SetHideCountdownNumbers(true)
    end

    button.timer = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.timer:SetPoint("CENTER", 0, 1)

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)

    -- Rangzahl direkt auf dem Icon: acht Ränge derselben Fähigkeit sehen
    -- sonst identisch aus.
    button.rank = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    button.rank:SetPoint("TOPLEFT", 2, -2)
    button.rank:SetTextColor(1, 0.82, 0)

    button:EnableMouse(false)
    button:SetScript("OnEnter", function(self)
        if not self.tooltipTarget then
            return
        end
        local spellID, itemID = self.spellID, self.itemID
        local setter
        if self.tooltipTarget.kind == "spell" and spellID then
            setter = function(tip) tip:SetSpellByID(spellID) end
        elseif itemID then
            setter = function(tip) tip:SetItemByID(itemID) end
        end
        FCD.Widgets.ShowEntryTooltip(self, "ANCHOR_RIGHT", setter, self.displayName)
    end)
    button:SetScript("OnLeave", FCD.Widgets.HideTooltip)

    return button
end

-- Legt fest, was ein Klick auslöst - oder nimmt die Belegung wieder weg.
-- Im Kampf ist beides gesperrt; dann bleibt die vorige Belegung stehen.
local function setClickAction(button, bar, kind, value)
    if InCombatLockdown() or type(button.SetAttribute) ~= "function" then
        return
    end
    -- Ohne die sichere Vorlage passiert beim Klick nichts. Das einmal sagen,
    -- statt es stillschweigend nicht zu tun.
    if bar.clickToUse and not button.secure then
        if not Viewer.secureWarned then
            Viewer.secureWarned = true
            FCD.Print(L["Dieser Client kennt SecureActionButtonTemplate nicht -"])
            FCD.Print(L["'Beim Anklicken benutzen' bleibt deshalb wirkungslos."])
        end
        return
    end
    if not bar.clickToUse or not kind or not value then
        button:SetAttribute("type", nil)
        button:SetAttribute("spell", nil)
        button:SetAttribute("item", nil)
        return
    end
    button:SetAttribute("type", kind)
    if kind == "spell" then
        button:SetAttribute("spell", value)
        button:SetAttribute("item", nil)
    else
        button:SetAttribute("item", value)
        button:SetAttribute("spell", nil)
    end
end

local function acquireIcon(barFrame, index)
    local button = barFrame.icons[index]
    -- Blizzards Rahmengrafik gibt den Symbolen die runden Ecken. Der Versuch
    -- wird bei jedem Neuaufbau wiederholt, denn abgelesen werden kann sie
    -- erst, wenn ihr Fenster einmal offen war; danach ist er ein Nullgriff.
    if button and FCD.Art and FCD.Art:Decorate(button, "tile") then
        for _, edge in ipairs(button.edges or {}) do
            edge:Hide()
        end
    end
    if not button then
        button = createIcon(barFrame)
        barFrame.icons[index] = button
    end
    return button
end

-- ------------------------------------------------------------------ Leisten

local function saveBarPosition(barFrame)
    local bar = barFrame.config
    if not bar then
        return
    end
    local point, _, relativePoint, x, y = barFrame:GetPoint()
    bar.point = point or bar.point
    bar.relativePoint = relativePoint or bar.relativePoint
    bar.x = math.floor((x or 0) + 0.5)
    bar.y = math.floor((y or 0) + 0.5)
end

local function createBarFrame(bar)
    local frame = CreateFrame("Frame", "ForeverCooldownsBar" .. bar.id, UIParent)
    frame:SetClampedToScreen(true)
    frame.icons = {}

    -- Der Schleier muss VOR den Symbolen liegen, nicht dahinter: er zeigt an,
    -- dass hier die Leiste angefasst wird und nicht das einzelne Symbol.
    -- Texturen des Rahmens liegen immer unter seinen Kindrahmen, deshalb
    -- bekommt er einen eigenen Rahmen mit höherer Ebene. Die Maus nimmt der
    -- nicht an - der Klick geht an die Leiste darunter.
    -- Eine höhere Rahmenebene hat nicht gereicht; die Strata entscheidet
    -- darüber und ist absolut. Der Schleier ist ohnehin nur im
    -- Bearbeitungsmodus sichtbar, sonst wäre das zu weit oben.
    frame.overlay = CreateFrame("Frame", nil, frame)
    frame.overlay:SetAllPoints()
    frame.overlay:SetFrameStrata("HIGH")
    frame.overlay:EnableMouse(false)
    frame.overlay:Hide()

    frame.handle = frame.overlay:CreateTexture(nil, "BACKGROUND")
    frame.handle:SetPoint("TOPLEFT", -3, 3)
    frame.handle:SetPoint("BOTTOMRIGHT", 3, -3)
    frame.handle:SetColorTexture(0.1, 0.5, 0.9, 0.07)
    frame.handle:Hide()

    frame.handleEdges = {}
    for index = 1, 4 do
        local edge = frame.overlay:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0.35, 0.72, 1, 0.9)
        edge:Hide()
        frame.handleEdges[index] = edge
    end
    frame.handleEdges[1]:SetPoint("TOPLEFT", frame.handle, "TOPLEFT")
    frame.handleEdges[1]:SetPoint("TOPRIGHT", frame.handle, "TOPRIGHT")
    frame.handleEdges[1]:SetHeight(2)
    frame.handleEdges[2]:SetPoint("BOTTOMLEFT", frame.handle, "BOTTOMLEFT")
    frame.handleEdges[2]:SetPoint("BOTTOMRIGHT", frame.handle, "BOTTOMRIGHT")
    frame.handleEdges[2]:SetHeight(2)
    frame.handleEdges[3]:SetPoint("TOPLEFT", frame.handle, "TOPLEFT")
    frame.handleEdges[3]:SetPoint("BOTTOMLEFT", frame.handle, "BOTTOMLEFT")
    frame.handleEdges[3]:SetWidth(2)
    frame.handleEdges[4]:SetPoint("TOPRIGHT", frame.handle, "TOPRIGHT")
    frame.handleEdges[4]:SetPoint("BOTTOMRIGHT", frame.handle, "BOTTOMRIGHT")
    frame.handleEdges[4]:SetWidth(2)

    frame:SetScript("OnDragStart", function(self)
        if self:IsMovable() then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.wasDragged = true
        saveBarPosition(self)
    end)

    -- Anklicken öffnet die Einstellungen dieser Leiste - wie in Blizzards
    -- Bearbeitungsmodus. Nach einem Verschieben nicht, sonst ginge das
    -- Fenster bei jedem Ablegen auf.
    frame:SetScript("OnMouseUp", function(self)
        if self.wasDragged then
            self.wasDragged = nil
            return
        end
        if Viewer.unlocked and self.config and FCD.BarOptions then
            Viewer:SelectBar(self)
            FCD.BarOptions:Open(self.config, self)
        end
    end)

    -- Wie bei Blizzard: der Name steht nicht dauerhaft an der Leiste, sondern
    -- erscheint als Tooltip, sobald der Zeiger darüber ist.
    frame:SetScript("OnEnter", function(self)
        self.hovered = true
        Viewer:PaintBarState(self)
        if Viewer.unlocked and self.config then
            FCD.Widgets.ShowTooltip(self, "ANCHOR_TOP",
                -- Der gespeicherte Name ist die Kennung der Leiste; für die
                -- Anzeige wird er übersetzt, sofern es eine Übersetzung gibt.
                self.config.name and L[self.config.name]
                    or (L["Leiste "] .. tostring(self.config.id)),
                L["Zum Bearbeiten anklicken"])
        end
    end)
    frame:SetScript("OnLeave", function(self)
        self.hovered = nil
        Viewer:PaintBarState(self)
        GameTooltip:Hide()
    end)

    return frame
end

local function layoutBar(barFrame, bar)
    local size = bar.iconSize or 40
    local spacing = bar.spacing or 4
    local columns = math.max(1, bar.columns or 12)
    local growth = bar.growth or "RIGHT"

    local count = #bar.entries
    local visible = 0
    for index = 1, count do
        local button = acquireIcon(barFrame, index)
        button:SetSize(size, size)
        button:ClearAllPoints()

        -- Bei senkrechter Ausrichtung laufen die Symbole untereinander;
        -- "Spalten" zählt dann, wie viele in eine Spalte passen. Vorher wurde
        -- nur die Ecke gewechselt, die Symbole liefen weiter waagerecht -
        -- deshalb schien "Ausrichtung" nichts zu tun.
        local vertical = (growth == "UP" or growth == "DOWN")
        local along = (index - 1) % columns
        local across = math.floor((index - 1) / columns)
        local offsetX, offsetY
        if vertical then
            offsetX = across * (size + spacing)
            offsetY = along * (size + spacing)
        else
            offsetX = along * (size + spacing)
            offsetY = across * (size + spacing)
        end

        if growth == "LEFT" then
            button:SetPoint("TOPRIGHT", barFrame, "TOPRIGHT", -offsetX, -offsetY)
        elseif growth == "UP" then
            button:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", offsetX, offsetY)
        elseif growth == "DOWN" then
            button:SetPoint("TOPLEFT", barFrame, "TOPLEFT", offsetX, -offsetY)
        else
            button:SetPoint("TOPLEFT", barFrame, "TOPLEFT", offsetX, -offsetY)
        end
        visible = index
    end

    for index = visible + 1, #barFrame.icons do
        barFrame.icons[index]:Hide()
    end

    local usedAlong = math.min(columns, math.max(1, count))
    local usedAcross = math.max(1, math.ceil(math.max(1, count) / columns))
    local usedColumns, usedRows = usedAlong, usedAcross
    if growth == "UP" or growth == "DOWN" then
        usedColumns, usedRows = usedAcross, usedAlong
    end
    barFrame:SetSize(usedColumns * size + (usedColumns - 1) * spacing,
        usedRows * size + (usedRows - 1) * spacing)
    barFrame:ClearAllPoints()
    barFrame:SetPoint(bar.point or "CENTER", UIParent, bar.relativePoint or "CENTER", bar.x or 0, bar.y or 0)
    barFrame:SetScale(bar.scale or 1)
    barFrame:SetAlpha(bar.alpha or 1)
end

-- ------------------------------------------------------------- Aktualisierung

local function setCountdownNumbers(button, show)
    if button.countdownNumbers == show then
        return
    end
    button.countdownNumbers = show
    if button.cooldown.SetHideCountdownNumbers then
        button.cooldown:SetHideCountdownNumbers(not show)
    end
end

-- Schützt der Client die Abklingzeit-Werte, dürfen sie nur an SetCooldown
-- weitergereicht werden. Eigene Restzeit, GCD-Unterdrückung und das
-- Abdunkeln laufender Abklingzeiten setzen einen Vergleich voraus und
-- entfallen dann; die Blizzard-Uhr zeichnet Wischer und Zahlen selbst.
-- Rückgabe: false, wenn das Symbol verborgen werden soll.
-- Fertig-Meldung: aufleuchten und wahlweise ein Ton, sobald eine Abklingzeit
-- abgelaufen ist. Erkannt wird der Übergang, nicht der Zustand - sonst würde
-- es bei jedem Durchlauf erneut melden.
local READY_FLASH = 0.9
local soundBlockedUntil = 0

-- Welche Töne dieser Client kennt, steht in SOUNDKIT. Die Liste wird daraus
-- gebaut statt geraten: was dort fehlt, wird gar nicht erst angeboten.
local SOUND_CANDIDATES = {
    { key = "RAID_WARNING", label = "Schlachtzugswarnung" },
    { key = "READY_CHECK", label = "Bereitschaftsprüfung" },
    { key = "ALARM_CLOCK_WARNING_3", label = "Wecker" },
    { key = "IG_QUEST_LIST_COMPLETE", label = "Quest erledigt" },
    { key = "UI_RAID_BOSS_DEFEATED", label = "Sieg" },
    { key = "IG_MAINMENU_OPTION_CHECKBOX_ON", label = "Klick" },
}

function Viewer:GetSoundChoices()
    -- Ohne Zwischenspeicher: er hielte die Sprache fest, in der zum ersten
    -- Mal ein Auswahlfeld geoeffnet wurde. Die Liste hat sechs Einträge.
    
    local list = {}
    local kit = _G.SOUNDKIT
    if type(kit) == "table" then
        for _, candidate in ipairs(SOUND_CANDIDATES) do
            local id = rawget(kit, candidate.key)
            if type(id) == "number" then
                list[#list + 1] = { id = id, label = L[candidate.label] }
            end
        end
    end
    if #list == 0 then
        -- Ohne SOUNDKIT bleibt die Nummer der Schlachtzugswarnung, die es seit
        -- jeher gibt. Hört man nichts, taugt sie in diesem Client nicht.
        list[1] = { id = 8959, label = L["Standardton"] }
    end
    return list
end

function Viewer:PlayAlertSound(soundID)
    if type(_G.PlaySound) ~= "function" then
        return false
    end
    local choices = self:GetSoundChoices()
    local ok = pcall(_G.PlaySound, soundID or choices[1].id)
    return ok
end

function Viewer:AnnounceReady(button, bar, entry)
    local _, mode, soundID = FCD.Profiles:ResolveAlert(bar, entry)

    if mode ~= "sound" then
        button.flashUntil = GetTime() + READY_FLASH
        button.glow:SetColorTexture(READY_GLOW[1], READY_GLOW[2], READY_GLOW[3], 1)
        button.glow:SetAlpha(0.8)
        button.glow:Show()
        self.flashing = true
    end

    -- Mehrere Symbole werden gleichzeitig fertig; ohne Sperre gäbe das ein
    -- Geklapper statt eines Signals.
    if mode == "glow" or GetTime() < soundBlockedUntil then
        return
    end
    soundBlockedUntil = GetTime() + 0.6
    self:PlayAlertSound(soundID)
end

-- Das Aufleuchten sofort zeigen, statt darauf zu warten, dass irgendwann
-- eine Abklingzeit endet. Der Ton wird beim Auswählen bereits vorgespielt -
-- ohne dasselbe fürs Leuchten wählt man blind und sieht tagelang nichts.
--
-- Läuft über denselben Weg wie die echte Meldung, damit die Vorschau nicht
-- etwas anderes zeigt als das, was später passiert.
function Viewer:PreviewAlert(bar, entry)
    if type(bar) ~= "table" then
        return false
    end
    local barFrame = barFrames[bar.id]
    if not barFrame then
        return false
    end

    -- "Aus" ist auch eine Auswahl - und dann darf die Vorschau gerade nicht
    -- leuchten, sonst zeigt sie das Gegenteil dessen, was eingestellt wurde.
    local enabled, mode = FCD.Profiles:ResolveAlert(bar, entry)
    if not enabled then
        return false
    end

    -- Im Bearbeitungsmodus liegt der blaue Schleier der Leiste VOR den
    -- Symbolen - absichtlich, sonst wäre die Leiste nicht als Ganzes zu
    -- fassen. Für die Vorschau ist er im Weg: das Leuchten läge dahinter und
    -- man sähe kaum etwas. Also für die Dauer des Aufleuchtens abblenden.
    if barFrame.overlay and barFrame.overlay:IsShown() then
        barFrame.overlay:SetAlpha(0.15)
        if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
            C_Timer.After(READY_FLASH, function()
                if barFrame.overlay then
                    barFrame.overlay:SetAlpha(1)
                end
            end)
        else
            barFrame.overlay:SetAlpha(1)
        end
    end

    local shown = false
    for _, button in ipairs(barFrame.icons) do
        -- Ohne Eintrag ist die ganze Leiste gemeint; sonst nur ihr Symbol.
        if button:IsShown() and (not entry or button.tooltipTarget == entry) then
            self:AnnounceReady(button, bar, entry)
            shown = true
        end
    end

    -- Der Ton hängt an derselben Auswahl. Bei "Nur Leuchten" fällt er weg,
    -- das erledigt AnnounceReady bereits selbst.
    if not shown and mode ~= "sound" then
        FCD.Print(L["Die Leiste zeigt dieses Symbol gerade nicht -"])
        FCD.Print(L["das Aufleuchten ist deshalb nicht zu sehen."])
    end
    return shown
end

-- Beide Leuchtwege an einer Stelle zurücknehmen. Getrennt geführt liefen
-- sie auseinander: Blizzards Leuchten bliebe stehen, weil nur unser Ring
-- ausgeblendet wird.
function Viewer:StopReadyGlow(button)
    if button.glowing == "blizzard" then
        Compat.HideOverlayGlow(button)
    end
    button.glowing = nil
    button.ready:Hide()
end

local function applyCooldown(button, bar, settings, start, duration, enabled)
    if Compat.caps.secretCooldown then
        Viewer:StopReadyGlow(button)
        setCountdownNumbers(button, true)
        button.cooldown:SetCooldown(start, duration)
        button.timer:SetText("")
        button.icon:SetDesaturated(false)
        return true
    end

    setCountdownNumbers(button, false)

    local onCooldown = enabled and duration and duration > 0
    if onCooldown and settings.hideGCD and bar.hideGCD and duration <= (settings.gcdThreshold or 1.6) then
        onCooldown = false
    end

    if onCooldown then
        Viewer:StopReadyGlow(button)
        button.cooldown:SetCooldown(start, duration)
        local remaining = math.max(0, (start + duration) - GetTime())
        button.timer:SetText((bar.showTimer and settings.showTimerText) and formatTime(remaining) or "")
        button.icon:SetDesaturated(true)
        button.wasOnCooldown = true
        return true
    end

    -- tooltipTarget ist der Eintrag dieses Symbols; er wird in beiden
    -- Update-Wegen gesetzt, bevor hierher verzweigt wird.
    local entry = button.tooltipTarget
    local alerting, alertMode = FCD.Profiles:ResolveAlert(bar, entry)

    -- Genau hier ist der Übergang von "läuft" auf "bereit"
    if button.wasOnCooldown then
        button.wasOnCooldown = false
        if alerting then
            Viewer:AnnounceReady(button, bar, entry)
        end
    end

    -- Und danach bleibt es markiert, solange es bereit ist. Den Übergang
    -- allein zu melden hieß: wer im falschen Moment hinsieht, sieht nie
    -- etwas. Das Leuchten ist stumm - der Ton fällt weiter nur beim Übergang.
    --
    -- Bevorzugt Blizzards eigenes Spell-Alert-Leuchten: dasselbe goldene
    -- Pulsieren wie an der Aktionsleiste, wenn ein Zauber verfügbar wird.
    -- Kennt der Client es nicht, bleibt unser grüner Ring.
    if alerting and alertMode ~= "sound" then
        -- Nur beim Wechsel einschalten, nicht bei jeder Aktualisierung:
        -- Blizzards Leuchten ist eine Animation und finge sonst zehnmal je
        -- Sekunde von vorn an.
        if not button.glowing then
            button.glowing = Compat.ShowOverlayGlow(button) and "blizzard" or "ring"
            if button.glowing == "ring" then
                button.ready:Show()
            end
        end
    else
        Viewer:StopReadyGlow(button)
    end

    clearCooldown(button.cooldown)
    button.timer:SetText("")
    button.icon:SetDesaturated(false)
    return not bar.visibility.onlyOnCooldown
end

local function updateSpellIcon(button, entry, bar, settings)
    local spellID, rank, family, known = FCD.Ranks:Resolve(entry)
    button.spellID = spellID
    button.itemID = nil
    button.tooltipTarget = entry

    if not spellID then
        button:Hide()
        return false
    end

    local name, icon = Compat.GetSpellInfo(spellID)
    button.displayName = name
    button.icon:SetTexture(icon or 134400)

    if not known then
        if bar.visibility.hideUnknown then
            button:Hide()
            return false
        end
        button:SetAlpha(UNKNOWN_ALPHA)
    else
        button:SetAlpha(1)
    end

    -- Rangzahl
    if (bar.showRank and settings.showRankText) and rank then
        button.rank:SetText(rank)
        button.rank:Show()
        if entry.rankMode == "fixed" then
            button.rank:SetTextColor(0.4, 0.8, 1)
        else
            button.rank:SetTextColor(1, 0.82, 0)
        end
    else
        button.rank:Hide()
    end

    -- Aura-Verfolgung: GetPlayerAura liefert nil, wenn der Client die Werte
    -- schützt - dann fällt der Eintrag auf die Abklingzeit zurück.
    if entry.trackAura then
        local auraDuration, expiration = Compat.GetPlayerAura(spellID)
        if auraDuration and expiration and auraDuration > 0 then
            setCountdownNumbers(button, false)
            Viewer:StopReadyGlow(button)
            button.cooldown:SetCooldown(expiration - auraDuration, auraDuration)
            button.glow:SetColorTexture(READY_GLOW[1], READY_GLOW[2], READY_GLOW[3], 0.35)
            button.glow:Show()
            button.timer:SetText(formatTime(math.max(0, expiration - GetTime())))
            button.icon:SetDesaturated(false)
            button:Show()
            return true
        end
    end

    -- Ein laufendes Aufleuchten nicht wegnehmen: es wird vom Treiber beendet.
    if not (button.flashUntil and button.flashUntil > GetTime()) then
        button.glow:Hide()
    end

    local start, duration, enabled = Compat.GetSpellCooldown(spellID)
    if not applyCooldown(button, bar, settings, start, duration, enabled) then
        button:Hide()
        return false
    end

    -- Ressourcen-Zustand: "bereit, aber zu wenig Wut" sieht anders aus als bereit.
    -- IsSpellUsable liefert nil, wenn der Client die Werte schützt.
    local usable, noPower = Compat.IsSpellUsable(spellID)
    if settings.dimOutOfPower and known and usable ~= nil then
        if noPower then
            button.icon:SetVertexColor(NO_POWER_TINT[1], NO_POWER_TINT[2], NO_POWER_TINT[3])
        elseif not usable then
            button.icon:SetVertexColor(UNUSABLE_TINT[1], UNUSABLE_TINT[2], UNUSABLE_TINT[3])
        else
            button.icon:SetVertexColor(1, 1, 1)
        end
    else
        button.icon:SetVertexColor(1, 1, 1)
    end

    local current, maximum = Compat.GetSpellCharges(spellID)
    if current and maximum then
        button.count:SetText(current)
    else
        button.count:SetText("")
    end

    setClickAction(button, bar, "spell", spellID)
    button:Show()
    return true
end

local function updateItemIcon(button, entry, bar, settings)
    local name, icon, count, present, loaded = FCD.Items:GetDisplay(entry)
    button.spellID = nil
    button.itemID = entry.kind == "inventory" and Compat.GetInventoryItemID(entry.id) or entry.id
    button.tooltipTarget = entry
    button.displayName = name
    button.icon:SetTexture(icon or 134400)
    button.rank:Hide()

    if not present then
        -- Nur ausblenden, wenn der Client den Gegenstand wirklich kennt und
        -- er trotzdem fehlt. Solange seine Daten noch nachgeladen werden,
        -- bleibt er blass stehen statt zu verschwinden.
        if bar.visibility.hideUnknown and loaded then
            button:Hide()
            return false
        end
        button:SetAlpha(UNKNOWN_ALPHA)
    else
        button:SetAlpha(1)
    end

    -- Wie beim Zauber: ein laufendes Aufleuchten stehen lassen, sonst alles
    -- zurücknehmen. Ohne diese Zeile blieb ein Leuchten an einem Symbol
    -- hängen, das später einen Gegenstand zeigte.
    if not (button.flashUntil and button.flashUntil > GetTime()) then
        button.glow:Hide()
    end

    local start, duration, enabled = FCD.Items:GetCooldown(entry)
    if not applyCooldown(button, bar, settings, start, duration, enabled) then
        button:Hide()
        return false
    end

    button.icon:SetVertexColor(1, 1, 1)
    -- "Anzahl anzeigen" ist bei Gegenständen das, was bei Zaubern der Rang
    -- ist: die Zahl auf dem Symbol. Ohne Angabe bleibt sie an.
    button.count:SetText((bar.showCount ~= false and Compat.IsPositive(count))
        and count or "")
    -- Der Name wird von allen Clients verstanden, die Verknüpfung nicht
    -- überall; solange er noch nachlädt, nehmen wir die Verknüpfung.
    setClickAction(button, bar, "item",
        (loaded and name) or (button.itemID and ("item:" .. button.itemID)) or nil)
    button:Show()
    return true
end

local function barShouldShow(bar)
    local visibility = bar.visibility or {}
    -- "Nie" schlägt alles andere. Der Inhalt bleibt erhalten, nur gezeigt
    -- wird nichts - im Bearbeitungsmodus dagegen schon, sonst wäre die
    -- Einstellung nicht mehr rückgängig zu machen.
    if visibility.never then
        return false
    end
    if visibility.always then
        return true
    end
    if visibility.inCombat and not InCombatLockdown() then
        return false
    end
    if visibility.hasTarget and not UnitExists("target") then
        return false
    end
    return true
end

function Viewer:UpdateBar(barFrame, bar)
    local settings = FCD.Profiles:GetSettings()
    -- Eine leere Leiste hat nichts zu zeigen und nichts zu verschieben. Im
    -- Bearbeitungsmodus standen die beiden angelegten Vorgabeleisten sonst
    -- als leere Kästen herum.
    if #bar.entries == 0 then
        barFrame:Hide()
        return
    end
    if not barShouldShow(bar) and not self.unlocked then
        barFrame:Hide()
        return
    end
    barFrame:Show()

    for index, entry in ipairs(bar.entries) do
        local button = acquireIcon(barFrame, index)
        if entry.kind == "spell" then
            updateSpellIcon(button, entry, bar, settings)
        else
            updateItemIcon(button, entry, bar, settings)
        end
        -- Im entsperrten Zustand bleibt jedes Icon sichtbar, damit man die
        -- Leiste überhaupt fassen und einschätzen kann.
        if self.unlocked then
            button:Show()
            button:SetAlpha(1)
        end
    end
end

function Viewer:Update()
    local profile = FCD.Profiles:GetActive()
    if not profile then
        return
    end
    for _, bar in ipairs(profile.bars) do
        local barFrame = barFrames[bar.id]
        if barFrame then
            self:UpdateBar(barFrame, bar)
        end
    end
end

function Viewer:RebuildAll()
    local profile = FCD.Profiles:GetActive()
    if not profile then
        return
    end

    local live = {}
    for _, bar in ipairs(profile.bars) do
        local barFrame = barFrames[bar.id]
        if not barFrame then
            barFrame = createBarFrame(bar)
            barFrames[bar.id] = barFrame
        end
        barFrame.config = bar
        layoutBar(barFrame, bar)
        live[bar.id] = true
    end

    for id, barFrame in pairs(barFrames) do
        if not live[id] then
            barFrame:Hide()
            barFrame.config = nil
        end
    end

    self:ApplyLockState()
    self:Update()
end

-- Wendet den aktuellen Zustand auf die Frames an, ohne ihn zu speichern.
-- RebuildAll darf die gespeicherte Einstellung nicht überschreiben, sonst
-- steht nach dem Login immer "gesperrt".
function Viewer:ApplyLockState()
    -- SetMovable und EnableMouse nehmen kein nil, und beim ersten RebuildAll
    -- ist der Zustand noch nicht gesetzt.
    local unlocked = self.unlocked and true or false
    for _, barFrame in pairs(barFrames) do
        if barFrame.config then
            barFrame:SetMovable(unlocked)
            barFrame:EnableMouse(unlocked)
            -- Der Nachbau von Blizzards Auswahlrahmen ist hier wieder heraus:
            -- er griff bei einer Leiste und bei der nächsten nicht, und er
            -- liefert nur einen Rand ohne Füllung. Dadurch sahen zwei Leisten
            -- nebeneinander verschieden aus. Alle bekommen jetzt dieselbe
            -- selbstgezeichnete Markierung.
            barFrame.overlay:SetShown(unlocked)
            if unlocked then
                -- Die Ebene erst hier setzen, nicht beim Erzeugen: die
                -- Symbolknöpfe entstehen später und bekommen dann ihre eigene
                -- Ebene. Ein früh gesetzter Wert kann darunter geraten, und
                -- dann liegen ihre Grafiken über dem Schleier.
                barFrame.overlay:SetFrameLevel(barFrame:GetFrameLevel() + 50)
                barFrame:RegisterForDrag("LeftButton")
                barFrame.handle:Show()
                for _, edge in ipairs(barFrame.handleEdges or {}) do
                    edge:Show()
                end
                self:PaintBarState(barFrame)
            else
                barFrame:RegisterForDrag()
                barFrame.hovered = nil
                barFrame.handle:Hide()
                for _, edge in ipairs(barFrame.handleEdges or {}) do
                    edge:Hide()
                end
                self.selectedFrame = nil
                if FCD.BarOptions then
                    FCD.BarOptions:Close()
                end
            end
            -- Genau andersherum als vorher: im Bearbeitungsmodus nehmen die
            -- Symbole die Maus NICHT an, sonst fangen sie Klick und Zeiger ab
            -- und die Leiste ist nicht zu fassen. Im normalen Spiel dagegen
            -- schon, sofern die Leiste Tooltips zeigen soll.
            local wantMouse = (not unlocked)
                and (barFrame.config.showTooltips ~= false
                    or barFrame.config.clickToUse)
            for _, button in ipairs(barFrame.icons) do
                button:EnableMouse(wantMouse)
            end
        end
    end
end

-- Drei Zustände wie in Blizzards Bearbeitungsmodus: ruhend blau, unter dem
-- Zeiger heller, angeklickt golden. Der Schleier liegt im Hintergrund - die
-- Symbole sind Kindrahmen und bleiben darüber sichtbar.
function Viewer:PaintBarState(barFrame)
    if not barFrame or not barFrame.handle then
        return
    end
    local selected = (self.selectedFrame == barFrame)
    local red, green, blue, fill, edge
    if selected then
        red, green, blue, fill, edge = 1, 0.82, 0, 0.30, 1
    elseif barFrame.hovered then
        red, green, blue, fill, edge = 0.55, 0.85, 1, 0.36, 1
    else
        red, green, blue, fill, edge = 0.30, 0.65, 1, 0.26, 0.85
    end
    barFrame.handle:SetColorTexture(red, green, blue, fill)
    for _, texture in ipairs(barFrame.handleEdges or {}) do
        texture:SetColorTexture(red, green, blue, edge)
    end
end

function Viewer:SelectBar(barFrame)
    local previous = self.selectedFrame
    self.selectedFrame = barFrame
    if previous and previous ~= barFrame then
        self:PaintBarState(previous)
    end
    self:PaintBarState(barFrame)
end

function Viewer:SetUnlocked(unlocked)
    self.unlocked = unlocked and true or false
    if FCD.db then
        FCD.db.settings.locked = not self.unlocked
    end
    self:ApplyLockState()
    self:Update()
end

function Viewer:ToggleLock()
    self:SetUnlocked(not self.unlocked)
    return self.unlocked
end

-- ------------------------------------------------- Blizzards Bearbeitungsmodus

-- Unsere Leisten in Blizzards Bearbeitungsmodus einzutragen ginge nur über
-- ihre geschützten Objekte und würde die Sitzung taintieren. Stattdessen
-- folgen wir ihm: solange ihr Fenster offen ist, sind unsere Leisten
-- entsperrt und beschriftet, danach wieder so wie vorher. Für den Benutzer
-- ist es dasselbe - alles liegt gleichzeitig zum Verschieben bereit.
local editDriver = CreateFrame("Frame")
local editAccumulated, editWasOpen, lockedBefore = 0, false, nil

local function editModeOpen()
    local manager = _G.EditModeManagerFrame
    if type(manager) ~= "table" or type(manager.IsShown) ~= "function" then
        return false
    end
    local ok, shown = pcall(manager.IsShown, manager)
    return ok and shown and true or false
end

editDriver:SetScript("OnUpdate", function(_, elapsed)
    if not FCD.db then
        return
    end
    editAccumulated = editAccumulated + elapsed
    if editAccumulated < 0.25 then
        return
    end
    editAccumulated = 0

    local open = editModeOpen()
    if open == editWasOpen then
        return
    end
    editWasOpen = open

    if open then
        lockedBefore = not Viewer.unlocked
        if lockedBefore then
            Viewer.unlocked = true
            Viewer:ApplyLockState()
            Viewer:Update()
        end
    elseif lockedBefore then
        -- Den vorherigen Zustand wiederherstellen, ohne die gespeicherte
        -- Einstellung zu verändern - der Modus war nur vorübergehend.
        lockedBefore = nil
        Viewer.unlocked = false
        Viewer:ApplyLockState()
        Viewer:Update()
    end
end)

Viewer.editDriver = editDriver

-- Ein einziger Treiber für alle Leisten statt OnUpdate pro Icon
local driver = CreateFrame("Frame")
local accumulated = 0
driver:SetScript("OnUpdate", function(_, elapsed)
    if not FCD.db then
        return
    end

    -- Das Aufleuchten läuft schneller als der Aktualisierungstakt, sonst
    -- ruckelt es. Es kostet nur etwas, solange wirklich etwas leuchtet.
    if Viewer.flashing then
        local now = GetTime()
        local anyLeft = false
        for _, barFrame in pairs(barFrames) do
            for _, button in ipairs(barFrame.icons) do
                if button.flashUntil then
                    local left = button.flashUntil - now
                    if left <= 0 then
                        button.flashUntil = nil
                        button.glow:Hide()
                    else
                        anyLeft = true
                        -- Zweimal pulsen, dann ausklingen
                        local pulse = 0.5 + 0.5 * math.cos(left * 14)
                        button.glow:SetAlpha(0.25 + 0.55 * pulse * (left / READY_FLASH))
                    end
                end
            end
        end
        Viewer.flashing = anyLeft
    end

    accumulated = accumulated + elapsed
    local interval = FCD.db.settings.updateInterval or 0.1
    if accumulated < interval then
        return
    end
    accumulated = 0

    if FCD.BlizzOptions and not FCD.BlizzOptions.hooked then
        FCD.BlizzOptions:HookDialog()
    end

    Viewer:Update()
end)
Viewer.driver = driver
