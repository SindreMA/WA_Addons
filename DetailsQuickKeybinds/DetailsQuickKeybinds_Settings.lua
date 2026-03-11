local addonName, ns = ...

local FRAME_WIDTH = 620
local FRAME_HEIGHT = 500
local BIND_HEADER_HEIGHT = 30
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

local function FindViewIndex(attribute, sub_attribute)
    if not attribute then return 1 end
    for i, opt in ipairs(VIEW_OPTIONS) do
        if opt.attribute == attribute and opt.sub_attribute == sub_attribute then
            return i
        end
    end
    return 1
end

local function WindowLabel(windowId)
    if windowId == ns.ALL_WINDOWS then return "All" end
    return "" .. windowId
end

local function SegmentLabel(segId)
    if segId == nil then return "No Change" end
    for _, seg in ipairs(ns.SEGMENTS) do
        if seg.id == segId then return seg.name end
    end
    return "No Change"
end

-- Simple dropdown helper
local dropdownCounter = 0
local function CreateDropdown(parent, width, initFunc)
    dropdownCounter = dropdownCounter + 1
    local name = "DQKDropdown" .. dropdownCounter
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, width)
    UIDropDownMenu_Initialize(dd, initFunc)
    return dd
end

-- Create a state row (segment + view dropdowns)
local function CreateStateRow(parent, bindFrame, label, stateData, yOffset, onChanged)
    local row = CreateFrame("Frame", nil, bindFrame)
    row:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 8, yOffset)
    row:SetPoint("RIGHT", bindFrame, "RIGHT", -8, 0)
    row:SetHeight(26)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.15, 0.15, 0.15, 0.3)

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 4, 0)
    lbl:SetText(label)
    lbl:SetWidth(50)

    -- Segment dropdown
    local segDD = CreateDropdown(row, 70, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = "No Change"
        info.checked = (stateData.segment == nil)
        info.func = function()
            stateData.segment = nil
            CloseDropDownMenus()
            onChanged()
        end
        UIDropDownMenu_AddButton(info, level)

        for _, seg in ipairs(ns.SEGMENTS) do
            info = UIDropDownMenu_CreateInfo()
            info.text = seg.name
            info.checked = (stateData.segment == seg.id)
            info.func = function()
                stateData.segment = seg.id
                CloseDropDownMenus()
                onChanged()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    segDD:SetPoint("LEFT", row, "LEFT", 44, 0)
    UIDropDownMenu_SetText(segDD, SegmentLabel(stateData.segment))

    -- View dropdown
    local viewDD = CreateDropdown(row, 130, function(self, level)
        for i, opt in ipairs(VIEW_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = opt.label
            info.checked = (FindViewIndex(stateData.attribute, stateData.sub_attribute) == i)
            info.func = function()
                stateData.attribute = opt.attribute
                stateData.sub_attribute = opt.sub_attribute
                CloseDropDownMenus()
                onChanged()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    viewDD:SetPoint("LEFT", row, "LEFT", 190, 0)
    local viewText = VIEW_OPTIONS[FindViewIndex(stateData.attribute, stateData.sub_attribute)].label
    UIDropDownMenu_SetText(viewDD, viewText)

    return row
end

local function RefreshSettings()
    if not settingsFrame or not settingsFrame:IsShown() then return end

    local content = settingsFrame.scrollContent
    for _, child in ipairs({ content:GetChildren() }) do
        child:Hide()
    end

    local binds = DetailsQuickKeybindsDB.binds
    local yOffset = 0

    for bindIdx, bind in ipairs(binds) do
        local bindFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
        bindFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        bindFrame:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        bindFrame:SetBackdrop({ bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        bindFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        bindFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)

        -- Header row: Name, Key, Mode, Delete
        local headerRow = CreateFrame("Frame", nil, bindFrame)
        headerRow:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 4, -4)
        headerRow:SetPoint("RIGHT", bindFrame, "RIGHT", -4, 0)
        headerRow:SetHeight(BIND_HEADER_HEIGHT)

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

        local deleteBtn = CreateFrame("Button", nil, headerRow, "UIPanelButtonTemplate")
        deleteBtn:SetSize(20, 20)
        deleteBtn:SetPoint("RIGHT", headerRow, "RIGHT", -4, 0)
        deleteBtn:SetText("X")
        deleteBtn:SetScript("OnClick", function()
            table.remove(binds, bindIdx)
            RefreshSettings()
        end)

        -- Window entries
        local innerY = -(BIND_HEADER_HEIGHT + 4)

        -- Column headers
        local colHeader = CreateFrame("Frame", nil, bindFrame)
        colHeader:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 8, innerY)
        colHeader:SetPoint("RIGHT", bindFrame, "RIGHT", -8, 0)
        colHeader:SetHeight(14)

        local colWin = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colWin:SetPoint("LEFT", colHeader, "LEFT", 0, 0)
        colWin:SetText("|cff888888Window|r")

        local colSeg = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colSeg:SetPoint("LEFT", colHeader, "LEFT", 60, 0)
        colSeg:SetText("|cff888888Segment|r")

        local colView = colHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        colView:SetPoint("LEFT", colHeader, "LEFT", 200, 0)
        colView:SetText("|cff888888View|r")

        innerY = innerY - 16

        -- Sort window IDs
        local windowIds = {}
        for wid in pairs(bind.windows) do
            table.insert(windowIds, wid)
        end
        table.sort(windowIds)

        for _, windowId in ipairs(windowIds) do
            local winConfig = bind.windows[windowId]

            -- Window label + remove button
            local winHeader = CreateFrame("Frame", nil, bindFrame)
            winHeader:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 8, innerY)
            winHeader:SetPoint("RIGHT", bindFrame, "RIGHT", -8, 0)
            winHeader:SetHeight(20)

            local winDD = CreateDropdown(winHeader, 44, function(self, level)
                local info = UIDropDownMenu_CreateInfo()
                info.text = "All"
                info.checked = (windowId == ns.ALL_WINDOWS)
                info.func = function()
                    if ns.ALL_WINDOWS ~= windowId then
                        bind.windows[ns.ALL_WINDOWS] = bind.windows[windowId]
                        bind.windows[windowId] = nil
                    end
                    CloseDropDownMenus()
                    RefreshSettings()
                end
                UIDropDownMenu_AddButton(info, level)

                local numWins = (Details and Details.GetNumInstances and Details:GetNumInstances()) or 5
                for wid = 1, math.max(numWins, 5) do
                    info = UIDropDownMenu_CreateInfo()
                    info.text = "" .. wid
                    info.checked = (windowId == wid)
                    info.func = function()
                        if wid ~= windowId then
                            bind.windows[wid] = bind.windows[windowId]
                            bind.windows[windowId] = nil
                        end
                        CloseDropDownMenus()
                        RefreshSettings()
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
            winDD:SetPoint("LEFT", winHeader, "LEFT", -16, 0)
            UIDropDownMenu_SetText(winDD, WindowLabel(windowId))

            local removeBtn = CreateFrame("Button", nil, winHeader, "UIPanelButtonTemplate")
            removeBtn:SetSize(20, 20)
            removeBtn:SetPoint("RIGHT", winHeader, "RIGHT", 0, 0)
            removeBtn:SetText("X")
            removeBtn:SetScript("OnClick", function()
                bind.windows[windowId] = nil
                RefreshSettings()
            end)

            innerY = innerY - 22

            -- State 1 row
            if not winConfig.state1 then winConfig.state1 = {} end
            CreateStateRow(content, bindFrame, "|cff88ff88S1|r", winConfig.state1, innerY, RefreshSettings)
            innerY = innerY - 28

            -- State 2 row
            if not winConfig.state2 then winConfig.state2 = {} end
            CreateStateRow(content, bindFrame, "|cffff8888S2|r", winConfig.state2, innerY, RefreshSettings)
            innerY = innerY - 30
        end

        -- Add window button
        local addWinBtn = CreateFrame("Button", nil, bindFrame, "UIPanelButtonTemplate")
        addWinBtn:SetSize(130, 20)
        addWinBtn:SetPoint("TOPLEFT", bindFrame, "TOPLEFT", 8, innerY - 2)
        addWinBtn:SetText("+ Add Window")
        addWinBtn:SetScript("OnClick", function()
            local nextId = 1
            while bind.windows[nextId] do nextId = nextId + 1 end
            bind.windows[nextId] = {
                state1 = { attribute = 1, sub_attribute = 1 },
                state2 = {},
            }
            RefreshSettings()
        end)

        innerY = innerY - 26

        local bindHeight = math.abs(innerY) + 8
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
            windows = {},
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

    -- Debug toggle in title bar
    local debugCheck = CreateFrame("CheckButton", "DQKDebugCheckbox", f, "UICheckButtonTemplate")
    debugCheck:SetPoint("RIGHT", f.CloseButton, "LEFT", -4, 0)
    debugCheck:SetSize(24, 24)
    debugCheck:SetChecked(ns.debugEnabled)
    debugCheck:SetScript("OnClick", function(self)
        ns.debugEnabled = self:GetChecked()
    end)
    local debugLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    debugLabel:SetPoint("RIGHT", debugCheck, "LEFT", -2, 0)
    debugLabel:SetText("Debug")

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
