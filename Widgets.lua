local FCD = ForeverCooldowns
local Compat = FCD.Compat

local Widgets = {}
FCD.Widgets = Widgets

-- Kästchen und Auswahlfelder. Sie standen im alten großen Fenster, das es
-- nicht mehr gibt - gebraucht werden sie weiter, vom Panel und vom
-- Optionsfenster. Deshalb liegen sie jetzt für sich.

local function createCheck(parent, text, getter, setter)
    local check, templated = Compat.CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check.text = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    check.text:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.text:SetText(text)

    -- Ohne die Blizzard-Vorlage fehlen alle Texturen; SetChecked funktioniert
    -- trotzdem, nur sichtbar wäre davon nichts.
    if not templated then
        local background = check:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0.6)
        check.mark = check:CreateTexture(nil, "OVERLAY")
        check.mark:SetPoint("TOPLEFT", 3, -3)
        check.mark:SetPoint("BOTTOMRIGHT", -3, 3)
        check.mark:SetColorTexture(0.3, 0.8, 1, 0.9)
    end

    function check.Refresh()
        local value = getter() and true or false
        check:SetChecked(value)
        if check.mark then
            check.mark:SetShown(value)
        end
    end

    check:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        check.Refresh()
    end)

    check.Refresh()
    return check
end

Widgets.CreateCheck = createCheck

-- Eigenes Aufklappmenü statt UIDropDownMenu: die Blizzard-Vorlage wurde in
-- neueren Clients mehrfach ersetzt, ein eigenes Frame ist versionsfest.
--
-- Die Menüs hängen an UIParent, nicht am Knopf - sonst würden sie am unteren
-- Fensterrand abgeschnitten. Damit gehen sie aber auch nicht mit unterm
-- Fenster zu, und ihre Klicksperre bliebe über dem ganzen Bildschirm liegen.
-- Deshalb merken wir uns jedes Menü und schließen sie beim Ausblenden.
local dropdowns = {}

function Widgets.CloseDropdowns()
    for _, button in ipairs(dropdowns) do
        local menu = button.menu
        if menu and menu:IsShown() then
            menu:Hide()
        end
    end
end

