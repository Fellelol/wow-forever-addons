-- "Mage power": one number for how good your gear is for leveling on your chosen path,
-- plus a tooltip line on any item showing what equipping it would do to that number.
-- Stats are read from the item's tooltip text (English client), so it also covers
-- "Equip:" lines such as spell damage, spell crit and mana per 5.
local _, MC = ...

local format, floor, abs = string.format, math.floor, math.abs

------------------------------------------------------------------------
-- Weights (points of power per stat point). Spell damage = 1.0 is the yardstick.
------------------------------------------------------------------------
local BASE = {
    spelldmg = 1.0,    -- "+X damage and healing done by magical spells"
    int      = 0.45,
    spi      = 0.35,   -- regen between pulls matters while leveling
    sta      = 0.35,
    crit     = 9,      -- per 1% spell crit
    hit      = 8,      -- per 1% spell hit
    mp5      = 1.2,
    wanddps  = 1.5,    -- wands are a big part of leveling a mage
    armor    = 0.01,
    -- rating-style stats, in case this client uses them
    critrating = 0.5, hasterating = 0.5, masteryrating = 0.3, versrating = 0.4, sprating = 1.0,
}
-- Path tweaks: school damage counts fully for your main school, a bit for the rest.
local PATH = {
    arcane   = { school = { Arcane = 1.0, Fire = 0.4, Frost = 0.3 } },
    frost    = { school = { Frost = 1.0, Fire = 0.3, Arcane = 0.3 } },
    fire     = { school = { Fire = 1.0, Arcane = 0.3, Frost = 0.3 } },
    frostaoe = { school = { Frost = 1.0, Arcane = 0.4, Fire = 0.2 }, sta = 0.5, int = 0.5 },
}
MC.PowerWeights = { base = BASE, path = PATH }

local function Weight(stat, pathKey)
    local p = PATH[pathKey] or PATH.arcane
    return p[stat] or BASE[stat] or 0
end

------------------------------------------------------------------------
-- Reading stats from tooltip lines
------------------------------------------------------------------------
local PRIMARY = {
    intellect = "int", spirit = "spi", stamina = "sta",
    ["spell power"] = "sprating", ["spell damage"] = "spelldmg", ["spell damage and healing"] = "spelldmg",
    ["critical strike"] = "critrating", ["critical strike rating"] = "critrating",
    haste = "hasterating", ["haste rating"] = "hasterating",
    mastery = "masteryrating", versatility = "versrating",
    ["mana every 5 sec"] = "mp5", ["mana per 5 sec"] = "mp5",
    ["mana regen"] = "mp5",
}

