local FCD = ForeverCooldowns
local L = FCD.L

local Art = {}
FCD.Art = Art

-- Blizzards Abklingzeit-Fenster zeichnet seine Einträge nicht mit Farbflächen,
-- sondern mit eigenen Atlas-Grafiken: gerundete Rahmen um die Symbole, ein
-- gefasster Balken bei den verfolgten Leisten. Die Atlasnamen stehen nirgends
-- und wechseln zwischen Builds - Raten hat hier also keinen Sinn.
--
-- Stattdessen lesen wir sie ab: solange Blizzards Fenster offen ist, suchen wir
-- darin einen echten Symboleintrag und einen echten Balkeneintrag, kopieren
-- deren Texturen samt Ebene, Farbe, Zuschnitt und Ankern auf unsere Zeilen und
-- setzen unser Symbol genau dorthin, wo ihres sitzt - inklusive der Maske, die
-- die runden Ecken macht. Findet sich nichts, bleibt die selbstgezeichnete
-- Fassung stehen.

local MAX_DEPTH = 12          -- Suchtiefe im Rahmenbaum
local CLONE_DEPTH = 5         -- wie tief wir Kindrahmen mitkopieren
local MIN_ICON = 14           -- kleiner ist kein Symbolfeld
local RETRY_SECONDS = 2       -- nicht bei jedem Neuaufbau erneut durchsuchen

Art.status = "noch nicht gesucht"
Art.learned = false
Art.report = {}

-- --------------------------------------------------------- Hilfsgriffe

