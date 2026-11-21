-- Live DPS for the current fight: your damage (plus your Water Elemental's) since combat started.
-- Resets on every new fight; after combat the last fight's number stays, greyed, until the next pull.
local _, MC = ...

local format = string.format
local damage, started, ended, inFight = 0, nil, nil, false
local playerGUID, petGUID
-- counters for /mc debug: did we get events, were they ours, were the numbers hidden?
local seen = { events = 0, mine = 0, secretSrc = 0, secretAmount = 0, counted = 0, lastSub = nil }

local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end

local function OnCombatLog()
    local _, sub, _, srcGUID, _, _, _, _, _, _, _, a12, _, _, a15 = CombatLogGetCurrentEventInfo()
    seen.events = seen.events + 1
    if Secret(srcGUID) then seen.secretSrc = seen.secretSrc + 1 return end
    if srcGUID == playerGUID then seen.mine = seen.mine + 1 seen.lastSub = sub end
    if srcGUID ~= playerGUID and (not petGUID or srcGUID ~= petGUID) then return end
    local amount
    if sub == "SWING_DAMAGE" then amount = a12
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE"
        or sub == "DAMAGE_SHIELD" then amount = a15 end
    if amount ~= nil and Secret(amount) then seen.secretAmount = seen.secretAmount + 1 return end
    if type(amount) == "number" then
        seen.counted = seen.counted + 1
        if not inFight then -- damage before the combat flag (e.g. Pyroblast opener)
            inFight, started, damage = true, GetTime(), 0
        end
        damage = damage + amount
    end
end

function MC:FightDps()
    if not started then return end
    local elapsed = ((inFight and GetTime()) or ended or GetTime()) - started
    return damage / math.max(elapsed, 1), inFight
end

------------------------------------------------------------------------
-- Blizzard's built-in damage meter (used when the combat log is blocked).
-- Its numbers may be "secret" in combat: we can show them but not do maths on them,
-- so we hand them straight to the font string.
------------------------------------------------------------------------
local DM = C_DamageMeter
local function EnumVal(enumName, keys, default)
    local e = Enum and Enum[enumName]
    if e then for _, k in ipairs(keys) do if e[k] ~= nil then return e[k] end end end
    return default
end
local function CurrentSession()
    if not (DM and DM.GetCombatSessionFromType) then return nil, "no GetCombatSessionFromType" end
    local cur = EnumVal("DamageMeterSessionType", { "Current" }, 1)
    local dmg = EnumVal("DamageMeterType", { "DamageDone" }, 0)
    local ok, session = pcall(DM.GetCombatSessionFromType, cur, dmg)
    if not ok then return nil, session end
    return session
end
local function SourcesOf(session)
    return type(session) == "table" and (session.combatSources or session.sources or session.combatants)
end
-- Find your own row: isLocalPlayer flag, else your GUID or name, else the only row when solo.
local function MyRow(sources)
    if type(sources) ~= "table" then return end
    local myName = UnitName("player")
    for _, src in ipairs(sources) do
        local ok, mine = pcall(function()
            if src.isLocalPlayer then return true end
            if src.sourceGUID and src.sourceGUID == playerGUID then return true end
            if src.name and src.name == myName then return true end
        end)
        if ok and mine then return src end
    end
    if #sources == 1 and not IsInGroup() then return sources[1] end
end
-- Returns (value, isPerSecond) from the damage meter, value possibly secret.
local function MeterDps()
    local session = CurrentSession()
    local row = MyRow(SourcesOf(session))
    if not row then return end
    if row.amountPerSecond ~= nil then return row.amountPerSecond end
    local total = row.totalAmount or row.amount
    if total == nil then return end
    local dur = session.durationSeconds
    if dur == nil and DM.GetSessionDurationSeconds then
        local ok, d = pcall(DM.GetSessionDurationSeconds, EnumVal("DamageMeterSessionType", { "Current" }, 1))
        if ok then dur = d end
    end
    if dur ~= nil and not Secret(total) and not Secret(dur) then return total / math.max(dur, 1) end
end

local function UpdateText()
    local fs = MC.fightText
    if not fs then return end
    if MageCoachDB.power == false or not MC:IsMage() then fs:Hide() return end
    local live = UnitAffectingCombat("player") and true or false
    local label = live and "|cffffd100Fight|r %.1f" or "|cff808080Last fight %.1f|r"
    local dps = (seen.counted > 0) and MC:FightDps() or nil
    if dps == nil and DM then
        local ok, v = pcall(MeterDps)
        if ok then dps = v else MC.meterErr = v end
    end
    if dps == nil then fs:Hide() return end
    -- SetFormattedText is done by the game itself, so it accepts hidden (secret) numbers
    local ok = pcall(fs.SetFormattedText, fs, label, dps)
    if not ok then ok = pcall(fs.SetText, fs, (live and "Fight " or "Last fight ") .. dps) end
    fs:SetShown(ok)
end

function MC:MeterDebug()
    self.Print("fight meter: combat log " .. (self.meterOK and "|cff40ff40readable|r" or "|cffff6060blocked|r")
        .. (self.meterErr and (" (" .. tostring(self.meterErr) .. ")") or ""))
    self.Print(format("  events %d, yours %d (last: %s), hidden source %d, hidden amounts %d, hits counted %d",
        seen.events, seen.mine, tostring(seen.lastSub), seen.secretSrc, seen.secretAmount, seen.counted))
    local dm = {}
    for _, n in ipairs({ "C_DamageMeter", "C_CombatLog", "DamageMeter" }) do
        if _G[n] then dm[#dm + 1] = n end
    end
    self.Print("  other damage APIs: " .. (#dm > 0 and table.concat(dm, ", ") or "none"))
    if DM then
        local ok, avail, why = pcall(DM.IsDamageMeterAvailable)
        self.Print("  damage meter available: " .. tostring(ok and avail) .. (why and (" (" .. tostring(why) .. ")") or ""))
        local session, err = CurrentSession()
        if type(session) ~= "table" then
            self.Print("  current session: " .. tostring(session) .. (err and (" - " .. tostring(err)) or ""))
        else
            local keys = {}
            for k in pairs(session) do keys[#keys + 1] = k end
            table.sort(keys)
            self.Print("  session fields: " .. table.concat(keys, ", "))
            local sources = SourcesOf(session)
            local first = type(sources) == "table" and sources[1]
            if type(first) == "table" then
                local f = {}
                for k, v in pairs(first) do f[#f + 1] = k .. (Secret(v) and "(hidden)" or "") end
                table.sort(f)
                self.Print("  row fields (" .. #sources .. " rows): " .. table.concat(f, ", "))
            end
            self.Print("  your row found: " .. tostring(MyRow(sources) ~= nil))
        end
    end
end

function MC:InitMeter()
    if self.meterInit then return end
    self.meterInit = true
    playerGUID = UnitGUID("player")
    if self.unitPowerText and PlayerFrame then
        local fs = PlayerFrame:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
        fs:SetPoint("LEFT", self.unitPowerText, "RIGHT", 8, 0)
        fs:Hide()
        self.fightText = fs
    end
    local f = CreateFrame("Frame")
    if type(CombatLogGetCurrentEventInfo) == "function" then
        local ok, err = pcall(f.RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")
        self.meterOK, self.meterErr = ok, (not ok) and err or nil
    else
        self.meterOK, self.meterErr = false, "no CombatLogGetCurrentEventInfo"
    end
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterUnitEvent("UNIT_PET", "player")
    f:SetScript("OnEvent", function(_, event)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            local ok, err = pcall(OnCombatLog)
            if not ok then MC.meterErr = err end
        elseif event == "PLAYER_REGEN_DISABLED" then
            if not inFight then inFight, started, damage = true, GetTime(), 0 end
            UpdateText()
        elseif event == "PLAYER_REGEN_ENABLED" then
            inFight, ended = false, GetTime()
            UpdateText()
            C_Timer.After(1, UpdateText) -- the damage meter may settle a moment after combat
        elseif event == "UNIT_PET" then
            petGUID = UnitGUID("pet")
        end
    end)
    petGUID = UnitGUID("pet")
    C_Timer.NewTicker(0.5, function() if inFight or UnitAffectingCombat("player") then UpdateText() end end)
end
