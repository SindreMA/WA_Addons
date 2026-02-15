local addonName, ns = ...

-- SavedVariables defaults
local defaults = {
    scaleMode = false,
    scales = {},        -- { ["FrameName"] = 1.2, ... }
    globalScale = nil,  -- optional global override
    minimap = { hide = false },
}

-- State
local isDragging = false
local dragFrame = nil
local dragStartY = 0
local dragStartScale = 1
local currentTarget = nil      -- the frame currently highlighted
local parentStack = {}         -- stack of frames we navigated up from (for going back to child)
local candidateFrames = {}     -- all frames under cursor (for cycling)
local candidateIndex = 1
local lastCursorX, lastCursorY = 0, 0  -- track cursor to detect movement
local scanThrottle = 0

-- Color constants
local ADDON_COLOR = "|cff00ccff"
local BORDER_COLOR = { 0, 0.8, 1, 0.8 }
local BORDER_SIZE = 2
local HANDLE_SIZE = 14

-- Print helper
local function Msg(text)
    print(ADDON_COLOR .. "FrameScale:|r " .. text)
end

-- Deep copy for nested defaults
local function MergeDefaults(db, defs)
    for k, v in pairs(defs) do
        if db[k] == nil then
            if type(v) == "table" then
                db[k] = {}
                MergeDefaults(db[k], v)
            else
                db[k] = v
            end
        end
    end
end

---------------------------------------------------------------------
-- Highlight frame: border-only with a resize handle at bottom-right
---------------------------------------------------------------------
local highlight = CreateFrame("Frame", "FrameScaleHighlight", UIParent)
highlight:SetFrameStrata("TOOLTIP")
highlight:Hide()

-- Four border edges (no fill)
local borderTop = highlight:CreateTexture(nil, "OVERLAY")
borderTop:SetColorTexture(unpack(BORDER_COLOR))
borderTop:SetPoint("TOPLEFT")
borderTop:SetPoint("TOPRIGHT")
borderTop:SetHeight(BORDER_SIZE)

local borderBottom = highlight:CreateTexture(nil, "OVERLAY")
borderBottom:SetColorTexture(unpack(BORDER_COLOR))
borderBottom:SetPoint("BOTTOMLEFT")
borderBottom:SetPoint("BOTTOMRIGHT")
borderBottom:SetHeight(BORDER_SIZE)

local borderLeft = highlight:CreateTexture(nil, "OVERLAY")
borderLeft:SetColorTexture(unpack(BORDER_COLOR))
borderLeft:SetPoint("TOPLEFT")
borderLeft:SetPoint("BOTTOMLEFT")
borderLeft:SetWidth(BORDER_SIZE)

local borderRight = highlight:CreateTexture(nil, "OVERLAY")
borderRight:SetColorTexture(unpack(BORDER_COLOR))
borderRight:SetPoint("TOPRIGHT")
borderRight:SetPoint("BOTTOMRIGHT")
borderRight:SetWidth(BORDER_SIZE)

-- Resize handle at bottom-right
local handle = CreateFrame("Frame", "FrameScaleHandle", highlight)
handle:SetSize(HANDLE_SIZE, HANDLE_SIZE)
handle:SetPoint("BOTTOMRIGHT", highlight, "BOTTOMRIGHT", 0, 0)
handle:SetFrameStrata("TOOLTIP")
handle:SetFrameLevel(highlight:GetFrameLevel() + 10)
handle:EnableMouse(true)

-- Draw the handle as a triangle-ish grip
local handleBg = handle:CreateTexture(nil, "OVERLAY")
handleBg:SetAllPoints()
handleBg:SetColorTexture(0, 0.8, 1, 0.9)

local handleInner = handle:CreateTexture(nil, "OVERLAY", nil, 1)
handleInner:SetPoint("TOPLEFT", 2, -2)
handleInner:SetPoint("BOTTOMRIGHT", -2, 2)
handleInner:SetColorTexture(0, 0.5, 0.7, 0.9)

-- Grip lines on handle
for i = 0, 2 do
    local line = handle:CreateTexture(nil, "OVERLAY", nil, 2)
    line:SetSize(HANDLE_SIZE - 4 - i * 3, 1)
    line:SetPoint("BOTTOMRIGHT", handle, "BOTTOMRIGHT", -3, 3 + i * 3)
    line:SetColorTexture(1, 1, 1, 0.5)
end

