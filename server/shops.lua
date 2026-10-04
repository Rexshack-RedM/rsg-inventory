local RSGCore = exports['rsg-core']:GetCoreObject()

-- Shops are containers of type 'shop' stored in InvCore.Inventories as 'shop-<name>'.
-- Drag from shop -> player buys, drag player -> shop sells (if the item has a buyPrice).

Shops = {}
local StockCache = {}   -- [shop] = { [item] = stock }
local Cooldown = {}
local notify = InvCore.Notify

local function Debug(src, msg, ...)
    if Config.Debug then print(('[rsg-inventory:shops] %s: ' .. msg):format(src, ...)) end
end

local function OnCooldown(src)
    local now = GetGameTimer()
    if Cooldown[src] and now - Cooldown[src] < 300 then return true end
    Cooldown[src] = now
    return false
end

local function ShopId(name) return 'shop-' .. name end

local function SetupItems(name, list, persistent)
    local items, slot = {}, 1
    for _, it in pairs(list or {}) do
        local s = it.name and RSGCore.Shared.Items[it.name:lower()]
        if s then
            local amount = it.amount
            if persistent and amount and StockCache[name] and StockCache[name][s.name] then
                amount = StockCache[name][s.name]
            end
            local built = InvCore.BuildItem(s.name, amount or 1, it.info, slot)
            built.amount       = amount          -- nil = unlimited
            built.price        = it.price
            built.buyPrice     = it.buyPrice
            built.defaultstock = it.amount
            built.maxStock     = it.maxStock
            built.restock      = it.restock
            built.minQuality   = it.minQuality
            items[slot] = built
            slot = slot + 1
        end
    end
    return items, slot - 1
end

local function Register(name, data)
    local id = ShopId(name)
    local items, count = SetupItems(name, data.items, data.persistentStock)
    local shop = InvCore.Inventories[id]
    if shop then
        shop.items, shop.slots = items, math.max(count, 1)
        if data.label then shop.label = data.label end
        if data.persistentStock ~= nil then shop.persistentStock = data.persistentStock end
        return shop
    end
    shop = {
        id = id, name = name, type = 'shop', label = data.label or name,
        slots = math.max(count, 1), maxWeight = 1e12, items = items,
        shopCoords = data.coords and vector3(data.coords.x, data.coords.y, data.coords.z) or nil,
        persistentStock = data.persistentStock, currency = data.currency or 'cash',
    }
    InvCore.Inventories[id] = shop
    return shop
end

--- CreateShop({ name, label, items = {{ name, price, amount?, buyPrice?, ... }}, coords?, persistentStock? })
--- or CreateShop({ shopA = {...}, shopB = {...} })
function Shops.CreateShop(data)
    if type(data) ~= 'table' then return end
    if data.name then return Register(data.name, data) end
    for key, v in pairs(data) do
        if type(v) == 'table' and v.items then
            Register(type(key) == 'number' and v.name or key, v)
        end
    end
end

function Shops.OpenShop(src, name)
    local shop = name and InvCore.Inventories[ShopId(name)]
    if not shop then return false end
    if shop.shopCoords and #(GetEntityCoords(GetPlayerPed(src)) - shop.shopCoords) > 10.0 then return false end
    InvCore.OpenFor(src, shop.id)
    return true
end

function Shops.DoesShopExist(name)
    return type(name) == 'string' and InvCore.Inventories[ShopId(name)] ~= nil
end

function Shops.RestockShop(name, percentage)
    local shop = InvCore.Inventories[ShopId(name)]
    if not shop then return false end
    local mult = (percentage or 100) / 100
    for _, it in pairs(shop.items) do
        if it.amount and it.defaultstock then
            it.amount = math.min(it.defaultstock, it.amount + math.floor(it.defaultstock * mult + 0.5))
        end
    end
    InvCore.Refresh(shop.id)
    return true
end

local function InRange(src, shop)
    if InvCore.OpenInv[src] ~= shop.id then return false end
    return not shop.shopCoords or #(GetEntityCoords(GetPlayerPed(src)) - shop.shopCoords) <= 10.0
end