-- Returns (statKey, amount, school) for one tooltip line, or nil.
local function ParseLine(text)
    if type(text) ~= "string" or text == "" then return end
    if text:find("^%(%d%) Set:") then return end -- set bonuses: ignore (can't tell if active)
    local t = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^Equip: ", ""):gsub("^Use: .*", "")
    if t == "" then return end
    local n
    n = t:match("damage and healing done by magical spells and effects by up to (%d+)")
    if n then return "spelldmg", tonumber(n) end
    local school
    school, n = t:match("damage done by (%a+) spells and effects by up to (%d+)")
    if n then return "school", tonumber(n), school end
    n = t:match("critical strike with spells by (%d+)%%")
    if n then return "crit", tonumber(n) end
    n = t:match("chance to hit with spells by (%d+)%%")
    if n then return "hit", tonumber(n) end
    n = t:match("[Rr]estores (%d+) mana per 5 sec") or t:match("(%d+) mana per 5 sec")
    if n then return "mp5", tonumber(n) end
    n = t:match("[Ii]ncreases spell power by (%d+)")
    if n then return "sprating", tonumber(n) end
    n = t:match("%(([%d%.]+) damage per second%)")
    if n then return "dps", tonumber(n) end
    n = t:match("^(%d+) Armor$")
    if n then return "armor", tonumber(n) end
    -- "+12 Intellect", "+7 Fire Spell Damage", "+15 Spell Damage"
    local amount, name = t:match("^%+(%d+) (.+)$")
    if amount then
        name = name:lower()
        local sch = name:match("^(%a+) spell damage$")
        if sch and sch ~= "spell" then
            return "school", tonumber(amount), sch:sub(1, 1):upper() .. sch:sub(2)
        end
        if PRIMARY[name] then return PRIMARY[name], tonumber(amount) end
    end
end
MC.ParsePowerLine = ParseLine

local scanTip
local function TooltipLines(link)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok and data and data.lines then
            for _, l in ipairs(data.lines) do
                if l.leftText then lines[#lines + 1] = l.leftText end
            end
            if #lines > 0 then return lines end
        end
    end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "MageCoachScanTip", nil, "GameTooltipTemplate")
        MC.scanTip = scanTip
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    pcall(scanTip.SetHyperlink, scanTip, link)
    for i = 1, scanTip:NumLines() do
        local fs = _G["MageCoachScanTipTextLeft" .. i]
        local txt = fs and fs:GetText()
        if txt then lines[#lines + 1] = txt end
    end
    scanTip:Hide()
    return lines
end

local function ItemInfo(link)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then return end
    local ok, name, _, _, _, reqLevel, _, _, _, equipLoc, _, _, classID, subclassID = pcall(fn, link)
    if ok and name then
        return { name = name, reqLevel = reqLevel or 0, equipLoc = equipLoc or "", classID = classID, subclassID = subclassID }
    end
end

-- Mages can wear cloth (and misc: rings, necks, trinkets, off-hands) and use daggers,
-- one-handed swords, staves and wands.
local MAGE_WEAPONS = { [7] = true, [10] = true, [15] = true, [19] = true }
local function MageCanUse(info)
    if info.classID == 4 then return info.subclassID == 0 or info.subclassID == 1 end
    if info.classID == 2 then return MAGE_WEAPONS[info.subclassID] == true end
    return true
end

local cache = {}
-- Score one item for the given path. Returns score, stats table.
function MC:ItemPower(link, pathKey)
    if not link then return 0, {} end
    pathKey = pathKey or self:PathKey()
    local key = pathKey .. link
    if cache[key] then return cache[key].score, cache[key].stats end
    local info = ItemInfo(link)
    local stats, score = {}, 0
    for _, text in ipairs(TooltipLines(link)) do
        local stat, n, school = ParseLine(text)
        if stat == "dps" then
            -- only wands' DPS matters to a mage; melee weapon DPS is ignored
            if info and info.classID == 2 and info.subclassID == 19 then stat = "wanddps" else stat = nil end
        end
        if stat == "school" then
            local w = (PATH[pathKey] or PATH.arcane).school[school] or 0.2
            stats[school .. " dmg"] = (stats[school .. " dmg"] or 0) + n
            score = score + n * w
        elseif stat then
            stats[stat] = (stats[stat] or 0) + n
            score = score + n * Weight(stat, pathKey)
        end
    end
    if info then cache[key] = { score = score, stats = stats } end -- don't cache half-loaded items
    return score, stats
end

------------------------------------------------------------------------
-- Equipped gear
------------------------------------------------------------------------
local SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local SLOT_NAMES = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist", [7] = "Legs",
    [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1",
    [14] = "Trinket 2", [15] = "Back", [16] = "Main hand", [17] = "Off hand", [18] = "Wand" }
local LOC_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 },
}

local function SlotPower(slot, pathKey)
    local link = GetInventoryItemLink("player", slot)
    if not link then return 0, nil end
    return (MC:ItemPower(link, pathKey)), link
end

local function MainHandIs2H()
    local link = GetInventoryItemLink("player", 16)
    local info = link and ItemInfo(link)
    return info and info.equipLoc == "INVTYPE_2HWEAPON"
end

function MC:GearPower(pathKey)
    local total = 0
    for _, slot in ipairs(SLOTS) do total = total + (SlotPower(slot, pathKey)) end
    return total
end

