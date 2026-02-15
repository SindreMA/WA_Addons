local addonName, ns = ...

-- Modifier key labels
ns.MODIFIERS = { "LALT", "LCTRL", "LSHIFT", "RALT", "RCTRL", "RSHIFT" }
ns.MODIFIER_LABELS = {
    LALT = "Left Alt", LCTRL = "Left Ctrl", LSHIFT = "Left Shift",
    RALT = "Right Alt", RCTRL = "Right Ctrl", RSHIFT = "Right Shift",
}

-- Details! attribute/sub-attribute definitions
ns.ATTRIBUTES = {
    { id = 1, name = "Damage", subs = {
        { id = 1, name = "Damage Done" }, { id = 2, name = "DPS" },
        { id = 3, name = "Damage Taken" }, { id = 4, name = "Friendly Fire" },
        { id = 5, name = "Frags" }, { id = 6, name = "Enemies" },
        { id = 7, name = "Voidzones" }, { id = 8, name = "By Spells" },
    }},
    { id = 2, name = "Healing", subs = {
        { id = 1, name = "Healing Done" }, { id = 2, name = "HPS" },
        { id = 3, name = "Overheal" }, { id = 4, name = "Healing Taken" },
        { id = 5, name = "Heal Enemy" }, { id = 6, name = "Prevented" },
        { id = 7, name = "Absorbed" },
    }},
    { id = 3, name = "Energy", subs = {
        { id = 1, name = "Mana" }, { id = 2, name = "Rage" },
        { id = 3, name = "Energy" }, { id = 4, name = "Rune" },
        { id = 5, name = "Resources" }, { id = 6, name = "Alt Power" },
    }},
    { id = 4, name = "Misc", subs = {
        { id = 1, name = "CC Break" }, { id = 2, name = "Ress" },
        { id = 3, name = "Interrupt" }, { id = 4, name = "Dispel" },
        { id = 5, name = "Death" }, { id = 6, name = "Cooldown" },
        { id = 7, name = "Buff Uptime" }, { id = 8, name = "Debuff Uptime" },
    }},
}

-- Segment options
ns.SEGMENTS = {
    { id = 0, name = "Current" },
    { id = -1, name = "Overall" },
}

-- Special window ID meaning "all active windows"
ns.ALL_WINDOWS = 0

-- Default keybinds
local defaultBinds = {
    {
        name = "Overall View",
        key = "LALT",
        mode = "hold",
        actions = {
            [0] = { segment = -1 },  -- 0 = all windows
        },
    },
    {
        name = "Interrupts & Dispels",
        key = "LCTRL",
        mode = "toggle",
        actions = {
            [1] = { attribute = 4, sub_attribute = 3 },
            [2] = { attribute = 4, sub_attribute = 4 },
        },
    },
}

local defaults = {
    minimap = { hide = false },
}

-- Runtime state: tracks which binds are currently active and their saved originals
local activeBinds = {} -- [bindIndex] = { originals = { [windowId] = { segmento, atributo, sub_atributo } } }

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")

-- Get a Details! window instance safely (must be active with a baseframe)
local function GetWindow(id)
    if not Details or not Details.GetWindow then return nil end
    local win = Details:GetWindow(id)
    if win and win.ativa and win.baseframe then return win end
    return nil
end

