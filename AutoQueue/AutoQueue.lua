local addonName = ...

-- SavedVariables defaults
local defaults = {
    active = true,
    minimap = { hide = false },
}

-- Event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("LFG_ROLE_CHECK_SHOW")

local function InitMinimapButton()
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
        end,
    })

    local icon = LibStub("LibDBIcon-1.0", true)
    icon:Register("AutoQueue", ldb, AutoQueueDB.minimap)
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
    end
end)
