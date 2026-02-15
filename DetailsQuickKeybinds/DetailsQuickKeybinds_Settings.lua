local addonName, ns = ...

local FRAME_WIDTH = 600
local FRAME_HEIGHT = 500
local BIND_HEADER_HEIGHT = 30
local ACTION_ROW_HEIGHT = 26
local BIND_PADDING = 6

local settingsFrame

-- Flat list of "Attribute > Sub" for dropdown
local function BuildViewOptions()
    local options = { { label = "No Change", attribute = nil, sub_attribute = nil } }
    for _, attr in ipairs(ns.ATTRIBUTES) do
        for _, sub in ipairs(attr.subs) do
            table.insert(options, {
                label = attr.name .. " > " .. sub.name,
                attribute = attr.id,
                sub_attribute = sub.id,
            })
        end
    end
    return options
end

local VIEW_OPTIONS = BuildViewOptions()

-- Find index in VIEW_OPTIONS matching attribute/sub_attribute
local function FindViewIndex(attribute, sub_attribute)
    if not attribute then return 1 end
    for i, opt in ipairs(VIEW_OPTIONS) do
        if opt.attribute == attribute and opt.sub_attribute == sub_attribute then
            return i
        end
    end
    return 1
end

-- Window display label
local function WindowLabel(windowId)
    if windowId == ns.ALL_WINDOWS then return "All" end
    return "" .. windowId
end

-- Simple dropdown helper using UIDropDownMenu
local dropdownCounter = 0
local function CreateDropdown(parent, width, initFunc)
    dropdownCounter = dropdownCounter + 1
    local name = "DQKDropdown" .. dropdownCounter
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width)
    UIDropDownMenu_Initialize(dd, initFunc)
    return dd
end

