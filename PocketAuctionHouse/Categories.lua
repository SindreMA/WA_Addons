local _, ns = ...

-- Builds the category tree. Uses Blizzard's own AuctionCategories table (the
-- exact list the real Auction House shows) and falls back to item classes.

local function CollectFilters(cat, out)
  if type(cat.filters) == "table" and #cat.filters > 0 then
    for _, f in ipairs(cat.filters) do out[#out + 1] = f end
  elseif type(cat.subCategories) == "table" then
    for _, sub in ipairs(cat.subCategories) do CollectFilters(sub, out) end
  end
  return out
end

local function Convert(list, depth, parent)
  local nodes = {}
  for _, cat in ipairs(list) do
    if type(cat) == "table" and cat.name then
      local node = {
        name = cat.name,
        depth = depth,
        parent = parent,
        filters = CollectFilters(cat, {}),
      }
      if type(cat.subCategories) == "table" and #cat.subCategories > 0 then
        node.children = Convert(cat.subCategories, depth + 1, node)
      end
      if #node.filters > 0 then
        nodes[#nodes + 1] = node
      end
    end
  end
  return nodes
end

local function TryLoadBlizzardCategories()
  if type(AuctionCategories) == "table" and #AuctionCategories > 0 then return true end
  local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
  local exists = (C_AddOns and C_AddOns.DoesAddOnExist) or function() return true end
  for _, name in ipairs({ "Blizzard_AuctionHouseShared", "Blizzard_AuctionHouseUI" }) do
    if exists(name) then
      pcall(load, name)
      if type(AuctionCategories) == "table" and #AuctionCategories > 0 then return true end
    end
  end
  return false
end

local FALLBACK_CLASSES = { 2, 4, 1, 0, 7, 6, 11, 9, 5, 15, 12, 13 }

local function BuildFallback()
  local classes = (Auctionator and Auctionator.Groups and Auctionator.Groups.Constants
    and Auctionator.Groups.Constants.ValidItemClassIDs) or FALLBACK_CLASSES
  local GetClassInfo = (C_Item and C_Item.GetItemClassInfo) or GetItemClassInfo
  local GetSubClassInfo = (C_Item and C_Item.GetItemSubClassInfo) or GetItemSubClassInfo
  local nodes, seen = {}, {}
  for _, classID in ipairs(classes) do
    if not seen[classID] then
      seen[classID] = true
      local name = GetClassInfo(classID)
      if name and name ~= "" then
        local node = { name = name, depth = 1, filters = { { classID = classID } } }
        local children = {}
        for sub = 0, 20 do
          local subName = GetSubClassInfo(classID, sub)
          if subName and subName ~= "" and subName ~= name then
            children[#children + 1] = {
              name = subName, depth = 2, parent = node,
              filters = { { classID = classID, subClassID = sub } },
            }
          end
        end
        if #children > 0 then node.children = children end
        nodes[#nodes + 1] = node
      end
    end
  end
  return nodes
end

function ns:GetCategories()
  if self.categories then return self.categories end
  if TryLoadBlizzardCategories() then
    self.categories = Convert(AuctionCategories, 1, nil)
    self.categorySource = "blizzard"
  end
  if not self.categories or #self.categories == 0 then
    self.categories = BuildFallback()
    self.categorySource = "fallback"
  end
  return self.categories
end
