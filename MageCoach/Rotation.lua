-- One-button macro + "next spell" helper.
-- Nothing here casts or moves for you: the macro is a normal player macro (one action per key press)
-- and the helper only shows an icon. Macros can't be edited in combat, so the macro handles
-- AoE with modifiers (Shift / Ctrl) and the helper tells you when to hold them.
local _, MC = ...

local MACRO_NAME = "MageCoach"
local format, tinsert, concat = string.format, table.insert, table.concat

------------------------------------------------------------------------
-- Spell / aura helpers (defensive: Forever's client may hide some values in combat)
------------------------------------------------------------------------
local function IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

function MC:Known(name)
    if not name then return false end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and info then return true end
    end
    if type(GetSpellInfo) == "function" then
        local ok, n = pcall(GetSpellInfo, name)
        if ok and n then return true end
    end
    return false
end

local function SpellIcon(name)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, name)
        if ok and tex then return tex end
    end
    if type(GetSpellTexture) == "function" then
        local ok, tex = pcall(GetSpellTexture, name)
        if ok and tex then return tex end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Ready = known, off cooldown (ignoring the global cooldown) and usable (mana etc).
local function Ready(name)
    if not MC:Known(name) then return false end
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(name)
        if info then start, duration = info.startTime, info.duration end
    elseif type(GetSpellCooldown) == "function" then
        start, duration = GetSpellCooldown(name)
    end
    if IsSecret(duration) then duration = 0 end
    if duration and duration > 1.6 and start and start > 0 then return false end
    local usable
    if C_Spell and C_Spell.IsSpellUsable then
        usable = C_Spell.IsSpellUsable(name)
    elseif type(IsUsableSpell) == "function" then
        usable = IsUsableSpell(name)
    else
        usable = true
    end
    if IsSecret(usable) then return true end
    return usable and true or false
end

-- Returns stack count (>=1) if the aura is on the unit, else nil.
local function Aura(unit, name, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, filter)
        if ok and a then
            local n = a.applications
            if IsSecret(n) or not n or n == 0 then n = 1 end
            return n
        end
        return nil
    end
    if AuraUtil and AuraUtil.FindAuraByName then
        local ok, found, _, count = pcall(AuraUtil.FindAuraByName, name, unit, filter)
        if ok and found then return (count and count > 0) and count or 1 end
    end
    return nil
end

local function Buff(name) return Aura("player", name, "HELPFUL") end
local function TargetFrozen()
    return Aura("target", "Frost Nova", "HARMFUL") or Aura("target", "Frostbite", "HARMFUL") or Aura("target", "Freeze", "HARMFUL")
end

local function ManaPct()
    local cur, maxp = UnitPower("player", 0), UnitPowerMax("player", 0)
    if IsSecret(cur) or IsSecret(maxp) or not maxp or maxp == 0 then return 100 end
    return cur / maxp * 100
end

------------------------------------------------------------------------
-- Enemy count: hostile nameplates that are targeting you.
-- Needs enemy nameplates switched on (default key: V).
------------------------------------------------------------------------
function MC:CountAttackers()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return 0, false end
    local n = 0
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            local ok, hit = pcall(function()
                if not UnitCanAttack("player", unit) or UnitIsDead(unit) then return false end
                if UnitIsUnit(unit .. "target", "player") then return true end
                local threat = UnitThreatSituation and UnitThreatSituation("player", unit)
                return (not IsSecret(threat)) and threat ~= nil
            end)
            if ok and hit then n = n + 1 end
        end
    end
    return n, true
end

------------------------------------------------------------------------
-- Priority lists per path. Each returns spellName, reason.
------------------------------------------------------------------------
local function AoE(mobs, ground)
    -- Shared AoE logic: Nova when crowded, ground AoE if safe, else Arcane Explosion.
    if mobs >= 2 and Ready("Frost Nova") then return "Frost Nova", "root the pack" end
    if Ready("Arcane Explosion") then return "Arcane Explosion", "hold Shift" end
    if ground and Ready(ground) then return ground, "hold Ctrl (at cursor)" end
end

