local _, ns = ...
local Data = ns.Data

-- Layout mirrors the modern Blizzard Auction House "Buy" tab.
local FRAME_W, FRAME_H = 800, 538
local CAT_W = 168
local ROW_H = 20
local CAT_ROW_H = 20

local COLUMNS = {
  { key = "price",     label = AUCTION_HOUSE_BROWSE_HEADER_PRICE or "Price", width = 150, justify = "RIGHT" },
  { key = "name",      label = NAME or "Name",                                width = 270, justify = "LEFT" },
  { key = "level",     label = "Lvl",                                         width = 44,  justify = "CENTER" },
  { key = "available", label = AUCTION_HOUSE_BROWSE_HEADER_QUANTITY or "Available", width = 66, justify = "RIGHT" },
  { key = "age",       label = "Seen",                                        width = 64,  justify = "RIGHT",
    tooltip = "How long ago Auctionator last saw this item on the Auction House." },
}

local HISTORY_COLUMNS = {
  { key = "date",      label = "Date",      width = 210, justify = "LEFT" },
  { key = "low",       label = "Lowest",    width = 140, justify = "RIGHT" },
  { key = "high",      label = "Highest",   width = 140, justify = "RIGHT" },
  { key = "available", label = "Available", width = 94,  justify = "RIGHT" },
}

local state = {
  category = nil,
  sortKey = "price",
  ascending = true,
  mode = "idle",
  selected = nil,
  results = {},
}

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function HasTemplate(name)
  if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
    return C_XMLUtil.GetTemplateInfo(name) ~= nil
  end
  return true
end

local function HasAtlas(atlas)
  return atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
end

-- Sets the first atlas that exists, otherwise the fallback (color table or file path).
local function SetAtlasOr(tex, atlases, fallback)
  if type(atlases) == "string" then atlases = { atlases } end
  for _, atlas in ipairs(atlases or {}) do
    if HasAtlas(atlas) then
      tex:SetAtlas(atlas)
      return true
    end
  end
  if type(fallback) == "table" then
    tex:SetColorTexture(unpack(fallback))
  elseif type(fallback) == "string" then
    tex:SetTexture(fallback)
  else
    tex:Hide()
  end
  return false
end

local function Money(copper)
  if not copper then return "" end
  if GetMoneyString then return GetMoneyString(copper, true) end
  return tostring(copper)
end

local function QualityColor(q)
  local c = (ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1])
  if c then return c.r, c.g, c.b, c.hex end
  return 1, 1, 1, "|cffffffff"
end

local function AgeText(age)
  if not age then return "|cff808080?|r" end
  if age <= 0 then return "|cff40ff40Today|r" end
  if age == 1 then return "|cffffffff1 day|r" end
  if age <= 3 then return "|cffffffff" .. age .. " days|r" end
  if age <= 7 then return "|cffffd200" .. age .. " days|r" end
  return "|cffff6060" .. age .. " days|r"
end

local function Number(n)
  if not n then return "|cff808080-|r" end
  if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
  return tostring(n)
end

local function PlaySoundKit(name)
  if SOUNDKIT and SOUNDKIT[name] then PlaySound(SOUNDKIT[name]) end
end

