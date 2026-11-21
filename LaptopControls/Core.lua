-- LaptopControls: A/D strafe in combat and turn out of combat, and trackpad-friendly camera presets.
-- Keys are changed only with override bindings (never saved over your own key setup), so
-- disabling the addon or /lc swap off gives you your normal bindings back.
local ADDON, LC = ...
_G.LaptopControls = LC

local format, lower, tonumber = string.format, string.lower, tonumber

local DEFAULTS = { swap = true, leftKey = nil, rightKey = nil, leftSteer = false }

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7LaptopControls|r: " .. tostring(msg))
end
LC.Print = Print

local function Locked()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function InCombat()
    if type(UnitAffectingCombat) ~= "function" then return false end
    local ok, v = pcall(UnitAffectingCombat, "player")
    if not ok or (type(issecretvalue) == "function" and issecretvalue(v)) then return Locked() end
    return v and true or false
end

------------------------------------------------------------------------
-- Movement keys
------------------------------------------------------------------------
local owner = CreateFrame("Frame", "LaptopControlsBindingOwner")
LC.owner = owner
LC.mode = nil          -- "strafe", "turn" or nil (no overrides active)
LC.pendingBind = false -- a swap we could not do because of combat lockdown

-- Finds the key the user uses for one side. Prefers the classic default (A / D) when it is bound
-- to turning or strafing that way; otherwise the first key bound to turn, then strafe.
local function FindKey(turn, strafe, default)
    if type(GetBindingAction) == "function" then
        local action = GetBindingAction(default)
        if action == turn or action == strafe then return default end
    end
    if type(GetBindingKey) == "function" then
        local k = GetBindingKey(turn) or GetBindingKey(strafe)
        if k then return k end
    end
    return default
end

function LC:Keys()
    local db = LaptopControlsDB or DEFAULTS
    local left = db.leftKey or FindKey("TURNLEFT", "STRAFELEFT", "A")
    local right = db.rightKey or FindKey("TURNRIGHT", "STRAFERIGHT", "D")
    return left, right
end

-- Preferred path: a secure state driver. Blizzard's secure code flips the bindings itself when
-- [combat] changes, which is allowed during combat lockdown, so it does not depend on our event
-- handler running before the lockdown starts. The plain-event path below is only a fallback.
-- States: "strafe" (in combat), "turn" (out of combat), "off" (swap disabled: no overrides) and
-- "wait" (combat just ended: keep strafing until A/D are let go, then our Lua code sets "turn").
-- Switching a key while it is held leaves the old movement running (stuck strafing), hence "wait".
-- The same goes for a fight starting while A or D is held: a held key keeps doing what it does now
-- (turning stays turning for that fight). lc-lheld / lc-rheld are kept up to date by our Lua code.
-- Turning is set explicitly, because on some clients A/D strafe by default.
local SNIPPET = [=[
    if newstate == "wait" then return end
    local was = self:GetAttribute("lc-bound")
    self:ClearBindings()
    self:SetAttribute("lc-bound", newstate)
    local l, r = self:GetAttribute("lc-left"), self:GetAttribute("lc-right")
    if l and r then
        if newstate == "strafe" then
            local keep = was == "turn"
            self:SetBinding(true, l, (keep and self:GetAttribute("lc-lheld")) and "TURNLEFT" or "STRAFELEFT")
            self:SetBinding(true, r, (keep and self:GetAttribute("lc-rheld")) and "TURNRIGHT" or "STRAFERIGHT")
        elseif newstate == "turn" then
            self:SetBinding(true, l, "TURNLEFT")
            self:SetBinding(true, r, "TURNRIGHT")
        end
    end
]=]

local secure
if type(RegisterStateDriver) == "function" and type(UnregisterStateDriver) == "function" then
    local ok, f = pcall(CreateFrame, "Frame", "LaptopControlsCombatSwap", UIParent, "SecureHandlerStateTemplate")
    if ok and f and f.SetAttribute then
        f:SetAttribute("_onstate-lcmode", SNIPPET)
        secure = f
    end