function Shops.Buy(src, shop, slot, amount, toSlot)
    if OnCooldown(src) then return Debug(src, 'buy ignored: cooldown') end
    if not InRange(src, shop) then
        Debug(src, 'buy denied: shop %s not open for player (open=%s)', shop.id, tostring(InvCore.OpenInv[src]))
        return notify(src, 'too_far')
    end

    local it = shop.items[slot]
    amount = math.tointeger(tonumber(amount)) or 1
    if not it or amount < 1 or amount > 1000 then
        return Debug(src, 'buy denied: slot %s item %s amount %s', tostring(slot), tostring(it and it.name), tostring(amount))
    end
    if not it.price then return notify(src, 'not_for_sale') end
    if it.unique then amount = 1 end
    if it.amount and amount > it.amount then return notify(src, 'out_of_stock') end
    if not InvCore.API.CanCarry(src, it.name, amount) then return notify(src, 'too_heavy') end

    local Player = RSGCore.Functions.GetPlayer(src)
    local price = math.floor(it.price * amount * 100 + 0.5) / 100
    if not Player or not Player.Functions.RemoveMoney(shop.currency, price, 'shop-purchase') then
        Debug(src, 'buy denied: RemoveMoney(%s, %s) failed', shop.currency, price)
        return notify(src, 'no_money')
    end
    if not InvCore.API.AddItem(src, it.name, amount, lib.table.deepclone(it.info or {}), toSlot, 'shop-purchase ' .. shop.name) then
        Player.Functions.AddMoney(shop.currency, price, 'shop-refund')
        return notify(src, 'too_heavy')
    end
    if it.amount then it.amount = it.amount - amount end
    Debug(src, 'bought %sx %s for %s', amount, it.name, price)
end

function Shops.Sell(src, shop, playerSlot, amount)
    if OnCooldown(src) or not InRange(src, shop) then return end
    local item = InvCore.API.GetItemBySlot(src, playerSlot)
    if not item then return end
    amount = math.tointeger(tonumber(amount)) or item.amount
    if amount < 1 or amount > item.amount then amount = item.amount end

    local entry
    for _, it in pairs(shop.items) do
        if it.name == item.name and it.buyPrice then entry = it break end
    end
    if not entry then return notify(src, 'shop_wont_buy') end
    local quality = (item.info and tonumber(item.info.quality)) or 100
    if quality < (entry.minQuality or 1) then return notify(src, 'quality_too_low') end
    if entry.amount and entry.maxStock and entry.amount + amount > entry.maxStock then
        return notify(src, 'shop_full')
    end
    local payout = math.floor(entry.buyPrice * amount * (quality / 100) * 100 + 0.5) / 100
    if payout <= 0 then return notify(src, 'shop_wont_buy') end
    if not InvCore.API.RemoveItem(src, item.name, amount, playerSlot, 'shop-sell ' .. shop.name) then return end
    if entry.amount then entry.amount = entry.amount + amount end
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then Player.Functions.AddMoney(shop.currency, payout, 'shop-sell') end
end

--------------------------------------------------------------------------------
-- Stock persistence + restock
--------------------------------------------------------------------------------
local function SaveStock()
    local rows = {}
    for _, inv in pairs(InvCore.Inventories) do
        if inv.type == 'shop' and inv.persistentStock then
            for _, it in pairs(inv.items) do
                if it.amount then rows[#rows + 1] = { inv.name, it.name, it.amount } end
            end
        end
    end
    for _, r in ipairs(rows) do
        MySQL.prepare('REPLACE INTO shop_stock (shop_name, item_name, stock) VALUES (?, ?, ?)', r)
    end
end

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `shop_stock` (
            `shop_name` VARCHAR(100) NOT NULL,
            `item_name` VARCHAR(100) NOT NULL,
            `stock` INT NOT NULL DEFAULT 0,
            PRIMARY KEY (`shop_name`, `item_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
    for _, row in ipairs(MySQL.query.await('SELECT shop_name, item_name, stock FROM shop_stock') or {}) do
        StockCache[row.shop_name] = StockCache[row.shop_name] or {}
        StockCache[row.shop_name][row.item_name] = tonumber(row.stock)
        local shop = InvCore.Inventories[ShopId(row.shop_name)]
        if shop and shop.persistentStock then
            for _, it in pairs(shop.items) do
                if it.name == row.item_name and it.amount then it.amount = tonumber(row.stock) end
            end
        end
    end
end)

lib.cron.new(Config.ShopRestockCycle, function()
    for _, inv in pairs(InvCore.Inventories) do
        if inv.type == 'shop' then
            for _, it in pairs(inv.items) do
                if it.restock and it.amount and it.defaultstock then
                    it.amount = math.min(it.defaultstock, it.amount + it.restock)
                end
            end
            InvCore.Refresh(inv.id)
        end
    end
    SaveStock()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SaveStock() end
end)
AddEventHandler('txAdmin:events:serverShuttingDown', SaveStock)
AddEventHandler('playerDropped', function() Cooldown[source] = nil end)

exports('CreateShop', Shops.CreateShop)
exports('OpenShop', Shops.OpenShop)
exports('DoesShopExist', Shops.DoesShopExist)
exports('RestockShop', Shops.RestockShop)
