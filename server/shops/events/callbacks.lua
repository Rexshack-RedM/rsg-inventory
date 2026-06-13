local RSGCore = exports['rsg-core']:GetCoreObject()

-- Rate limiting
local purchaseCooldowns = {}

-- Helper function for notifications
local function notifyPlayer(source, messageKey, type)
    TriggerClientEvent('ox_lib:notify', source, { title = locale(messageKey), type = type or 'error', duration = 5000 })
end

lib.callback.register('rsg-inventory:server:attemptPurchase', function(source, data)
    -- Rate limit
    local now = os.time()
    if purchaseCooldowns[source] and now - purchaseCooldowns[source] < 1 then return false end
    purchaseCooldowns[source] = now

    local itemInfo      = data.item
    local amount        = math.round(data.amount)
    local shopName      = string.gsub(data.shop, '^shop%-', '')
    local sourceInvType = data.sourceinvtype

    -- Prevent non-positive amount
    if amount <= 0 then return false end

    -- Unique items can only be purchased in quantity 1
    if itemInfo.unique and amount > 1 then amount = 1 end

    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local shopInfo = RegisteredShops[shopName]
    if not shopInfo then return false end

    -- Distance check if shop has coordinates
    if shopInfo.coords then
        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        local shopCoords   = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(playerCoords - shopCoords) > 10.0 then return false end
    end

    -- Selling items to shop
    if sourceInvType == 'player' then
        for _, shopItem in ipairs(shopInfo.items) do
            if itemInfo.name == shopItem.name and shopItem.buyPrice then
                -- Fetch the real item from player inventory by slot (don't trust client quality)
                local realItem = Inventory.GetItemBySlot(source, itemInfo.slot)
                if not realItem or realItem.name ~= itemInfo.name then
                    notifyPlayer(source, 'error.not_enough_items') return false
                end
                local realQuality = realItem.info.quality or 100

                -- Quality check
                if realQuality < (shopItem.minQuality or 1) then
                    notifyPlayer(source, 'error.quality_too_low') return false
                end

                -- Max stock check
                if shopItem.maxStock and shopItem.maxStock < (shopItem.amount + amount) then
                    notifyPlayer(source, 'error.shop_fully_stocked') return false
                end

                -- Player has enough items
                if not Inventory.HasItem(source, itemInfo.name, amount) then
                    notifyPlayer(source, 'error.not_enough_items') return false
                end

                -- Update shop stock and calculate buy price using server-side quality
                if shopItem.amount then shopItem.amount = shopItem.amount + amount end
                local buyPrice = shopItem.buyPrice * amount * (realQuality / 100)
                buyPrice = math.max(0.01, math.round(buyPrice, 2))

                Inventory.RemoveItem(source, itemInfo.name, amount, itemInfo.slot, 'shop-sell')
                Player.Functions.AddMoney('cash', buyPrice, 'shop-sell')
                TriggerClientEvent('rsg-inventory:client:updateInventory', source)
                return true
            end
        end

        notifyPlayer(source, 'error.shop_does_not_buy') return false
    end

    -- Buying items from shop
    local shopSlot = shopInfo.items[itemInfo.slot]
    if not shopSlot or shopSlot.name ~= itemInfo.name then return false end

    if shopSlot.amount and amount > shopSlot.amount then
        notifyPlayer(source, 'error.cannot_purchase_more_than_stock') return false
    end

    if not Inventory.CanAddItem(source, itemInfo.name, amount) then
        notifyPlayer(source, 'error.cannot_carry') return false
    end

    if not shopSlot.price then
        notifyPlayer(source, 'info.no_price_or_not_for_sale') return false
    end

    local price = math.round(shopSlot.price * amount, 2)
    if Player.PlayerData.money.cash < price then
        notifyPlayer(source, 'error.not_enough_money') return false
    end

    if shopSlot.amount then
        shopSlot.amount = shopSlot.amount - amount
    end

    Player.Functions.RemoveMoney('cash', price, 'shop-purchase')
    Inventory.AddItem(source, itemInfo.name, amount, false, itemInfo.info, 'shop-purchase')
    TriggerClientEvent('rsg-inventory:client:updateInventory', source)
    return true
end)
