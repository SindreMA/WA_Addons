local addonName, ns = ...

local settingsFrame = nil
local scrollContent = nil
local rows = {}
local globalEditBox = nil

local ROW_HEIGHT = 26
local FRAME_WIDTH = 500
local FRAME_HEIGHT = 420

-- Create the settings window
local function CreateSettingsFrame()
    local f = CreateFrame("Frame", "FrameScaleSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:Hide()

    -- Title
    f.TitleText:SetText("FrameScale Settings")

    -- ESC to close
    tinsert(UISpecialFrames, "FrameScaleSettingsFrame")

    -- Global scale section - anchored below the title bar
    local globalRow = CreateFrame("Frame", nil, f)
    globalRow:SetSize(FRAME_WIDTH - 20, 30)
    globalRow:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)

    local globalLabel = globalRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    globalLabel:SetPoint("LEFT", globalRow, "LEFT", 0, 0)
    globalLabel:SetText("Global Scale:")

    globalEditBox = CreateFrame("EditBox", nil, globalRow, "InputBoxTemplate")
    globalEditBox:SetSize(60, 22)
    globalEditBox:SetPoint("LEFT", globalLabel, "RIGHT", 8, 0)
    globalEditBox:SetAutoFocus(false)
    globalEditBox:SetNumeric(false)
    globalEditBox:SetMaxLetters(6)
    globalEditBox:SetText(FrameScaleDB.globalScale and string.format("%.2f", FrameScaleDB.globalScale) or "1.00")
    globalEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    globalEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local applyAllBtn = CreateFrame("Button", nil, globalRow, "UIPanelButtonTemplate")
    applyAllBtn:SetSize(80, 22)
    applyAllBtn:SetPoint("LEFT", globalEditBox, "RIGHT", 6, 0)
    applyAllBtn:SetText("Apply All")
    applyAllBtn:SetScript("OnClick", function()
        local val = tonumber(globalEditBox:GetText())
        if not val or val < 0.1 or val > 5.0 then
            ns.Msg("Invalid scale. Use 0.10 - 5.00.")
            return
        end
        FrameScaleDB.globalScale = val
        for frameName, _ in pairs(FrameScaleDB.scales) do
            FrameScaleDB.scales[frameName] = val
            ns.ApplyScale(frameName, val)
        end
        ns.Msg("All frames set to |cffffffff" .. string.format("%.2f", val) .. "|r.")
        ns.RefreshSettings()
    end)

    local resetAllBtn = CreateFrame("Button", nil, globalRow, "UIPanelButtonTemplate")
    resetAllBtn:SetSize(80, 22)
    resetAllBtn:SetPoint("LEFT", applyAllBtn, "RIGHT", 4, 0)
    resetAllBtn:SetText("Reset All")
    resetAllBtn:SetScript("OnClick", function()
        for frameName, _ in pairs(FrameScaleDB.scales) do
            ns.ApplyScale(frameName, 1.0)
        end
        wipe(FrameScaleDB.scales)
        FrameScaleDB.globalScale = nil
        globalEditBox:SetText("1.00")
        ns.Msg("All scales reset to |cffffffff1.00|r.")
        ns.RefreshSettings()
    end)

    -- Separator line
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", globalRow, "BOTTOMLEFT", 0, -4)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, 0)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.5)

    -- Column headers
    local headerRow = CreateFrame("Frame", nil, f)
    headerRow:SetSize(FRAME_WIDTH - 20, 16)
    headerRow:SetPoint("TOPLEFT", globalRow, "BOTTOMLEFT", 0, -8)

    local nameHeader = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameHeader:SetPoint("LEFT", headerRow, "LEFT", 4, 0)
    nameHeader:SetText("Frame Name")
    nameHeader:SetTextColor(0.7, 0.7, 0.7)

    local scaleHeader = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleHeader:SetPoint("LEFT", headerRow, "LEFT", 260, 0)
    scaleHeader:SetText("Scale")
    scaleHeader:SetTextColor(0.7, 0.7, 0.7)

    -- Scroll frame for the list
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", -4, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)

    scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(FRAME_WIDTH - 40, 1) -- height set dynamically
    scrollFrame:SetScrollChild(scrollContent)

    settingsFrame = f
    return f
