lib.callback.register('rsg-inventory:server:attemptPurchase', function(source, data)
    local itemInfo   = data.item
    local amount     = math.round(data.amount)
    local shopName   = string.gsub(data.shop, '^shop%-', '')
    local price      = itemInfo.price and math.round(itemInfo.price * amount, 2) or nil
    local sinvtype   = data.sourceinvtype
    local targetSlot = data.targetslot
    if itemInfo.unique and amount > 1 then amount = 1 end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    local shopInfo = RegisteredShops[shopName]
    if not shopInfo then return false end
    if shopInfo.coords then
        local playerCoords = GetEntityCoords(GetPlayerPed(source))
        local shopCoords   = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(playerCoords - shopCoords) > 10.0 then
            return false
        end
    end
    if sinvtype == 'player' then
        for _, item in ipairs(shopInfo.items) do
            if itemInfo.name == item.name and item.buyPrice then

                if itemInfo.info.quality and itemInfo.info.quality < (item.minQuality or 1) then
                    TriggerClientEvent('ox_lib:notify', source, { title = locale('error.quality_too_low'), type = 'error', duration = 5000 })
                    return false
                end

                if item.maxStock and item.maxStock < (item.amount + amount) then
                    TriggerClientEvent('ox_lib:notify', source, { title = locale('error.shop_fully_stocked'), type = 'error', duration = 5000 })
                    return false
                end

                if Inventory.HasItem(source, itemInfo.name, amount) then
                    if item.amount then item.amount = item.amount + amount end

                    local buyprice = item.buyPrice * amount
                    if itemInfo.info.quality then
                        buyprice = buyprice * (itemInfo.info.quality / 100)
                    end

                    buyprice = math.round(buyprice, 2)
                    if buyprice < 0.01 then
                        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.worthless_item'), type = 'error', duration = 5000 })
                        return false
                    end

                    Inventory.RemoveItem(source, itemInfo.name, amount, itemInfo.slot, 'shop-sell')
                    Player.Functions.AddMoney('cash', buyprice, 'shop-sell')
                    TriggerClientEvent('rsg-inventory:client:updateInventory', source)
                    return true
                else
                    TriggerClientEvent('ox_lib:notify', source, { title = locale('error.not_enough_items'), type = 'error', duration = 5000 })
                    return false
                end
            end
        end

        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.shop_does_not_buy'), type = 'error', duration = 5000 })
        return false
    end

    local shopSlot = shopInfo.items[itemInfo.slot]
    if not shopSlot or shopSlot.name ~= itemInfo.name then return false end

    if shopSlot.amount and amount > shopSlot.amount then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.cannot_purchase_more_than_stock'), type = 'error', duration = 5000 })
        return false
    end

    if not Inventory.CanAddItem(source, itemInfo.name, amount) then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.cannot_carry'), type = 'error', duration = 5000 })
        return false
    end

    if not price then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('info.no_price_or_not_for_sale'), type = 'error', duration = 5000 })
        return false
    end

    if Player.PlayerData.money.cash < price then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.not_enough_money'), type = 'error', duration = 5000 })
        return false
    end

    if shopSlot.amount then
        shopSlot.amount = shopSlot.amount - amount
    end

    Player.Functions.RemoveMoney('cash', price, 'shop-purchase')
    Inventory.AddItem(source, itemInfo.name, amount, targetSlot, itemInfo.info, 'shop-purchase')
    TriggerClientEvent('rsg-inventory:client:updateInventory', source)
    return true
end)