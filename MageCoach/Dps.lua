-- Rough sustained DPS estimate: your path's main filler spell (Frostbolt / Fireball / Arcane Missiles)
-- cast back to back, using your spell damage, crit, hit, talents and active buffs.
-- It ignores mana, movement and procs, so it's for comparing gear and buffs, not a combat log.
local _, MC = ...

local format, floor, min, max, abs = string.format, math.floor, math.min, math.max, math.abs

local SCHOOL_INDEX = { Fire = 3, Frost = 5, Arcane = 7 }

-- Classic base values per rank: min, max, cast/channel seconds, level learned, dot, missiles
local SPELLS = {
    Frostbolt = { school = "Frost", coefMul = 0.95, ranks = {
        { 18, 20, 1.5, 4 }, { 31, 35, 1.8, 8 }, { 51, 57, 2.2, 14 }, { 74, 82, 2.6, 20 }, { 126, 138, 3.0, 26 },
        { 174, 190, 3.0, 32 }, { 227, 245, 3.0, 38 }, { 292, 316, 3.0, 44 }, { 353, 383, 3.0, 50 },
        { 429, 463, 3.0, 56 }, { 515, 555, 3.0, 60 } } },
    Fireball = { school = "Fire", coefMul = 1.0, ranks = {
        { 14, 22, 1.5, 1, 2 }, { 31, 45, 2.0, 6, 3 }, { 53, 73, 2.5, 12, 6 }, { 84, 116, 3.0, 18, 12 },
        { 139, 187, 3.5, 24, 20 }, { 199, 265, 3.5, 30, 28 }, { 255, 329, 3.5, 36, 32 }, { 318, 406, 3.5, 42, 40 },
        { 392, 500, 3.5, 48, 52 }, { 475, 605, 3.5, 54, 60 }, { 561, 715, 3.5, 60, 72 } } },
    ["Arcane Missiles"] = { school = "Arcane", coefMul = 1.0, channel = true, ranks = {
        { 24, 24, 3, 8, 0, 3 }, { 36, 36, 4, 16, 0, 4 }, { 56, 56, 5, 24, 0, 5 }, { 83, 83, 5, 32, 0, 5 },
        { 115, 115, 5, 40, 0, 5 }, { 151, 151, 5, 48, 0, 5 }, { 192, 192, 5, 56, 0, 5 }, { 230, 230, 5, 60, 0, 5 } } },
}
local FILLER = { frost = { "Frostbolt" }, frostaoe = { "Frostbolt" }, fire = { "Fireball" },
    arcane = { "Arcane Missiles", "Fireball" } }