local function TargetHealthPct()
    local cur, maxh = UnitHealth("target"), UnitHealthMax("target")
    if IsSecret(cur) or IsSecret(maxh) or not maxh or maxh == 0 then return 100 end
    return cur / maxh * 100
end

local function IsMoving()
    if type(GetUnitSpeed) == "function" then
        local ok, speed = pcall(GetUnitSpeed, "player")
        if ok and not IsSecret(speed) and speed and speed > 0 then return true end
    end
    return false
end

-- True when the target is within ~10 yards (it has reached you).
local function InMelee()
    if type(CheckInteractDistance) ~= "function" then return false end
    local ok, close = pcall(CheckInteractDistance, "target", 3)
    return ok and not IsSecret(close) and close and true or false
end

-- Situations every path handles the same way (from the guide's general leveling advice).
local function Situational()
    if InMelee() and not TargetFrozen() and Ready("Frost Nova") then
        return "Frost Nova", "it reached you: root it, step back"
    end
    if IsMoving() then
        if TargetFrozen() and Ready("Ice Lance") then return "Ice Lance", "moving: instant" end
        if Ready("Fire Blast") then return "Fire Blast", "moving: instant" end
        if Ready("Ice Lance") then return "Ice Lance", "moving: instant" end
    end
    local hp = TargetHealthPct()
    if hp <= 20 and Ready("Fire Blast") then return "Fire Blast", "finish it off" end
    if hp <= 35 and ManaPct() < 25 and Ready("Shoot") then return "Shoot", "low mana: wand it down" end
end

local PRIORITY = {}

PRIORITY.arcane = function(inCombat, mobs, aoe)
    if not inCombat then
        for _, s in ipairs({ "Arcane Wrath", "Arcane Blast", "Fireball" }) do
            if Ready(s) then return s, "precast" end
        end
    end
    if aoe then
        local s, why = AoE(mobs, "Flamestrike"); if s then return s, why end
    end
    if Buff("Missile Barrage") and Ready("Arcane Missiles") then return "Arcane Missiles", "Missile Barrage proc" end
    if ManaPct() < 8 then
        if Ready("Evocation") then return "Evocation", "out of mana" end
        if Ready("Shoot") then return "Shoot", "out of mana: wand" end
    end
    if Ready("Arcane Wrath") then return "Arcane Wrath", "if safe to cast" end
    if Ready("Arcane Blast") then return "Arcane Blast", "filler" end
    if Ready("Arcane Missiles") and MC:Level() >= 11 then return "Arcane Missiles", "filler" end
    if Ready("Fireball") then return "Fireball", "filler" end
    if Ready("Frostbolt") then return "Frostbolt", "filler" end
end

local function FrostST(inCombat)
    if not inCombat and Ready("Frostbolt") then return "Frostbolt", "precast" end
    if (Buff("Fingers of Frost") or TargetFrozen()) and Ready("Ice Lance") then return "Ice Lance", "frozen / Fingers of Frost" end
    if Buff("Missile Barrage") and Ready("Arcane Missiles") then return "Arcane Missiles", "Missile Barrage proc" end
    if ManaPct() < 8 then
        if Ready("Evocation") then return "Evocation", "out of mana" end
        if Ready("Shoot") then return "Shoot", "out of mana: wand" end
    end
    if Ready("Frostbolt") then return "Frostbolt", "filler" end
    if Ready("Fireball") then return "Fireball", "filler" end
end

PRIORITY.frost = function(inCombat, mobs, aoe)
    if Ready("Ice Barrier") and not Buff("Ice Barrier") then return "Ice Barrier", "keep it up" end
    if aoe then
        if Buff("Fingers of Frost") and Ready("Cone of Cold") then return "Cone of Cold", "Fingers of Frost" end
        local s, why = AoE(mobs, "Blizzard"); if s then return s, why end
    end
    local wc = Aura("target", "Winter's Chill", "HARMFUL")
    if wc and wc >= 5 and Ready("Cone of Cold") then return "Cone of Cold", "Winter's Chill stacked" end
    return FrostST(inCombat)
end

PRIORITY.frostaoe = function(inCombat, mobs, aoe)
    if Ready("Ice Barrier") and not Buff("Ice Barrier") then return "Ice Barrier", "keep it up" end
    if aoe then
        if TargetFrozen() and Ready("Cone of Cold") then return "Cone of Cold", "Shatter combo" end
        local s, why = AoE(mobs, "Blizzard"); if s then return s, why end
        if Ready("Cone of Cold") then return "Cone of Cold", "slow the pack" end
    end
    return FrostST(inCombat)
end

PRIORITY.fire = function(inCombat, mobs, aoe)
    if not inCombat then
        if Ready("Pyroblast") then return "Pyroblast", "precast" end
        if Ready("Fireball") then return "Fireball", "precast" end
    end
    if aoe then
        if Ready("Blast Wave") then return "Blast Wave", "AoE" end
        local s, why = AoE(mobs, "Flamestrike"); if s then return s, why end
    end
    local hu = Buff("Heating Up")
    if hu and hu >= 3 and Ready("Pyroblast") then return "Pyroblast", "Heating Up x3" end
    if Buff("Missile Barrage") and Ready("Arcane Missiles") then return "Arcane Missiles", "Missile Barrage proc" end
    if MC:Known("Heating Up") and Ready("Fire Blast") then return "Fire Blast", "build Heating Up" end
    if ManaPct() < 8 then
        if Ready("Evocation") then return "Evocation", "out of mana" end
        if Ready("Shoot") then return "Shoot", "out of mana: wand" end
    end
    if Ready("Fireball") then return "Fireball", "filler" end
end

local COOLDOWNS = {
    arcane = { "Arcane Power", "Presence of Mind" },
    frost = { "Cold Snap" },
    frostaoe = {},
    fire = { "Combustion" },
}

------------------------------------------------------------------------
-- Helper display
------------------------------------------------------------------------
local helper

local function CreateHelper()
    if helper then return helper end
    helper = CreateFrame("Frame", "MageCoachHelper", UIParent)
    helper:SetSize(52, 52)
    helper:SetMovable(true)
    helper:SetClampedToScreen(true)
    helper:RegisterForDrag("LeftButton")
    helper:SetScript("OnDragStart", function(s) if MageCoachDB.helperLocked == false then s:StartMoving() end end)
    helper:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local p, _, rp, x, y = s:GetPoint()
        MageCoachDB.helperPos = { p, rp, x, y }
    end)
    local pos = MageCoachDB.helperPos
    if pos then helper:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else helper:SetPoint("CENTER", UIParent, "CENTER", 0, -160) end

    helper.icon = helper:CreateTexture(nil, "ARTWORK")
    helper.icon:SetAllPoints()
    helper.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    helper.border = helper:CreateTexture(nil, "OVERLAY")
    helper.border:SetPoint("TOPLEFT", -3, 3)
    helper.border:SetPoint("BOTTOMRIGHT", 3, -3)
    helper.border:SetColorTexture(0.41, 0.80, 0.94, 0.5)
    helper.border:SetDrawLayer("BACKGROUND")

    helper.name = helper:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helper.name:SetPoint("TOP", helper, "BOTTOM", 0, -4)
    helper.why = helper:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helper.why:SetPoint("TOP", helper.name, "BOTTOM", 0, -1)

    helper.mobs = helper:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helper.mobs:SetPoint("BOTTOM", helper, "TOP", 0, 6)

    helper.cd = CreateFrame("Frame", nil, helper)
    helper.cd:SetSize(30, 30)
    helper.cd:SetPoint("LEFT", helper, "RIGHT", 8, 0)
    helper.cd.icon = helper.cd:CreateTexture(nil, "ARTWORK")
    helper.cd.icon:SetAllPoints()
    helper.cd.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    helper.cd.label = helper.cd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helper.cd.label:SetPoint("TOP", helper.cd, "BOTTOM", 0, -2)
    helper.cd.label:SetText("CD")

    helper:Hide()
    return helper