local function RefreshSettings()
    if not settingsFrame or not settingsFrame:IsShown() then return end

    local content = settingsFrame.scrollContent
    -- Hide all existing children
    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
    end

    local binds = DetailsQuickKeybindsDB.binds
    local yOffset = 0

    for bindIdx, bind in ipairs(binds) do
        -- Bind container frame
        local bindFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
        bindFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        bindFrame:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        bindFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        bindFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        bindFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)

        -- Header row
        local headerRow = CreateFrame("Frame", nil, bindFrame)
        headerRow:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 4, -4)
        headerRow:SetPoint("RIGHT", bindFrame, "RIGHT", -4, 0)
        headerRow:SetHeight(BIND_HEADER_HEIGHT)

        -- Name input
        local nameLabel = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameLabel:SetPoint("LEFT", headerRow, "LEFT", 4, 0)
        nameLabel:SetText("Name:")

        local nameBox = CreateFrame("EditBox", nil, headerRow, "InputBoxTemplate")
        nameBox:SetSize(120, 20)
        nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
        nameBox:SetAutoFocus(false)
        nameBox:SetText(bind.name or "")
        nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        nameBox:SetScript("OnEditFocusLost", function(self)
            binds[bindIdx].name = self:GetText()
        end)

        -- Key dropdown
        local keyLabel = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        keyLabel:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
        keyLabel:SetText("Key:")

        local keyDD = CreateDropdown(headerRow, 90, function(self, level)
            for _, key in ipairs(ns.MODIFIERS) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = ns.MODIFIER_LABELS[key]
                info.checked = (bind.key == key)
                info.func = function()
                    binds[bindIdx].key = key
                    CloseDropDownMenus()
                    RefreshSettings()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        keyDD:SetPoint("LEFT", keyLabel, "RIGHT", -8, -2)
        UIDropDownMenu_SetText(keyDD, ns.MODIFIER_LABELS[bind.key] or bind.key)

        -- Mode dropdown (wider to fit "Toggle")
        local modeLabel = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        modeLabel:SetPoint("LEFT", keyDD, "RIGHT", 0, 2)
        modeLabel:SetText("Mode:")

        local modeDD = CreateDropdown(headerRow, 80, function(self, level)
            for _, mode in ipairs({ "hold", "toggle" }) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = mode:sub(1, 1):upper() .. mode:sub(2)
                info.checked = (bind.mode == mode)
                info.func = function()
                    binds[bindIdx].mode = mode
                    CloseDropDownMenus()
                    RefreshSettings()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        modeDD:SetPoint("LEFT", modeLabel, "RIGHT", -8, -2)
        UIDropDownMenu_SetText(modeDD, bind.mode:sub(1, 1):upper() .. bind.mode:sub(2))

        -- Delete bind button
        local deleteBtn = CreateFrame("Button", nil, headerRow, "UIPanelButtonTemplate")
        deleteBtn:SetSize(20, 20)
        deleteBtn:SetPoint("RIGHT", headerRow, "RIGHT", -4, 0)
        deleteBtn:SetText("X")
        deleteBtn:SetScript("OnClick", function()
            table.remove(binds, bindIdx)
            RefreshSettings()
        end)

        -- Action rows
        local actionYOffset = -(BIND_HEADER_HEIGHT + 8)

        -- Column headers
        local colHeader = CreateFrame("Frame", nil, bindFrame)
        colHeader:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 8, actionYOffset)
        colHeader:SetPoint("RIGHT", bindFrame, "RIGHT", -8, 0)
        colHeader:SetHeight(16)

        local colWin = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colWin:SetPoint("LEFT", colHeader, "LEFT", 0, 0)
        colWin:SetText("|cff888888Window|r")

        local colSeg = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colSeg:SetPoint("LEFT", colHeader, "LEFT", 70, 0)
        colSeg:SetText("|cff888888Segment|r")

        local colView = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colView:SetPoint("LEFT", colHeader, "LEFT", 210, 0)
        colView:SetText("|cff888888View|r")

        actionYOffset = actionYOffset - 18

        -- Sort window IDs for display (All=0 first, then 1, 2, 3...)
        local windowIds = {}
        for wid in pairs(bind.actions) do
            table.insert(windowIds, wid)
        end
        table.sort(windowIds)

        for _, windowId in ipairs(windowIds) do
            local action = bind.actions[windowId]

            local actionRow = CreateFrame("Frame", nil, bindFrame)
            actionRow:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 8, actionYOffset)
            actionRow:SetPoint("RIGHT", bindFrame, "RIGHT", -8, 0)
            actionRow:SetHeight(ACTION_ROW_HEIGHT)

            -- Background
            local bg = actionRow:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)

            -- Window ID dropdown (with "All" option)
            local winDD = CreateDropdown(actionRow, 50, function(self, level)
                -- "All" option
                local info = UIDropDownMenu_CreateInfo()
                info.text = "All"
                info.checked = (windowId == ns.ALL_WINDOWS)
                info.func = function()
                    if ns.ALL_WINDOWS ~= windowId then
                        bind.actions[ns.ALL_WINDOWS] = bind.actions[windowId]
                        bind.actions[windowId] = nil
                    end
                    CloseDropDownMenus()
                    RefreshSettings()
                end
                UIDropDownMenu_AddButton(info, level)

                -- Individual windows
                local numWins = (Details and Details.GetNumInstances and Details:GetNumInstances()) or 5
                for wid = 1, math.max(numWins, 5) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "" .. wid
                    info.checked = (windowId == wid)
                    info.func = function()
                        if wid ~= windowId then
                            bind.actions[wid] = bind.actions[windowId]
                            bind.actions[windowId] = nil
                        end
                        CloseDropDownMenus()
                        RefreshSettings()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
            winDD:SetPoint("LEFT", actionRow, "LEFT", -16, 0)
            UIDropDownMenu_SetText(winDD, WindowLabel(windowId))

            -- Segment dropdown
            local segDD = CreateDropdown(actionRow, 70, function(self, level)
                -- No Change option
                local info = UIDropDownMenu_CreateInfo()
                info.text = "No Change"
                info.checked = (action.segment == nil)
                info.func = function()
                    binds[bindIdx].actions[windowId].segment = nil
                    CloseDropDownMenus()
                    RefreshSettings()
                end
                UIDropDownMenu_AddButton(info, level)

                for _, seg in ipairs(ns.SEGMENTS) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = seg.name
                    info.checked = (action.segment == seg.id)
                    info.func = function()
                        binds[bindIdx].actions[windowId].segment = seg.id
                        CloseDropDownMenus()
                        RefreshSettings()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
            segDD:SetPoint("LEFT", actionRow, "LEFT", 60, 0)
            local segText = "No Change"
            if action.segment then
                for _, seg in ipairs(ns.SEGMENTS) do
                    if seg.id == action.segment then segText = seg.name break end
                end
            end
            UIDropDownMenu_SetText(segDD, segText)

            -- View dropdown (Attribute > Sub-attribute)
            local viewDD = CreateDropdown(actionRow, 130, function(self, level)
                for i, opt in ipairs(VIEW_OPTIONS) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = opt.label
                    info.checked = (FindViewIndex(action.attribute, action.sub_attribute) == i)
                    info.func = function()
                        binds[bindIdx].actions[windowId].attribute = opt.attribute
                        binds[bindIdx].actions[windowId].sub_attribute = opt.sub_attribute
                        CloseDropDownMenus()
                        RefreshSettings()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
            viewDD:SetPoint("LEFT", actionRow, "LEFT", 200, 0)
            local viewText = VIEW_OPTIONS[FindViewIndex(action.attribute, action.sub_attribute)].label
            UIDropDownMenu_SetText(viewDD, viewText)

            -- Remove action button
            local removeBtn = CreateFrame("Button", nil, actionRow, "UIPanelButtonTemplate")
            removeBtn:SetSize(20, 20)
            removeBtn:SetPoint("RIGHT", actionRow, "RIGHT", 0, 0)
            removeBtn:SetText("X")
            removeBtn:SetScript("OnClick", function()
                bind.actions[windowId] = nil
                RefreshSettings()
            end)

            actionYOffset = actionYOffset - ACTION_ROW_HEIGHT
        end

        -- Add action button
        local addActionBtn = CreateFrame("Button", nil, bindFrame, "UIPanelButtonTemplate")
        addActionBtn:SetSize(130, 20)
        addActionBtn:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 8, actionYOffset - 4)
        addActionBtn:SetText("+ Add Window")
        addActionBtn:SetScript("OnClick", function()
            -- Find next unused window ID (skip 0=All, start at 1)
            local nextId = 1
            while bind.actions[nextId] do nextId = nextId + 1 end
            bind.actions[nextId] = { segment = -1 }
            RefreshSettings()
        end)

        actionYOffset = actionYOffset - 28

        local bindHeight = math.abs(actionYOffset) + 8
        bindFrame:SetHeight(bindHeight)

        yOffset = yOffset + bindHeight + BIND_PADDING
    end

    -- Add new keybind button
    local addBindBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    addBindBtn:SetSize(160, 24)
    addBindBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOffset - 4)
    addBindBtn:SetText("+ Add New Keybind")
    addBindBtn:SetScript("OnClick", function()
        table.insert(binds, {
            name = "New Keybind",
            key = "LALT",
            mode = "hold",
            actions = {},
        })
        RefreshSettings()
    end)

    yOffset = yOffset + 36
    content:SetHeight(math.max(yOffset, FRAME_HEIGHT - 60))
end

local function CreateSettingsFrame()
    local f = CreateFrame("Frame", "DetailsQuickKeybindsSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")

    tinsert(UISpecialFrames, "DetailsQuickKeybindsSettingsFrame")

    f.TitleBg:SetHeight(30)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOPLEFT", f.TitleBg, "TOPLEFT", 6, -3)
    f.title:SetText("Details Quick Keybinds")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f.InsetBg, "TOPLEFT", 6, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", f.InsetBg, "BOTTOMRIGHT", -24, 6)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(FRAME_WIDTH - 56)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)

    f.scrollContent = scrollContent
    f:SetScript("OnShow", RefreshSettings)

    return f
end

function ns.ToggleSettings()
    if not settingsFrame then
        settingsFrame = CreateSettingsFrame()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
    end
end