-- Known % damage buffs (flat spell damage / crit buffs are already in the game's own numbers).
local DAMAGE_BUFFS = { ["Arcane Power"] = 1.3, ["Power Infusion"] = 1.2 }

------------------------------------------------------------------------
-- Small safe wrappers
------------------------------------------------------------------------
local function Secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g = pcall(fn, ...)
    if ok and not Secret(a) then return a, b, c, d, e, f, g end
end

local function SpellData(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = Call(C_Spell.GetSpellInfo, name)
        if info then return info.spellID, (info.castTime or 0) / 1000 end
    end
    local n, _, _, castTime, _, _, id = Call(GetSpellInfo, name)
    if n then return id, (castTime or 0) / 1000 end
end

local function SpellRank(id)
    local sub = (C_Spell and Call(C_Spell.GetSpellSubtext, id)) or Call(GetSpellSubtext, id)
    return sub and tonumber(sub:match("(%d+)"))
end

local function SpellDescription(id)
    return (C_Spell and Call(C_Spell.GetSpellDescription, id)) or Call(GetSpellDescription, id)
end

local function HasBuff(name)
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        return Call(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL") ~= nil
    end
    if AuraUtil and AuraUtil.FindAuraByName then
        return Call(AuraUtil.FindAuraByName, name, "player", "HELPFUL") ~= nil
    end
    return false
end

-- Spell damage / hit / crit from your equipped items (fallback when the game doesn't report them).
local function GearStats()
    local t = {}
    for _, slot in ipairs(MC.PowerSlots or {}) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local _, stats = MC:ItemPower(link)
            for k, v in pairs(stats) do t[k] = (t[k] or 0) + v end
        end
    end
    return t
end

local function IntPerCrit()
    return 59.5 * max(MC:Level(), 10) / 60 -- ~59.5 Intellect per 1% crit at 60, less at low level
end

------------------------------------------------------------------------
-- The estimate
------------------------------------------------------------------------
local function PickSpell()
    for _, name in ipairs(FILLER[MC:PathKey()] or FILLER.arcane) do
        if MC:Known(name) then return name end
    end
end

-- mods (optional): { sp = n, crit = %, hit = %, int = n, mult = x } added on top of your current state.
function MC:EstimateDps(mods)
    mods = mods or {}
    local name = PickSpell()
    if not name then return { dps = 0, spell = "none" } end
    local def = SPELLS[name]
    local school = def.school
    local idx = SCHOOL_INDEX[school]
    local id, castTime = SpellData(name)
    local level = self:Level()

    -- rank row: the game's rank text, else the best rank for your level
    local rank = id and SpellRank(id)
    if not rank or not def.ranks[rank] then
        rank = 1
        for i, r in ipairs(def.ranks) do if r[4] <= level then rank = i end end
    end
    local row = def.ranks[rank]
    local missiles = row[6] or 1
    local baseAvg = (row[1] + row[2]) / 2 * missiles + (row[5] or 0)
    local baseCast = row[3]

    -- spell damage
    local gear
    local sp = idx and Call(GetSpellBonusDamage, idx)
    if type(sp) ~= "number" then
        gear = gear or GearStats()
        sp = (gear.spelldmg or 0) + (gear.sprating or 0) + (gear[school .. " dmg"] or 0)
    end
    sp = max(0, sp + (mods.sp or 0))

    -- coefficient: cast time / 3.5, with the classic penalty for spells learned before level 20
    local coef = min(baseCast, 3.5) / 3.5 * def.coefMul
    if row[4] < 20 then coef = coef * (1 - (20 - row[4]) * 0.0375) end

    -- use the in-game description when it parses (catches tuned values on this server)
    local desc = id and SpellDescription(id)
    if desc then
        local lo, hi = desc:match("(%d+) to (%d+)")
        local each = desc:match("(%d+) Arcane damage")
        local avg
        if def.channel and each then avg = tonumber(each) * missiles
        elseif lo then avg = (tonumber(lo) + tonumber(hi)) / 2 + (row[5] or 0) end
        if avg then
            -- some clients bake spell damage into the tooltip numbers; don't count it twice
            local extra = avg - baseAvg
            if sp > 5 and extra > 2 and abs(extra - coef * sp) <= 0.3 * coef * sp + 2 then
                avg = baseAvg
            end
            baseAvg = avg
        end
    end

    local talents = self:ReadTalentRanks() or {}
    local tr = function(n) return talents[n] or 0 end

    -- crit
    local crit = idx and Call(GetSpellCritChance, idx)
    if type(crit) ~= "number" then
        gear = gear or GearStats()
        local int = Call(UnitStat, "player", 4) or 0
        crit = 1 + (gear.crit or 0) + (type(int) == "number" and int / IntPerCrit() or 0) + tr("Arcane Instability")
            + (school == "Fire" and 2 * tr("Critical Mass") or 0)
    end
    crit = crit + (mods.crit or 0) + (mods.int or 0) / IntPerCrit()
    crit = min(max(crit, 0), 100)
    local critMult = 1.5
    if school == "Frost" then critMult = 1 + 0.5 * (1 + 0.2 * tr("Ice Shards")) end
    if school == "Fire" then critMult = critMult * (1 + 0.08 * tr("Ignite")) end

    -- hit (vs a mob your level)
    gear = gear or GearStats()
    local hit = 96 + (gear.hit or 0) + (mods.hit or 0)
    if school ~= "Arcane" then hit = hit + 2 * tr("Elemental Precision") else hit = hit + 2 * tr("Arcane Focus") end
    hit = min(hit, 99)

    -- damage multipliers: talents + buffs
    local mult = 1 + 0.01 * tr("Arcane Instability")
    if school == "Fire" then mult = mult * (1 + 0.02 * tr("Fire Power")) end
    if school == "Frost" then mult = mult * (1 + 0.02 * tr("Piercing Ice")) end
    for buff, m in pairs(DAMAGE_BUFFS) do if HasBuff(buff) then mult = mult * m end end
    mult = mult * (mods.mult or 1)

    -- cast time from the game (includes Improved Frostbolt/Fireball and haste); channels use the row
    local cast = (not def.channel and castTime and castTime > 0) and castTime or baseCast
    cast = max(cast, 1.5)

    local hitDmg = baseAvg + coef * sp
    local avgDmg = hitDmg * (hit / 100) * (1 + crit / 100 * (critMult - 1)) * mult
    return { dps = avgDmg / cast, spell = name, rank = rank, base = baseAvg, sp = sp, coef = coef,
        crit = crit, critMult = critMult, hit = hit, mult = mult, cast = cast, school = school }
end

------------------------------------------------------------------------
-- Reading buff / consumable text into mods
------------------------------------------------------------------------
-- Returns a mods table (or nil) from one line of buff or "Use:" text.
function MC:ParseEffect(text, school)
    if type(text) ~= "string" then return end
    local t = text:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local m, n = {}, nil
    local function num(p) local v = t:match(p) return v and tonumber(v) end
    -- % damage first, so "spell damage by 30%" isn't read as +30 spell damage
    n = num("(%d+)%% more damage") or num("spell damage by (%d+)%%") or num("damage done by spells.- by (%d+)%%")
        or num("increases damage done by (%d+)%%") or num("damage increased by (%d+)%%")
    if n then m.mult = 1 + n / 100 end
    -- school-specific spell damage
    local sch, v = t:match("damage done by (%a+) spells and effects by up to (%d+)")
    if not sch then v, sch = nil, nil
        local a = t:match("spell (%a+) damage by up to %d+")
        if a then sch, v = a, t:match("spell %a+ damage by up to (%d+)") end
    end
    if not sch then
        local a, b = t:match("(%a+) spell damage by up to (%d+)")
        if a and a ~= "the" then sch, v = a, b end
    end
    if sch == "magical" then sch = nil end -- "magical spells and effects" = all schools
    if sch and school and sch == school:lower() then m.sp = (m.sp or 0) + tonumber(v) end
    if not sch then
        n = num("magical spells and effects by up to (%d+)") or num("spell damage by up to (%d+)")
            or num("spell power by (%d+)") or num("spell damage increased by (%d+)")
            or (not m.mult and num("spell damage by (%d+)"))
        if n then m.sp = (m.sp or 0) + n end
    end
    n = num("intellect by (%d+)") or num("all stats by (%d+)") or num("^%+(%d+) intellect")
    if n then m.int = n end
    n = num("critical strike with spells by (%d+)%%") or num("spell critical strike chance by (%d+)%%")
        or num("chance to critically hit with spells by (%d+)%%") or num("critical strike chance .-by (%d+)%%")
    if n then m.crit = n end
    n = num("chance to hit with spells by (%d+)%%") or num("spell hit chance by (%d+)%%")
    if n then m.hit = n end
    if next(m) then return m end
end

local function Merge(a, b)
    if not b then return a end
    a = a or {}
    for k, v in pairs(b) do
        if k == "mult" then a.mult = (a.mult or 1) * v else a[k] = (a[k] or 0) + v end
    end
    return a
end

local function Negate(m)
    local r = {}
    for k, v in pairs(m) do if k == "mult" then r.mult = 1 / v else r[k] = -v end end
    return r
end

local function Fmt(v) return format("%.1f", v) end
local function Delta(d)
    local color = (d > 0.05 and "ff40ff40") or (d < -0.05 and "ffff6060") or "ffaaaaaa"
    return "|c" .. color .. (d > 0.05 and "+" or "") .. Fmt(d) .. "|r"
end

------------------------------------------------------------------------
-- Tooltip lines
------------------------------------------------------------------------
-- Item you could equip: DPS change vs what it replaces.
function MC:DpsItemLine(link, replaced)
    local info = self.PowerItemInfo(link)
    if info and info.classID == 2 and info.subclassID == 19 then return end -- wands: the game shows their DPS
    local base = self:EstimateDps()
    if base.dps <= 0 then return end
    local school = base.school
    local function ModsOf(l, sign)
        local _, s = self:ItemPower(l)
        return { sp = sign * ((s.spelldmg or 0) + (s.sprating or 0) + (s[school .. " dmg"] or 0)),
            crit = sign * (s.crit or 0), hit = sign * (s.hit or 0), int = sign * (s.int or 0) }
    end
    local mods = ModsOf(link, 1)
    for _, l in ipairs(replaced or {}) do Merge(mods, ModsOf(l, -1)) end
    local new = self:EstimateDps(mods).dps
    return "|cff69ccf0DPS|r " .. Delta(new - base.dps) .. "  |cffaaaaaa(" .. Fmt(base.dps) .. " -> " .. Fmt(new) .. ")|r"
end

-- Potions, elixirs, food, scrolls: what the "Use:" effect would add.
function MC:AddDpsToConsumable(tt, link)
    local base = self:EstimateDps()
    if base.dps <= 0 then return end
    local mods
    for _, line in ipairs(self.PowerTooltipLines(link)) do
        if line:find("^Use:") or line:find("well fed") then mods = Merge(mods, self:ParseEffect(line, base.school)) end
    end
    if not mods then return end
    local new = self:EstimateDps(mods).dps
    if abs(new - base.dps) < 0.05 then return end
    tt:AddLine("|cff69ccf0If used:|r " .. Delta(new - base.dps) .. " DPS  |cffaaaaaa(" .. Fmt(base.dps) .. " -> " .. Fmt(new) .. ")|r")
    tt:Show()
end

-- Buff tooltip: how much DPS this buff gives you (or would give you).
function MC:AddDpsToAura(tt, lines)
    if not lines or not lines[1] then return end
    local base = self:EstimateDps()
    if base.dps <= 0 then return end
    local mods
    for i = 2, #lines do mods = Merge(mods, self:ParseEffect(lines[i], base.school)) end
    local name = lines[1]
    if DAMAGE_BUFFS[name] then mods = Merge(mods, { mult = DAMAGE_BUFFS[name] }) end
    if not mods then return end
    local d
    if HasBuff(name) then
        if DAMAGE_BUFFS[name] then -- already in the estimate as a multiplier
            d = base.dps - self:EstimateDps({ mult = 1 / DAMAGE_BUFFS[name] }).dps
        else
            d = base.dps - self:EstimateDps(Negate(mods)).dps
        end
        if abs(d) < 0.05 then return end
        tt:AddLine("|cff69ccf0Worth|r " .. Delta(d) .. " DPS to you")
    else
        d = self:EstimateDps(mods).dps - base.dps
        if abs(d) < 0.05 then return end
        tt:AddLine("|cff69ccf0On you:|r " .. Delta(d) .. " DPS")
    end
    tt:Show()
end

local function AuraLines(tt, data)
    local lines = {}
    if data and data.lines then
        for _, l in ipairs(data.lines) do if l.leftText then lines[#lines + 1] = l.leftText end end
    end
    if #lines == 0 and tt and tt.GetName and tt:GetName() then
        for i = 1, tt:NumLines() do
            local fs = _G[tt:GetName() .. "TextLeft" .. i]
            local s = fs and fs:GetText()
            if s then lines[#lines + 1] = s end
        end
    end
    return lines
end

local function OnAuraTooltip(tt, data)
    if not MageCoachDB or MageCoachDB.power == false or not MC:IsMage() then return end
    local ok, err = pcall(MC.AddDpsToAura, MC, tt, AuraLines(tt, data))
    if not ok then MC.powerError = err end
end

------------------------------------------------------------------------
-- Report + init
------------------------------------------------------------------------
function MC:DpsReport()
    local e = self:EstimateDps()
    if e.dps <= 0 then self.Print("No filler spell known yet.") return end
    self.Print(format("~%.1f DPS casting %s (rank %d) back to back:", e.dps, e.spell, e.rank))
    self.Print(format("  base %.0f + %.0f spell damage x %.2f, crit %.1f%% (x%.2f), hit %.0f%%, damage x%.2f, %.2fs cast",
        e.base, e.sp, e.coef, e.crit, e.critMult, e.hit, e.mult, e.cast))
    self.Print("  ignores mana, movement, procs and resists. Hover gear, buffs and elixirs to see the change.")
end

function MC:InitDps()
    if self.dpsInit then return end
    self.dpsInit = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.UnitAura then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, OnAuraTooltip)
    elseif GameTooltip and hooksecurefunc then
        for _, fn in ipairs({ "SetUnitBuff", "SetUnitAura" }) do
            if GameTooltip[fn] then hooksecurefunc(GameTooltip, fn, function(tt) OnAuraTooltip(tt) end) end
        end
    end
end