-- What equipping `link` would do. Returns delta, newTotal, note (or nil if not equippable).
function MC:PowerChange(link)
    local info = ItemInfo(link)
    if not info then return end
    local slots = LOC_SLOTS[info.equipLoc]
    if not slots then return end
    local pathKey = self:PathKey()
    local new = self:ItemPower(link, pathKey)
    local total = self:GearPower(pathKey)

    for _, s in ipairs(slots) do
        if GetInventoryItemLink("player", s) == link then return 0, total, "equipped" end
    end

    local old, note, replaced = 0, nil, {}
    local function take(slot)
        local p, l = SlotPower(slot, pathKey)
        if l then replaced[#replaced + 1] = l end
        return p
    end
    if info.equipLoc == "INVTYPE_2HWEAPON" then
        old = take(16) + take(17)
        if GetInventoryItemLink("player", 17) then note = "replaces main + off hand" end
    elseif slots[1] == 17 and MainHandIs2H() then
        old = take(16)
        note = "you'd have to drop your 2-hander"
    elseif #slots == 2 then
        local a, b = SlotPower(slots[1], pathKey), SlotPower(slots[2], pathKey)
        local emptyA = not GetInventoryItemLink("player", slots[1])
        local emptyB = not GetInventoryItemLink("player", slots[2])
        if not (emptyA or emptyB) then old = take(a <= b and slots[1] or slots[2]) end
        note = "vs your weaker " .. (slots[1] == 11 and "ring" or "trinket")
    else
        old = take(slots[1])
    end
    local delta = new - old
    return delta, total + delta, note, replaced
end

------------------------------------------------------------------------
-- Tooltip line
------------------------------------------------------------------------
local function Num(v) return tostring(floor(v + 0.5)) end

function MC:AddPowerToTooltip(tt, link)
    local info = ItemInfo(link)
    if not info or not LOC_SLOTS[info.equipLoc] then return end
    if not MageCanUse(info) then
        tt:AddLine("|cff69ccf0Mage power|r |cffff6060- a mage can't use this|r")
        tt:Show()
        return
    end
    local delta, newTotal, note, replaced = self:PowerChange(link)
    if not delta then return end
    local own = self:ItemPower(link)
    local label = "|cff69ccf0Mage power|r " .. Num(own)
    if note == "equipped" then
        tt:AddLine(label .. "  |cffaaaaaa(equipped, total " .. Num(newTotal) .. ")|r")
    else
        local color = (delta > 0.5 and "ff40ff40") or (delta < -0.5 and "ffff6060") or "ffaaaaaa"
        local sign = delta > 0.5 and "+" or ""
        local line = label .. "  |c" .. color .. sign .. Num(delta) .. "|r  |cffaaaaaa(total " ..
            Num(newTotal - delta) .. " -> " .. Num(newTotal) .. ")|r"
        tt:AddLine(line)
        if self.DpsItemLine then
            local ok, l = pcall(self.DpsItemLine, self, link, replaced)
            if ok and l then tt:AddLine(l) elseif not ok then self.powerError = l end
        end
        if note then tt:AddLine("|cffaaaaaa  " .. note .. "|r") end
        if info.reqLevel and info.reqLevel > (UnitLevel("player") or 1) then
            tt:AddLine("|cffff6060  needs level " .. info.reqLevel .. "|r")
        end
    end
    tt:Show()
end

local function OnItemTooltip(tt)
    if tt == scanTip or not MageCoachDB or MageCoachDB.power == false or not MC:IsMage() then return end
    if not tt or not tt.GetItem then return end
    local ok, _, link = pcall(tt.GetItem, tt)
    if not ok or type(link) ~= "string" then return end
    local info = ItemInfo(link)
    local ok2, err
    if info and info.classID == 0 and MC.AddDpsToConsumable then -- potions, elixirs, food, scrolls
        ok2, err = pcall(MC.AddDpsToConsumable, MC, tt, link)
    else
        ok2, err = pcall(MC.AddPowerToTooltip, MC, tt, link)
    end
    if not ok2 then MC.powerError = err end
end

------------------------------------------------------------------------
-- Character frame label
------------------------------------------------------------------------
function MC:UpdatePowerLabel()
    local on = self:IsMage() and MageCoachDB.power ~= false
    local total = on and Num(self:GearPower()) or ""
    if self.powerLabel then
        if on then
            local path = self:Path()
            local dps = self.EstimateDps and self:EstimateDps()
            self.powerLabel:SetText("Mage power: |cffffffff" .. total .. "|r" ..
                (dps and dps.dps > 0 and ("  ~|cffffffff" .. format("%.1f", dps.dps) .. "|r DPS (" .. dps.spell .. ")") or "") ..
                "  |c" .. path.color .. path.name .. "|r")
        end
        self.powerLabel:SetShown(on)
    end
    if self.unitPowerText then
        local dps = on and self.EstimateDps and self:EstimateDps()
        self.unitPowerText:SetText("|cff69ccf0Power|r " .. total ..
            (dps and dps.dps > 0 and ("  |cff69ccf0DPS|r " .. format("%.1f", dps.dps)) or ""))
        self.unitPowerText:SetShown(on)
    end
end

-- Small "Power 143" text under the mana bar on your own unit frame.
local function CreateUnitFrameText()
    if MC.unitPowerText or not PlayerFrame then return end
    -- above the whole frame (portrait + bars), where buffs don't cover it
    local fs = PlayerFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    fs:SetPoint("BOTTOM", PlayerFrame, "TOP", 20, 2)
    MC.unitPowerText = fs
end

local function CreatePowerLabel()
    local parent = PaperDollFrame or CharacterFrame
    if MC.powerLabel or not parent then return end
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    -- sits just under the "Level N Race Mage" line
    if CharacterLevelText then
        fs:SetPoint("TOP", CharacterLevelText, "BOTTOM", 0, -2)
    else
        fs:SetPoint("TOP", CharacterFrame or parent, "TOP", 0, -52)
    end
    MC.powerLabel = fs
    parent:HookScript("OnShow", function() MC:UpdatePowerLabel() end)
end

function MC:PowerReport()
    local pathKey = self:PathKey()
    self.Print("Mage power " .. Num(self:GearPower(pathKey)) .. " for " .. self:Path().name .. ":")
    for _, slot in ipairs(SLOTS) do
        local p, link = SlotPower(slot, pathKey)
        if link then self.Print(format("  %s: %s  %s", SLOT_NAMES[slot], Num(p), link)) end
    end
    local w = {}
    for _, k in ipairs({ "spelldmg", "int", "spi", "sta", "crit", "hit", "mp5", "wanddps" }) do
        w[#w + 1] = k .. " " .. Weight(k, pathKey)
    end
    self.Print("weights: " .. table.concat(w, ", ") .. " (crit/hit per 1%)")
    if self.powerError then self.Print("last tooltip error: " .. tostring(self.powerError)) end
end

function MC:ClearPowerCache() cache = {} end
MC.PowerItemInfo = ItemInfo
MC.PowerTooltipLines = TooltipLines
MC.PowerSlots = SLOTS

------------------------------------------------------------------------
-- Other players: inspect your target and show their power under the target frame.
-- Uses your own path's weights, so it reads as "how good is this gear for a mage like me".
------------------------------------------------------------------------
local targetCache, pendingGUID, tries = {}, nil, 0

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if ok and not (type(issecretvalue) == "function" and issecretvalue(r)) then return r end
end

local function CreateTargetText()
    if MC.targetPowerText or not TargetFrame then return end
    -- above the whole target frame, where buffs/debuffs don't cover it
    local fs = TargetFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    fs:SetPoint("BOTTOM", TargetFrame, "TOP", -20, 2)
    fs:Hide()
    MC.targetPowerText = fs
end

-- Sum the target's gear; returns nil if some items aren't loaded yet.
local function ReadTargetGear(pathKey)
    local total = 0
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink("target", slot)
        if link then
            if not ItemInfo(link) then return nil end
            total = total + (MC:ItemPower(link, pathKey))
        end
    end
    return total
end

function MC:UpdateTargetPower()
    local fs = self.targetPowerText
    if not fs then return end
    pendingGUID = nil
    if MageCoachDB.power == false or not self:IsMage() or not UnitExists("target")
        or not UnitIsPlayer("target") or UnitIsUnit("target", "player") then
        fs:Hide()
        return
    end
    local guid = UnitGUID("target")
    local key = guid and (guid .. self:PathKey())
    if key and targetCache[key] then
        fs:SetText("|cff69ccf0Power|r " .. Num(targetCache[key]))
    elseif SafeCall(CanInspect, "target") and SafeCall(CheckInteractDistance, "target", 1)
        and not (InspectFrame and InspectFrame:IsShown()) then
        pendingGUID, tries = guid, 0
        fs:SetText("|cff69ccf0Power|r |cffaaaaaa...|r")
        NotifyInspect("target")
    else
        pendingGUID = guid -- keep trying while you walk closer
        fs:SetText("|cff69ccf0Power|r |cffaaaaaa? (get closer)|r")
    end
    fs:Show()
end

local function OnInspectReady(guid)
    if not guid or guid ~= UnitGUID("target") then return end
    local pathKey = MC:PathKey()
    local total = ReadTargetGear(pathKey)
    if not total then
        tries = tries + 1
        if tries <= 5 then C_Timer.After(0.5, function() OnInspectReady(guid) end) end
        return
    end
    targetCache[guid .. pathKey] = total
    pendingGUID = nil
    MC:UpdateTargetPower()
end

function MC:InitPower()
    if MageCoachDB.power == nil then MageCoachDB.power = true end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
    else
        for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
            if tt and tt.HookScript then pcall(tt.HookScript, tt, "OnTooltipSetItem", OnItemTooltip) end
        end
    end
    CreatePowerLabel()
    CreateUnitFrameText()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:RegisterUnitEvent("UNIT_AURA", "player")
    f:RegisterEvent("SPELLS_CHANGED")
    f:RegisterEvent("CHARACTER_POINTS_CHANGED")
    f:RegisterEvent("INSPECT_READY")
    f:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_TARGET_CHANGED" then
            MC:UpdateTargetPower()
        elseif event == "INSPECT_READY" then
            OnInspectReady(arg1)
        elseif event == "UNIT_AURA" or event == "SPELLS_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then
            -- buffs come and go often; refresh at most a few times a second
            if not MC.powerLabelQueued then
                MC.powerLabelQueued = true
                C_Timer.After(0.3, function() MC.powerLabelQueued = false MC:UpdatePowerLabel() end)
            end
        else
            MC:UpdatePowerLabel()
        end
    end)
    if MC.InitDps then MC:InitDps() end
    if MC.InitMeter then MC:InitMeter() end
    CreateTargetText()
    -- retry targets that were out of inspect range
    C_Timer.NewTicker(1, function()
        if pendingGUID and pendingGUID == UnitGUID("target") and MC.targetPowerText
            and MC.targetPowerText:GetText() and MC.targetPowerText:GetText():find("closer") then
            MC:UpdateTargetPower()
        end
    end)
    self:UpdatePowerLabel()
end