end
LC.secure = secure
LC.armed = false

-- True while the key is physically held down.
local function KeyDown(k)
    if not k or type(IsKeyDown) ~= "function" then return false end
    local ok, down = pcall(IsKeyDown, k)
    return ok and down and not (type(issecretvalue) == "function" and issecretvalue(down)) and true or false
end

local function KeysHeld()
    local left, right = LC:Keys()
    return KeyDown(left) or KeyDown(right)
end
LC.KeysHeld = KeysHeld

-- Out of combat, tell the secure code which keys are held right now, so a fight that starts
-- mid-press leaves that key alone. Only touches the attributes when something changed.
local heldPoll = CreateFrame("Frame")
local pollSince, lastL, lastR = 0, nil, nil
heldPoll:SetScript("OnUpdate", function(_, elapsed)
    pollSince = pollSince + (elapsed or 0)
    if pollSince < 0.02 then return end
    pollSince = 0
    if not (secure and LC.armed) or Locked() then return end
    local l, r = secure:GetAttribute("lc-left"), secure:GetAttribute("lc-right")
    local lh, rh = KeyDown(l), KeyDown(r)
    if lh ~= lastL then lastL = lh; secure:SetAttribute("lc-lheld", lh) end
    if rh ~= lastR then lastR = rh; secure:SetAttribute("lc-rheld", rh) end
end)
LC.heldPoll = heldPoll

local watcher = CreateFrame("Frame")
watcher:Hide()
local since = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
    since = since + (elapsed or 0)
    if since < 0.05 then return end
    since = 0
    if InCombat() then self:Hide() return end
    if not KeysHeld() then
        self:Hide()
        LC:SettleTurn()
    end
end)
LC.watcher = watcher

-- Event path (fallback): mode "strafe", "turn" or nil to remove our overrides. Returns true when applied.
function LC:SetMode(mode)
    if Locked() then
        self.pendingBind = true
        return false
    end
    if type(ClearOverrideBindings) ~= "function" or type(SetOverrideBinding) ~= "function" then
        return false
    end
    local was = self.mode
    ClearOverrideBindings(owner)
    self.mode = nil
    self.pendingBind = false
    if not mode then return true end
    local left, right = self:Keys()
    local la, ra = "STRAFELEFT", "STRAFERIGHT"
    if mode == "turn" then la, ra = "TURNLEFT", "TURNRIGHT" end
    if mode == "strafe" and was == "turn" then -- a key held as the fight starts keeps turning (see SNIPPET)
        if KeyDown(left) then la = "TURNLEFT" end
        if KeyDown(right) then ra = "TURNRIGHT" end
    end
    local ok = pcall(SetOverrideBinding, owner, true, left, la)
    ok = pcall(SetOverrideBinding, owner, true, right, ra) and ok
    if not ok then
        ClearOverrideBindings(owner)
        return false
    end
    self.mode = mode
    self.boundKeys = left .. "/" .. right
    return true
end

-- "strafe" or "turn" for what A/D do right now, nil when the swap is off (your normal keys).
function LC:CurrentMode()
    if secure and self.armed then
        local st = secure:GetAttribute("lc-bound")
        return (st == "strafe" or st == "turn") and st or nil
    end
    return self.mode
end

-- Out of combat: switch A/D to turning, but only once neither key is held.
function LC:SettleTurn()
    if not LaptopControlsDB.swap or InCombat() or Locked() then return false end
    if secure then
        if not self.armed or secure:GetAttribute("lc-bound") == "turn" then return true end
    elseif self.mode == "turn" then
        return true
    end
    if KeysHeld() then
        since = 0
        watcher:Show()
        return false
    end
    if secure then
        secure:SetAttribute("state-lcmode", "turn")
    else
        self:SetMode("turn")
    end
    return true
end

