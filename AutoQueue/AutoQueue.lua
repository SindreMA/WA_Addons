local addonName = ...

-- SavedVariables defaults
local defaults = {
    active = true,
    autoReady = false,
    minimap = { hide = false },
}

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
frame:RegisterEvent("READY_CHECK")

-- Right-click dropdown menu
local menuFrame = CreateFrame("Frame", "AutoQueueMenu", UIParent, "UIDropDownMenuTemplate")

local function InitMenu(self, level)
    local info = UIDropDownMenu_CreateInfo()

    info.isTitle = true
    info.text = "|cffb048f8AutoQueue|r"
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Auto Queue"
    info.checked = function() return AutoQueueDB.active end
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.func = function()
        AutoQueueDB.active = not AutoQueueDB.active
        if AutoQueueDB.active then
            print("|cffb048f8AutoQueue:|r Auto Queue |cff00ff00enabled|r.")
        else
            print("|cffb048f8AutoQueue:|r Auto Queue |cffff0000disabled|r.")
        end
    end
    UIDropDownMenu_AddButton(info, level)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Auto Ready Check"
    info.checked = function() return AutoQueueDB.autoReady end
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.func = function()
        AutoQueueDB.autoReady = not AutoQueueDB.autoReady
        if AutoQueueDB.autoReady then
            print("|cffb048f8AutoQueue:|r Auto Ready Check |cff00ff00enabled|r.")
        else
            print("|cffb048f8AutoQueue:|r Auto Ready Check |cffff0000disabled|r.")
        end
    end
    UIDropDownMenu_AddButton(info, level)
end

local function InitMinimapButton()
    UIDropDownMenu_Initialize(menuFrame, InitMenu, "MENU")

    local img = AutoQueueDB.active
        and "Interface/COMMON/Indicator-Green.png"
        or "Interface/COMMON/Indicator-Red.png"

    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("AutoQueue", {
        type = "data source",
        text = "AutoQueue",
        icon = img,

        OnClick = function(self, btn)
            if btn == "LeftButton" then
                AutoQueueDB.active = not AutoQueueDB.active
                if AutoQueueDB.active then
                    self.icon:SetTexture("Interface/COMMON/Indicator-Green.png")
                    print("|cffb048f8AutoQueue:|r Enabled.")
                else
                    self.icon:SetTexture("Interface/COMMON/Indicator-Red.png")
                    print("|cffb048f8AutoQueue:|r Disabled.")
                end
            elseif btn == "RightButton" then
                ToggleDropDownMenu(1, nil, menuFrame, self, 0, 0)
            end
        end,

        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("AutoQueue")
            if AutoQueueDB.active then
                tooltip:AddLine("Status: |cff00ff00Active|r")
            else
                tooltip:AddLine("Status: |cffff0000Disabled|r")
            end
            tooltip:AddLine("Left-click to toggle")
            tooltip:AddLine("Right-click for options")
        end,
    })

    local icon = LibStub("LibDBIcon-1.0", true)
    icon:Register("AutoQueue", ldb, AutoQueueDB.minimap)

    local button = icon:GetMinimapButton("AutoQueue")
    if button then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            -- Initialize saved variables
            if not AutoQueueDB then
                AutoQueueDB = {}
            end
            for k, v in pairs(defaults) do
                if AutoQueueDB[k] == nil then
                    AutoQueueDB[k] = v
                end
            end
            if not AutoQueueDB.minimap then
                AutoQueueDB.minimap = { hide = false }
            end

            InitMinimapButton()
            self:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "LFG_ROLE_CHECK_SHOW" then
        if AutoQueueDB and AutoQueueDB.active then
            CompleteLFGRoleCheck(true)
            print("|cffb048f8AutoQueue:|r Rolecheck accepted.")
        end

    elseif event == "READY_CHECK" then
        if AutoQueueDB and AutoQueueDB.autoReady then
            ConfirmReadyCheck()
            print("|cffb048f8AutoQueue:|r Ready check accepted.")
        end
    end
end)