end

-- Create a single row in the list
local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(FRAME_WIDTH - 50, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    -- Alternating background
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)

    -- Frame name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
    nameText:SetWidth(240)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Scale input
    local editBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    editBox:SetSize(50, 20)
    editBox:SetPoint("LEFT", row, "LEFT", 252, 0)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(false)
    editBox:SetMaxLetters(6)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    row.editBox = editBox

    -- Apply button
    local applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    applyBtn:SetSize(50, 20)
    applyBtn:SetPoint("LEFT", editBox, "RIGHT", 4, 0)
    applyBtn:SetText("Apply")
    row.applyBtn = applyBtn

    -- Remove button
    local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    removeBtn:SetSize(20, 20)
    removeBtn:SetPoint("LEFT", applyBtn, "RIGHT", 2, 0)
    removeBtn:SetText("X")
    removeBtn:GetFontString():SetTextColor(1, 0.3, 0.3)
    row.removeBtn = removeBtn

    row:Hide()
    return row
end

-- Refresh the settings list
function ns.RefreshSettings()
    if not settingsFrame or not settingsFrame:IsShown() then return end

    -- Update global scale box
    if globalEditBox then
        globalEditBox:SetText(FrameScaleDB.globalScale and string.format("%.2f", FrameScaleDB.globalScale) or "1.00")
    end

    -- Gather sorted frame names
    local frameNames = {}
    for name, _ in pairs(FrameScaleDB.scales) do
        table.insert(frameNames, name)
    end
    table.sort(frameNames)

    -- Ensure enough rows
    while #rows < #frameNames do
        table.insert(rows, CreateRow(scrollContent, #rows + 1))
    end

    -- Populate rows
    for i, frameName in ipairs(frameNames) do
        local row = rows[i]
        local scale = FrameScaleDB.scales[frameName]

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
        row.nameText:SetText(frameName)
        row.editBox:SetText(string.format("%.2f", scale))

        row.applyBtn:SetScript("OnClick", function()
            local val = tonumber(row.editBox:GetText())
            if not val or val < 0.1 or val > 5.0 then
                ns.Msg("Invalid scale for " .. frameName .. ". Use 0.10 - 5.00.")
                return
            end
            FrameScaleDB.scales[frameName] = val
            ns.ApplyScale(frameName, val)
            ns.Msg(frameName .. " set to |cffffffff" .. string.format("%.2f", val) .. "|r.")
        end)

        row.editBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            row.applyBtn:Click()
        end)

        row.removeBtn:SetScript("OnClick", function()
            ns.ApplyScale(frameName, 1.0)
            FrameScaleDB.scales[frameName] = nil
            ns.Msg("Removed |cffffffff" .. frameName .. "|r (reset to 1.0).")
            ns.RefreshSettings()
        end)

        row:Show()
    end

    -- Hide unused rows
    for i = #frameNames + 1, #rows do
        rows[i]:Hide()
    end

    -- Update scroll content height
    scrollContent:SetHeight(math.max(1, #frameNames * ROW_HEIGHT))

    -- Show empty message
    if #frameNames == 0 then
        if not scrollContent.emptyText then
            scrollContent.emptyText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            scrollContent.emptyText:SetPoint("CENTER", scrollContent:GetParent(), "CENTER", 0, 0)
            scrollContent.emptyText:SetText("No frames scaled yet.\nUse scale mode to add frames.")
        end
        scrollContent.emptyText:Show()
    elseif scrollContent.emptyText then
        scrollContent.emptyText:Hide()
    end
end

-- Toggle settings window
function ns.ToggleSettings()
    if not settingsFrame then
        CreateSettingsFrame()
    end
    if settingsFrame:IsShown() then
        settingsFrame:Hide()
    else
        settingsFrame:Show()
        ns.RefreshSettings()
    end
end
