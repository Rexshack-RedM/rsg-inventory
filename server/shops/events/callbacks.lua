local RSGCore = exports['rsg-core']:GetCoreObject()

local MAX_PURCHASE = 1000
local purchaseCooldowns = {}
AddEventHandler('playerDropped', function() purchaseCooldowns[source] = nil end)

local function notifyPlayer(src, key, notifType)
    TriggerClientEvent('ox_lib:notify', src, { title = locale(key), type = notifType or 'error', duration = 5000 })
end

local function sellToShop(src, Player, shopInfo, slot, amount)
    local realItem = Inventory.GetItemBySlot(src, slot)
    if not realItem then return notifyPlayer(src, 'error.not_enough_items') end

    local shopItem
    for _, item in ipairs(shopInfo.items) do
        if item.name == realItem.name and item.buyPrice then shopItem = item break end
    end
    if not shopItem then return notifyPlayer(src, 'error.shop_does_not_buy') end

    if realItem.amount < amount then return notifyPlayer(src, 'error.not_enough_items') end

    local quality = realItem.info.quality or 100
    if quality < (shopItem.minQuality or 1) then return notifyPlayer(src, 'error.quality_too_low') end

    if shopItem.amount and shopItem.maxStock and shopItem.amount + amount > shopItem.maxStock then
        return notifyPlayer(src, 'error.shop_fully_stocked')
    end

    local payout = math.round(shopItem.buyPrice * amount * (quality / 100), 2)
    if payout <= 0 then return notifyPlayer(src, 'error.worthless_item') end

    -- Remove first; only pay if the removal actually succeeded
    if not Inventory.RemoveItem(src, realItem.name, amount, slot, 'shop-sell') then
        return notifyPlayer(src, 'error.not_enough_items')
    end
    if shopItem.amount then shopItem.amount = shopItem.amount + amount end
    Player.Functions.AddMoney('cash', payout, 'shop-sell')
    return true
end

local function buyFromShop(src, Player, shopInfo, slot, amount)
    local shopSlot = shopInfo.items[slot]
    if not shopSlot then return false end
    if not shopSlot.price then return notifyPlayer(src, 'info.no_price_or_not_for_sale') end

    local itemDef = RSGCore.Shared.Items[shopSlot.name]
    if not itemDef then return false end
    if itemDef.unique then amount = 1 end

    if shopSlot.amount and amount > shopSlot.amount then
        return notifyPlayer(src, 'error.cannot_purchase_more_than_stock')
    end
    if not Inventory.CanAddItem(src, shopSlot.name, amount) then
        return notifyPlayer(src, 'error.cannot_carry')
    end

    local price = math.round(shopSlot.price * amount, 2)
    if not Player.Functions.RemoveMoney('cash', price, 'shop-purchase') then
        return notifyPlayer(src, 'error.not_enough_money')
    end
    if shopSlot.amount then shopSlot.amount = shopSlot.amount - amount end

    if not Inventory.AddItem(src, shopSlot.name, amount, false, shopSlot.info, 'shop-purchase') then
        -- refund if the item could not be delivered at all
        if shopSlot.amount then shopSlot.amount = shopSlot.amount + amount end
        Player.Functions.AddMoney('cash', price, 'shop-purchase refund')
        return notifyPlayer(src, 'error.cannot_carry')
    end
    return true
end

lib.callback.register('rsg-inventory:server:attemptPurchase', function(source, data)
    local now = GetGameTimer()
    if purchaseCooldowns[source] and now - purchaseCooldowns[source] < 500 then return false end
    purchaseCooldowns[source] = now

    if type(data) ~= 'table' or type(data.item) ~= 'table' or type(data.shop) ~= 'string' then return false end

    local amount, slot = tonumber(data.amount), tonumber(data.item.slot)
    if not amount or not slot or amount ~= amount then return false end -- nil / NaN
    amount = math.floor(amount)
    if amount < 1 or amount > MAX_PURCHASE then return false end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local shopName = data.shop:gsub('^shop%-', '')
    local shopInfo = RegisteredShops[shopName]
    if not shopInfo or OpenedInventories[source] ~= 'shop-' .. shopName then return false end

    if shopInfo.coords then
        local shopCoords = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(GetEntityCoords(GetPlayerPed(source)) - shopCoords) > 10.0 then return false end
    end

    local ok
    if data.sourceinvtype == 'player' then
        ok = sellToShop(source, Player, shopInfo, slot, amount)
    else
        ok = buyFromShop(source, Player, shopInfo, slot, amount)
    end

    TriggerClientEvent('rsg-inventory:client:updateInventory', source)
    return ok == true
end)