local function createDropdown(parent, width, getItems, onSelect)
    -- Kein UIPanelButtonTemplate: Blizzards Auswahlfelder sind dunkle Felder
    -- mit linksbündigem Text und einem Pfeilkasten rechts, keine roten Knöpfe.
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 22)

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetAllPoints()
    button.background:SetColorTexture(0.06, 0.06, 0.08, 0.95)

    button.edges = {}
    for index = 1, 4 do
        button.edges[index] = button:CreateTexture(nil, "BORDER")
        button.edges[index]:SetColorTexture(0.45, 0.40, 0.28, 0.9)
    end
    button.edges[1]:SetPoint("TOPLEFT")
    button.edges[1]:SetPoint("TOPRIGHT")
    button.edges[1]:SetHeight(1)
    button.edges[2]:SetPoint("BOTTOMLEFT")
    button.edges[2]:SetPoint("BOTTOMRIGHT")
    button.edges[2]:SetHeight(1)
    button.edges[3]:SetPoint("TOPLEFT")
    button.edges[3]:SetPoint("BOTTOMLEFT")
    button.edges[3]:SetWidth(1)
    button.edges[4]:SetPoint("TOPRIGHT")
    button.edges[4]:SetPoint("BOTTOMRIGHT")
    button.edges[4]:SetWidth(1)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.label:SetPoint("LEFT", 8, 0)
    button.label:SetPoint("RIGHT", -24, 0)
    button.label:SetJustifyH("LEFT")
    button.label:SetTextColor(1, 0.82, 0)
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

    button:SetText("-")

    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("DIALOG")
    menu:Hide()
    menu.background = menu:CreateTexture(nil, "BACKGROUND")
    menu.background:SetAllPoints()
    menu.background:SetColorTexture(0.04, 0.04, 0.06, 0.95)
    menu.rows = {}

    -- Unsichtbare Fläche hinter dem Menü: ein Klick daneben schließt es
    local blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("DIALOG")
    blocker:SetFrameLevel(1)
    blocker:Hide()
    blocker:SetScript("OnClick", function()
        menu:Hide()
    end)
    menu:SetScript("OnShow", function()
        -- Das Menü muss auf dieselbe Stapelebene wie sein Knopf. Sitzt der in
        -- einem Fenster auf FULLSCREEN_DIALOG, läge ein Menü auf DIALOG
        -- dahinter - sichtbar wäre nichts, anklickbar auch nicht.
        local strata = button:GetFrameStrata() or "DIALOG"
        local level = button:GetFrameLevel() or 1
        blocker:SetFrameStrata(strata)
        blocker:SetFrameLevel(level + 10)
        menu:SetFrameStrata(strata)
        blocker:Show()
        menu:SetFrameLevel(level + 20)
    end)
    menu:SetScript("OnHide", function()
        blocker:Hide()
    end)

    button:SetScript("OnClick", function(self)
        if menu:IsShown() then
            menu:Hide()
            return
        end
        local items = getItems() or {}
        local rowCount = 0
        for index, item in ipairs(items) do
            local row = menu.rows[index]
            if not row then
                row = CreateFrame("Button", nil, menu)
                row:SetHeight(20)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 6, 0)
                row.text:SetJustifyH("LEFT")
                row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                row.highlight:SetAllPoints()
                row.highlight:SetColorTexture(0.3, 0.5, 0.9, 0.35)
                menu.rows[index] = row
            end
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, -((index - 1) * 20) - 3)
            row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", 0, -((index - 1) * 20) - 3)
            row.text:SetText(item.text)
            row:SetScript("OnClick", function()
                menu:Hide()
                onSelect(item.value, item.text)
            end)
            row:Show()
            rowCount = index
        end
        for index = rowCount + 1, #menu.rows do
            menu.rows[index]:Hide()
        end
        if rowCount == 0 then
            return
        end
        menu:SetSize(math.max(width, 140), rowCount * 20 + 6)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:Show()
    end)

    button.menu = menu
    dropdowns[#dropdowns + 1] = button
    return button
end

Widgets.CreateDropdown = createDropdown

-- Ein Fenster neben eine Leiste stellen, nicht darüber oder darunter. Beide
-- Optionsfenster benutzen dieselbe Regel: rechts daneben, wenn dort Platz
-- ist, sonst links; Oberkanten bündig, aber nie über den Bildrand hinaus.
--
-- Gerechnet wird in Bildschirmkoordinaten und an UIParent gehängt, nicht an
-- die Leiste: die Leiste kann sich bewegen oder ausgeblendet werden, und ein
-- Fenster, das an einem verschwundenen Rahmen hängt, wird nirgends gezeichnet.
function Widgets.PlaceBeside(frame, target, gap)
    gap = gap or 16
    frame:ClearAllPoints()

    local left, right, top
    if type(target) == "table" and type(target.GetLeft) == "function" then
        pcall(function()
            left, right, top = target:GetLeft(), target:GetRight(), target:GetTop()
        end)
    end
    if type(left) ~= "number" or type(right) ~= "number" or type(top) ~= "number" then
        frame:SetPoint("CENTER")
        return false
    end

    local width = frame:GetWidth() or 300
    local height = frame:GetHeight() or 300
    local screenWidth = UIParent:GetWidth() or 1920
    local screenHeight = UIParent:GetHeight() or 1080

    local x = right + gap
    if x + width > screenWidth then
        x = left - gap - width
    end
    if x < 0 then
        x = 0
    end

    -- Oberkante auf Höhe der Leiste, sofern das Fenster damit ganz ins Bild
    -- passt. Leisten am unteren Rand bekommen ihr Fenster sonst abgeschnitten.
    local y = top
    if y > screenHeight then
        y = screenHeight
    end
    if y - height < 0 then
        y = height
    end

    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
        math.floor(x + 0.5), math.floor(y + 0.5))
    return true
end

-- ------------------------------------------------------------- Tooltips

-- Vorher baute jede Stelle ihren Tooltip selbst: mal ANCHOR_LEFT, mal
-- ANCHOR_RIGHT, Hinweiszeilen in drei verschiedenen Blautoenen, mal mit
-- Leerzeile und mal ohne. Ein Baustein haelt sie gleich.
local HINT_R, HINT_G, HINT_B = 0.62, 0.78, 1

function Widgets.ShowTooltip(owner, anchor, title, ...)
    if not owner or not title then
        return
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    local count = select("#", ...)
    if count > 0 then
        GameTooltip:AddLine(" ")
        for index = 1, count do
            local line = select(index, ...)
            if line and line ~= "" then
                GameTooltip:AddLine(line, HINT_R, HINT_G, HINT_B, true)
            end
        end
    end
    GameTooltip:Show()
end

-- Dieselbe Form, aber der Kopf ist ein Zauber oder Gegenstand statt Text.
function Widgets.ShowEntryTooltip(owner, anchor, setter, fallbackTitle, ...)
    if not owner then
        return
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    if not (setter and pcall(setter, GameTooltip)) then
        GameTooltip:SetText(fallbackTitle or "")
    end
    local count = select("#", ...)
    if count > 0 then
        GameTooltip:AddLine(" ")
        for index = 1, count do
            local line = select(index, ...)
            if line and line ~= "" then
                GameTooltip:AddLine(line, HINT_R, HINT_G, HINT_B, true)
            end
        end
    end
    GameTooltip:Show()
end

function Widgets.HideTooltip()
    GameTooltip:Hide()
end