local function NewFont(parent, font, justify, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", font)
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  return fs
end

---------------------------------------------------------------------------
-- column headers
---------------------------------------------------------------------------
local function CreateHeader(parent, col, onClick)
  local useTemplate = HasTemplate("ColumnDisplayButtonShortTemplate")
  local b = CreateFrame("Button", nil, parent, useTemplate and "ColumnDisplayButtonShortTemplate" or nil)
  b:SetSize(col.width, 19)

  if not useTemplate then
    local file = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs"
    local l = b:CreateTexture(nil, "BACKGROUND")
    l:SetTexture(file); l:SetSize(5, 19); l:SetPoint("TOPLEFT"); l:SetTexCoord(0, 0.078125, 0, 0.59375)
    local r = b:CreateTexture(nil, "BACKGROUND")
    r:SetTexture(file); r:SetSize(4, 19); r:SetPoint("TOPRIGHT"); r:SetTexCoord(0.90625, 0.96875, 0, 0.59375)
    local m = b:CreateTexture(nil, "BACKGROUND")
    m:SetTexture(file); m:SetPoint("LEFT", l, "RIGHT"); m:SetPoint("RIGHT", r, "LEFT"); m:SetHeight(19)
    m:SetTexCoord(0.078125, 0.90625, 0, 0.59375)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
    hl:SetBlendMode("ADD"); hl:SetPoint("TOPLEFT", 0, 4); hl:SetPoint("BOTTOMRIGHT", 0, -4)
  end

  local text = b.Text or b:GetFontString()
  if not text then
    text = NewFont(b, "GameFontHighlightSmall")
    b:SetFontString(text)
  end
  b:SetText(col.label)
  text = b:GetFontString() or text
  text:ClearAllPoints()
  if col.justify == "RIGHT" then
    text:SetPoint("RIGHT", -14, 0)
  elseif col.justify == "CENTER" then
    text:SetPoint("CENTER")
  else
    text:SetPoint("LEFT", 8, 0)
  end

  local arrow = b:CreateTexture(nil, "OVERLAY")
  if not SetAtlasOr(arrow, "auctionhouse-ui-sortarrow", "Interface\\Buttons\\UI-SortArrow") then
    arrow:SetSize(9, 8)
  else
    arrow:SetSize(9, 7)
  end
  arrow:SetPoint("LEFT", text, "RIGHT", 3, 0)
  arrow:Hide()
  b.Arrow = arrow
  b.col = col

  if onClick then b:SetScript("OnClick", onClick) end
  if col.tooltip then
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(col.label, 1, 1, 1)
      GameTooltip:AddLine(col.tooltip, nil, nil, nil, true)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
  end
  return b
end

local function LayoutHeaders(parent, columns, onClick)
  local headers, x = {}, 0
  for i, col in ipairs(columns) do
    local h = CreateHeader(parent, col, onClick)
    h:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
    x = x + col.width - 2
    headers[i] = h
  end
  return headers
end

---------------------------------------------------------------------------
-- scroll lists
---------------------------------------------------------------------------
local function CreateList(parent, rowHeight, initRow, updateRow)
  local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
  local barTemplate = HasTemplate("WowTrimScrollBar") and "WowTrimScrollBar" or "MinimalScrollBar"
  local bar = CreateFrame("EventFrame", nil, parent, barTemplate)
  local view = CreateScrollBoxListLinearView()
  view:SetElementExtent(rowHeight)
  view:SetElementInitializer("Button", function(row, data)
    if not row.pahInit then
      initRow(row)
      row.pahInit = true
    end
    updateRow(row, data)
  end)
  ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
  box.updateRow = updateRow
  return box, bar
end

local function SetListData(box, list, keepScroll)
  for i, item in ipairs(list) do item._odd = (i % 2 == 1) end
  local provider = CreateDataProvider(list)
  if keepScroll and ScrollBoxConstants then
    box:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
  else
    box:SetDataProvider(provider)
  end
end

local function RefreshVisibleRows(box)
  if box.ForEachFrame then
    box:ForEachFrame(function(row, data) box.updateRow(row, data) end)
  end
end

---------------------------------------------------------------------------
-- frame
---------------------------------------------------------------------------
local frame

local function SavePosition()
  local p, _, rp, x, y = frame:GetPoint()
  ns.db.point = { p, rp, x, y }
end

local function SetTitle(f, text)
  if f.SetTitle then
    f:SetTitle(text)
  elseif f.TitleContainer and f.TitleContainer.TitleText then
    f.TitleContainer.TitleText:SetText(text)
  elseif f.TitleText then
    f.TitleText:SetText(text)
  end
end

local function SetPortrait(f, file)
  if f.SetPortraitToAsset then
    f:SetPortraitToAsset(file)
  elseif f.PortraitContainer and f.PortraitContainer.portrait then
    SetPortraitToTexture(f.PortraitContainer.portrait, file)
  elseif f.portrait then
    SetPortraitToTexture(f.portrait, file)
  end
end

local UpdateCategories, RunSearch, ShowDetail, ShowList, UpdateHeaders, UpdateStatus, UpdateMoney
local UpdateSourceTabs, UpdateTitle

-- category list ------------------------------------------------------------
local CAT_STYLE = {
  [1] = { normal = { "auctionhouse-nav-button" }, select = { "auctionhouse-nav-button-select" },
          highlight = { "auctionhouse-nav-button-highlight" }, font = "GameFontNormalSmall", indent = 10,
          fallback = { 0.24, 0.18, 0.08, 0.9 } },
  [2] = { normal = { "auctionhouse-nav-button-secondary" }, select = { "auctionhouse-nav-button-secondary-select", "auctionhouse-nav-button-select" },
          highlight = { "auctionhouse-nav-button-secondary-highlight", "auctionhouse-nav-button-highlight" },
          font = "GameFontHighlightSmall", indent = 18, fallback = { 0.16, 0.12, 0.05, 0.9 } },
  [3] = { normal = { "auctionhouse-nav-button-tertiary" }, select = { "auctionhouse-nav-button-tertiary-select", "auctionhouse-ui-row-select" },
          highlight = { "auctionhouse-nav-button-tertiary-highlight", "auctionhouse-ui-row-highlight" },
          font = "GameFontHighlightSmall", indent = 26, fallback = { 0, 0, 0, 0 } },
}

local function IsOnPath(node)
  local c = state.category
  while c do
    if c == node then return true end
    c = c.parent
  end
  return false
end

local function InitCategoryRow(row)
  row:SetHeight(CAT_ROW_H)
  row.Normal = row:CreateTexture(nil, "BACKGROUND")
  row.Normal:SetAllPoints()
  row.Selected = row:CreateTexture(nil, "ARTWORK")
  row.Selected:SetAllPoints()
  row.Selected:SetBlendMode("ADD")
  row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
  row.Highlight:SetAllPoints()
  row.Highlight:SetBlendMode("ADD")
  row.Text = NewFont(row, "GameFontNormalSmall")
  row:SetScript("OnClick", function(self)
    local node = self.node
    if state.category == node then
      state.category = node.parent -- clicking the open category collapses it
    else
      state.category = node
    end
    PlaySoundKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
    UpdateCategories()
    RunSearch()
  end)
end

local function UpdateCategoryRow(row, node)
  row.node = node
  local style = CAT_STYLE[math.min(node.depth, 3)]
  if row.depthStyle ~= style then
    row.depthStyle = style
    row.Normal:Show(); row.Highlight:Show()
    SetAtlasOr(row.Normal, style.normal, style.fallback)
    SetAtlasOr(row.Selected, style.select, { 1, 0.82, 0, 0.25 })
    SetAtlasOr(row.Highlight, style.highlight, { 1, 1, 1, 0.1 })
    row.Text:SetFontObject(style.font)
    row.Text:ClearAllPoints()
    row.Text:SetPoint("LEFT", style.indent, 0)
    row.Text:SetPoint("RIGHT", -6, 0)
  end
  row.Text:SetText(node.name)
  row.Selected:SetShown(state.category == node)
end

-- results list -------------------------------------------------------------
local function ToggleFavorite(e)
  local fav = ns.db.favorites
  if fav[e.itemID] then fav[e.itemID] = nil else fav[e.itemID] = true end
  PlaySoundKit(fav[e.itemID] and "AUCTION_HOUSE_FAVORITE_ADD" or "AUCTION_HOUSE_FAVORITE_REMOVE")
  if state.mode == "favorites" or state.mode == "idle" then
    RunSearch(true)
  else
    RefreshVisibleRows(frame.list)
  end
end

local function ShowItemTooltip(owner, e)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if e.link then
    GameTooltip:SetHyperlink(e.link)
  elseif GameTooltip.SetItemByID then
    GameTooltip:SetItemByID(e.itemID)
  else
    GameTooltip:SetHyperlink("item:" .. e.itemID)
  end
  GameTooltip:Show()
end

local function InitResultRow(row)
  row:SetHeight(ROW_H)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  row.Stripe = row:CreateTexture(nil, "BACKGROUND")
  row.Stripe:SetAllPoints()
  SetAtlasOr(row.Stripe, "auctionhouse-rowstripe-1", { 1, 1, 1, 0.04 })

  row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
  row.Highlight:SetAllPoints()
  SetAtlasOr(row.Highlight, "auctionhouse-ui-row-highlight", { 1, 1, 1, 0.08 })
  row.Highlight:SetBlendMode("ADD")

  row.Selected = row:CreateTexture(nil, "ARTWORK")
  row.Selected:SetAllPoints()
  SetAtlasOr(row.Selected, "auctionhouse-ui-row-select", { 1, 0.82, 0, 0.15 })
  row.Selected:SetBlendMode("ADD")
  row.Selected:Hide()

  local x = 0
  local priceCol, nameCol, lvlCol, availCol, ageCol = COLUMNS[1], COLUMNS[2], COLUMNS[3], COLUMNS[4], COLUMNS[5]

  row.Star = CreateFrame("Button", nil, row)
  row.Star:SetSize(13, 13)
  row.Star:SetPoint("LEFT", 6, 0)
  row.Star.Tex = row.Star:CreateTexture(nil, "ARTWORK")
  row.Star.Tex:SetAllPoints()
  row.Star:SetScript("OnClick", function(self) ToggleFavorite(self:GetParent().entry) end)
  row.Star:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.db.favorites[self:GetParent().entry.itemID] and "Remove from favorites" or "Add to favorites")
    GameTooltip:Show()
    self:GetParent():LockHighlight()
  end)
  row.Star:SetScript("OnLeave", function(self)
    GameTooltip_Hide()
    self:GetParent():UnlockHighlight()
  end)

  row.Price = NewFont(row, "GameFontHighlight", "RIGHT")
  row.Price:SetPoint("RIGHT", row, "LEFT", x + priceCol.width - 12, 0)
  x = x + priceCol.width - 2

  row.IconBorder = row:CreateTexture(nil, "OVERLAY")
  row.IconBorder:SetSize(18, 18)
  row.IconBorder:SetPoint("LEFT", x + 6, 0)
  SetAtlasOr(row.IconBorder, "auctionhouse-itemicon-small-border", nil)
  row.Icon = row:CreateTexture(nil, "ARTWORK")
  row.Icon:SetSize(16, 16)
  row.Icon:SetPoint("CENTER", row.IconBorder)

  row.Name = NewFont(row, "GameFontNormal", "LEFT")
  row.Name:SetPoint("LEFT", row.IconBorder, "RIGHT", 4, 0)
  row.Name:SetWidth(nameCol.width - 34)
  x = x + nameCol.width - 2

  row.Level = NewFont(row, "GameFontHighlightSmall", "CENTER")
  row.Level:SetPoint("CENTER", row, "LEFT", x + lvlCol.width / 2, 0)
  x = x + lvlCol.width - 2

  row.Available = NewFont(row, "GameFontHighlightSmall", "RIGHT")
  row.Available:SetPoint("RIGHT", row, "LEFT", x + availCol.width - 12, 0)
  x = x + availCol.width - 2

  row.Age = NewFont(row, "GameFontHighlightSmall", "RIGHT")
  row.Age:SetPoint("RIGHT", row, "LEFT", x + ageCol.width - 12, 0)

  row:SetScript("OnClick", function(self, button)
    local e = self.entry
    if IsModifiedClick() and e.link then
      HandleModifiedItemClick(e.link)
    elseif button == "RightButton" then
      ToggleFavorite(e)
    else
      PlaySoundKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
      ShowDetail(e)
    end
  end)
  row:SetScript("OnEnter", function(self) ShowItemTooltip(self, self.entry) end)
  row:SetScript("OnLeave", GameTooltip_Hide)