-- Sets things up for the current situation (only possible out of combat).
function LC:Refresh(inCombat)
    if not secure then
        if inCombat == nil then inCombat = InCombat() end
        if not LaptopControlsDB.swap then return self:SetMode(nil) end
        if inCombat then return self:SetMode("strafe") end
        if not self:SetMode(nil) then return false end
        self:SettleTurn()
        return true
    end
    if Locked() then
        self.pendingBind = true
        return false
    end
    self.pendingBind = false
    if type(ClearOverrideBindings) == "function" then ClearOverrideBindings(owner) end
    self.mode = nil
    if LaptopControlsDB.swap then
        local left, right = self:Keys()
        secure:SetAttribute("lc-left", left)
        secure:SetAttribute("lc-right", right)
        self.boundKeys = left .. "/" .. right
        secure:SetAttribute("state-lcmode", "off")
        RegisterStateDriver(secure, "lcmode", "[combat] strafe; wait")
        self.armed = true
        self:SettleTurn()
    else
        UnregisterStateDriver(secure, "lcmode")
        secure:SetAttribute("state-lcmode", "off")
        if type(ClearOverrideBindings) == "function" then ClearOverrideBindings(secure) end
        self.armed = false
    end
    return true
end

-- Prints what the game reports, for bug reports.
function LC:Debug()
    local function A(k, over)
        if type(GetBindingAction) ~= "function" then return "?" end
        local ok, a = pcall(GetBindingAction, k, over)
        return ok and (a ~= "" and a or "nothing") or "error"
    end
    local left, right = self:Keys()
    Print(format("debug: method=%s armed=%s swap=%s combat=%s lockdown=%s",
        secure and "secure" or "events", tostring(self.armed), tostring(LaptopControlsDB.swap),
        tostring(InCombat()), tostring(Locked())))
    Print(format("debug: keys %s/%s, mode=%s, state=%s, pending=%s", left, right, tostring(self:CurrentMode()),
        tostring(secure and secure:GetAttribute("state-lcmode")), tostring(self.pendingBind)))
    Print(format("debug: keys held=%s, waiting for release=%s", tostring(KeysHeld()), tostring(watcher:IsShown())))
    for _, k in ipairs({ left, right }) do
        Print(format("debug: %s -> normal: %s, right now: %s", k, A(k, false), A(k, true)))
    end
    Print(format("debug: steer=%s active=%s, BUTTON1 -> %s, BUTTON2 -> %s", tostring(LaptopControlsDB.leftSteer),
        tostring(self.steerActive), A("BUTTON1", true), A("BUTTON2", true)))
    local gk = type(GetBindingKey) == "function" and GetBindingKey or function() return nil end
    Print(format("debug: TURNLEFT=%s STRAFELEFT=%s TURNRIGHT=%s STRAFERIGHT=%s", tostring(gk("TURNLEFT")),
        tostring(gk("STRAFELEFT")), tostring(gk("TURNRIGHT")), tostring(gk("STRAFERIGHT"))))
end

------------------------------------------------------------------------
-- Left-click steering: swaps what the two mouse buttons do in the game world.
-- Left-drag then steers your character (like right-drag normally does) and right-drag only moves
-- the camera. Clicks on buttons and windows are not affected. Override bindings again, on their
-- own owner frame, so turning it off gives the normal mouse back.
------------------------------------------------------------------------
local mouseOwner = CreateFrame("Frame", "LaptopControlsMouseOwner")
LC.steerActive = false
LC.pendingSteer = false

function LC:ApplySteer()
    if Locked() then
        self.pendingSteer = true
        return false
    end
    self.pendingSteer = false
    if type(ClearOverrideBindings) ~= "function" or type(SetOverrideBinding) ~= "function" then return false end
    ClearOverrideBindings(mouseOwner)
    self.steerActive = false
    if not LaptopControlsDB.leftSteer then return true end
    local ok = pcall(SetOverrideBinding, mouseOwner, true, "BUTTON1", "TURNORACTION")
    ok = pcall(SetOverrideBinding, mouseOwner, true, "BUTTON2", "CAMERAORSELECTORMOVE") and ok
    if not ok then
        ClearOverrideBindings(mouseOwner)
        Print("Left-click steering could not be set up on this client.")
        return false
    end
    self.steerActive = true
    return true
