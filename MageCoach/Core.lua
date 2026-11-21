local ADDON, MC = ...
local D = MC.Data
_G.MageCoach = MC

local floor, max, min = math.floor, math.max, math.min
local format, tinsert, concat = string.format, table.insert, table.concat

local MAX_LEVEL = 60
local TABS = { "Talents", "Trainer", "Tips", "Zones" }

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0MageCoach|r: " .. tostring(msg))
end
MC.Print = Print

local function C(color, text) return "|c" .. color .. text .. "|r" end
local GREEN, YELLOW, GREY, WHITE, RED, GOLD = "ff40ff40", "ffffff00", "ff808080", "ffffffff", "ffff6060", "ffffd100"

function MC:IsMage()
    local _, class = UnitClass("player")
    return class == "MAGE"
end

function MC:Faction()
    local f = UnitFactionGroup("player")
    if f == "Alliance" then return "A" elseif f == "Horde" then return "H" end
    return "B"
end

function MC:Level()
    return self.levelOverride or UnitLevel("player") or 1
end

function MC:PathKey()
    local key = MageCoachCharDB and MageCoachCharDB.path
    if not key or not D.Paths[key] then key = D.DefaultPath or "arcane" end
    return key
end

function MC:Path()
    return D.Paths[self:PathKey()]
end

------------------------------------------------------------------------
-- Talent API (defensive: WoW Forever may or may not expose the classic talent calls)
------------------------------------------------------------------------
-- Returns { [talentName] = currentRank } or nil when the classic API is unavailable.
function MC:ReadTalentRanks()
    if type(GetNumTalentTabs) ~= "function" or type(GetNumTalents) ~= "function" or type(GetTalentInfo) ~= "function" then
        return nil
    end
    local ok, numTabs = pcall(GetNumTalentTabs)
    if not ok or type(numTabs) ~= "number" or numTabs == 0 then return nil end

    local ranks, found = {}, false
    for tab = 1, numTabs do
        local okN, n = pcall(GetNumTalents, tab)
        if okN and type(n) == "number" then
            for i = 1, n do
                local okI, name, _, _, _, rank = pcall(GetTalentInfo, tab, i)
                if okI and type(name) == "string" and type(rank) == "number" then
                    ranks[name] = rank
                    found = true
                end
            end
        end
    end
    return found and ranks or nil
end