end

local function UpdateResultRow(row, e)
  row.entry = e
  row.Stripe:SetShown(e._odd)
  row.Selected:SetShown(state.selected == e)
  row.Icon:SetTexture(e.icon)
  local r, g, b = QualityColor(e.quality)
  row.IconBorder:SetVertexColor(r, g, b)
  if e.loaded then
    row.Name:SetText(e.name)
    row.Name:SetTextColor(r, g, b)
  else
    row.Name:SetText(RETRIEVING_ITEM_INFO or "Retrieving item information")
    row.Name:SetTextColor(0.5, 0.5, 0.5)
  end
  row.Price:SetText(Money(e.price))
  row.Level:SetText((e.minLevel and e.minLevel > 1) and e.minLevel or "")
  row.Available:SetText(Number(e.available))
  row.Age:SetText(AgeText(e.age))

  local fav = ns.db.favorites[e.itemID]
  SetAtlasOr(row.Star.Tex, fav and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off",
    "Interface\\Common\\ReputationStar")
  row.Star.Tex:SetShown(true)
  row.Star.Tex:SetAlpha(fav and 1 or 0.35)
end

-- history list -------------------------------------------------------------
local function InitHistoryRow(row)
  row:SetHeight(ROW_H)
  row.Stripe = row:CreateTexture(nil, "BACKGROUND")
  row.Stripe:SetAllPoints()
  SetAtlasOr(row.Stripe, "auctionhouse-rowstripe-1", { 1, 1, 1, 0.04 })
  row.Highlight = row:CreateTexture(nil, "HIGHLIGHT")
  row.Highlight:SetAllPoints()
  SetAtlasOr(row.Highlight, "auctionhouse-ui-row-highlight", { 1, 1, 1, 0.08 })
  row.Highlight:SetBlendMode("ADD")

  local x = 0
  row.cells = {}
  for i, col in ipairs(HISTORY_COLUMNS) do
    local fs = NewFont(row, i == 1 and "GameFontNormal" or "GameFontHighlight", col.justify)
    if col.justify == "RIGHT" then
      fs:SetPoint("RIGHT", row, "LEFT", x + col.width - 12, 0)
    else
      fs:SetPoint("LEFT", row, "LEFT", x + 8, 0)
    end
    row.cells[i] = fs
    x = x + col.width - 2
  end