end

function MC:UpdateHelper()
    if not helper then return end
    local preview = MageCoachDB.helperLocked == false -- explicitly unlocked: always visible so it can be moved
    local hasTarget = UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
    local show = MageCoachDB.helper and self:IsMage() and (hasTarget or preview)
    if not show then
        helper:Hide()
        return
    end
    helper:EnableMouse(preview)

    local inCombat = UnitAffectingCombat("player")
    local mobs, canCount = self:CountAttackers()
    local threshold = MageCoachDB.aoeThreshold or 3
    if self:PathKey() == "frostaoe" then threshold = math.min(threshold, 2) end
    local aoe = mobs >= threshold

    local pathKey = self:PathKey()
    local ok, spell, why = pcall(function()
        if inCombat and not aoe then
            local s, w = Situational()
            if s then return s, w end
        end
        return PRIORITY[pathKey](inCombat, mobs, aoe)
    end)
    if not ok then
        self.helperError = tostring(spell)
        spell, why = nil, "restricted in combat"
    end

    if spell then
        helper.icon:SetTexture(SpellIcon(spell))
        helper.name:SetText(spell == "Shoot" and "Wand" or spell)
        helper.why:SetText(why or "")
    else
        helper.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        helper.name:SetText("")
        helper.why:SetText(why or "")
    end

    if preview and not hasTarget then
        helper.mobs:SetText("|cff69ccf0MageCoach helper - drag me, then /mc lock|r")
    elseif canCount and mobs >= 2 then
        local color = aoe and "|cffff8040" or "|cffffff00"
        local extra = ""
        if aoe then extra = " - AoE! (Shift)"
        elseif self:Known("Polymorph") then extra = " - Polymorph one" end
        helper.mobs:SetText(color .. mobs .. " on you" .. extra .. "|r")
    else
        helper.mobs:SetText("")
    end

    helper.cd:Hide()
    if inCombat then
        for _, cd in ipairs(COOLDOWNS[self:PathKey()] or {}) do
            local okR, ready = pcall(Ready, cd)
            if okR and ready then
                helper.cd.icon:SetTexture(SpellIcon(cd))
                helper.cd:Show()
                break
            end
        end
    end
    helper:Show()
