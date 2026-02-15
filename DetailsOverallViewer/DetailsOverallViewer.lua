local addonName = ...

-- Modifier keys that can be used as the toggle
local MODIFIERS = { "LALT", "LCTRL", "LSHIFT", "RALT", "RCTRL", "RSHIFT" }

-- Display-friendly names for the dropdown
local MODIFIER_LABELS = {
    LALT    = "Left Alt",
    LCTRL   = "Left Ctrl",
    LSHIFT  = "Left Shift",
    RALT    = "Right Alt",
    RCTRL   = "Right Ctrl",
    RSHIFT  = "Right Shift",
}

-- SavedVariables defaults
local defaults = {
    modifier = "LALT",
    windows  = {},       -- { [1] = true, [2] = true, ... }
    minimap  = { hide = false },
}

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")

-- Count how many Details! windows exist
local function GetDetailsWindowCount()
    if not Details or not Details.GetWindow then return 0 end
    local count = 0
    for i = 1, 20 do
        local win = Details:GetWindow(i)
        if win then
            count = i
        else
            break
        end
    end
    return count
end

-- Ensure all detected windows have a saved toggle (default enabled)
local function RefreshWindowDefaults()
    local count = GetDetailsWindowCount()
    for i = 1, count do
        if DetailsOverallViewerDB.windows[i] == nil then
            DetailsOverallViewerDB.windows[i] = true
        end
    end
end

-- Switch a single Details! window to the given segment
local function SetDetailsWindow(windowId, segmentId)
    local win = Details:GetWindow(windowId)
    if not win then return end
    win:SetDisplay(segmentId, win.atributo, win.sub_atributo)
end

-- Switch all enabled windows to the given segment
local function SetView(segmentId)
    local count = GetDetailsWindowCount()
    for i = 1, count do
        if DetailsOverallViewerDB.windows[i] then
            SetDetailsWindow(i, segmentId)
        end
    end
end

-- Right-click dropdown menu
local menuFrame = CreateFrame("Frame", "DetailsOverallViewerMenu", UIParent, "UIDropDownMenuTemplate")

local function InitMenu(self, level)
    local info = UIDropDownMenu_CreateInfo()

    -- Title
    info.isTitle = true
    info.text = "|cffb048f8Details Overall Viewer|r"
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)

    -- Modifier key selection
    for _, key in ipairs(MODIFIERS) do
        info = UIDropDownMenu_CreateInfo()
        info.text = MODIFIER_LABELS[key]
        info.checked = function() return DetailsOverallViewerDB.modifier == key end
        info.keepShownOnClick = true
        info.func = function()
            DetailsOverallViewerDB.modifier = key
            print("|cffb048f8Details Overall Viewer:|r Modifier set to |cff00ff00" .. MODIFIER_LABELS[key] .. "|r.")
        end
        UIDropDownMenu_AddButton(info, level)
    end

    -- Separator
    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    info.disabled = true
    info.text = " "
    UIDropDownMenu_AddButton(info, level)

    -- Windows header
    info = UIDropDownMenu_CreateInfo()
    info.isTitle = true
    info.text = "Windows"
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)

    -- Window checkboxes
    RefreshWindowDefaults()
    local count = GetDetailsWindowCount()
    if count == 0 then
        info = UIDropDownMenu_CreateInfo()
        info.text = "|cff888888No Details! windows found|r"
        info.notCheckable = true
        info.disabled = true
        UIDropDownMenu_AddButton(info, level)
    else
        for i = 1, count do
            info = UIDropDownMenu_CreateInfo()
            info.text = "Window " .. i
            info.isNotRadio = true
            info.checked = function() return DetailsOverallViewerDB.windows[i] end
            info.keepShownOnClick = true
            info.func = function()
                DetailsOverallViewerDB.windows[i] = not DetailsOverallViewerDB.windows[i]
                if DetailsOverallViewerDB.windows[i] then
                    print("|cffb048f8Details Overall Viewer:|r Window " .. i .. " |cff00ff00enabled|r.")
                else
                    print("|cffb048f8Details Overall Viewer:|r Window " .. i .. " |cffff0000disabled|r.")
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end

local function InitMinimapButton()
    UIDropDownMenu_Initialize(menuFrame, InitMenu, "MENU")

    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("DetailsOverallViewer", {
        type = "data source",
        text = "Details Overall Viewer",
        icon = "Interface/Icons/Spell_Holy_BorrowedTime",

        OnClick = function(self, btn)
            if btn == "RightButton" then
                ToggleDropDownMenu(1, nil, menuFrame, self, 0, 0)
            end
        end,

        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("Details Overall Viewer")
            tooltip:AddLine("Modifier: |cff00ff00" .. MODIFIER_LABELS[DetailsOverallViewerDB.modifier] .. "|r")
            tooltip:AddLine("Hold modifier to view Overall")
            tooltip:AddLine("Right-click for options")
        end,
    })

    local icon = LibStub("LibDBIcon-1.0", true)
    icon:Register("DetailsOverallViewer", ldb, DetailsOverallViewerDB.minimap)

    local button = icon:GetMinimapButton("DetailsOverallViewer")
    if button then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            -- Initialize saved variables
            if not DetailsOverallViewerDB then
                DetailsOverallViewerDB = {}
            end
            for k, v in pairs(defaults) do
                if DetailsOverallViewerDB[k] == nil then
                    if type(v) == "table" then
                        DetailsOverallViewerDB[k] = {}
                        for k2, v2 in pairs(v) do
                            DetailsOverallViewerDB[k][k2] = v2
                        end
                    else
                        DetailsOverallViewerDB[k] = v
                    end
                end
            end
            if not DetailsOverallViewerDB.minimap then
                DetailsOverallViewerDB.minimap = { hide = false }
            end

            RefreshWindowDefaults()
            InitMinimapButton()
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "MODIFIER_STATE_CHANGED" then
        local key, down = ...
        if key == DetailsOverallViewerDB.modifier then
            if down == 0 then
                SetView(DETAILS_SEGMENTID_CURRENT)
            else
                SetView(DETAILS_SEGMENTID_OVERALL)
            end
        end
    end
end)
