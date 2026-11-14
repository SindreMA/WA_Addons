local _, ns = ...

-- Standard round minimap button (same layout as LibDBIcon buttons).
-- Left-click toggles the window, drag moves it around the minimap.

local function UpdatePosition(button)
  local angle = math.rad(ns.db.minimap.angle or 200)
  local radius = (Minimap:GetWidth() / 2) + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate(button)
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  px, py = px / scale, py / scale
  ns.db.minimap.angle = math.deg(math.atan2(py - my, px - mx))
  UpdatePosition(button)
end

function ns:CreateMinimapButton()
  if self.minimapButton then return end
  self.db.minimap = self.db.minimap or { angle = 200 }

  local b = CreateFrame("Button", "PocketAHMinimapButton", Minimap)
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  icon:SetPoint("TOPLEFT", 7, -6)
  b.icon = icon

  b:SetScript("OnClick", function()
    ns:Toggle()
  end)
  b:SetScript("OnMouseDown", function() icon:SetTexCoord(0, 1, 0, 1) end)
  b:SetScript("OnMouseUp", function() icon:SetTexCoord(0.05, 0.95, 0.05, 0.95) end)
  b:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    GameTooltip:Hide()
    self:SetScript("OnUpdate", OnDragUpdate)
  end)
  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Pocket Auction House", 1, 1, 1)
    GameTooltip:AddLine("Click to open or close.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag to move this button.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)

  UpdatePosition(b)
  self.minimapButton = b
end