-- Works out where the player is on the chosen path.
-- Returns a table: { missing = {...}, nextPick = {lvl, name}, apiOk = bool, unknown = {name=true} }
function MC:TalentStatus()
    local path = self:Path()
    local level = self:Level()
    local owed = max(0, min(#path.talents, level - 9))
    local ranks = self:ReadTalentRanks()
    local status = { apiOk = ranks ~= nil, missing = {}, unknown = {}, owed = owed }

    if ranks then
        local running = {}
        for i = 1, #path.talents do
            local name = path.talents[i]
            running[name] = (running[name] or 0) + 1
            if ranks[name] == nil then status.unknown[name] = true end
            local have = ranks[name] or 0
            if have < running[name] then
                if i <= owed then
                    tinsert(status.missing, { lvl = i + 9, name = name })
                elseif not status.upcoming then
                    status.upcoming = { lvl = i + 9, name = name }
                end
            end
        end
        status.nextPick = status.missing[1] or status.upcoming
    else
        if owed >= 1 then
            status.nextPick = { lvl = level, name = path.talents[owed] }
        elseif level < 10 then
            status.nextPick = { lvl = 10, name = path.talents[1] }
        end
        if owed < #path.talents then
            status.upcoming = { lvl = owed + 10, name = path.talents[owed + 1] }
        end
    end
    return status
end

------------------------------------------------------------------------
-- Page builders (return a single rich-text string)
------------------------------------------------------------------------
local function NoteFor(path, lvl)
    for _, n in ipairs(path.notes) do
        if n[1] == lvl then return n[2] end
    end
end

function MC:BuildTalents()
    local path, level = self:Path(), self:Level()
    local st = self:TalentStatus()
    local out = {}

    tinsert(out, C(path.color, path.name .. " leveling") .. "  " .. C(GREY, "(" .. path.split .. ")"))
    tinsert(out, C(WHITE, path.blurb))
    tinsert(out, " ")

    if level < 10 then
        tinsert(out, C(YELLOW, "Talents start at level 10.") .. " First pick: " .. C(GOLD, path.talents[1]))
    elseif st.apiOk then
        if #st.missing > 0 then
            tinsert(out, C(YELLOW, format("Take next: %s", st.missing[1].name)))
            if #st.missing > 1 then
                tinsert(out, C(GREY, format("%d guide points not matched yet (unspent, or spent elsewhere).", #st.missing)))
            end
        elseif st.upcoming then
            tinsert(out, C(GREEN, "You're on track!") .. "  Next at level " .. st.upcoming.lvl .. ": " .. C(GOLD, st.upcoming.name))
        else
            tinsert(out, C(GREEN, "Build complete."))
        end
        local unknownList = {}
        for name in pairs(st.unknown) do tinsert(unknownList, name) end
        if #unknownList > 0 then
            table.sort(unknownList)
            tinsert(out, C(RED, "Not found in your talent tree: ") .. C(GREY, concat(unknownList, ", ")))
        end
    else
        if st.nextPick then
            tinsert(out, C(YELLOW, format("Level %d point: %s", st.nextPick.lvl, st.nextPick.name)))
        end
        tinsert(out, C(GREY, "(Can't read your talent tree on this client, so this follows your level only.)"))
    end
    tinsert(out, " ")

    -- Missing lookup for colouring.
    local missingAt = {}
    for _, m in ipairs(st.missing) do missingAt[m.lvl] = true end

    local seen = {}
    for i, name in ipairs(path.talents) do
        local lvl = i + 9
        local note = NoteFor(path, lvl)
        if note then tinsert(out, C(GOLD, "  " .. note)) end
        seen[name] = (seen[name] or 0) + 1
        local info = D.TalentInfo and D.TalentInfo[name]
        local line = format("%2d  %s", lvl, name)
        if info then line = line .. format(" %d/%d", seen[name], info[3]) end
        if info and seen[name] == 1 then line = line .. "  " .. C(GREY, "- " .. info[4]) end
        if lvl > level then
            line = C(GREY, line)
        elseif missingAt[lvl] then
            line = C(YELLOW, line .. "   <- take this")
        elseif lvl == level then
            line = C(GREEN, line .. "   (this level)")
        else
            line = C(GREEN, line)
        end
        tinsert(out, line)
    end
    tinsert(out, " ")
    tinsert(out, C(GREY, "Built from the Mobalytics leveling guide, checked against the WoW Forever talent data (Nov 2026). Swap points freely."))
    return concat(out, "\n")
end

local function SpellLabel(s)
    local name = s[2]
    if s[3] then name = name .. " (Rank " .. s[3] .. ")" end
    return name
end

function MC:BuildTrainer()
    local pathKey, path, level = self:PathKey(), self:Path(), self:Level()
    local out = {}
    tinsert(out, C(path.color, "Trainer list - " .. path.name))
    tinsert(out, C(GREY, path.skipNote))
    tinsert(out, C(GREEN, "buy") .. "   " .. C(GREY, "optional / skip") .. "   " .. C(RED, "other spec only"))
    tinsert(out, " ")

    local byLevel, levels = {}, {}
    for _, s in ipairs(D.Spells) do
        if s[1] <= level + 4 then
            if not byLevel[s[1]] then byLevel[s[1]] = {}; tinsert(levels, s[1]) end
            tinsert(byLevel[s[1]], s)
        end
    end
    table.sort(levels, function(a, b) return a > b end) -- newest first

    for _, lvl in ipairs(levels) do
        local header = "Level " .. lvl
        if lvl > level then header = header .. "  (coming up)"
        elseif lvl > level - 2 then header = header .. "  (new!)" end
        tinsert(out, C(lvl > level and GREY or GOLD, header))
        for _, s in ipairs(byLevel[lvl]) do
            local label = SpellLabel(s)
            local line
            if s[4] and s[4] ~= pathKey and not (s[4] == "frost" and pathKey == "frostaoe") then
                line = C(RED, "  " .. label .. "  - " .. D.Paths[s[4]].name .. " only")
            elseif path.skip[s[2]] and s[4] == nil then
                line = C(GREY, "  " .. label .. "  - skip for " .. path.name)
            else
                line = C(lvl > level and GREY or GREEN, "  " .. label)
            end
            if s[5] then line = line .. C(GREY, "  " .. s[5]) end
            tinsert(out, line)
        end
    end
    return concat(out, "\n")
end

function MC:Bracket(level)
    for _, b in ipairs(D.Brackets) do
        if level >= b.min and level <= b.max then return b end
    end
    return D.Brackets[#D.Brackets]
end

function MC:BuildTips()
    local path, level = self:Path(), self:Level()
    local b = self:Bracket(level)
    local out = {}

    tinsert(out, C(GOLD, "Right now (level " .. level .. ")"))
    tinsert(out, "  Water: " .. b.water)
    tinsert(out, "  Wand: " .. b.wand)
    tinsert(out, "  " .. b.extra)
    if b.aoe then tinsert(out, "  " .. C(YELLOW, "AoE / mana: ") .. b.aoe) end
    tinsert(out, " ")

    tinsert(out, C(GOLD, "One-button macro") .. C(GREY, "  (type /mc macro)"))
    tinsert(out, "  Press = single target,  Shift = Arcane Explosion,  Ctrl = Blizzard/Flamestrike at cursor.")
    tinsert(out, "  The next-spell icon counts enemies on you and says when to hold Shift. Procs are on the icon, not the macro.")
    tinsert(out, " ")

    tinsert(out, C(path.color, path.name .. " rotation"))
    for i, r in ipairs(path.rotation) do tinsert(out, format("  %d. %s", i, r)) end
    tinsert(out, " ")

    tinsert(out, C(GOLD, "Professions"))
    for _, p in ipairs(D.Professions) do tinsert(out, "  " .. p) end
    tinsert(out, " ")

    tinsert(out, C(GOLD, "Stats"))
    tinsert(out, "  " .. D.Stats)
    tinsert(out, " ")

    tinsert(out, C(GOLD, "Consumables"))
    for _, c in ipairs(D.Consumables) do tinsert(out, "  " .. c) end
    tinsert(out, " ")

    tinsert(out, C(GOLD, "General tips"))
    for _, t in ipairs(D.GeneralTips) do tinsert(out, "  - " .. t) end
    return concat(out, "\n")
end

function MC:ZonesFor(level)
    local fac, list = self:Faction(), {}
    for _, z in ipairs(D.Zones) do
        if (z[5] == "B" or z[5] == fac) and level >= z[3] - 1 and level <= z[4] - 2 then
            tinsert(list, z)
        end
    end
    return list
end

function MC:BuildZones()
    local level, fac = self:Level(), self:Faction()
    local out = {}
    tinsert(out, C(GOLD, "Good zones for level " .. level))
    local now = self:ZonesFor(level)
    if #now == 0 then tinsert(out, C(GREY, "  (none listed - try dungeons or the zones below)")) end
    for _, z in ipairs(now) do
        tinsert(out, C(GREEN, format("  %s  (%d-%d)", z[2], z[3], z[4])))
    end
    tinsert(out, " ")
    tinsert(out, C(GREY, "Questie / RestedXP handle the actual quests. Open the world map: MageCoach marks trainers and says whether a zone fits your level."))
    tinsert(out, " ")
    tinsert(out, C(GOLD, "All zones"))
    for _, z in ipairs(D.Zones) do
        if z[5] == "B" or z[5] == fac then
            local line = format("  %2d-%2d  %s", z[3], z[4], z[2])
            if level >= z[3] - 1 and level <= z[4] - 2 then line = C(GREEN, line)
            elseif level > z[4] then line = C(GREY, line) end
            tinsert(out, line)
        end
    end
    return concat(out, "\n")
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local frame

local function MakeButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 90, 22)
    b:SetText(text)
    return b
end

function MC:CreateUI()
    if frame then return frame end
    frame = CreateFrame("Frame", "MageCoachFrame", UIParent, "BackdropTemplate")
    frame:SetSize(440, 520)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        MageCoachDB.pos = { point, relPoint, x, y }
        MC.anchoredTo = nil
    end)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.04, 0.05, 0.10, 0.94)
    frame:SetBackdropBorderColor(0.41, 0.80, 0.94, 0.9)
    frame:Hide()
    tinsert(UISpecialFrames, "MageCoachFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText("|cff69ccf0MageCoach|r")
    frame.title = title

    local sub = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("LEFT", title, "RIGHT", 10, -1)
    frame.sub = sub

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    -- Path buttons
    frame.pathButtons = {}
    local prev
    for _, key in ipairs(D.PathOrder) do
        local b = MakeButton(frame, D.Paths[key].name, 100)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 12, -38) end
        b:SetScript("OnClick", function() MC:SetPath(key) end)
        frame.pathButtons[key] = b
        prev = b
    end

    -- Tab buttons
    frame.tabButtons = {}
    prev = nil
    for i, name in ipairs(TABS) do
        local b = MakeButton(frame, name, 100)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 12, -64) end
        b:SetScript("OnClick", function() MC:ShowTab(i) end)
        frame.tabButtons[i] = b
        prev = b
    end

    -- Scrolling body
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 14, -94)
    scroll:SetPoint("BOTTOMRIGHT", -14, 12)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(s, delta)
        local new = s:GetVerticalScroll() - delta * 40
        new = max(0, min(new, s:GetVerticalScrollRange()))
        s:SetVerticalScroll(new)
    end)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(410, 10)
    scroll:SetScrollChild(child)
    local body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT")
    body:SetWidth(408)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    if body.SetSpacing then body:SetSpacing(2) end
    frame.scroll, frame.child, frame.body = scroll, child, body

    self:RestorePosition()
    return frame
