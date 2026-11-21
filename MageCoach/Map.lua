-- World map pins + zone hint.
-- Pins are plain frames on the map canvas (not MapCanvas pins), so Blizzard's gamepad map
-- cursor never enumerates them - Questie notes that addon pins there taint the map on Forever.
local _, MC = ...
local D = MC.Data

local pool, used = {}, 0
local canvas, hint, watcher
local PIN_SIZE = 16

local function GetPin()
    used = used + 1
    local p = pool[used]
    if not p then
        p = CreateFrame("Button", nil, canvas)
        p:SetSize(PIN_SIZE, PIN_SIZE)
        p:SetFrameLevel(canvas:GetFrameLevel() + 2000)
        p.ring = p:CreateTexture(nil, "BACKGROUND")
        p.ring:SetAllPoints()
        p.ring:SetTexture("Interface\\Minimap\\UI-Minimap-Background") -- round dark backing
        p.ring:SetVertexColor(0, 0, 0, 0.8)
        p.dot = p:CreateTexture(nil, "ARTWORK")
        p.dot:SetPoint("CENTER")
        p.dot:SetSize(PIN_SIZE - 4, PIN_SIZE - 4)
        p.dot:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
        if p.dot.SetMask then pcall(p.dot.SetMask, p.dot, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
        p:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|cff69ccf0MageCoach|r")
            GameTooltip:AddLine(s.label, 1, 1, 1)
            if s.kind ~= "custom" then GameTooltip:AddLine("Approximate location", 0.6, 0.6, 0.6) end
            GameTooltip:AddLine("Click: set map waypoint", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnClick", function(s)
            if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
                pcall(function()
                    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(s.mapID) then return end
                    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(s.mapID, s.x, s.y))
                    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                    end
                end)
            end
        end)
        pool[used] = p
    end
    return p
end

local function PlacePin(p)
    local w, h = canvas:GetSize()
    local s = canvas:GetScale()
    local inv = (s and s > 0) and (1 / s) or 1
    p:SetScale(inv)
    p:ClearAllPoints()
    -- Offsets are in the pin's own (scaled) coordinate space.
    p:SetPoint("CENTER", canvas, "TOPLEFT", (p.x * w) / inv, -(p.y * h) / inv)
end

local function AddPin(mapID, x, y, kind, label)
    local p = GetPin()
    p.mapID, p.x, p.y, p.kind, p.label = mapID, x / 100, y / 100, kind, label
    local c = D.PinColors[kind] or D.PinColors.custom
    if kind == "mage" then
        p.dot:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
        p.dot:SetVertexColor(1, 1, 1)
    elseif kind == "portal" then
        p.dot:SetTexture("Interface\\Icons\\Spell_Arcane_PortalStormWind")
        p.dot:SetVertexColor(1, 1, 1)
    else
        p.dot:SetTexture("Interface\\Buttons\\WHITE8X8")
        p.dot:SetVertexColor(c[1], c[2], c[3])
    end
    PlacePin(p)
    p:Show()
end

local function ZoneHint(mapID)
    if not hint then return end
    if not MageCoachDB.pins then hint:Hide(); return end
    local level, fac = MC:Level(), MC:Faction()
    local text
    for _, z in ipairs(D.Zones) do
        if z[1] == mapID then
            if z[5] ~= "B" and z[5] ~= fac then
                text = "|cffff6060Enemy faction zone|r"
            elseif level < z[3] - 1 then
                text = string.format("|cffff6060%s is %d-%d: too high for you right now|r", z[2], z[3], z[4])
            elseif level > z[4] then
                text = string.format("|cff808080%s (%d-%d) is grey for you|r", z[2], z[3], z[4])
            else
                text = string.format("|cff40ff40%s (%d-%d) is a good zone for you|r", z[2], z[3], z[4])
            end
        end
    end
    local good = {}
    for _, z in ipairs(MC:ZonesFor(level)) do table.insert(good, z[2]) end
    local line2 = #good > 0 and ("Level " .. level .. ": " .. table.concat(good, ", ")) or ""
    hint:SetText("|cff69ccf0MageCoach|r  " .. (text or "") .. "\n|cffd0d0d0" .. line2 .. "|r")
    hint:Show()
end

function MC:RefreshMap()
    if not canvas or not WorldMapFrame:IsShown() then return end
    for i = 1, used do pool[i]:Hide() end
    used = 0
    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end
    ZoneHint(mapID)
    if not MageCoachDB.pins then return end

    local fac = self:Faction()
    if self:IsMage() then
        for _, pin in ipairs(D.Pins) do
            if pin[1] == mapID and (pin[4] == "B" or pin[4] == fac) then
                AddPin(pin[1], pin[2], pin[3], pin[5], pin[6])
            end
        end
    end
    for _, pin in ipairs(MageCoachDB.customPins or {}) do
        if pin[1] == mapID then AddPin(pin[1], pin[2], pin[3], "custom", pin[4]) end
    end
    self.lastScale = canvas:GetScale()
end

function MC:AddCustomPin(note)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        MC.Print("This client can't read your map position.")
        return
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then
        MC.Print("Can't get your position here (instances don't have map coordinates).")
        return
    end
    local x, y = pos:GetXY()
    if not x or not y then
        MC.Print("Can't get your position here.")
        return
    end
    note = (note and note ~= "") and note or "My pin"
    table.insert(MageCoachDB.customPins, { mapID, x * 100, y * 100, note })
    MC.Print(string.format("Pinned \"%s\" at %.1f, %.1f.", note, x * 100, y * 100))
    self:RefreshMap()
end

function MC:InitMap()
    if not (WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child) then
        return
    end
    canvas = WorldMapFrame.ScrollContainer.Child

    hint = WorldMapFrame.ScrollContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOP", WorldMapFrame.ScrollContainer, "TOP", 0, -8)
    hint:SetJustifyH("CENTER")
    hint:SetShadowOffset(1, -1)

    if WorldMapFrame.OnMapChanged then
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function() MC:RefreshMap() end)
    end
    WorldMapFrame:HookScript("OnShow", function() MC:RefreshMap() end)

    -- Keep pins a constant size while zooming.
    watcher = CreateFrame("Frame", nil, WorldMapFrame)
    watcher:SetScript("OnUpdate", function()
        if used > 0 and canvas:GetScale() ~= MC.lastScale then
            MC.lastScale = canvas:GetScale()
            for i = 1, used do PlacePin(pool[i]) end
        end
    end)
end