end

local function UpdateHistoryRow(row, h)
  row.Stripe:SetShown(h._odd)
  row.cells[1]:SetText(h.date or "")
  row.cells[2]:SetText(Money(h.minSeen))
  row.cells[3]:SetText(Money(h.maxSeen))
  row.cells[4]:SetText(Number(h.available))
end

---------------------------------------------------------------------------
-- filter popup
---------------------------------------------------------------------------
local function CreateCheck(parent, label, r, g, b)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  local fs = cb.Text or cb.text
  if not fs then
    fs = NewFont(cb, "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontHighlightSmall")
  fs:SetText(label)
  if r then fs:SetTextColor(r, g, b) end
  return cb
end

local function FiltersActive()
  local f = ns.db.filters
  if f.minLevel or f.maxLevel or f.usable then return true end
  for q = 0, 5 do
    if not f.qualities[q] then return true end
  end
  return false
end

local function CreateFilterPopup(anchor)
  local p = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  p:SetSize(190, 250)
  p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  p:SetFrameStrata("DIALOG")
  p:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  p:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  p:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  p:EnableMouse(true)
  p:Hide()

  local function Changed()
    frame.FilterButton:UpdateLabel()
    if state.mode == "search" then RunSearch() end
  end

  local y = -10
  local lvlLabel = NewFont(p, "GameFontNormalSmall")
  lvlLabel:SetPoint("TOPLEFT", 12, y)
  lvlLabel:SetText(LEVEL_RANGE or "Level Range")
  y = y - 18

  local function LevelBox(field, x)
    local eb = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    eb:SetSize(32, 18)
    eb:SetPoint("TOPLEFT", x, y)
    eb:SetAutoFocus(false)
    eb:SetNumeric(true)
    eb:SetMaxLetters(2)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", function(self)
      local v = tonumber(self:GetText())
      if ns.db.filters[field] ~= v then
        ns.db.filters[field] = v
        Changed()
      end
    end)
    return eb
  end
  p.MinLevel = LevelBox("minLevel", 18)
  local dash = NewFont(p, "GameFontHighlightSmall")
  dash:SetPoint("LEFT", p.MinLevel, "RIGHT", 4, 0)
  dash:SetText("-")
  p.MaxLevel = LevelBox("maxLevel", 70)
  y = y - 26

  p.Usable = CreateCheck(p, "Usable Only")
  p.Usable:SetPoint("TOPLEFT", 10, y)
  p.Usable:SetScript("OnClick", function(self)
    ns.db.filters.usable = self:GetChecked() and true or false
    Changed()
  end)
  if not Data.SupportsUsable then p.Usable:Disable() end
  y = y - 26

  local rarity = NewFont(p, "GameFontNormalSmall")
  rarity:SetPoint("TOPLEFT", 12, y)
  rarity:SetText(RARITY or "Rarity")
  y = y - 16

  p.Quality = {}
  for q = 0, 5 do
    local r, g, b = QualityColor(q)
    local label = _G["ITEM_QUALITY" .. q .. "_DESC"] or ("Quality " .. q)
    local cb = CreateCheck(p, label, r, g, b)
    cb:SetPoint("TOPLEFT", 10, y)
    cb:SetScript("OnClick", function(self)
      ns.db.filters.qualities[q] = self:GetChecked() and true or false
      Changed()
    end)
    p.Quality[q] = cb
    y = y - 22
  end

  local reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  reset:SetSize(80, 20)
  reset:SetPoint("BOTTOM", 0, 10)
  reset:SetText(RESET or "Reset")
  reset:SetScript("OnClick", function()
    ns:ResetFilters()
    p:Refresh()
    Changed()
  end)

  function p:Refresh()
    local f = ns.db.filters
    self.MinLevel:SetText(f.minLevel and tostring(f.minLevel) or "")
    self.MaxLevel:SetText(f.maxLevel and tostring(f.maxLevel) or "")
    self.Usable:SetChecked(f.usable)
    for q = 0, 5 do self.Quality[q]:SetChecked(f.qualities[q]) end
  end
  p:SetScript("OnShow", p.Refresh)
  return p
end