end

function MC:RestorePosition()
    frame:ClearAllPoints()
    local p = MageCoachDB.pos
    if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint("CENTER", UIParent, "CENTER", 250, 0) end
end

local builders = { "BuildTalents", "BuildTrainer", "BuildTips", "BuildZones" }

function MC:Refresh()
    if not frame or not frame:IsShown() then return end
    local tab = self.tab or 1
    for key, b in pairs(frame.pathButtons) do
        if key == self:PathKey() then b:LockHighlight() else b:UnlockHighlight() end
    end
    for i, b in ipairs(frame.tabButtons) do
        if i == tab then b:LockHighlight() else b:UnlockHighlight() end
    end
    frame.sub:SetText(format("Level %d  -  %s", self:Level(), self:Path().name))
    local ok, text = pcall(self[builders[tab]], self)
    if not ok then text = "|cffff6060Error building page:|r " .. tostring(text) end
    frame.body:SetText(text)
    frame.child:SetHeight(frame.body:GetStringHeight() + 20)
    frame.scroll:SetVerticalScroll(0)
end

function MC:ShowTab(i)
    self:CreateUI()
    self.tab = i
    MageCoachDB.tab = i
    frame:Show()
    self:Refresh()
end

function MC:Toggle()
    self:CreateUI()
    if frame:IsShown() then frame:Hide() else self:ShowTab(self.tab or 1) end
