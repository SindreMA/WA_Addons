local ADDON, ns = ...

BINDING_HEADER_POCKETAH = "Pocket Auction House"
BINDING_NAME_POCKETAH_TOGGLE = "Toggle Pocket Auction House"

local DEFAULT_FILTERS = {
  minLevel = nil,
  maxLevel = nil,
  usable = false,
  qualities = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true },
}
ns.DEFAULT_FILTERS = DEFAULT_FILTERS

function ns.Print(msg)
  print("|cffffd200Pocket AH:|r " .. tostring(msg))
end

local function CopyDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      CopyDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function ns:ResetFilters()
  self.db.filters = {}
  CopyDefaults(self.db.filters, DEFAULT_FILTERS)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    PocketAHDB = PocketAHDB or {}
    local db = PocketAHDB
    db.favorites = db.favorites or {}
    db.filters = db.filters or {}
    CopyDefaults(db.filters, DEFAULT_FILTERS)
    ns.db = db
    ns:CreateMinimapButton()
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
    -- The real Auction House opened: get out of its way.
    if Enum.PlayerInteractionType and arg1 == Enum.PlayerInteractionType.Auctioneer
       and ns.frame and ns.frame:IsShown() then
      ns.frame:Hide()
    end
  end
end)

function ns:Toggle()
  local frame = self:GetFrame()
  if frame:IsShown() then frame:Hide() else frame:Show() end
end

function PocketAH_Toggle()
  ns:Toggle()
end

SLASH_POCKETAH1 = "/pah"
SLASH_POCKETAH2 = "/pocketah"
SLASH_POCKETAH3 = "/offlineah"
SlashCmdList.POCKETAH = function(msg)
  msg = strtrim(msg or "")
  if msg == "reset" then
    ns.db.point = nil
    if ns.frame then
      ns.frame:ClearAllPoints()
      ns.frame:SetPoint("CENTER")
    end
    ns.Print("Window position reset.")
  elseif msg == "help" then
    ns.Print("/pah - toggle window   /pah <text> - search   /pah reset - reset position")
  elseif msg ~= "" then
    local frame = ns:GetFrame()
    frame:Show()
    ns:SearchFor(msg)
  else
    ns:Toggle()
  end
end