---------------------------------------------------------------------
-- Frame detection
---------------------------------------------------------------------
local SKIP_FRAMES = {
    ["UIParent"] = true,
    ["WorldFrame"] = true,
    ["FrameScaleOverlay"] = true,
    ["FrameScaleHighlight"] = true,
    ["FrameScaleHandle"] = true,
    ["FrameScaleSettingsFrame"] = true,
    ["DropDownList1"] = true,
    ["DropDownList2"] = true,
}

local SKIP_PATTERNS = {
    "^GameTooltip",
    "^FrameScale",
    "^Tooltip",
    "^SharedTooltip",
}

local STRATA_ORDER = {
    WORLD = 0, BACKGROUND = 1, LOW = 2, MEDIUM = 3,
    HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}

-- Check if a frame covers most of the screen (use effective scale to get true visual size)
local function IsFullScreenFrame(frame)
    local w, h = frame:GetWidth(), frame:GetHeight()
    if not w or not h then return false end
    local es = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local screenW, screenH = GetScreenWidth(), GetScreenHeight()
    return (w * es) >= screenW * 0.9 and (h * es) >= screenH * 0.9
end

local function GetFramesAtCursor()
    local frames = {}

    local frame = EnumerateFrames()
    while frame do
        if frame:IsVisible() and frame:GetName() then
            local name = frame:GetName()
            local skip = SKIP_FRAMES[name]

            if not skip then
                for _, pat in ipairs(SKIP_PATTERNS) do
                    if name:match(pat) then
                        skip = true
                        break
                    end
                end
            end

            if not skip then
                local fsOk, isFS = pcall(IsFullScreenFrame, frame)
                if fsOk and isFS then
                    skip = true
                end
            end

            -- IsMouseOver handles all coordinate/scale conversion internally
            -- pcall guards against "Can't measure restricted regions" on nameplates etc.
            if not skip then
                local ok, over = pcall(frame.IsMouseOver, frame)
                if ok and over then
                    table.insert(frames, frame)
                end
            end
        end
        frame = EnumerateFrames(frame)
    end

    -- Sort: highest strata/level first
    table.sort(frames, function(a, b)
        local sa = STRATA_ORDER[a:GetFrameStrata()] or 3
        local sb = STRATA_ORDER[b:GetFrameStrata()] or 3
        if sa ~= sb then return sa > sb end
        return a:GetFrameLevel() > b:GetFrameLevel()
    end)

    return frames
end

---------------------------------------------------------------------
-- Apply scale
---------------------------------------------------------------------
local function ApplyScale(frameName, scale)
    local f = _G[frameName]
    if f and f.SetScale then
        if InCombatLockdown() and f:IsProtected() then
            Msg("Cannot scale |cffffffff" .. frameName .. "|r during combat.")
            return false
        end
        f:SetScale(scale)
        return true
    end
    return false
end

local function ApplyAllScales()
    if not FrameScaleDB or not FrameScaleDB.scales then return end
    for frameName, scale in pairs(FrameScaleDB.scales) do
        ApplyScale(frameName, scale)
    end
end

---------------------------------------------------------------------
-- Overlay (captures input when scale mode is active)
---------------------------------------------------------------------
local scaleOverlay = CreateFrame("Frame", "FrameScaleOverlay", UIParent)
scaleOverlay:SetAllPoints()
scaleOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
scaleOverlay:EnableMouse(true)
scaleOverlay:EnableMouseWheel(true)
scaleOverlay:EnableKeyboard(true)
scaleOverlay:Hide()

---------------------------------------------------------------------
-- Get current target
---------------------------------------------------------------------
local function GetCurrentTarget()
    return currentTarget
end