---------------------------------------------------------------------------
-- detail view (item clicked)
---------------------------------------------------------------------------
local function CreateDetail(parent)
  local d = CreateFrame("Frame", nil, parent)
  d:SetAllPoints()
  d:Hide()

  d.Back = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
  d.Back:SetSize(90, 22)
  d.Back:SetPoint("TOPLEFT", 2, 0)
  d.Back:SetText(BACK or "Back")
  d.Back:SetScript("OnClick", function()
    PlaySoundKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
    ShowList()
  end)

  local header = CreateFrame("Button", nil, d)
  header:SetPoint("TOPLEFT", 0, -28)
  header:SetPoint("TOPRIGHT", 0, -28)
  header:SetHeight(64)
  header.Bg = header:CreateTexture(nil, "BACKGROUND")
  header.Bg:SetAllPoints()
  SetAtlasOr(header.Bg, { "auctionhouse-background-buy-noncommodities-header", "auctionhouse-background-sell-left" },
    { 0, 0, 0, 0.35 })
  d.Header = header

  header.Icon = header:CreateTexture(nil, "ARTWORK")
  header.Icon:SetSize(42, 42)
  header.Icon:SetPoint("LEFT", 14, 0)
  header.IconBorder = header:CreateTexture(nil, "OVERLAY")
  header.IconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
  header.IconBorder:SetAllPoints(header.Icon)

  header.Name = NewFont(header, "GameFontNormalLarge")
  header.Name:SetPoint("TOPLEFT", header.Icon, "TOPRIGHT", 10, -3)
  header.Name:SetPoint("RIGHT", header, "CENTER", 60, 0)
  header.Sub = NewFont(header, "GameFontHighlightSmall")
  header.Sub:SetPoint("TOPLEFT", header.Name, "BOTTOMLEFT", 0, -5)

  header.Stats = {}
  for i = 1, 3 do
    local label = NewFont(header, "GameFontNormalSmall", "RIGHT")
    local value = NewFont(header, "GameFontHighlightSmall", "RIGHT")
    value:SetPoint("TOPRIGHT", header, "TOPRIGHT", -12, -8 - (i - 1) * 16)
    label:SetPoint("RIGHT", value, "LEFT", -8, 0)
    header.Stats[i] = { label = label, value = value }
  end

  header:RegisterForClicks("LeftButtonUp")
  header:SetScript("OnEnter", function(self)
    if self.entry then ShowItemTooltip(self, self.entry) end
  end)
  header:SetScript("OnLeave", GameTooltip_Hide)
  header:SetScript("OnClick", function(self)
    if self.entry and self.entry.link and IsModifiedClick() then HandleModifiedItemClick(self.entry.link) end
  end)

  d.Fav = CreateFrame("Button", nil, d)
  d.Fav:SetSize(18, 18)
  d.Fav:SetPoint("LEFT", d.Back, "RIGHT", 8, 0)
  d.Fav.Tex = d.Fav:CreateTexture(nil, "ARTWORK")
  d.Fav.Tex:SetAllPoints()
  d.Fav:SetScript("OnClick", function()
    if d.entry then
      ToggleFavorite(d.entry)
      d:UpdateFav()
    end
  end)
  function d:UpdateFav()
    local fav = self.entry and ns.db.favorites[self.entry.itemID]
    SetAtlasOr(self.Fav.Tex, fav and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off",
      "Interface\\Common\\ReputationStar")
    self.Fav.Tex:SetShown(true)
    self.Fav.Tex:SetAlpha(fav and 1 or 0.4)
  end

  local headerRow = CreateFrame("Frame", nil, d)
  headerRow:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
  headerRow:SetSize(10, 19)
  LayoutHeaders(headerRow, HISTORY_COLUMNS)

  d.List, d.Bar = CreateList(d, ROW_H, InitHistoryRow, UpdateHistoryRow)
  d.List:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
  d.List:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -20, 0)
  d.Bar:SetPoint("TOPLEFT", d.List, "TOPRIGHT", 4, 0)
  d.Bar:SetPoint("BOTTOMLEFT", d.List, "BOTTOMRIGHT", 4, 0)

  d.Empty = NewFont(d, "GameFontNormal", "CENTER")
  d.Empty:SetPoint("CENTER", d.List, "CENTER")
  d.Empty:SetText("No price history saved for this item.")

  function d:SetEntry(e)
    self.entry = e
    header.entry = e
    header.Icon:SetTexture(e.icon)
    local r, g, b = QualityColor(e.quality)
    header.IconBorder:SetVertexColor(r, g, b)
    header.Name:SetText(e.name or ("item:" .. e.itemID))
    header.Name:SetTextColor(r, g, b)
    local sub = {}
    if e.itemLevel and e.itemLevel > 0 then sub[#sub + 1] = "Item Level " .. e.itemLevel end
    if e.minLevel and e.minLevel > 1 then sub[#sub + 1] = "Requires Level " .. e.minLevel end
    header.Sub:SetText(table.concat(sub, "   "))

    local days = Data:HistoryDays()
    header.Stats[1].label:SetText("Last seen")
    header.Stats[1].value:SetText(Money(e.price) .. "  " .. AgeText(e.age))
    header.Stats[2].label:SetText(days .. "-day average")
    local history = Data:GetHistory(e)
    local total, n = 0, 0
    local cutoff = Data.ScanDay() - days
    for _, h in ipairs(history) do
      if h.minSeen and (tonumber(h.rawDay) or 0) > cutoff then
        total, n = total + h.minSeen, n + 1
      end
    end
    local mean = n > 0 and math.floor(total / n) or nil
    header.Stats[2].value:SetText(mean and Money(mean) or "|cff808080-|r")
    header.Stats[3].label:SetText("Sells to vendor for")
    header.Stats[3].value:SetText((e.sellPrice and e.sellPrice > 0) and Money(e.sellPrice) or "|cff808080-|r")

    self:UpdateFav()
    SetListData(self.List, history)
    self.Empty:SetShown(#history == 0)
  end

  return d
end

---------------------------------------------------------------------------
-- building the window
---------------------------------------------------------------------------
local function BuildFrame()
  local template = HasTemplate("PortraitFrameTemplate") and "PortraitFrameTemplate"
    or (HasTemplate("ButtonFrameTemplate") and "ButtonFrameTemplate") or "BasicFrameTemplate"
  frame = CreateFrame("Frame", "PocketAHFrame", UIParent, template)
  ns.frame = frame
  frame:SetSize(FRAME_W, FRAME_H)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
  end)
  local pt = ns.db.point
  if pt then
    frame:SetPoint(pt[1], UIParent, pt[2], pt[3], pt[4])
  else
    frame:SetPoint("CENTER", 0, 40)
  end
  frame:Hide()
  tinsert(UISpecialFrames, "PocketAHFrame")

  if not frame.Bg then
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(0.06, 0.06, 0.06, 0.95)
  end
  UpdateTitle()
  SetPortrait(frame, "Interface\\Icons\\INV_Misc_Coin_01")

  -- search bar -------------------------------------------------------------
  local fav = CreateFrame("Button", nil, frame)
  fav:SetSize(22, 22)
  fav:SetPoint("TOPLEFT", 68, -30)
  fav.Tex = fav:CreateTexture(nil, "ARTWORK")
  fav.Tex:SetAllPoints()
  SetAtlasOr(fav.Tex, "auctionhouse-icon-favorite", "Interface\\Common\\ReputationStar")
  fav.Tex:Show()
  fav.HL = fav:CreateTexture(nil, "HIGHLIGHT")
  fav.HL:SetAllPoints()
  SetAtlasOr(fav.HL, "auctionhouse-icon-favorite", "Interface\\Common\\ReputationStar")
  fav.HL:SetBlendMode("ADD")
  fav.HL:SetAlpha(0.4)
  fav:SetScript("OnClick", function()
    frame.SearchBox:SetText("")
    frame.SearchBox:ClearFocus()
    state.category = nil
    UpdateCategories()
    RunSearch()
  end)
  fav:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(AUCTION_HOUSE_FAVORITES_SEARCH_TOOLTIP or "Show your favorites")
    GameTooltip:Show()
  end)
  fav:SetScript("OnLeave", GameTooltip_Hide)

  local search = CreateFrame("EditBox", "PocketAHSearchBox", frame, "SearchBoxTemplate")
  search:SetSize(360, 22)
  search:SetPoint("LEFT", fav, "RIGHT", 10, 0)
  search:SetAutoFocus(false)
  search:SetMaxLetters(63)
  if search.Instructions then search.Instructions:SetText(SEARCH or "Search") end
  search:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    RunSearch()
  end)
  frame.SearchBox = search

  local searchButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  searchButton:SetSize(132, 22)
  searchButton:SetPoint("TOPRIGHT", -10, -30)
  searchButton:SetText(SEARCH or "Search")
  searchButton:SetScript("OnClick", function()
    search:ClearFocus()
    RunSearch()
  end)

  local filter = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  filter:SetSize(96, 22)
  filter:SetPoint("RIGHT", searchButton, "LEFT", -8, 0)
  function filter:UpdateLabel()
    self:SetText((FILTER or "Filter") .. (FiltersActive() and " |cffff4040*|r" or ""))
  end
  filter:UpdateLabel()
  frame.FilterButton = filter
  frame.FilterPopup = CreateFilterPopup(filter)
  filter:SetScript("OnClick", function()
    frame.FilterPopup:SetShown(not frame.FilterPopup:IsShown())
  end)
  search:SetPoint("RIGHT", filter, "LEFT", -12, 0)

  -- categories -------------------------------------------------------------
  local cats = CreateFrame("Frame", nil, frame)
  cats:SetPoint("TOPLEFT", 4, -62)
  cats:SetPoint("BOTTOMLEFT", 4, 28)
  cats:SetWidth(CAT_W)
  cats.Bg = cats:CreateTexture(nil, "BACKGROUND")
  cats.Bg:SetAllPoints()
  SetAtlasOr(cats.Bg, "auctionhouse-background-index", { 0, 0, 0, 0.4 })
  frame.CatList, frame.CatBar = CreateList(cats, CAT_ROW_H, InitCategoryRow, UpdateCategoryRow)
  frame.CatList:SetPoint("TOPLEFT", 3, -5)
  frame.CatList:SetPoint("BOTTOMRIGHT", -16, 5)
  frame.CatBar:SetPoint("TOPLEFT", frame.CatList, "TOPRIGHT", 2, 0)
  frame.CatBar:SetPoint("BOTTOMLEFT", frame.CatList, "BOTTOMRIGHT", 2, 0)

  -- results ----------------------------------------------------------------
  local results = CreateFrame("Frame", nil, frame, HasTemplate("InsetFrameTemplate") and "InsetFrameTemplate" or nil)
  results:SetPoint("TOPLEFT", cats, "TOPRIGHT", 6, 0)
  results:SetPoint("BOTTOMRIGHT", -6, 28)
  frame.Results = results

  local listHolder = CreateFrame("Frame", nil, results)
  listHolder:SetPoint("TOPLEFT", 4, -4)
  listHolder:SetPoint("BOTTOMRIGHT", -4, 4)
  frame.ListHolder = listHolder

  local headerRow = CreateFrame("Frame", nil, listHolder)
  headerRow:SetPoint("TOPLEFT")
  headerRow:SetSize(10, 19)
  frame.Headers = LayoutHeaders(headerRow, COLUMNS, function(self)
    local key = self.col.key
    if state.sortKey == key then
      state.ascending = not state.ascending
    else
      state.sortKey = key
      state.ascending = (key ~= "available")
    end
    PlaySoundKit("IG_MAINMENU_OPTION_CHECKBOX_ON")
    UpdateHeaders()
    RunSearch(true)
  end)

  frame.list, frame.listBar = CreateList(listHolder, ROW_H, InitResultRow, UpdateResultRow)
  frame.list:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
  frame.list:SetPoint("BOTTOMRIGHT", listHolder, "BOTTOMRIGHT", -18, 0)
  frame.listBar:SetPoint("TOPLEFT", frame.list, "TOPRIGHT", 4, 0)
  frame.listBar:SetPoint("BOTTOMLEFT", frame.list, "BOTTOMRIGHT", 4, 0)

  frame.Empty = NewFont(listHolder, "GameFontNormal", "CENTER")
  frame.Empty:SetPoint("CENTER", frame.list, "CENTER", 0, 20)
  frame.Empty:SetWidth(380)
  frame.Empty:SetWordWrap(true)

  local spinner = listHolder:CreateTexture(nil, "OVERLAY")
  spinner:SetSize(48, 48)
  spinner:SetPoint("TOP", frame.Empty, "BOTTOM", 0, -10)
  SetAtlasOr(spinner, "auctionhouse-ui-loadingspinner", "Interface\\COMMON\\StreamCircle")
  local spin = spinner:CreateAnimationGroup()
  local rot = spin:CreateAnimation("Rotation")
  rot:SetDegrees(-360)
  rot:SetDuration(1)
  spin:SetLooping("REPEAT")
  spinner.anim = spin
  spinner:Hide()
  frame.Spinner = spinner

  frame.Detail = CreateDetail(results)
  frame.Detail:ClearAllPoints()
  frame.Detail:SetPoint("TOPLEFT", 4, -4)
  frame.Detail:SetPoint("BOTTOMRIGHT", -4, 4)

  -- bottom bar -------------------------------------------------------------
  frame.MoneyText = NewFont(frame, "GameFontHighlight", "LEFT")
  frame.MoneyText:SetPoint("BOTTOMLEFT", 14, 8)

  frame.Status = NewFont(frame, "GameFontHighlightSmall", "RIGHT")
  frame.Status:SetPoint("BOTTOMRIGHT", -14, 9)
  frame.Status:SetTextColor(0.7, 0.7, 0.7)

  -- tabs under the frame (like the real AH), one per Auctionator price
  -- database; built/refreshed in UpdateSourceTabs on show
  frame.Tabs = {}
  frame.numTabs = 0

  -- events -----------------------------------------------------------------
  local refreshPending = false
  frame:SetScript("OnEvent", function(_, event, ...)
    if event == "GET_ITEM_INFO_RECEIVED" then
      local itemID, success = ...
      if Data:OnItemInfo(itemID, success) and not refreshPending then
        refreshPending = true
        C_Timer.After(0.3, function()
          refreshPending = false
          if not frame:IsShown() then return end
          if state.needsInfo then
            RunSearch(true)
          else
            RefreshVisibleRows(frame.list)
            UpdateStatus()
          end
        end)
      end
    elseif event == "PLAYER_MONEY" then
      UpdateMoney()
    end
  end)

  frame:SetScript("OnShow", function()
    frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:RegisterEvent("PLAYER_MONEY")
    PlaySoundKit("AUCTION_WINDOW_OPEN")
    UpdateSourceTabs()
    Data:Rebuild()
    UpdateMoney()
    UpdateHeaders()
    UpdateCategories()
    if state.selected and frame.Detail:IsShown() then
      ShowList()
    end
    RunSearch()
  end)
  frame:SetScript("OnHide", function()
    frame:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
    frame:UnregisterEvent("PLAYER_MONEY")
    frame.FilterPopup:Hide()
    PlaySoundKit("AUCTION_WINDOW_CLOSE")
  end)
