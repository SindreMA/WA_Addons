local _, ns = ...

-- Index over Auctionator's in-memory price database for the current realm.
local Data = {
  entries = {},      -- list of entries
  byItemID = {},     -- itemID -> { entry, ... }
  queue = {},        -- itemIDs waiting for item data
  queued = {},       -- itemID -> true
  pending = 0,       -- entries still missing a name
  built = false,
}
ns.Data = Data

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetInventoryTypeByID = C_Item and C_Item.GetItemInventoryTypeByID
local RequestLoad = C_Item and C_Item.RequestLoadItemDataByID

local function ScanDay()
  local day0 = (Auctionator and Auctionator.Constants and Auctionator.Constants.SCAN_DAY_0)
    or time({ year = 2020, month = 1, day = 1, hour = 0 })
  return math.floor((time() - day0) / 86400)
end
Data.ScanDay = ScanDay

local function ParseKey(key)
  local id = tonumber(key)
  if id then return id end
  local a, b = key:match("^g:(%d+):(%d+)$")
  if a then return tonumber(a), tonumber(b) end
  local c, s = key:match("^gr:(%d+):(.+)$")
  if c then return tonumber(c), nil, s end
  return nil -- battle pets ("p:") and anything unknown
end

local function LatestDay(t)
  if type(t) ~= "table" then return nil end
  local best
  for day in pairs(t) do
    local n = tonumber(day)
    if n and (not best or n > best) then best = n end
  end
  return best
end

function Data:GetDB()
  local db = Auctionator and Auctionator.Database and Auctionator.Database.db
  if type(db) == "table" then return db end
  return nil
end

function Data:IsReady()
  return self:GetDB() ~= nil
end

local function FillInfo(e)
  local name, link, quality, itemLevel, minLevel, _, _, _, _, _, sellPrice = GetItemInfo(e.itemID)
  if not name then return false end
  if e.suffix then name = name .. " " .. e.suffix end
  e.name = name
  e.nameLower = name:lower()
  e.link = link
  e.quality = quality or 1
  e.minLevel = minLevel or 0
  e.itemLevel = e.ilvl or itemLevel or 0
  e.sellPrice = sellPrice
  e.loaded = true
  return true
end

function Data:Enqueue(itemID)
  if self.queued[itemID] then return end
  self.queued[itemID] = true
  table.insert(self.queue, itemID)
  if not self.ticker then
    self.ticker = C_Timer.NewTicker(0.05, function() self:ProcessQueue() end)
  end
end

function Data:ProcessQueue()
  for _ = 1, 40 do
    local id = table.remove(self.queue)
    if not id then break end
    if RequestLoad then RequestLoad(id) else GetItemInfo(id) end
  end
  if #self.queue == 0 and self.ticker then
    self.ticker:Cancel()
    self.ticker = nil
  end
end

function Data:Rebuild()
  wipe(self.entries)
  wipe(self.byItemID)
  self.pending = 0
  self.newestAge = nil

  local db = self:GetDB()
  if not db then
    self.built = false
    return false
  end

  local today = ScanDay()
  for key, data in pairs(db) do
    if type(key) == "string" and type(data) == "table" and type(data.m) == "number" and data.m > 0 then
      local itemID, ilvl, suffix = ParseKey(key)
      if itemID then
        local lastDay = LatestDay(data.h)
        local available
        if lastDay and type(data.a) == "table" then
          available = data.a[tostring(lastDay)] or data.a[lastDay]
        end
        local e = {
          key = key,
          itemID = itemID,
          ilvl = ilvl,
          suffix = suffix,
          price = data.m,
          age = lastDay and (today - lastDay) or nil,
          available = available,
        }
        local _, _, _, _, icon, classID, subClassID = GetItemInfoInstant(itemID)
        e.icon = icon or 134400
        e.classID = classID
        e.subClassID = subClassID
        e.invType = GetInventoryTypeByID and GetInventoryTypeByID(itemID) or nil

        if not FillInfo(e) then
          self.pending = self.pending + 1
          self:Enqueue(itemID)
        end

        if e.age and (not self.newestAge or e.age < self.newestAge) then
          self.newestAge = e.age
        end

        self.entries[#self.entries + 1] = e
        local list = self.byItemID[itemID]
        if not list then
          list = {}
          self.byItemID[itemID] = list
        end
        list[#list + 1] = e
      end
    end
  end

  self.built = true
  return true
end

-- Called from GET_ITEM_INFO_RECEIVED
function Data:OnItemInfo(itemID, success)
  local list = self.byItemID[itemID]
  if not list then return false end
  local changed = false
  for _, e in ipairs(list) do
    if not e.loaded then
      if FillInfo(e) then
        self.pending = self.pending - 1
        changed = true
      elseif success == false then
        e.name = "Item #" .. itemID
        e.nameLower = e.name:lower()
        e.quality = 1
        e.minLevel = 0
        e.itemLevel = e.ilvl or 0
        e.loaded = true
        e.failed = true
        self.pending = self.pending - 1
        changed = true
      end
    end
  end
  return changed
end

local function FilterMatches(e, filters)
  for _, f in ipairs(filters) do
    if f.classID == e.classID
       and (f.subClassID == nil or f.subClassID == e.subClassID)
       and (f.inventoryType == nil or e.invType == nil or f.inventoryType == e.invType) then
      return true
    end
  end
  return false
end

local CanUseItem = C_PlayerInfo and C_PlayerInfo.CanUseItem
Data.SupportsUsable = CanUseItem ~= nil

-- q = { text, exact, filters (category filter list or nil), minLevel, maxLevel, qualities, usable, favorites }
function Data:Query(q)
  local out = {}
  local text = q.text
  local needsInfo = (text and text ~= "") or q.minLevel or q.maxLevel or q.restrictQuality or q.usable
  local skipped = 0

  for _, e in ipairs(self.entries) do
    local ok = true

    if q.favorites and not q.favorites[e.itemID] then ok = false end
    if ok and q.filters and not FilterMatches(e, q.filters) then ok = false end

    if ok and needsInfo then
      if not e.loaded then
        ok = false
        skipped = skipped + 1
      else
        if text and text ~= "" then
          if q.exact then
            ok = e.nameLower == text
          else
            ok = e.nameLower:find(text, 1, true) ~= nil
          end
        end
        if ok and q.minLevel and e.minLevel < q.minLevel then ok = false end
        if ok and q.maxLevel and e.minLevel > q.maxLevel then ok = false end
        if ok and q.restrictQuality and not q.qualities[e.quality] then ok = false end
        if ok and q.usable and CanUseItem and not CanUseItem(e.itemID) then ok = false end
      end
    end

    if ok then out[#out + 1] = e end
  end

  return out, skipped
end

function Data:GetHistory(e)
  local db = Auctionator and Auctionator.Database
  if not db or not db.GetPriceHistory then return {} end
  local ok, history = pcall(db.GetPriceHistory, db, e.key)
  return ok and history or {}
end

function Data:GetMean(e, days)
  local db = Auctionator and Auctionator.Database
  if not db or not db.GetMeanPrice then return nil end
  local ok, mean = pcall(db.GetMeanPrice, db, e.key, days)
  if ok then return mean end
end

function Data:HistoryDays()
  local ok, days = pcall(function()
    return Auctionator.Config.Get(Auctionator.Config.Options.PRICE_HISTORY_DAYS)
  end)
  return (ok and tonumber(days)) or 21
end
