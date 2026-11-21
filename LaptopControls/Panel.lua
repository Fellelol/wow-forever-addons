-- Small settings window: /lc opens it. Every control just calls the same code as the slash
-- commands, so combat rules (queued changes) are the same.
local _, LC = ...
local format, floor = string.format, math.floor

local panel
local WIDTH, HEIGHT = 340, 430

local function Num(name)
    return tonumber(LC.GetCV(name) or "")
end

local function Round(v, step)
    return floor(v / step + 0.5) * step
end

local function NewFrame(kind, name, parent, template)
    if template then
        local ok, f = pcall(CreateFrame, kind, name, parent, template)
        if ok and f then return f end
    end
    return CreateFrame(kind, name, parent)
end

local function Label(parent, text, x, y, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function Button(parent, text, w, x, y, onClick)
    local b = NewFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", function() onClick() panel:Update() end)
    return b
end

local function Check(parent, text, x, y, onClick)
    local c = NewFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    c:SetPoint("TOPLEFT", x, y)
    c.label = Label(parent, text, x + 28, y - 5)
    c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) panel:Update() end)
    return c
end

-- "Turn speed   [-] 120 [+]" stepper for one camera setting.
local function Stepper(parent, text, y, cvar, step, lo, hi, apply)
    local row = { cvar = cvar }
    Label(parent, text, 20, y - 4)
    row.value = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.value:SetPoint("TOPLEFT", 236, y - 4)
    local function Change(dir)
        local cur = Num(cvar)
        if not cur then return end
        local v = Round(cur + dir * step, step)
        if v < lo then v = lo elseif v > hi then v = hi end
        apply(v)
    end
    Button(parent, "-", 26, 204, y, function() Change(-1) end)
    Button(parent, "+", 26, 290, y, function() Change(1) end)
    return row
end

local function Build()
    panel = NewFrame("Frame", "LaptopControlsPanel", UIParent, "BasicFrameTemplateWithInset")
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "LaptopControlsPanel") end -- Esc closes

    if panel.TitleText then
        panel.TitleText:SetText("LaptopControls")
    else
        Label(panel, "LaptopControls", 12, -8, "GameFontNormal")
    end

    -- Movement
    Label(panel, "Movement", 16, -32, "GameFontNormal")
    panel.swap = Check(panel, "A/D strafe in combat (turn out of combat)", 16, -50, function(on)
        LC:Command(on and "swap on" or "swap off")
    end)
    panel.keys = Label(panel, "", 22, -80, "GameFontHighlightSmall")
    panel.mode = Label(panel, "", 22, -96, "GameFontHighlightSmall")
    Button(panel, "Auto keys", 90, 230, -82, function() LC:Command("keys auto") end)

    panel.steer = Check(panel, "Left-click drag steers your character", 16, -110, function(on)
        LC:Command(on and "steer on" or "steer off")
    end)

    -- Camera presets
    Label(panel, "Camera preset", 16, -154, "GameFontNormal")
    Button(panel, "Trackpad", 74, 16, -174, function() LC:Command("cam trackpad") end)
    Button(panel, "Follow", 74, 94, -174, function() LC:Command("cam follow") end)
    Button(panel, "Precise", 74, 172, -174, function() LC:Command("cam precise") end)
    Button(panel, "Reset", 74, 250, -174, function() LC:Command("cam reset") end)
    panel.preset = Label(panel, "", 22, -202, "GameFontHighlightSmall")

    -- Fine tuning
    Label(panel, "Fine tuning", 16, -226, "GameFontNormal")
    panel.follow = Check(panel, "Camera swings behind you while moving", 16, -244, function(on)
        LC:Command(on and "follow on" or "follow off")
    end)
    panel.rows = {
        Stepper(panel, "Turn speed", -276, "cameraYawMoveSpeed", 20, 20, 360,
            function(v) LC:Command("speed " .. v) end),
        Stepper(panel, "Max zoom-out", -306, "cameraDistanceMaxZoomFactor", 0.1, 1, 2.6,
            function(v) LC:Command(format("zoom %.1f", v)) end),
        Stepper(panel, "Zoom speed", -336, "cameraZoomSpeed", 2, 2, 50,
            function(v) LC:Command("zoomspeed " .. v) end),
        Stepper(panel, "Sensitivity", -366, "mouseSpeed", 0.1, 0.1, 5,
            function(v) LC:Command(format("sens %.1f", v)) end),
    }
    panel.note = Label(panel, "", 16, -398, "GameFontDisableSmall")

    function panel:Update()
        local db = LaptopControlsDB or {}
        self.swap:SetChecked(db.swap and true or false)
        self.steer:SetChecked(db.leftSteer and true or false)
        local left, right = LC:Keys()
        self.keys:SetText(format("Keys: %s / %s (%s)", left, right, (db.leftKey or db.rightKey) and "your choice" or "auto"))
        local cm = LC:CurrentMode()
        local m = cm == "strafe" and "strafing (in combat)" or cm == "turn" and "turning" or "your normal keys"
        self.mode:SetText("Now: " .. m .. (LC.pendingBind and ", waiting for combat to end" or ""))
        self.preset:SetText("Active: " .. (db.preset or "none (game settings)"))
        self.follow:SetChecked(Num("cameraSmoothStyle") == 4)
        for _, row in ipairs(self.rows) do
            local v = Num(row.cvar)
            row.value:SetText(v and format(v == floor(v) and "%d" or "%.1f", v) or "n/a")
        end
        local queued = LC.pendingReset or next(LC.pendingCam) ~= nil
        self.note:SetText(queued and "Camera changes will apply after combat." or "Use /lc keys Q E to pick other keys.")
    end

    -- Keep the window current while it is open (combat start/end changes the mode).
    local t = 0
    panel:SetScript("OnUpdate", function(self, elapsed)
        t = t + (elapsed or 0)
        if t >= 0.5 then t = 0 self:Update() end
    end)
    panel:SetScript("OnShow", function(self) self:Update() end)
end

function LC:TogglePanel()
    if not panel then Build() end
    if panel:IsShown() then panel:Hide() else panel:Show() end
end

-- Also list the addon in the game's Options > AddOns, with a button that opens the window.
local function RegisterOptions()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local f = CreateFrame("Frame")
    Label(f, "LaptopControls", 16, -16, "GameFontNormalLarge")
    Label(f, "Type /lc or press the button to open the settings window.", 16, -44)
    local b = NewFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(160, 24)
    b:SetPoint("TOPLEFT", 16, -70)
    b:SetText("Open settings")
    b:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.Hide then pcall(SettingsPanel.Hide, SettingsPanel) end
        if not panel then Build() end
        panel:Show()
    end)
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, f, "LaptopControls")
    if ok and cat then pcall(Settings.RegisterAddOnCategory, cat) end
end
pcall(RegisterOptions)
