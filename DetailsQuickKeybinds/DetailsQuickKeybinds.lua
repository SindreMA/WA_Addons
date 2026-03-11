local addonName, ns = ...

-- Debug logging (toggle via settings UI)
ns.debugEnabled = false
local function dbg(msg)
    if ns.debugEnabled then
        print("|cFF00FF00[DQK]|r " .. msg)
    end
end

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

--[[
    Data structure for binds:
    Each bind has two states per window. Pressing the key swaps between them.
    {
        name = "Overall View",
        key = "LALT",
        mode = "hold",  -- "hold" = state2 while held, state1 on release. "toggle" = swap on press.
        windows = {
            [0] = {  -- 0 = all windows
                state1 = { segment = 0 },
                state2 = { segment = -1 },
            },
        },
    }
    Each state can have: segment (number or nil), attribute (number or nil), sub_attribute (number or nil).
    nil = don't change that property.
]]

local defaultBinds = {
    {
        name = "Overall View",
        key = "LALT",
        mode = "hold",
        windows = {
            [0] = {
                state1 = { segment = 0 },
                state2 = { segment = -1 },
            },
        },
    },
    {
        name = "Interrupts & Dispels",
        key = "LCTRL",
        mode = "toggle",
        windows = {
            [1] = {
                state1 = { attribute = 1, sub_attribute = 1 },
                state2 = { attribute = 4, sub_attribute = 3 },
            },
            [2] = {
                state1 = { attribute = 1, sub_attribute = 1 },
                state2 = { attribute = 4, sub_attribute = 4 },
            },
        },
    },
}

local defaults = {
    minimap = { hide = false },
}

-- Runtime: tracks which state each bind is in (1 or 2)
local bindStates = {} -- [bindIndex] = 1 or 2

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")

local function GetWindow(id)
    if not Details or not Details.GetWindow then return nil end
    local win = Details:GetWindow(id)
    if win and win.ativa and win.baseframe then return win end
    return nil
end

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

local function IsBlizzardAPI()
    return Details and Details.IsUsingBlizzardAPI and Details:IsUsingBlizzardAPI()
end

-- Apply a state to a window
local function ApplyState(windowId, state)
    local win = GetWindow(windowId)
    if not win then
        dbg("ApplyState: window " .. tostring(windowId) .. " not found")
        return
    end

    dbg("ApplyState: win=" .. windowId ..
        " seg=" .. tostring(state.segment) ..
        " attr=" .. tostring(state.attribute) ..
        " sub=" .. tostring(state.sub_attribute))

    if IsBlizzardAPI() then
        if state.segment ~= nil then
            local targetType = (state.segment == DETAILS_SEGMENTID_OVERALL) and 0 or 1
            win:SetSegmentType(targetType)
            dbg("  SetSegmentType -> " .. targetType)
        end

        if state.attribute then
            local attr = state.attribute
            local subAttr = state.sub_attribute or win.sub_atributo_last[attr] or 1
            win.atributo = attr
            win.sub_atributo = subAttr
            win.sub_atributo_last[attr] = subAttr
            win:ChangeIcon()
            dbg("  SetAttribute -> " .. attr .. "/" .. subAttr)
        end

        win:RefreshWindow(true)
        dbg("  RefreshWindow done")
    else
        local seg = state.segment or win.segmento
        local attr = state.attribute or win.atributo
        local subAttr = state.sub_attribute or win.sub_atributo
        win:SetDisplay(seg, attr, subAttr)
        dbg("  SetDisplay done")
    end
end

-- Resolve ALL_WINDOWS into individual IDs and apply a target state number
local function ApplyBind(bind, targetState)
    for windowId, windowConfig in pairs(bind.windows) do
        local state = (targetState == 2) and windowConfig.state2 or windowConfig.state1
        if not state then return end

        if windowId == ns.ALL_WINDOWS then
            for _, id in ipairs(GetActiveWindowIds()) do
                if not bind.windows[id] then
                    ApplyState(id, state)
                end
            end
        else
            ApplyState(windowId, state)
        end
    end
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
                dbg("Key " .. key .. " -> bind #" .. i .. " '" .. bind.name .. "' mode=" .. bind.mode)
                local current = bindStates[i] or 1

                if bind.mode == "hold" then
                    if down == 1 then
                        ApplyBind(bind, 2)
                        bindStates[i] = 2
                        dbg("  -> state 2")
                    else
                        ApplyBind(bind, 1)
                        bindStates[i] = 1
                        dbg("  -> state 1")
                    end
                elseif bind.mode == "toggle" then
                    if down == 1 then
                        local next = (current == 1) and 2 or 1
                        ApplyBind(bind, next)
                        bindStates[i] = next
                        dbg("  -> state " .. next)
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
