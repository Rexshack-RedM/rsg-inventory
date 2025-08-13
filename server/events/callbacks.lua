lib.callback.register('rsg-inventory:server:giveItem', function(source, target, item, amount, slot, info)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or player.PlayerData.metadata['ishandcuffed'] then
        return false
    end
    local Target = RSGCore.Functions.GetPlayer(target)
    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or Target.PlayerData.metadata['ishandcuffed'] then
        return false
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(target))) > 5.0 then
        return false
    end
    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then
        return false
    end
    local isMove = false
    if itemInfo.type == 'weapon' then
        isMove = true
        Inventory.CheckWeapon(source, item)
    end
    if not Inventory.HasItem(source, item) then
        return false
    end
    local invItem = Inventory.GetItemByName(source, item)
    if not invItem or invItem.amount <= 0 or tonumber(amount) > invItem.amount then
        return false
    end
    if not Inventory.AddItem(target, item, amount, false, info, ('Item given from ID #%s'):format(source)) then
        return false
    end
    if not Inventory.RemoveItem(source, item, amount, slot, ('Item given to ID #%s'):format(target), isMove) then
        return false
    end
    TriggerClientEvent('rsg-inventory:client:giveAnim', source)
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, itemInfo, 'remove', amount)
    TriggerClientEvent('rsg-inventory:client:giveAnim', target)
    TriggerClientEvent('rsg-inventory:client:ItemBox', target, itemInfo, 'add', amount)
    if Player(target).state.inv_busy then
        TriggerClientEvent('rsg-inventory:client:updateInventory', target)
    end
    return true
end)