end

---------------------------------------------------------------------------
-- behaviour
---------------------------------------------------------------------------
function UpdateMoney()
  frame.MoneyText:SetText(Money(GetMoney()))
end

function UpdateTitle()
  local title = (AUCTION_HOUSE or "Auction House") .. " |cff9d9d9d(offline)|r"
  if Data.source then
    title = title .. " - |cffffd200" .. Data.source .. "|r"
  end
  SetTitle(frame, title)
end

local function SelectSource(realm)
  if not Data:SetSource(realm) then return end
  ns.db.source = Data.source
  UpdateSourceTabs()
  UpdateTitle()
  if frame.Detail:IsShown() then ShowList() end
  Data:Rebuild()
  RunSearch()
end

local tabTemplate
function UpdateSourceTabs()
  -- restore the saved choice, dropping it if that database is gone
  local realms = Data:ListRealms()
  local saved = ns.db.source
  if saved then
    local found = false
    for _, r in ipairs(realms) do if r == saved then found = true end end
    if not found then saved = nil; ns.db.source = nil end
  end
  Data:SetSource(saved)
  UpdateTitle()

  if tabTemplate == nil then
    tabTemplate = (HasTemplate("PanelTabButtonTemplate") and "PanelTabButtonTemplate")
      or (HasTemplate("CharacterFrameTabButtonTemplate") and "CharacterFrameTabButtonTemplate")
      or false
  end
  if not tabTemplate then return end

  local current = Data:CurrentRealm()
  local active = Data:ActiveRealm()
  local selectedIndex
  for i, realm in ipairs(realms) do
    local tab = frame.Tabs[i]
    if not tab then
      local ok, created = pcall(CreateFrame, "Button", "PocketAHFrameTab" .. i, frame, tabTemplate)
      if not ok then return end
      tab = created
      tab:SetID(i)
      if i == 1 then
        tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 20, 2)
      else
        tab:SetPoint("LEFT", frame.Tabs[i - 1], "RIGHT", -16, 0)
      end
      tab:SetScript("OnClick", function(self)
        PlaySoundKit("IG_CHARACTER_INFO_TAB")
        SelectSource(self.realm)
      end)
      tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.realm, 1, 1, 1)
        if self.realm == Data:CurrentRealm() then
          GameTooltip:AddLine("The Auction House your character is on.", nil, nil, nil, true)
        else
          GameTooltip:AddLine("Prices Auctionator saved while you played on this Auction House.", nil, nil, nil, true)
        end
        GameTooltip:Show()
      end)
      tab:SetScript("OnLeave", GameTooltip_Hide)
      frame.Tabs[i] = tab
    end
    tab.realm = realm
    tab:SetText(realm == current and (realm .. " |cff9d9d9d(here)|r") or realm)
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    tab:Show()
    if realm == active then selectedIndex = i end
  end
  for i = #realms + 1, #frame.Tabs do frame.Tabs[i]:Hide() end
  frame.numTabs = #realms
  if selectedIndex and PanelTemplates_SetTab then pcall(PanelTemplates_SetTab, frame, selectedIndex) end