end

------------------------------------------------------------------------
-- One-button macro
------------------------------------------------------------------------
local function KnownList(list)
    local out = {}
    for _, s in ipairs(list) do if MC:Known(s) then tinsert(out, s) end end
    return out
end

-- Single-target sequence for the path, based on what you know right now.
local function SingleTarget(pathKey)
    local K = function(s) return MC:Known(s) end
    if pathKey == "arcane" then
        if K("Arcane Wrath") and K("Arcane Blast") then return KnownList({ "Arcane Wrath", "Arcane Blast", "Arcane Blast", "Arcane Missiles" }) end
        if K("Arcane Blast") then return KnownList({ "Arcane Blast", "Arcane Blast", "Arcane Missiles" }) end
        if K("Arcane Missiles") and MC:Level() >= 11 then return KnownList({ "Fireball", "Arcane Missiles", "Arcane Missiles" }) end
        return KnownList({ "Fireball" })
    elseif pathKey == "fire" then
        if K("Pyroblast") then return KnownList({ "Pyroblast", "Fireball", "Fireball", "Fireball", "Fireball" }) end
        return KnownList({ "Fireball" })
    else -- frost, frostaoe
        if K("Frostbolt") then return { "Frostbolt" } end
        return KnownList({ "Fireball" })
    end
end

