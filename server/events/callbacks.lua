RSGCore.Functions.CreateCallback('rsg-inventory:server:giveItem', function(source, cb, target, item, amount, slot, info)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or player.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(source)
    local isMove = false
    local Target = RSGCore.Functions.GetPlayer(target)
    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or Target.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local targetPed = GetPlayerPed(target)

    local pCoords = GetEntityCoords(playerPed)
    local tCoords = GetEntityCoords(targetPed)
    if #(pCoords - tCoords) > 5 then
        cb(false)
        return
    end

    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then
        cb(false)
        return
    end

    if itemInfo.type == 'weapon' then 
        isMove = true
        Inventory.CheckWeapon(source, item) 
    end

    local hasItem = Inventory.HasItem(source, item)
    if not hasItem then
        cb(false)
        return
    end

    local itemAmount = Inventory.GetItemByName(source, item).amount
    if itemAmount <= 0 then
        cb(false)
        return
    end

    local giveAmount = tonumber(amount)
    if giveAmount > itemAmount then
        cb(false)
        return
    end

    local giveItem = Inventory.AddItem(target, item, giveAmount, false, info, 'Item given from ID #' .. source)
    if not giveItem then
        cb(false)
        return
    end

    local removeItem = Inventory.RemoveItem(source, item, giveAmount, slot, 'Item given to ID #' .. target, isMove)
    if not removeItem then
        cb(false)
        return
    end

    TriggerClientEvent('rsg-inventory:client:giveAnim', source)
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, itemInfo, 'remove', giveAmount)
    TriggerClientEvent('rsg-inventory:client:giveAnim', target)
    TriggerClientEvent('rsg-inventory:client:ItemBox', target, itemInfo, 'add', giveAmount)
    if Player(target).state.inv_busy then TriggerClientEvent('rsg-inventory:client:updateInventory', target) end
    cb(true)
end)