-- Get list of all active window IDs
local function GetActiveWindowIds()
    local ids = {}
    if not Details or not Details.GetNumInstances then return ids end
    for i = 1, Details:GetNumInstances() do
        local win = Details:GetWindow(i)
        if win and win.ativa and win.baseframe then
            ids[#ids + 1] = i
        end
    end
    return ids
end

-- Save original state of a window
local function SaveOriginal(windowId)
    local win = GetWindow(windowId)
    if not win then return nil end
    return {
        segmento = win.segmento,
        atributo = win.atributo,
        sub_atributo = win.sub_atributo,
    }
end

-- Ensure Details! freeze UI elements exist (they're missing on some windows)
local function EnsureFreezeElements(win)
    if not win.baseframe then return end
    if not win.freeze_texto then
        win.freeze_texto = win.baseframe:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        win.freeze_texto:SetPoint("CENTER", win.baseframe, "CENTER", 10, 0)
        win.freeze_texto:Hide()
    end
    if not win.freeze_icon then
        win.freeze_icon = win.baseframe:CreateTexture(nil, "OVERLAY")
        win.freeze_icon:SetSize(16, 16)
        win.freeze_icon:SetPoint("RIGHT", win.freeze_texto, "LEFT", -4, 0)
        win.freeze_icon:Hide()
    end
end

-- Apply a single action to a window
local function ApplyAction(windowId, action)
    local win = GetWindow(windowId)
    if not win then return end

    EnsureFreezeElements(win)

    -- Smart segment: if already on the target segment, flip to the opposite
    local seg = action.segment
    if seg then
        if seg == win.segmento then
            -- Flip: Overall <-> Current
            if seg == DETAILS_SEGMENTID_OVERALL then
                seg = DETAILS_SEGMENTID_CURRENT
            else
                seg = DETAILS_SEGMENTID_OVERALL
            end
        end
    else
        seg = win.segmento
    end

    local attr = action.attribute or win.atributo
    local subAttr = action.sub_attribute or win.sub_atributo

    win:SetDisplay(seg, attr, subAttr)
end

-- Restore a window to its original state
local function RestoreOriginal(windowId, original)
    local win = GetWindow(windowId)
    if not win or not original then return end
    EnsureFreezeElements(win)
    win:SetDisplay(original.segmento, original.atributo, original.sub_atributo)
end

-- Expand actions: resolve ALL_WINDOWS (0) into individual window IDs
local function ExpandActions(bind)
    local expanded = {}
    for windowId, action in pairs(bind.actions) do
        if windowId == ns.ALL_WINDOWS then
            for _, id in ipairs(GetActiveWindowIds()) do
                if not bind.actions[id] then -- specific window overrides "all"
                    expanded[id] = action
                end
            end
        else
            expanded[windowId] = action
        end
    end
    return expanded
end

-- Activate a bind: save originals and apply all actions
local function ActivateBind(bindIndex, bind)
    local originals = {}
    local expanded = ExpandActions(bind)
    for windowId, action in pairs(expanded) do
        originals[windowId] = SaveOriginal(windowId)
        ApplyAction(windowId, action)
    end
    activeBinds[bindIndex] = { originals = originals }
end

-- Deactivate a bind: restore all originals
local function DeactivateBind(bindIndex)
    local state = activeBinds[bindIndex]
    if not state then return end
    for windowId, original in pairs(state.originals) do
        RestoreOriginal(windowId, original)
    end
    activeBinds[bindIndex] = nil
end

-- Minimap button
local function InitMinimapButton()
    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("DetailsQuickKeybinds", {
        type = "data source",
        text = "Details Quick Keybinds",
        icon = "Interface/Icons/Spell_Holy_BorrowedTime",

        OnClick = function(self, btn)
            if btn == "LeftButton" then
                ns.ToggleSettings()
            end
        end,

        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("Details Quick Keybinds")
            local count = DetailsQuickKeybindsDB.binds and #DetailsQuickKeybindsDB.binds or 0
            tooltip:AddLine(count .. " keybind(s) configured")
            tooltip:AddLine("Left-click to open settings")
        end,
    })

    local icon = LibStub("LibDBIcon-1.0", true)
    icon:Register("DetailsQuickKeybinds", ldb, DetailsQuickKeybindsDB.minimap)

    local button = icon:GetMinimapButton("DetailsQuickKeybinds")
    if button then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
end

-- Deep copy a table
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            if not DetailsQuickKeybindsDB then
                DetailsQuickKeybindsDB = {}
            end
            for k, v in pairs(defaults) do
                if DetailsQuickKeybindsDB[k] == nil then
                    DetailsQuickKeybindsDB[k] = DeepCopy(v)
                end
            end
            if not DetailsQuickKeybindsDB.minimap then
                DetailsQuickKeybindsDB.minimap = { hide = false }
            end
            if not DetailsQuickKeybindsDB.binds then
                DetailsQuickKeybindsDB.binds = DeepCopy(defaultBinds)
            end

            InitMinimapButton()
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "MODIFIER_STATE_CHANGED" then
        local key, down = ...
        local binds = DetailsQuickKeybindsDB and DetailsQuickKeybindsDB.binds
        if not binds then return end

        for i, bind in ipairs(binds) do
            if bind.key == key then
                if bind.mode == "hold" then
                    if down == 1 then
                        ActivateBind(i, bind)
                    else
                        DeactivateBind(i)
                    end
                elseif bind.mode == "toggle" then
                    if down == 1 then
                        if activeBinds[i] then
                            DeactivateBind(i)
                        else
                            ActivateBind(i, bind)
                        end
                    end
                end
            end
        end
    end
end)

-- Slash command
SLASH_DETAILSQUICKKEYBINDS1 = "/dqk"
SlashCmdList["DETAILSQUICKKEYBINDS"] = function()
    ns.ToggleSettings()
end
