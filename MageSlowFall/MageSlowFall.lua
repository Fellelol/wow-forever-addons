-- MageSlowFall: the Jump key jumps on the ground; while you're falling out of combat it is
-- temporarily bound to a secure button that casts Slow Fall on you. Bindings only change
-- out of combat and only when the jump key isn't held (changing a held key's binding
-- misbehaves on WoW Forever).
local SLOW_FALL_ID = 130

local _, class = UnitClass("player")
if class ~= "MAGE" then return end

------------------------------------------------------------------------
-- Safe API helpers (same style as MageCoach: prefer C_ APIs, pcall, skip hidden values)
------------------------------------------------------------------------
local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b = pcall(fn, ...)
    if ok and not Secret(a) then return a, b end
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local n = Call(C_Spell.GetSpellName, id)
        if n then return n end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = Call(C_Spell.GetSpellInfo, id)
        if type(info) == "table" and info.name then return info.name end
    end
    return (Call(GetSpellInfo, id))
end

local function Known()
    if type(IsPlayerSpell) == "function" then return Call(IsPlayerSpell, SLOW_FALL_ID) and true or false end
    if type(IsSpellKnown) == "function" then return Call(IsSpellKnown, SLOW_FALL_ID) and true or false end
    return SpellName(SLOW_FALL_ID) ~= nil
end

-- Castable right now: covers mana and the Light Feather reagent.
local function Usable()
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, usable = pcall(C_Spell.IsSpellUsable, SLOW_FALL_ID)
        if ok and not Secret(usable) then return usable and true or false end
    end
    if type(IsUsableSpell) == "function" then
        local ok, usable = pcall(IsUsableSpell, SLOW_FALL_ID)
        if ok and not Secret(usable) then return usable and true or false end
    end
    return true
end

local function HasSlowFall()
    if C_UnitAuras then
        if C_UnitAuras.GetPlayerAuraBySpellID then
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, SLOW_FALL_ID)
            if ok and aura ~= nil then return true end
        end
        local name = SpellName(SLOW_FALL_ID)
        if name and C_UnitAuras.GetAuraDataBySpellName then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
            if ok and aura ~= nil then return true end
        end
        return false
    end
    local name = SpellName(SLOW_FALL_ID)
    if name and AuraUtil and AuraUtil.FindAuraByName then
        return Call(AuraUtil.FindAuraByName, name, "player", "HELPFUL") ~= nil
    end
    return false
end

local function Is(fn, ...) return Call(fn, ...) and true or false end

------------------------------------------------------------------------
-- Secure button + binding swap
------------------------------------------------------------------------
local btn = CreateFrame("Button", "MageSlowFallButton", UIParent, "SecureActionButtonTemplate")
btn:SetAttribute("type", "spell")
btn:SetAttribute("unit", "player")
-- Down + Up: the secure template acts on whichever one ActionButtonUseKeyDown says
btn:RegisterForClicks("AnyDown", "AnyUp")

local spellSet = false
local function SetupSpell()
    if InCombatLockdown() then return end
    btn:SetAttribute("spell", SpellName(SLOW_FALL_ID) or SLOW_FALL_ID)
    spellSet = true
end

local driver = CreateFrame("Frame")
local active = false

local function JumpKeys() return GetBindingKey("JUMP") end

local function KeysReleased()
    local a, b = JumpKeys()
    if a and Is(IsKeyDown, a) then return false end
    if b and Is(IsKeyDown, b) then return false end
    return true
end

local function Restore()
    if active and not InCombatLockdown() then
        ClearOverrideBindings(driver)
        active = false
    end
end

local function Arm()
    if active or InCombatLockdown() then return end
    local a, b = JumpKeys()
    if not a and not b then return end
    if a then SetOverrideBindingClick(driver, true, a, "MageSlowFallButton", "LeftButton") end
    if b then SetOverrideBindingClick(driver, true, b, "MageSlowFallButton", "LeftButton") end
    active = true
end

-- Situations where Space must stay a plain jump.
local function Blocked()
    return Is(UnitIsDeadOrGhost, "player") or Is(IsFlying) or Is(IsSwimming) or Is(IsMounted)
        or Is(UnitOnTaxi, "player")
end

local function ShouldArm()
    if not MageSlowFallDB.enabled or not spellSet then return false end
    if InCombatLockdown() or not Is(IsFalling) or Blocked() then return false end
    if not Known() or not Usable() or HasSlowFall() then return false end
    return KeysReleased()
end

local elapsed = 0
driver:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.03 then return end
    elapsed = 0
    if not MageSlowFallDB or InCombatLockdown() then return end
    if not active then
        if ShouldArm() then Arm() end
    elseif not Is(IsFalling) or HasSlowFall() or Blocked() or not MageSlowFallDB.enabled then
        -- switch back once the key is let go, so a held key never changes binding
        if KeysReleased() then Restore() end
    end
end)

driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("SPELLS_CHANGED")
driver:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        MageSlowFallDB = MageSlowFallDB or {}
        if MageSlowFallDB.enabled == nil then MageSlowFallDB.enabled = true end
        SetupSpell()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- last moment bindings may change before combat lockdown
        if active then ClearOverrideBindings(driver); active = false end
    elseif (event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED") and not InCombatLockdown() then
        SetupSpell()
    end
end)

SLASH_MAGESLOWFALL1 = "/sf"
SlashCmdList.MAGESLOWFALL = function(msg)
    MageSlowFallDB = MageSlowFallDB or { enabled = true }
    msg = (msg or ""):lower():gsub("%s", "")
    if msg == "on" then MageSlowFallDB.enabled = true
    elseif msg == "off" then MageSlowFallDB.enabled = false
    else MageSlowFallDB.enabled = not MageSlowFallDB.enabled end
    if not MageSlowFallDB.enabled then Restore() end
    print("|cff69ccf0MageSlowFall|r: " .. (MageSlowFallDB.enabled and "on" or "off")
        .. (Known() and "" or " (you don't know Slow Fall yet)"))
end