---------------------------------------------------------------------
-- Show/hide highlight and tooltip (forward-declared for SelectParent/SelectChild)
---------------------------------------------------------------------
local ShowHighlight
ShowHighlight = function(targetFrame)
    if not targetFrame then
        highlight:Hide()
        GameTooltip:Hide()
        return
    end

    -- Anchor directly to the target frame (WoW handles coordinate conversion)
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -BORDER_SIZE, BORDER_SIZE)
    highlight:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", BORDER_SIZE, -BORDER_SIZE)
    highlight:Show()

    -- Tooltip
    GameTooltip:SetOwner(scaleOverlay, "ANCHOR_CURSOR")
    local name = targetFrame:GetName() or "?"
    local scale = targetFrame:GetScale()

    GameTooltip:AddLine(name, 0, 0.8, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Scale:", string.format("%.2f", scale), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Strata:", targetFrame:GetFrameStrata(), 0.7, 0.7, 0.7, 1, 1, 1)
    GameTooltip:AddDoubleLine("Level:", tostring(targetFrame:GetFrameLevel()), 0.7, 0.7, 0.7, 1, 1, 1)

    -- Show parent info
    local parent = targetFrame:GetParent()
    if parent and parent ~= UIParent and parent ~= WorldFrame and parent:GetName() then
        GameTooltip:AddDoubleLine("Parent:", parent:GetName(), 0.7, 0.7, 0.7, 0.6, 0.6, 0.6)
    end

    -- Show overlapping frames list
    if #candidateFrames > 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(string.format("|cff00ccffOverlapping: %d frames|r", #candidateFrames), 1, 1, 1)
        for i, f in ipairs(candidateFrames) do
            local n = f:GetName() or "?"
            if i == candidateIndex then
                GameTooltip:AddLine("  > " .. n, 0, 1, 0.5)
            else
                GameTooltip:AddLine("    " .. n, 0.5, 0.5, 0.5)
            end
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff666666Scroll: cycle overlapping frames|r")
    GameTooltip:AddLine("|cff666666Tab: select parent  |  Shift+Tab: back to child|r")
    GameTooltip:AddLine("|cff666666Drag handle: adjust scale|r")
    GameTooltip:AddLine("|cff666666Right-click / Esc: exit|r")
    GameTooltip:Show()
end

-- Navigate to parent frame
local function SelectParent()
    if not currentTarget then return end
    local parent = currentTarget:GetParent()
    if parent and parent ~= UIParent and parent ~= WorldFrame and parent:GetName() then
        table.insert(parentStack, currentTarget)
        currentTarget = parent
        ShowHighlight(currentTarget)
    end
end

-- Navigate back to child frame
local function SelectChild()
    if #parentStack == 0 then return end
    currentTarget = table.remove(parentStack)
    ShowHighlight(currentTarget)
end

---------------------------------------------------------------------
-- Scan + update (called from OnUpdate)
---------------------------------------------------------------------
local function ScanAndUpdate()
    local uiScale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / uiScale, cy / uiScale

    -- Only rescan if cursor moved enough (higher threshold to avoid resetting during scroll cycling)
    local moved = (math.abs(cx - lastCursorX) > 5 or math.abs(cy - lastCursorY) > 5)
    if moved then
        lastCursorX, lastCursorY = cx, cy
        candidateFrames = GetFramesAtCursor()
        candidateIndex = 1
        currentTarget = candidateFrames[1] or nil
        wipe(parentStack)
    end

    ShowHighlight(currentTarget)
end


---------------------------------------------------------------------
-- Scale mode toggle
---------------------------------------------------------------------
local function SetScaleMode(active)
    FrameScaleDB.scaleMode = active
    if active then
        scaleOverlay:Show()
        Msg("Scale mode |cff00ff00enabled|r.")
    else
        scaleOverlay:Hide()
        highlight:Hide()
        GameTooltip:Hide()
        isDragging = false
        dragFrame = nil
        currentTarget = nil
        wipe(parentStack)
        wipe(candidateFrames)
        candidateIndex = 1
        lastCursorX, lastCursorY = 0, 0
        Msg("Scale mode |cffff0000disabled|r.")
    end
end

---------------------------------------------------------------------
-- Handle drag (resize handle at bottom-right of highlight)
-- Dragging down/right = bigger, up/left = smaller
---------------------------------------------------------------------
handle:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
        local target = GetCurrentTarget()
        if target then
            isDragging = true
            dragFrame = target
            local _, cursorY = GetCursorPosition()
            dragStartY = cursorY / UIParent:GetEffectiveScale()
            dragStartScale = target:GetScale()
        end
    end
end)

handle:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        isDragging = false
        dragFrame = nil
    end
end)

---------------------------------------------------------------------
-- Overlay scripts
---------------------------------------------------------------------
scaleOverlay:SetScript("OnUpdate", function(self, elapsed)
    -- Handle drag: only from the resize handle
    if isDragging and dragFrame then
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / UIParent:GetEffectiveScale()
        -- Dragging DOWN = cursorY decreases (WoW Y goes up)
        -- We want down = bigger, so negate
        local delta = (dragStartY - cursorY) / 200
        local newScale = math.max(0.1, dragStartScale + delta)
        newScale = math.floor(newScale * 100 + 0.5) / 100

        local name = dragFrame:GetName()
        if ApplyScale(name, newScale) then
            FrameScaleDB.scales[name] = newScale
            ShowHighlight(dragFrame)
        end
        return
    end

    -- Throttle scanning to ~20fps
    scanThrottle = scanThrottle + elapsed
    if scanThrottle < 0.05 then return end
    scanThrottle = 0

    ScanAndUpdate()
end)