end

------------------------------------------------------------------------
-- Camera
------------------------------------------------------------------------
local function GetCV(name)
    local ok, v
    if C_CVar and C_CVar.GetCVar then
        ok, v = pcall(C_CVar.GetCVar, name)
    elseif type(GetCVar) == "function" then
        ok, v = pcall(GetCVar, name)
    end
    if ok then return v end
end

LC.GetCV = GetCV

local function SetCV(name, value)
    local ok, res
    if C_CVar and C_CVar.SetCVar then
        ok, res = pcall(C_CVar.SetCVar, name, tostring(value))
    elseif type(SetCVar) == "function" then
        ok, res = pcall(SetCVar, name, tostring(value))
    end
    return ok and res ~= false
end

LC.CameraCVars = {
    "cameraYawMoveSpeed", "cameraPitchMoveSpeed", "cameraSmoothStyle",
    "cameraDistanceMaxZoomFactor", "cameraZoomSpeed", "cameraReduceUnexpectedMovement", "mouseSpeed",
}

-- cameraSmoothStyle: 0 = camera stays where you put it, 4 = swings behind you while you move.
LC.Presets = {
    trackpad = {
        desc = "calmer turning, slower trackpad zoom, max zoom-out, camera stays put",
        cvars = {
            cameraYawMoveSpeed = 120, cameraPitchMoveSpeed = 60, cameraSmoothStyle = 0,
            cameraDistanceMaxZoomFactor = 2.6, cameraZoomSpeed = 10, cameraReduceUnexpectedMovement = 1,
        },
    },
    follow = {
        desc = "like trackpad, but the camera swings behind you while you move (less dragging)",
        cvars = {
            cameraYawMoveSpeed = 120, cameraPitchMoveSpeed = 60, cameraSmoothStyle = 4,
            cameraDistanceMaxZoomFactor = 2.6, cameraZoomSpeed = 10, cameraReduceUnexpectedMovement = 1,
        },
    },
    precise = {
        desc = "slow, fine turning for sensitive trackpads",
        cvars = {
            cameraYawMoveSpeed = 80, cameraPitchMoveSpeed = 40, cameraSmoothStyle = 0,
            cameraDistanceMaxZoomFactor = 2.6, cameraZoomSpeed = 8, cameraReduceUnexpectedMovement = 1,
        },
    },
}
LC.PresetOrder = { "trackpad", "follow", "precise" }

LC.pendingCam = {}   -- cvar -> value, applied when combat ends
LC.pendingReset = false

-- Sets one camera cvar, remembering the user's original value the first time.
-- Returns "ok", "queued" (in combat) or "unknown" (cvar does not exist on this client).
function LC:SetCam(name, value)
    if InCombat() then
        self.pendingCam[name] = value
        return "queued"
    end
    local cur = GetCV(name)
    if cur == nil then return "unknown" end
    local orig = LaptopControlsDB.original
    if orig[name] == nil then orig[name] = cur end
    if not SetCV(name, value) then return "unknown" end
    return "ok"
end