-- Blizzards Rahmen gehören uns nicht: jeder Zugriff läuft über pcall, damit
-- ein fehlendes oder geschütztes Feld die Suche nicht abbricht.
local function call(object, method, ...)
    if type(object) ~= "table" and type(object) ~= "userdata" then
        return nil
    end
    local fn
    local ok = pcall(function() fn = object[method] end)
    if not ok or type(fn) ~= "function" then
        return nil
    end
    local a, b, c, d, e, f, g, h
    ok, a, b, c, d, e, f, g, h = pcall(fn, object, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e, f, g, h
end

local function objectType(widget)
    return call(widget, "GetObjectType")
end

local function isShown(widget)
    return call(widget, "IsShown") and true or false
end

local function atlasOf(region)
    local atlas = call(region, "GetAtlas")
    if type(atlas) == "string" and atlas ~= "" then
        return atlas
    end
    return nil
end

local function regionsOf(frame)
    local list = {}
    pcall(function()
        for index = 1, select("#", frame:GetRegions()) do
            list[index] = select(index, frame:GetRegions())
        end
    end)
    return list
end

local function childrenOf(frame)
    local list = {}
    pcall(function()
        for index = 1, select("#", frame:GetChildren()) do
            list[index] = select(index, frame:GetChildren())
        end
    end)
    return list
end

local function sizeOf(widget)
    local width, height = call(widget, "GetSize")
    if type(width) ~= "number" or type(height) ~= "number" then
        return nil, nil
    end
    return width, height
end

-- Ein Symbolfeld zu erkennen war der Fehler im ersten Anlauf: "quadratisch und
-- keine Atlasgrafik" trifft auch auf Blizzards leere Plätze zu, und weil es
-- davon die meisten gibt, wurde ihr Pluszeichen zur Vorlage.
--
-- Jetzt muss der Nachweis von außen kommen: die Textur muss genau eines der
-- Symbole zeigen, die in unserer eigenen Liste stehen. Ein leerer Platz, ein
-- Kästchen oder ein Reiter kann das nicht erfüllen.
Art.iconSet = nil

local function looksLikeIcon(region)
    if atlasOf(region) or type(Art.iconSet) ~= "table" then
        return false
    end
    local width, height = sizeOf(region)
    if not width or width < MIN_ICON or height < MIN_ICON then
        return false
    end
    if width > height * 1.4 or height > width * 1.4 then
        return false
    end
    local file = call(region, "GetTexture")
    return file ~= nil and Art.iconSet[file] == true
end

-- ------------------------------------------------------ Kandidaten finden

-- Eine Textur zählt als Grafik, wenn sie überhaupt etwas zeigt - egal ob
-- Atlas oder Datei. Der erste Anlauf hat nur Atlanten gezählt und deshalb
-- Blizzards Rahmen übersehen, die schlicht Dateitexturen sind.
local function isArt(region)
    return atlasOf(region) ~= nil or call(region, "GetTexture") ~= nil
end

local function survey(frame, depth, found)
    for _, region in ipairs(regionsOf(frame)) do
        if objectType(region) == "Texture" and isShown(region) then
            if not found.icon and looksLikeIcon(region) then
                found.icon = region
            elseif isArt(region) then
                found.art = found.art + 1
            end
        end
    end
    if depth > 0 then
        for _, child in ipairs(childrenOf(frame)) do
            if isShown(child) then
                survey(child, depth - 1, found)
            end
        end
    end
end

-- Maßgeblich ist allein das nachgewiesene Zaubersymbol. Grafik wird nicht mehr
-- verlangt: der Rahmen kann auch nur aus einer Maske auf dem Symbol bestehen.
local function classify(frame)
    local width, height = sizeOf(frame)
    if not width or height < 16 or height > 72 or width < 16 then
        return nil
    end
    local found = { art = 0 }
    survey(frame, 3, found)
    if not found.icon then
        return nil
    end
    if width <= height * 1.4 and height <= width * 1.4 then
        return "tile", found, width, height
    end
    if width >= height * 2.5 then
        return "bar", found, width, height
    end
    return nil
end

local function walk(frame, depth, found)
    if depth > MAX_DEPTH then
        return
    end
    local kind, survey, width, height = classify(frame)
    if kind then
        local list = found[kind]
        list[#list + 1] = {
            frame = frame,
            art = survey.art,
            icon = survey.icon,
            width = width,
            height = height,
            sizeKey = string.format("%dx%d",
                math.floor(width + 0.5), math.floor(height + 0.5)),
        }
    end
    for _, child in ipairs(childrenOf(frame)) do
        if isShown(child) then
            walk(child, depth + 1, found)
        end
    end
end

-- Aus den Treffern den echten Eintrag herausfinden. Der innerste ist es
-- nicht zwangsläufig - das Symbolfeld innerhalb einer Balkenzeile wäre
-- kleiner als eine Rasterkachel und würde sie schlagen. Was ein Eintrag ist,
-- verrät stattdessen die Häufigkeit: ein Raster besteht aus vielen gleich
-- großen Zellen, ein Sonderfall aus genau einer.
local function pick(list)
    if #list == 0 then
        return nil
    end

    -- Ohne nachgewiesenes Zaubersymbol kommt nichts in Frage. Kein Rückfall auf
    -- "dann eben irgendetwas" - genau das hat die Pluszeichen hereingelassen.
    local pool = {}
    for _, entry in ipairs(list) do
        if entry.icon then
            pool[#pool + 1] = entry
        end
    end
    if #pool == 0 then
        return nil
    end

    local counts = {}
    for _, entry in ipairs(pool) do
        counts[entry.sizeKey] = (counts[entry.sizeKey] or 0) + 1
    end

    local best
    for _, entry in ipairs(pool) do
        if not best
            or counts[entry.sizeKey] > counts[best.sizeKey]
            or (counts[entry.sizeKey] == counts[best.sizeKey] and entry.art > best.art) then
            best = entry
        end
    end
    if best then
        best.siblings = counts[best.sizeKey]
    end
    return best
end

-- ------------------------------------------------------------- Kopieren

local function applyGeometry(source, target, map)
    target:ClearAllPoints()
    local count = call(source, "GetNumPoints") or 0
    local hasTop, hasBottom, hasLeft, hasRight = false, false, false, false
    local applied = 0
    for index = 1, count do
        local point, relative, relativePoint, x, y = call(source, "GetPoint", index)
        local anchor = relative and map[relative]
        if anchor and type(point) == "string" then
            local ok = pcall(target.SetPoint, target, point, anchor,
                relativePoint or point, x or 0, y or 0)
            if ok then
                applied = applied + 1
                if point:find("TOP") then hasTop = true end
                if point:find("BOTTOM") then hasBottom = true end
                if point:find("LEFT") then hasLeft = true end
                if point:find("RIGHT") then hasRight = true end
            end
        end
    end
    if applied == 0 then
        target:SetPoint("CENTER")
    end
    local width, height = sizeOf(source)
    if width then
        if not (hasLeft and hasRight) and width > 0 then
            target:SetWidth(width)
        end
        if not (hasTop and hasBottom) and height > 0 then
            target:SetHeight(height)
        end
    end
end

local function copyTexture(source, target)
    local atlas = atlasOf(source)
    if atlas then
        pcall(target.SetAtlas, target, atlas)
    else
        local file = call(source, "GetTexture")
        if file ~= nil then
            pcall(target.SetTexture, target, file)
        end
        -- Bei Dateitexturen entscheidet der Zuschnitt mit, welcher Teil des
        -- Blattes zu sehen ist; ohne ihn wird aus einem Rahmen ein Klecks.
        local a, b, c, d, e, f, g, h = call(source, "GetTexCoord")
        if type(a) == "number" and type(h) == "number" then
            pcall(target.SetTexCoord, target, a, b, c, d, e, f, g, h)
        end
    end
    local red, green, blue, alpha = call(source, "GetVertexColor")
    if type(red) == "number" then
        pcall(target.SetVertexColor, target, red, green or 1, blue or 1, alpha or 1)
    end
    local blend = call(source, "GetBlendMode")
    if type(blend) == "string" then
        pcall(target.SetBlendMode, target, blend)
    end
    local opacity = call(source, "GetAlpha")
    if type(opacity) == "number" then
        target:SetAlpha(opacity)
    end
    if call(source, "IsDesaturated") then
        pcall(target.SetDesaturated, target, true)
    end
end

-- Die Maske ist der Grund für die runden Ecken am Symbol. Sie hängt an der
-- Textur, nicht am Rahmen, und muss darum eigens nachgebaut werden.
local function describeMasks(region)
    local masks = {}
    local count = call(region, "GetNumMaskTextures") or 0
    for index = 1, count do
        local mask = call(region, "GetMaskTexture", index)
        if mask then
            masks[#masks + 1] = {
                atlas = atlasOf(mask),
                file = call(mask, "GetTexture"),
            }
        end
    end
    return masks
end

-- Wo das Symbol sitzt, wird gemessen und nicht aus Blizzards Ankern
-- abgeschrieben. Der erste Anlauf hat deren Kette übernommen, und weil ein
-- Glied davon bei uns anders hängt, wurde das Symbol über die ganze
-- Balkenzeile gezogen. Ein Rechteck in Bildschirmkoordinaten kann das nicht.
local function rectOf(widget)
    local left = call(widget, "GetLeft")
    local right = call(widget, "GetRight")
    local top = call(widget, "GetTop")
    local bottom = call(widget, "GetBottom")
    if type(left) ~= "number" or type(right) ~= "number"
        or type(top) ~= "number" or type(bottom) ~= "number" then
        return nil
    end
    return left, right, top, bottom
end

local function describeSlot(region, sourceFrame)
    local slot = { masks = describeMasks(region) }

    -- Als Abstände zu allen vier Kanten, nicht als feste Größe: so sitzt das
    -- Symbol auch dann richtig, wenn unser Element größer ist als Blizzards
    -- Vorlage oder später in der Größe verändert wird.
    local fl, fr, ft, fb = rectOf(sourceFrame)
    local il, ir, it, ib = rectOf(region)
    if fl and il then
        slot.insetLeft = il - fl
        slot.insetTop = ft - it
        slot.insetRight = fr - ir
        slot.insetBottom = ib - fb
        slot.width = ir - il
        slot.height = it - ib
    else
        slot.width, slot.height = sizeOf(region)
    end

    local layer, sublevel = call(region, "GetDrawLayer")
    slot.layer, slot.sublevel = layer, sublevel
    local a, b, c, d, e, f, g, h = call(region, "GetTexCoord")
    if type(a) == "number" and type(h) == "number" then
        slot.texCoord = { a, b, c, d, e, f, g, h }
    end
    return slot
end

local function cloneInto(source, target, map, pending, textures, depth, slotBox)
    for _, region in ipairs(regionsOf(source)) do
        if objectType(region) == "Texture" and isShown(region) then
            -- Reihenfolge wie beim Durchmustern: erst das Symbol erkennen,
            -- alles andere ist Rahmen und wird nachgebaut.
            if not slotBox.region and looksLikeIcon(region) then
                slotBox.region = region
            elseif isArt(region) then
                local layer, sublevel = call(region, "GetDrawLayer")
                local texture = target:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
                copyTexture(region, texture)
                map[region] = texture
                pending[#pending + 1] = { source = region, target = texture }
                textures[#textures + 1] = texture
            end
        end
    end
    if depth > 0 then
        for _, child in ipairs(childrenOf(source)) do
            if isShown(child) and objectType(child) ~= "Texture" then
                local holder = CreateFrame("Frame", nil, target)
                map[child] = holder
                pending[#pending + 1] = { source = child, target = holder }
                cloneInto(child, holder, map, pending, textures, depth - 1, slotBox)
            end
        end
    end
end

local function applySlot(icon, slot, widget)
    if slot.insetRight then
        -- Beide Ecken verankert: der Rahmen behält seine Breite, das Symbol
        -- dazwischen wächst und schrumpft mit dem Element.
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", widget, "TOPLEFT",
            slot.insetLeft or 0, -(slot.insetTop or 0))
        icon:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT",
            -(slot.insetRight or 0), slot.insetBottom or 0)
    elseif slot.width and slot.height and slot.width > 0 and slot.height > 0 then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", widget, "TOPLEFT",
            slot.insetLeft or 0, -(slot.insetTop or 0))
        icon:SetSize(slot.width, slot.height)
    end
    if slot.layer then
        pcall(icon.SetDrawLayer, icon, slot.layer, slot.sublevel or 0)
    end
    if slot.texCoord then
        pcall(icon.SetTexCoord, icon, unpack(slot.texCoord))
    end
    local parent = icon:GetParent()
    if type(parent) ~= "table" or type(parent.CreateMaskTexture) ~= "function" then
        return
    end
    -- Die Maske aufheben: sie ist das einzige Stück, das runde Ecken macht,
    -- und wir brauchen sie auch dort, wo wir selbst zeichnen. Sie wandert in
    -- die Datenbank, denn unsere Leisten stehen im Spiel, lange bevor jemand
    -- Blizzards Fenster zum ersten Mal öffnet.
    if slot.masks[1] then
        Art.iconMask = slot.masks[1]
        if FCD.db and FCD.db.settings then
            FCD.db.settings.iconMask = slot.masks[1]
        end
    end
    for _, mask in ipairs(slot.masks) do
        local ok, created = pcall(parent.CreateMaskTexture, parent)
        if ok and created then
            if mask.atlas then
                pcall(created.SetAtlas, created, mask.atlas)
            elseif mask.file then
                pcall(created.SetTexture, created, mask.file,
                    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            end
            created:SetAllPoints(icon)
            pcall(icon.AddMaskTexture, icon, created)
        end
    end
end

-- ------------------------------------------------------------ Schnittstelle

function Art:Source()
    local window = _G.CooldownViewerSettings
    if type(window) ~= "table" or type(window.IsShown) ~= "function" then
        return nil
    end
    if not isShown(window) then
        return nil
    end
    return window
end

-- Die Liste der Symbole, die als Beweis gelten. Ohne sie wird nichts gelernt.
function Art:SetIconSet(set)
    self.iconSet = set
end

function Art:Enabled()
    local settings = FCD.db and FCD.db.settings
    if settings and settings.useBlizzardArt == false then
        return false
    end
    return true
end

function Art:Learn()
    if self.learned then
        return true
    end
    if not self:Enabled() then
        self.status = "abgeschaltet mit  /fcd art off"
        return false
    end
    if type(self.iconSet) ~= "table" or next(self.iconSet) == nil then
        self.status = "noch keine eigenen Symbole zum Abgleichen vorhanden."
        return false
    end
    local now = GetTime and GetTime() or 0
    if self.lastTry and now - self.lastTry < RETRY_SECONDS then
        return false
    end
    self.lastTry = now

    local window = self:Source()
    if not window then
        self.status = "Blizzards Fenster ist zu - ohne offenes Fenster gibt es nichts abzulesen."
        return false
    end

    local found = { tile = {}, bar = {} }
    local ok = pcall(walk, window, 0, found)
    if not ok then
        self.status = "Die Suche im Rahmenbaum ist abgebrochen."
        return false
    end

    self.candidates = found
    self.tileSource = pick(found.tile)
    self.barSource = pick(found.bar)
    if not self.tileSource and not self.barSource then
        self.status = "Kein Eintrag gefunden, der eines unserer Symbole zeigt."
        return false
    end

    local function describe(entry, label)
        if not entry then
            return "kein " .. label
        end
        return string.format(L["%s %s (%d Grafiken, %d gleich große)"],
            label, entry.sizeKey, entry.art, entry.siblings or 1)
    end

    self.learned = true
    self.status = describe(self.tileSource, "Symbolmuster")
        .. ", " .. describe(self.barSource, "Balkenmuster")
    return true
end

-- ------------------------------------------------- Sinnbilder der Reiter

-- Blizzards Reiter sitzen außerhalb ihres Fensterrahmens: quadratische Knöpfe,
-- senkrecht gestapelt, und darin ein Sinnbild - Stoppuhr, Blitz - statt eines
-- Zaubersymbols. Genau diese Sinnbilder wollen wir. Ihre Atlasnamen zu raten
-- ginge wieder daneben, also holen wir sie dort ab, wo sie gezeichnet werden.
local function glyphOf(frame, size)
    local best
    local function look(node, depth)
        for _, region in ipairs(regionsOf(node)) do
            if objectType(region) == "Texture" and isShown(region) and isArt(region) then
                local width, height = sizeOf(region)
                -- Der Rahmen des Knopfes füllt ihn ganz aus, das Sinnbild sitzt
                -- eingerückt. Darum zählt nur, was deutlich kleiner ist.
                if width and height and width > 4
                    and width <= size * 0.85 and height <= size * 0.85 then
                    local area = width * height
                    if not best or area > best.area then
                        local a, b, c, d, e, f, g, h = call(region, "GetTexCoord")
                        best = {
                            area = area,
                            -- Die Größe, in der Blizzard es zeichnet. Wer eine
                            -- Grafik auf ein anderes Maß zwingt, bekommt
                            -- krumme Kanten - deshalb merken wir sie uns.
                            width = width,
                            height = height,
                            atlas = atlasOf(region),
                            file = call(region, "GetTexture"),
                            texCoord = (type(a) == "number" and type(h) == "number")
                                and { a, b, c, d, e, f, g, h } or nil,
                        }
                    end
                end
            end
        end
        if depth > 0 then
            for _, child in ipairs(childrenOf(node)) do
                if isShown(child) then
                    look(child, depth - 1)
                end
            end
        end
    end
    pcall(look, frame, 2)
    return best
end

function Art:LearnTabIcons()
    if self.tabIcons then
        return self.tabIcons
    end
    if not self:Enabled() then
        return nil
    end
    -- Einmal abgeholt reicht: die Angaben sind reiner Text und überleben in
    -- der Datenbank. Ohne das wären die Sinnbilder weg, sobald ihr Fenster
    -- nicht mehr von selbst aufgeht.
    local cached = FCD.db and FCD.db.settings and FCD.db.settings.tabIcons
    if type(cached) == "table" and #cached > 0 then
        self.tabIcons = cached
        return cached
    end
    local now = GetTime and GetTime() or 0
    if self.lastTabTry and now - self.lastTabTry < RETRY_SECONDS then
        return nil
    end
    self.lastTabTry = now

    local window = self:Source()
    if not window then
        return nil
    end
    local windowLeft, windowRight = rectOf(window)
    if not windowLeft then
        return nil
    end

    local found = {}
    local function scan(frame, depth)
        for _, child in ipairs(childrenOf(frame)) do
            if isShown(child) then
                local left, right, top, bottom = rectOf(child)
                if left then
                    local width, height = right - left, top - bottom
                    if height >= 20 and height <= 56
                        and math.abs(width - height) <= 0.3 * math.max(width, height)
                        and (right <= windowLeft + 8 or left >= windowRight - 8) then
                        found[#found + 1] = { frame = child, x = left, y = top, size = height }
                    end
                end
                if depth > 0 then
                    scan(child, depth - 1)
                end
            end
        end
    end
    pcall(scan, window, 3)
    if #found < 2 then
        return nil
    end

    -- Nur die Spalte mit den meisten Knöpfen gilt als Reiterleiste; ein
    -- einzelner quadratischer Knopf am Rand ist etwas anderes.
    local columns = {}
    for _, entry in ipairs(found) do
        local key = math.floor(entry.x + 0.5)
        columns[key] = columns[key] or {}
        table.insert(columns[key], entry)
    end
    local column
    for _, list in pairs(columns) do
        if not column or #list > #column then
            column = list
        end
    end
    if not column or #column < 2 then
        return nil
    end
    table.sort(column, function(a, b) return a.y > b.y end)

    local icons = {}
    for _, entry in ipairs(column) do
        local glyph = glyphOf(entry.frame, entry.size)
        if glyph then
            icons[#icons + 1] = glyph
        end
    end
    if #icons == 0 then
        return nil
    end
    self.tabIcons = icons
    if FCD.db and FCD.db.settings then
        FCD.db.settings.tabIcons = icons
    end
    return icons
end

-- Legt ein abgeholtes Sinnbild auf eine Textur von uns. Gibt false zurück,
-- wenn es keines gibt - dann bleibt das Zaubersymbol stehen.
function Art:ApplyTabIcon(texture, index)
    local icons = self:LearnTabIcons()
    local glyph = icons and icons[index]
    if not glyph then
        return false
    end
    if glyph.atlas then
        if not pcall(texture.SetAtlas, texture, glyph.atlas) then
            return false
        end
    elseif glyph.file ~= nil then
        if not pcall(texture.SetTexture, texture, glyph.file) then
            return false
        end
    else
        return false
    end
    if glyph.texCoord then
        pcall(texture.SetTexCoord, texture, unpack(glyph.texCoord))
    end
    return true, glyph.width, glyph.height
end

-- Legt Blizzards Eckenmaske auf eine Fläche von uns. Über einen breiten
-- Balken gezogen rundet sie dessen Enden - das ist genau der Eindruck, den
-- ihre Leiste macht.
function Art:ApplyMask(texture)
    if not self:Enabled() then
        return false
    end
    -- Aus der letzten Sitzung übernehmen, falls in dieser noch nichts
    -- abgelesen wurde.
    if not self.iconMask and FCD.db and FCD.db.settings then
        self.iconMask = FCD.db.settings.iconMask
    end
    local mask = self.iconMask
    if not mask or texture.fcdMasked then
        return texture.fcdMasked == true
    end
    local parent = texture:GetParent()
    if type(parent) ~= "table" or type(parent.CreateMaskTexture) ~= "function" then
        return false
    end
    local ok, created = pcall(parent.CreateMaskTexture, parent)
    if not ok or not created then
        return false
    end
    if mask.atlas then
        if not pcall(created.SetAtlas, created, mask.atlas) then
            return false
        end
    elseif mask.file then
        if not pcall(created.SetTexture, created, mask.file,
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") then
            return false
        end
    else
        return false
    end
    created:SetAllPoints(texture)
    if pcall(texture.AddMaskTexture, texture, created) then
        texture.fcdMasked = true
        return true
    end
    return false
end

-- ------------------------------------------- Auswahlrahmen im Bearbeitungsmodus

-- Blizzards Bearbeitungsmodus umgibt jedes seiner Elemente mit demselben
-- Auswahlrahmen. Nachbauen hieße wieder Atlasnamen raten - stattdessen holen
-- wir ihn dort ab, solange der Modus offen ist. Gelesen wird nur; geschrieben
-- wird ausschließlich auf unsere eigenen Rahmen, damit nichts taintet.
local SYSTEM_LISTS = { "registeredSystemFrames", "systemFrames", "registeredSystems" }
local SELECTION_FIELDS = { "Selection", "SelectionFrame", "Highlight" }

local function editModeSystem()
    local manager = _G.EditModeManagerFrame
    if type(manager) ~= "table" or not isShown(manager) then
        return nil
    end
    for _, key in ipairs(SYSTEM_LISTS) do
        local list
        pcall(function() list = manager[key] end)
        if type(list) == "table" then
            for _, frame in pairs(list) do
                if type(frame) == "table" and objectType(frame) and isShown(frame) then
                    local left, right, top, bottom = rectOf(frame)
                    if left and (right - left) > 30 and (top - bottom) > 10 then
                        return frame
                    end
                end
            end
        end
    end
    return nil
end

local function selectionOverlay(system)
    for _, name in ipairs(SELECTION_FIELDS) do
        local candidate
        pcall(function() candidate = system[name] end)
        if type(candidate) == "table" and objectType(candidate) and isShown(candidate) then
            return candidate
        end
    end
    -- Sonst das Kind suchen, das die Fläche abdeckt und Atlasgrafik trägt
    local left, right, top, bottom = rectOf(system)
    if not left then
        return nil
    end
    for _, child in ipairs(childrenOf(system)) do
        if isShown(child) then
            local cl, cr, ct, cb = rectOf(child)
            if cl and cl <= left + 8 and cr >= right - 8
                and ct >= top - 8 and cb <= bottom + 8 then
                local found = { art = 0 }
                survey(child, 2, found)
                if found.art >= 3 then
                    return child
                end
            end
        end
    end
    return nil
end

function Art:DecorateEditSelection(widget)
    if widget.editArt then
        return true
    end
    if widget.editArtFailed or not self:Enabled() then
        return false
    end
    local system = editModeSystem()
    if not system then
        return false
    end
    local overlay = selectionOverlay(system)
    if not overlay then
        self.editStatus = "Auswahlrahmen im Bearbeitungsmodus nicht gefunden."
        return false
    end

    local map = { [overlay] = widget }
    local pending, textures = {}, {}
    local slotBox = {}
    local ok = pcall(cloneInto, overlay, widget, map, pending, textures, CLONE_DEPTH, slotBox)
    if not ok or #textures == 0 then
        for _, texture in ipairs(textures) do
            texture:Hide()
        end
        widget.editArtFailed = true
        self.editStatus = string.format("Nachbau des Auswahlrahmens erfolglos (%d Texturen).",
            #textures)
        return false
    end
    for _, item in ipairs(pending) do
        pcall(applyGeometry, item.source, item.target, map)
    end

    widget.editArt = textures
    self.editStatus = string.format(L["Auswahlrahmen übernommen (%d Texturen)."], #textures)
    return true
end

function Art:ShowEditSelection(widget, shown)
    if not widget.editArt then
        return false
    end
    for _, texture in ipairs(widget.editArt) do
        texture:SetShown(shown and true or false)
    end
    return true
end

-- ------------------------------------------------- Regler aus dem Bearbeitungsmodus

-- Ihr Bearbeitungsmodus hat selbst einen Regler ("Raster") mit Griff und zwei
-- Pfeilknöpfen. Den Griff bekommen wir ohne jedes Raten: ein Slider gibt seine
-- Grifftextur über GetThumbTexture heraus. Die Pfeile sind die kleinen Knöpfe
-- links und rechts daneben.
local function textureInfo(region)
    if not region then
        return nil
    end
    local info = {
        atlas = atlasOf(region),
        file = call(region, "GetTexture"),
    }
    if not info.atlas and info.file == nil then
        return nil
    end
    info.width, info.height = sizeOf(region)
    local a, b, c, d, e, f, g, h = call(region, "GetTexCoord")
    if type(a) == "number" and type(h) == "number" then
        info.texCoord = { a, b, c, d, e, f, g, h }
    end
    return info
end

function Art:LearnSliderArt()
    if self.sliderArt then
        return self.sliderArt
    end
    if not self:Enabled() then
        return nil
    end
    local manager = _G.EditModeManagerFrame
    if type(manager) ~= "table" or not isShown(manager) then
        return nil
    end

    local slider
    local function hunt(frame, depth)
        if slider or depth < 0 then
            return
        end
        for _, child in ipairs(childrenOf(frame)) do
            if isShown(child) then
                if objectType(child) == "Slider" then
                    slider = child
                    return
                end
                hunt(child, depth - 1)
            end
        end
    end
    pcall(hunt, manager, 6)
    if not slider then
        return nil
    end

    local art = { thumb = textureInfo(call(slider, "GetThumbTexture")) }
    if not art.thumb then
        return nil
    end

    -- Pfeilknöpfe: kleine Knöpfe im selben Rahmen, einer links, einer rechts
    local parent = call(slider, "GetParent")
    local sliderLeft, sliderRight = rectOf(slider)
    if parent and sliderLeft then
        for _, child in ipairs(childrenOf(parent)) do
            if isShown(child) and objectType(child) == "Button" then
                local left, right, top, bottom = rectOf(child)
                if left and (right - left) <= 24 and (top - bottom) <= 28 then
                    local info = textureInfo(call(child, "GetNormalTexture"))
                    if info then
                        if right <= sliderLeft + 4 and not art.left then
                            art.left = info
                        elseif left >= sliderRight - 4 and not art.right then
                            art.right = info
                        end
                    end
                end
            end
        end
    end

    self.sliderArt = art
    self.sliderStatus = string.format("Griff %s, Pfeile %s",
        tostring(art.thumb.atlas or art.thumb.file),
        (art.left and art.right) and "gefunden" or "nicht gefunden")
    return art
end

-- Legt eine abgeholte Grafik auf eine Textur von uns.
function Art:ApplyTexture(texture, info, keepSize)
    if not info or not texture then
        return false
    end
    if info.atlas then
        if not pcall(texture.SetAtlas, texture, info.atlas) then
            return false
        end
    elseif not pcall(texture.SetTexture, texture, info.file) then
        return false
    end
    if info.texCoord then
        pcall(texture.SetTexCoord, texture, unpack(info.texCoord))
    end
    if not keepSize and info.width and info.height
        and info.width > 0 and info.height > 0 then
        texture:SetSize(info.width, info.height)
    end
    texture:SetVertexColor(1, 1, 1, 1)
    return true
end

function Art:TileSize()
    if self.tileSource then
        local size = math.floor(self.tileSource.height + 0.5)
        if size >= 24 and size <= 64 then
            return size
        end
    end
    return nil
end

function Art:BarHeight()
    if self.barSource then
        local size = math.floor(self.barSource.height + 0.5)
        if size >= 18 and size <= 60 then
            return size
        end
    end
    return nil
end

-- Legt Blizzards Grafik auf ein Element von uns. Gibt false zurück, wenn es
-- noch nichts abzuschauen gibt - dann bleibt unsere eigene Zeichnung stehen.
function Art:Decorate(widget, kind)
    if widget.artApplied then
        return true
    end
    -- Ein einmal gescheiterter Nachbau wird nicht erneut versucht: sonst
    -- entstünde bei jedem Neuzeichnen ein weiterer Satz toter Texturen.
    if widget.artFailed then
        return false
    end
    if not self:Learn() then
        return false
    end
    local entry = (kind == "bar") and self.barSource or self.tileSource
    if not entry or not entry.frame then
        return false
    end

    local map = { [entry.frame] = widget }
    local pending, textures = {}, {}
    local slotBox = {}
    local ok = pcall(cloneInto, entry.frame, widget, map, pending, textures,
        CLONE_DEPTH, slotBox)
    -- Beim Symbol genügt die Maske: die runden Ecken stecken dort und nicht
    -- zwingend in einer Rahmentextur. Beim Balken nicht - dort ersetzt der
    -- Nachbau unsere eigene Zeichnung, und ohne Rahmentextur bliebe die Zeile
    -- leer. Also muss dafür wirklich etwas kopiert worden sein.
    -- Für die Fehlersuche festhalten, was ein Versuch eingebracht hat
    self.lastClone = self.lastClone or {}
    self.lastClone[kind] = string.format("%d Textur(en), Symbolfeld %s%s",
        #textures, slotBox.region and "ja" or "nein", ok and "" or ", Abbruch")

    local enough = (#textures > 0) or (kind ~= "bar" and slotBox.region ~= nil)
    if not ok or not enough then
        for _, texture in ipairs(textures) do
            texture:Hide()
        end
        widget.artFailed = true
        return false
    end

    for _, item in ipairs(pending) do
        pcall(applyGeometry, item.source, item.target, map)
    end

    if slotBox.region and widget.icon then
        pcall(applySlot, widget.icon, describeSlot(slotBox.region, entry.frame), widget)
    end

    widget.artTextures = textures
    widget.artApplied = true
    return true
end

-- Ungelerntes soll matt wirken, ohne dass wir wissen müssen, welche der
-- kopierten Texturen die Füllung ist: entsättigt wird einfach alles.
function Art:SetActive(widget, active)
    if not widget.artTextures then
        return
    end
    for _, texture in ipairs(widget.artTextures) do
        pcall(texture.SetDesaturated, texture, not active)
    end
end

function Art:Describe()
    local lines = {}
    lines[#lines + 1] = L["== Blizzards Einträge als Vorlage =="]
    lines[#lines + 1] = "Stand: " .. tostring(self.status)
    lines[#lines + 1] = ""

    local window = self:Source()
    if not window then
        lines[#lines + 1] = "Blizzards Abklingzeit-Fenster ist gerade nicht offen."
        lines[#lines + 1] = L["Öffne es und rufe den Befehl erneut auf."]
        return table.concat(lines, "\n")
    end

    -- Die entscheidende Frage, wenn nichts gefunden wurde: zeigt in ihrem
    -- Fenster überhaupt irgendeine Textur eines unserer Symbole?
    local known = 0
    if type(self.iconSet) == "table" then
        for _ in pairs(self.iconSet) do
            known = known + 1
        end
    end
    lines[#lines + 1] = string.format("Eigene Symbole zum Abgleich: %d", known)
    for _, kind in ipairs({ "tile", "bar" }) do
        local result = self.lastClone and self.lastClone[kind]
        lines[#lines + 1] = string.format("Letzter Nachbau %s: %s",
            (kind == "bar") and "Balken" or "Symbol", result or "nicht versucht")
    end
    lines[#lines + 1] = "Auswahlrahmen Bearbeitungsmodus: "
        .. tostring(self.editStatus or "noch nicht versucht")
    local tabIcons = self.tabIcons
    lines[#lines + 1] = string.format("Sinnbilder der Reiter: %s",
        tabIcons and (#tabIcons .. " abgeholt") or "keine gefunden")
    for index, glyph in ipairs(tabIcons or {}) do
        lines[#lines + 1] = string.format("    %d: %s", index,
            tostring(glyph.atlas or glyph.file))
    end

    local hits, samples = 0, {}
    local function hunt(frame, depth)
        for _, region in ipairs(regionsOf(frame)) do
            if objectType(region) == "Texture" and isShown(region) then
                local file = call(region, "GetTexture")
                if file ~= nil and self.iconSet and self.iconSet[file] then
                    hits = hits + 1
                    if #samples < 6 then
                        local width, height = sizeOf(region)
                        local pw, ph = sizeOf(frame)
                        samples[#samples + 1] = string.format(
                            "    Symbol %s (%.0fx%.0f) in Rahmen %s (%.0fx%.0f), Masken: %d",
                            tostring(file), width or 0, height or 0,
                            tostring(call(frame, "GetObjectType")), pw or 0, ph or 0,
                            #describeMasks(region))
                    end
                end
            end
        end
        if depth > 0 then
            for _, child in ipairs(childrenOf(frame)) do
                if isShown(child) then
                    hunt(child, depth - 1)
                end
            end
        end
    end
    pcall(hunt, window, MAX_DEPTH)
    lines[#lines + 1] = string.format("Davon in ihrem Fenster sichtbar: %d", hits)
    for _, sample in ipairs(samples) do
        lines[#lines + 1] = sample
    end
    lines[#lines + 1] = ""

    for _, kind in ipairs({ "tile", "bar" }) do
        local entry = (kind == "bar") and self.barSource or self.tileSource
        lines[#lines + 1] = (kind == "bar") and "-- Balkeneintrag --" or "-- Symboleintrag --"
        if not entry then
            lines[#lines + 1] = "  nichts gefunden"
        else
            local name = call(entry.frame, "GetName")
            lines[#lines + 1] = string.format("  Rahmen: %s", name or "ohne Namen")
            lines[#lines + 1] = string.format(L["  Maße: %.0f x %.0f"], entry.width, entry.height)
            lines[#lines + 1] = string.format("  Atlas-Texturen: %d", entry.art)
            local seen = {}
            local function list(frame, depth)
                for _, region in ipairs(regionsOf(frame)) do
                    if objectType(region) == "Texture" and isShown(region) then
                        local atlas = atlasOf(region)
                        local layer, sublevel = call(region, "GetDrawLayer")
                        local width, height = sizeOf(region)
                        if atlas and not seen[atlas] then
                            seen[atlas] = true
                            lines[#lines + 1] = string.format("    %s  [%s %s]  %.0fx%.0f",
                                atlas, tostring(layer), tostring(sublevel or 0),
                                width or 0, height or 0)
                        elseif not atlas then
                            local masks = describeMasks(region)
                            lines[#lines + 1] = string.format("    (Datei) %.0fx%.0f, Masken: %d",
                                width or 0, height or 0, #masks)
                            for _, mask in ipairs(masks) do
                                lines[#lines + 1] = "      Maske: " ..
                                    tostring(mask.atlas or mask.file)
                            end
                        end
                    end
                end
                if depth > 0 then
                    for _, child in ipairs(childrenOf(frame)) do
                        if isShown(child) then
                            list(child, depth - 1)
                        end
                    end
                end
            end
            pcall(list, entry.frame, CLONE_DEPTH)
        end
        lines[#lines + 1] = ""
    end

    -- Alle Treffer nach Größe gebündelt: daran sieht man, ob die Auswahl oben
    -- den richtigen Eintrag erwischt hat oder ein Nachbar häufiger war.
    if self.candidates then
        for _, kind in ipairs({ "tile", "bar" }) do
            local list = self.candidates[kind]
            lines[#lines + 1] = (kind == "bar")
                and "-- alle breiten Treffer --" or "-- alle quadratischen Treffer --"
            local counts, order = {}, {}
            for _, entry in ipairs(list or {}) do
                local key = entry.sizeKey .. (entry.icon and " mit Symbol" or " ohne Symbol")
                if not counts[key] then
                    order[#order + 1] = key
                    counts[key] = 0
                end
                counts[key] = counts[key] + 1
            end
            if #order == 0 then
                lines[#lines + 1] = "  keine"
            end
            for _, key in ipairs(order) do
                lines[#lines + 1] = string.format("  %s: %d", key, counts[key])
            end
            lines[#lines + 1] = ""
        end
    end

    return table.concat(lines, "\n")
end