function MC:BuildMacroBody()
    local pathKey = self:PathKey()
    local ground = (pathKey == "frost" or pathKey == "frostaoe") and "Blizzard" or "Flamestrike"
    local lines = { "#showtooltip" }
    if self:Known(ground) then tinsert(lines, "/cast [mod:ctrl,@cursor] " .. ground) end
    if self:Known("Arcane Explosion") then tinsert(lines, "/cast [mod:shift] Arcane Explosion") end
    local st = SingleTarget(pathKey)
    local cond = (#lines > 1) and "[nomod] " or ""
    if #st == 1 then
        tinsert(lines, "/cast " .. cond .. st[1])
    elseif #st > 1 then
        tinsert(lines, "/castsequence " .. cond .. "reset=target/combat " .. concat(st, ", "))
    end
    local body = concat(lines, "\n")
    if #body > 255 then body = body:sub(1, 255) end
    return body, st, ground
end

-- Creates or updates the macro. Returns true on success.
function MC:UpdateMacro(quiet)
    if not self:IsMage() then return false end
    if InCombatLockdown() then
        self.macroPending = true
        if not quiet then MC.Print("In combat - I'll update the macro when combat ends.") end
        return false
    end
    if type(CreateMacro) ~= "function" or type(GetMacroIndexByName) ~= "function" then
        if not quiet then MC.Print("This client doesn't allow addons to create macros.") end
        return false
    end
    local body = self:BuildMacroBody()
    local idx = GetMacroIndexByName(MACRO_NAME)
    local ok, err
    if idx and idx > 0 then
        local oldBody = GetMacroBody and GetMacroBody(idx)
        if oldBody == body then self.macroPending = nil; return true end
        ok, err = pcall(EditMacro, idx, MACRO_NAME, "INV_Misc_QuestionMark", body)
        if ok and not quiet then MC.Print("Macro updated.") end
    else
        if not MageCoachDB.macroCreated and quiet then return false end -- only auto-create after /mc macro
        ok, err = pcall(CreateMacro, MACRO_NAME, "INV_Misc_QuestionMark", body, true)
        if ok and not quiet then MC.Print("Macro \"" .. MACRO_NAME .. "\" created (character-specific).") end
    end
    if not ok then
        if not quiet then MC.Print("Couldn't save the macro: " .. tostring(err) .. " (macro slots full?)") end
        return false
    end
    MageCoachDB.macroCreated = true
    self.macroPending = nil
    return true
end

function MC:MacroCommand()
    if not self:UpdateMacro(false) then return end
    local body = self:BuildMacroBody()
    MC.Print("Drag it to your action bar (it's on your cursor now, or find it under /macro).")
    MC.Print("|cffffd100Press|r = single target   |cffffd100Shift|r = Arcane Explosion   |cffffd100Ctrl|r = ground AoE at your cursor")
    for line in body:gmatch("[^\n]+") do MC.Print("|cff808080" .. line .. "|r") end
    local idx = GetMacroIndexByName(MACRO_NAME)
    if idx and idx > 0 and type(PickupMacro) == "function" and not GetCursorInfo() then
        pcall(PickupMacro, idx)
    end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
function MC:InitRotation()
    if MageCoachDB.helper == nil then MageCoachDB.helper = true end
    MageCoachDB.aoeThreshold = MageCoachDB.aoeThreshold or 3
    if not self:IsMage() then return end
    CreateHelper()

    local elapsed = 0
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.15 then return end
        elapsed = 0
        MC:UpdateHelper()
    end)

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("SPELLS_CHANGED")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    local pending
    ev:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if MC.macroPending then MC:UpdateMacro(true) end
            return
        end
        -- SPELLS_CHANGED fires in bursts; debounce.
        if pending then return end
        pending = true
        C_Timer.After(2, function()
            pending = nil
            MC:UpdateMacro(true)
        end)
    end)
end

function MC:HelperDebug()
    local hasSecret = type(issecretvalue) == "function"
    MC.Print("secret-value API " .. (hasSecret and "|cffffff00present (some combat info may be hidden)|r" or "|cff40ff40absent|r"))
    MC.Print("C_AssistedCombat (Blizzard's own rotation helper) " .. ((C_AssistedCombat and "|cff40ff40present|r") or "|cff808080absent|r"))
    MC.Print("CreateMacro " .. (type(CreateMacro) == "function" and "|cff40ff40yes|r" or "|cffff6060no|r") ..
        "  nameplates API " .. ((C_NamePlate and C_NamePlate.GetNamePlates) and "|cff40ff40yes|r" or "|cffff6060no|r"))
    local n = self:CountAttackers()
    MC.Print("enemies targeting you right now: " .. n .. " (enemy nameplates must be on - key V)")
    if self.helperError then MC.Print("last helper error: " .. self.helperError) end
end