function LC:ApplyPreset(key)
    local p = self.Presets[key]
    if not p then return false end
    self.pendingReset = false
    local queued, skipped = false, {}
    for _, name in ipairs(self.CameraCVars) do
        local v = p.cvars[name]
        if v ~= nil then
            local r = self:SetCam(name, v)
            if r == "queued" then queued = true elseif r == "unknown" then skipped[#skipped + 1] = name end
        end
    end
    if queued then
        Print(format("In combat - the '%s' camera will be applied when combat ends.", key))
    else
        LaptopControlsDB.preset = key
        Print(format("Camera preset '%s' applied.", key))
    end
    if #skipped > 0 then Print("Not available on this client: " .. table.concat(skipped, ", ")) end
    return true
end

function LC:ResetCamera()
    if InCombat() then
        self.pendingReset = true
        wipe(self.pendingCam)
        Print("In combat - camera will be reset when combat ends.")
        return "queued"
    end
    local n = 0
    for name, v in pairs(LaptopControlsDB.original) do
        SetCV(name, v)
        n = n + 1
    end
    wipe(LaptopControlsDB.original)
    LaptopControlsDB.preset = nil
    Print(n > 0 and "Camera settings restored to what you had before." or "Nothing to reset.")
    return "ok"
end

function LC:FlushCamera()
    if self.pendingReset then
        self.pendingReset = false
        self:ResetCamera()
    end
    local any = false
    for name, v in pairs(self.pendingCam) do
        self:SetCam(name, v)
        any = true
    end
    wipe(self.pendingCam)
    if any then Print("Queued camera changes applied.") end
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
local function OnOff(b) return b and "|cff40ff40on|r" or "|cffff6060off|r" end

function LC:Status()
    local db = LaptopControlsDB
    local left, right = self:Keys()
    Print(format("A/D swap: %s  (keys %s / %s%s)", OnOff(db.swap), left, right,
        (db.leftKey or db.rightKey) and ", set by you" or ", auto"))
    local m = self:CurrentMode()
    Print("Right now the keys " .. (m == "strafe" and "STRAFE (in combat)"
        or m == "turn" and "TURN. They switch to strafing when a fight starts" or "use your normal bindings")
        .. (self.pendingBind and " (waiting for combat to end)" or ""))
    Print("Left-click steering: " .. OnOff(db.leftSteer) .. (self.pendingSteer and " (waiting for combat to end)" or ""))
    Print("Camera preset: " .. (db.preset or "none"))
    for _, name in ipairs(self.CameraCVars) do
        local v = GetCV(name)
        if v ~= nil then Print(format("  %s = %s", name, v)) end
    end
end

local function Help()
    Print("commands (/lc on its own opens the settings window):")
    Print("  /lc status - show what is active")
    Print("  /lc debug - details for bug reports")
    Print("  /lc swap [on|off] - A/D strafe in combat, turn out of combat")
    Print("  /lc steer [on|off] - left-click drag steers your character")
    Print("  /lc keys <left> <right> - use other keys (e.g. /lc keys Q E), /lc keys auto")
    Print("  /lc cam trackpad | follow | precise - camera presets")
    Print("  /lc cam reset - put your old camera settings back")
    Print("  /lc speed <n> - turn speed (stock 180, trackpad 120)")
    Print("  /lc zoom <1-2.6> - how far you can zoom out")
    Print("  /lc zoomspeed <n> - scroll zoom speed (stock 20)")
    Print("  /lc follow on|off - camera swings behind you while moving")
    Print("  /lc sens <n> - mouse/trackpad sensitivity (stock 1)")
end

local function Tweak(name, value, label)
    local r = LC:SetCam(name, value)
    if r == "ok" then Print(format("%s set to %s.", label, tostring(value)))
    elseif r == "queued" then Print(format("In combat - %s will change when combat ends.", label))
    else Print(label .. " is not available on this client.") end
end

function LC:Command(msg)
    msg = lower(msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    local db = LaptopControlsDB
    local num = tonumber(rest)

    if cmd == "" or cmd == "options" or cmd == "config" then
        if self.TogglePanel then self:TogglePanel() else Help() end
    elseif cmd == "debug" then
        self:Debug()
    elseif cmd == "help" then
        Help()
    elseif cmd == "status" then
        self:Status()
    elseif cmd == "swap" then
        if rest == "on" then db.swap = true
        elseif rest == "off" then db.swap = false
        else db.swap = not db.swap end
        local done = self:Refresh()
        Print("A/D swap " .. OnOff(db.swap) .. (done and "." or " (will apply when combat ends)."))
    elseif cmd == "steer" then
        if rest == "on" then db.leftSteer = true
        elseif rest == "off" then db.leftSteer = false
        else db.leftSteer = not db.leftSteer end
        local done = self:ApplySteer()
        Print("Left-click steering " .. OnOff(db.leftSteer) .. (done and "." or (self.pendingSteer
            and " (will apply when combat ends)." or ".")))
        if done and db.leftSteer then Print("Left-drag steers you, left-click attacks/talks/loots, right-drag moves the camera.") end
    elseif cmd == "keys" then
        if rest == "auto" or rest == "" then
            db.leftKey, db.rightKey = nil, nil
        else
            local l, r = rest:match("^(%S+)%s+(%S+)$")
            if not l then return Print("usage: /lc keys <left> <right>   (or /lc keys auto)") end
            db.leftKey, db.rightKey = l:upper(), r:upper()
        end
        self:Refresh()
        local left, right = self:Keys()
        Print(format("Movement keys: %s / %s.", left, right))
    elseif cmd == "cam" or cmd == "camera" then
        if rest == "reset" then
            self:ResetCamera()
        elseif self.Presets[rest] then
            self:ApplyPreset(rest)
        else
            Print("presets:")
            for _, k in ipairs(self.PresetOrder) do Print(format("  %s - %s", k, self.Presets[k].desc)) end
            Print("  reset - put your old settings back")
        end
    elseif cmd == "speed" and num and num > 0 and num <= 360 then
        Tweak("cameraYawMoveSpeed", num, "Turn speed")
        self:SetCam("cameraPitchMoveSpeed", math.floor(num / 2 + 0.5))
    elseif cmd == "zoom" and num then
        if num < 1 then num = 1 elseif num > 2.6 then num = 2.6 end
        Tweak("cameraDistanceMaxZoomFactor", num, "Max zoom")
    elseif cmd == "zoomspeed" and num and num > 0 and num <= 50 then
        Tweak("cameraZoomSpeed", num, "Zoom speed")
    elseif cmd == "follow" and (rest == "on" or rest == "off") then
        Tweak("cameraSmoothStyle", rest == "on" and 4 or 0, "Camera follow")
    elseif cmd == "sens" and num and num > 0 and num <= 5 then
        Tweak("mouseSpeed", num, "Sensitivity")
    else
        Help()
    end
end

SLASH_LAPTOPCONTROLS1 = "/lc"
SLASH_LAPTOPCONTROLS2 = "/laptopcontrols"
SlashCmdList.LAPTOPCONTROLS = function(msg) LC:Command(msg) end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
LC.events = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("UPDATE_BINDINGS")

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        LaptopControlsDB = LaptopControlsDB or {}
        local db = LaptopControlsDB
        for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
        db.original = db.original or {}
    elseif event == "PLAYER_LOGIN" then
        LC:Refresh()
        LC:ApplySteer()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Fires just before combat lockdown, so bindings can still be changed here.
        if not LC.secure and LaptopControlsDB.swap and not LC:SetMode("strafe") then
            LC.pendingBind = true
            if not LC.warned then
                LC.warned = true
                Print("Could not switch A/D to strafing (the game blocked it). Use /lc swap off if this keeps happening.")
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if LC.pendingBind then LC:Refresh(false) else LC:SettleTurn() end
        if LC.pendingSteer then LC:ApplySteer() end
        LC:FlushCamera()
    elseif event == "UPDATE_BINDINGS" then
        -- The user changed their key bindings: follow them (auto keys only, never in combat).
        if LaptopControlsDB and LaptopControlsDB.swap and LC.boundKeys and not Locked() then
            local left, right = LC:Keys()
            if left .. "/" .. right ~= LC.boundKeys then LC:Refresh() end
        end
    end
end)