-- Left-click on overlay does nothing (drag only from handle)
-- Right-click exits scale mode
scaleOverlay:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
        SetScaleMode(false)
    end
end)

-- Scroll wheel cycles through overlapping frames
scaleOverlay:SetScript("OnMouseWheel", function(self, delta)
    if #candidateFrames <= 1 then return end
    if delta > 0 then
        candidateIndex = candidateIndex - 1
        if candidateIndex < 1 then candidateIndex = #candidateFrames end
    else
        candidateIndex = candidateIndex + 1
        if candidateIndex > #candidateFrames then candidateIndex = 1 end
    end
    currentTarget = candidateFrames[candidateIndex]
    wipe(parentStack)
    ShowHighlight(currentTarget)
end)

scaleOverlay:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
        SetScaleMode(false)
        self:SetPropagateKeyboardInput(false)
    elseif key == "TAB" then
        if IsShiftKeyDown() then
            SelectChild()
        else
            SelectParent()
        end
        self:SetPropagateKeyboardInput(false)
    else
        self:SetPropagateKeyboardInput(true)
    end
end)

---------------------------------------------------------------------
-- Event frame
---------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Minimap button
local function InitMinimapButton()
    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("FrameScale", {
        type = "data source",
        text = "FrameScale",
        icon = "Interface/Icons/INV_Misc_EngGizmos_swissArmy",

        OnClick = function(self, btn)
            if btn == "LeftButton" then
                FrameScaleDB.scaleMode = not FrameScaleDB.scaleMode
                SetScaleMode(FrameScaleDB.scaleMode)
            elseif btn == "RightButton" then
                ns.ToggleSettings()
            end
        end,

        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("FrameScale")
            if FrameScaleDB.scaleMode then
                tooltip:AddLine("Mode: |cff00ff00Scale Edit|r")
            else
                tooltip:AddLine("Mode: |cffaaaaaaInactive|r")
            end
            local count = 0
            for _ in pairs(FrameScaleDB.scales) do count = count + 1 end
            tooltip:AddLine("Scaled frames: |cffffffff" .. count .. "|r")
            tooltip:AddLine(" ")
            tooltip:AddLine("|cff888888Left-click:|r Toggle scale mode")
            tooltip:AddLine("|cff888888Right-click:|r Open settings")
        end,
    })

    ns.ldb = ldb
    local icon = LibStub("LibDBIcon-1.0", true)
    icon:Register("FrameScale", ldb, FrameScaleDB.minimap)
end

-- Slash command
SLASH_FRAMESCALE1 = "/framescale"
SLASH_FRAMESCALE2 = "/fscale"
SlashCmdList["FRAMESCALE"] = function(msg)
    msg = (msg or ""):trim():lower()
    if msg == "settings" or msg == "config" or msg == "options" then
        ns.ToggleSettings()
    elseif msg == "toggle" then
        FrameScaleDB.scaleMode = not FrameScaleDB.scaleMode
        SetScaleMode(FrameScaleDB.scaleMode)
    elseif msg == "reset" then
        for frameName, _ in pairs(FrameScaleDB.scales) do
            ApplyScale(frameName, 1.0)
        end
        wipe(FrameScaleDB.scales)
        FrameScaleDB.globalScale = nil
        Msg("All scales reset to 1.0.")
        if ns.RefreshSettings then ns.RefreshSettings() end
    else
        Msg("Commands: |cffffffff/framescale toggle|r | |cffffffff/framescale settings|r | |cffffffff/framescale reset|r")
    end
end

-- Event handler
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            if not FrameScaleDB then
                FrameScaleDB = {}
            end
            MergeDefaults(FrameScaleDB, defaults)
            if not FrameScaleDB.minimap then
                FrameScaleDB.minimap = { hide = false }
            end

            FrameScaleDB.scaleMode = false

            InitMinimapButton()
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, ApplyAllScales)
    end
end)

-- Expose for settings UI
ns.ApplyScale = ApplyScale
ns.ApplyAllScales = ApplyAllScales
ns.SetScaleMode = SetScaleMode
ns.Msg = Msg