end

function UpdateHeaders()
  for _, h in ipairs(frame.Headers) do
    if h.col.key == state.sortKey then
      h.Arrow:Show()
      if state.ascending then h.Arrow:SetTexCoord(0, 1, 0, 1) else h.Arrow:SetTexCoord(0, 1, 1, 0) end
    else
      h.Arrow:Hide()
    end
  end
end

function UpdateCategories()
  local out = {}
  local function Flatten(nodes)
    for _, n in ipairs(nodes) do
      out[#out + 1] = n
      if n.children and IsOnPath(n) then Flatten(n.children) end
    end
  end
  Flatten(ns:GetCategories())
  SetListData(frame.CatList, out, true)
end

function UpdateStatus(count)
  if count then state.count = count end
  local parts = {}
  if state.mode ~= "idle" then
    parts[#parts + 1] = (state.count or 0) .. " results"
  end
  parts[#parts + 1] = #Data.entries .. " items known"
  if Data.newestAge then
    parts[#parts + 1] = "newest scan: " .. (Data.newestAge <= 0 and "today" or (Data.newestAge .. "d ago"))
  end
  if Data.pending > 0 then
    parts[#parts + 1] = "|cffffd200loading " .. Data.pending .. "|r"
  end
  frame.Status:SetText(table.concat(parts, "  ·  "))
end

local function Compare(a, b)
  local k = state.sortKey
  local va, vb
  if k == "name" then
    va, vb = a.nameLower or "\255", b.nameLower or "\255"
  elseif k == "level" then
    va, vb = a.minLevel or 0, b.minLevel or 0
  elseif k == "available" then
    va, vb = a.available or -1, b.available or -1
  elseif k == "age" then
    va, vb = a.age or 99999, b.age or 99999
  else
    va, vb = a.price, b.price
  end
  if va ~= vb then
    if state.ascending then return va < vb else return va > vb end
  end
  if a.price ~= b.price then return a.price < b.price end
  return a.key < b.key
end

function RunSearch(keepScroll)
  if not frame then return end
  if frame.Detail:IsShown() and not keepScroll then ShowList() end

  if not Data.built and not Data:Rebuild() then
    state.mode = "idle"
    state.results = {}
    SetListData(frame.list, state.results)
    frame.Empty:SetText("Auctionator's price database isn't loaded yet.")
    frame.Empty:Show()
    frame.Spinner:Hide()
    UpdateStatus(0)
    return
  end

  local f = ns.db.filters
  local text = strtrim(frame.SearchBox:GetText() or ""):lower()
  local exact = false
  local quoted = text:match('^"(.*)"$')
  if quoted then text, exact = quoted, true end

  local restrictQuality = false
  for q = 0, 5 do
    if not f.qualities[q] then restrictQuality = true end
  end

  local query
  if text == "" and not state.category then
    if next(ns.db.favorites) then
      state.mode = "favorites"
      query = { favorites = ns.db.favorites }
    else
      state.mode = "idle"
    end
  else
    state.mode = "search"
    query = {
      text = text,
      exact = exact,
      filters = state.category and state.category.filters,
      minLevel = f.minLevel,
      maxLevel = f.maxLevel,
      qualities = f.qualities,
      restrictQuality = restrictQuality,
      usable = f.usable and Data.SupportsUsable,
    }
  end

  local results, skipped = {}, 0
  if query then
    results, skipped = Data:Query(query)
    table.sort(results, Compare)
  end
  state.results = results
  state.needsInfo = query ~= nil and (skipped > 0 or state.sortKey == "name")
  SetListData(frame.list, results, keepScroll)

  local loading = skipped > 0 and Data.pending > 0
  if #results == 0 then
    if state.mode == "idle" then
      frame.Empty:SetText("Search for an item or pick a category.\n\n|cffa0a0a0Right-click or star a result to add it to your favorites; they show here when the search is empty.|r")
    elseif loading then
      frame.Empty:SetText("Retrieving item information...")
    else
      frame.Empty:SetText(AUCTION_HOUSE_BROWSE_NO_RESULTS or "No results found")
    end
    frame.Empty:Show()
  else
    frame.Empty:Hide()
  end
  frame.Spinner:SetShown(loading and #results == 0)
  if frame.Spinner:IsShown() then frame.Spinner.anim:Play() else frame.Spinner.anim:Stop() end

  UpdateStatus(#results)
end

function ShowDetail(e)
  state.selected = e
  RefreshVisibleRows(frame.list)
  frame.ListHolder:Hide()
  frame.Detail:SetEntry(e)
  frame.Detail:Show()
end

function ShowList()
  frame.Detail:Hide()
  frame.ListHolder:Show()
  RefreshVisibleRows(frame.list)
end

function ns:GetFrame()
  if not frame then BuildFrame() end
  return frame
end

function ns:SearchFor(text)
  local f = self:GetFrame()
  f.SearchBox:SetText(text)
  state.category = nil
  UpdateCategories()
  RunSearch()
end