end

-- Open next to a Blizzard frame (talent window / trainer).
function MC:ShowBeside(other, tab)
    if not MageCoachDB.autoShow or not self:IsMage() then return end
    self:ShowTab(tab)
    if other and other.IsShown and other:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", other, "TOPRIGHT", 8, 0)
        self.anchoredTo = other
    end
end

function MC:HideIfBeside(other)
    if frame and self.anchoredTo == other then
        frame:Hide()
        self.anchoredTo = nil
        self:RestorePosition()
    end
end

function MC:SetPath(key)
    if not D.Paths[key] then
        Print("Unknown path. Use: arcane, frost, fire, frostaoe")
        return
    end
    MageCoachCharDB.path = key
    Print("Path set to " .. C(D.Paths[key].color, D.Paths[key].name))
    self:Refresh()
    if self.RefreshMap then self:RefreshMap() end
    if self.UpdatePowerLabel then self:UpdatePowerLabel() end
end

------------------------------------------------------------------------
-- Minimap button
------------------------------------------------------------------------
function MC:CreateMinimapButton()
    if self.mmButton or not Minimap then return end
    local b = CreateFrame("Button", "MageCoachMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local function Place()
        local a = math.rad(MageCoachDB.mmAngle or 200)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
    end
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" then
            MageCoachDB.pins = not MageCoachDB.pins
            Print("Map pins " .. (MageCoachDB.pins and "on" or "off"))
            if MC.RefreshMap then MC:RefreshMap() end
        else
            MC:Toggle()
        end
    end)
    b:SetScript("OnDragStart", function(s)
        s:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            MageCoachDB.mmAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
            Place()
        end)
    end)
    b:SetScript("OnDragStop", function(s) s:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine("MageCoach")
        GameTooltip:AddLine("Left-click: open / close", 1, 1, 1)
        GameTooltip:AddLine("Right-click: toggle map pins", 1, 1, 1)
        GameTooltip:AddLine("Drag: move", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Place()
    if MageCoachDB.hideMinimap then b:Hide() end
    self.mmButton = b
end

------------------------------------------------------------------------
-- Level-up announcement
------------------------------------------------------------------------
function MC:AnnounceLevel(level)
    if not self:IsMage() then return end
    local path = self:Path()
    local idx = level - 9
    if idx >= 1 and path.talents[idx] then
        Print(format("Level %d! Talent point -> %s", level, C(GOLD, path.talents[idx])))
        local note = NoteFor(path, level)
        if note then Print(C(GREY, note)) end
    end
    local new = {}
    for _, s in ipairs(D.Spells) do
        if s[1] == level and (not s[4] or s[4] == self:PathKey() or (s[4] == "frost" and self:PathKey() == "frostaoe")) then
            tinsert(new, SpellLabel(s))
        end
    end
    if #new > 0 then Print("New at the trainer: " .. concat(new, ", ")) end
    for _, z in ipairs(D.Zones) do
        if (z[5] == "B" or z[5] == self:Faction()) and z[3] - 1 == level then
            Print("New zone opens up: " .. C(GREEN, z[2]) .. format(" (%d-%d)", z[3], z[4]))
        end
    end
end

------------------------------------------------------------------------
-- Talent / trainer window hooks
------------------------------------------------------------------------
local hooked = {}
local TALENT_FRAMES = { "PlayerTalentFrame", "TalentFrame", "ClassTalentFrame", "PlayerSpellsFrame" }

function MC:TryHookTalentFrames()
    for _, name in ipairs(TALENT_FRAMES) do
        local f = _G[name]
        if f and not hooked[name] and f.HookScript then
            hooked[name] = true
            f:HookScript("OnShow", function(s) MC:ShowBeside(s, 1) end)
            f:HookScript("OnHide", function(s) MC:HideIfBeside(s) end)
        end
    end
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function Help()
    Print("commands:")
    Print("  /mc - open/close")
    Print("  /mc path arcane|frost|fire|frostaoe")
    Print("  /mc talents | trainer | tips | zones")
    Print("  /mc pins on|off  - trainer pins + zone hint on the world map")
    Print("  /mc pin <note>  - pin your current spot (e.g. /mc pin Melon Juice vendor)")
    Print("  /mc pins clear  - remove your own pins")
    Print("  /mc macro  - create/update your one-button rotation macro")
    Print("  /mc helper on|off  - next-spell icon (shows on hostile targets)")
    Print("  /mc lock | unlock  - lock or move the next-spell icon")
    Print("  /mc aoe <n>  - enemies on you before it says AoE (default 3)")
    Print("  /mc power  - gear score for your path (also shown on item tooltips)")
    Print("  /mc dps  - how the DPS estimate is worked out")
    Print("  /mc power on|off  - show/hide the tooltip + character frame line")
    Print("  /mc auto on|off  - open beside talent window / trainer")
    Print("  /mc minimap  - show/hide minimap button")
    Print("  /mc debug  - check which game APIs this client has")
end

local function Debug()
    local _, _, _, iface = GetBuildInfo()
    Print("interface " .. tostring(iface) .. ", level " .. MC:Level() .. ", faction " .. MC:Faction())
    local function has(n) return (type(_G[n]) == "function") and "|cff40ff40yes|r" or "|cffff6060no|r" end
    Print("GetNumTalentTabs " .. has("GetNumTalentTabs") .. "  GetTalentInfo " .. has("GetTalentInfo") .. "  GetNumTalents " .. has("GetNumTalents"))
    local ranks = MC:ReadTalentRanks()
    if ranks then
        local n, sample = 0, nil
        for name in pairs(ranks) do n = n + 1; sample = sample or name end
        Print("talent tree readable: " .. n .. " talents (e.g. " .. tostring(sample) .. ")")
    else
        Print("talent tree NOT readable - talent coach falls back to level-only mode")
    end
    Print("WorldMapFrame canvas " .. ((WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child) and "|cff40ff40yes|r" or "|cffff6060no|r"))
    if C_Map and C_Map.GetBestMapForUnit then
        local id = C_Map.GetBestMapForUnit("player")
        local info = id and C_Map.GetMapInfo(id)
        Print("current uiMapID " .. tostring(id) .. " (" .. tostring(info and info.name) .. ")")
    end
end

SLASH_MAGECOACH1 = "/mc"
SLASH_MAGECOACH2 = "/magecoach"
SlashCmdList.MAGECOACH = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        MC:Toggle()
    elseif cmd == "path" then
        MC:SetPath((rest or ""):lower():gsub("%s", ""))
    elseif cmd == "talents" then MC:ShowTab(1)
    elseif cmd == "trainer" then MC:ShowTab(2)
    elseif cmd == "tips" then MC:ShowTab(3)
    elseif cmd == "zones" then MC:ShowTab(4)
    elseif cmd == "pins" then
        rest = (rest or ""):lower()
        if rest == "clear" then
            MageCoachDB.customPins = {}
            Print("Your pins were cleared.")
        elseif rest == "on" or rest == "off" then
            MageCoachDB.pins = (rest == "on")
            Print("Map pins " .. rest)
        else
            MageCoachDB.pins = not MageCoachDB.pins
            Print("Map pins " .. (MageCoachDB.pins and "on" or "off"))
        end
        if MC.RefreshMap then MC:RefreshMap() end
    elseif cmd == "pin" then
        if MC.AddCustomPin then MC:AddCustomPin(rest) end
    elseif cmd == "auto" then
        MageCoachDB.autoShow = (rest:lower() ~= "off")
        Print("Auto-open " .. (MageCoachDB.autoShow and "on" or "off"))
    elseif cmd == "minimap" then
        MageCoachDB.hideMinimap = not MageCoachDB.hideMinimap
        if MC.mmButton then MC.mmButton:SetShown(not MageCoachDB.hideMinimap) end
    elseif cmd == "level" then -- testing aid: /mc level 25 (blank resets)
        MC.levelOverride = tonumber(rest)
        Print("Previewing level " .. MC:Level())
        MC:Refresh()
        if MC.RefreshMap then MC:RefreshMap() end
    elseif cmd == "macro" then
        MC:MacroCommand()
    elseif cmd == "helper" then
        rest = (rest or ""):lower()
        if rest == "on" or rest == "off" then MageCoachDB.helper = (rest == "on") else MageCoachDB.helper = not MageCoachDB.helper end
        Print("Next-spell helper " .. (MageCoachDB.helper and "on" or "off"))
    elseif cmd == "lock" or cmd == "unlock" then
        MageCoachDB.helperLocked = (cmd == "lock")
        Print("Helper " .. (MageCoachDB.helperLocked and "locked - it shows when you target an enemy" or "unlocked - it's on screen now, drag it where you want, then /mc lock"))
    elseif cmd == "aoe" then
        local n = tonumber(rest)
        if n and n >= 2 then
            MageCoachDB.aoeThreshold = math.floor(n)
            Print("AoE suggested at " .. MageCoachDB.aoeThreshold .. "+ enemies on you")
        else
            Print("Usage: /mc aoe 3")
        end
    elseif cmd == "power" then
        rest = (rest or ""):lower()
        if rest == "on" or rest == "off" then
            MageCoachDB.power = (rest == "on")
            Print("Mage power " .. rest)
            if MC.UpdatePowerLabel then MC:UpdatePowerLabel() end
        elseif MC.PowerReport then
            MC:PowerReport()
        end
    elseif cmd == "dps" then
        if MC.DpsReport then MC:DpsReport() end
    elseif cmd == "debug" then
        Debug()
        if MC.HelperDebug then MC:HelperDebug() end
        if MC.MeterDebug then MC:MeterDebug() end
    else
        Help()
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LEVEL_UP")
ev:RegisterEvent("CHARACTER_POINTS_CHANGED")
ev:RegisterEvent("TRAINER_SHOW")
ev:RegisterEvent("TRAINER_CLOSED")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            MageCoachDB = MageCoachDB or {}
            MageCoachCharDB = MageCoachCharDB or {}
            if MageCoachDB.autoShow == nil then MageCoachDB.autoShow = true end
            if MageCoachDB.pins == nil then MageCoachDB.pins = true end
            MageCoachDB.customPins = MageCoachDB.customPins or {}
            MC.tab = MageCoachDB.tab or 1
        end
        MC:TryHookTalentFrames()
    elseif event == "PLAYER_LOGIN" then
        MC:TryHookTalentFrames()
        MC:CreateMinimapButton()
        if MC.InitMap then MC:InitMap() end
        if MC.InitRotation then MC:InitRotation() end
        if MC.InitPower then MC:InitPower() end
        if MC:IsMage() then
            Print("loaded. /mc to open, /mc help for commands. Path: " .. C(MC:Path().color, MC:Path().name))
        end
    elseif event == "PLAYER_LEVEL_UP" then
        -- UnitLevel can lag behind this event, so preview the new level for the message.
        MC:AnnounceLevel(tonumber(arg1) or MC:Level())
        C_Timer.After(1, function()
            MC:Refresh()
            if MC.RefreshMap then MC:RefreshMap() end
        end)
    elseif event == "CHARACTER_POINTS_CHANGED" then
        MC:Refresh()
    elseif event == "TRAINER_SHOW" then
        local _, class = UnitClass("player")
        -- Only pop up at mage trainers: IsTradeskillTrainer exists on Classic clients.
        local isTrade = type(IsTradeskillTrainer) == "function" and IsTradeskillTrainer()
        if class == "MAGE" and not isTrade and MageCoachDB.autoShow then
            -- The trainer window is load-on-demand; give it a moment to appear before anchoring.
            C_Timer.After(0.2, function()
                MC.openedForTrainer = true
                MC:ShowBeside(_G.ClassTrainerFrame, 2)
            end)
        end
    elseif event == "TRAINER_CLOSED" then
        if MC.openedForTrainer and frame then
            MC.openedForTrainer = nil
            frame:Hide()
            MC.anchoredTo = nil
            MC:RestorePosition()
        end
    end
end)
