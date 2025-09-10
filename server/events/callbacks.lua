local RSGCore = exports['rsg-core']:GetCoreObject()
-- Register a server callback for giving an item from one player to another
lib.callback.register('rsg-inventory:server:giveItem', function(source, target, item, amount, slot, info)
    -- Get the player object for the source (the giver)
    local player = RSGCore.Functions.GetPlayer(source)
    -- Check if the source player exists and is not dead, in last stand, or handcuffed
    if not player or player.PlayerData.metadata.isdead or player.PlayerData.metadata.inlaststand or player.PlayerData.metadata.ishandcuffed then
        return false
    end

    -- Get the player object for the target (the receiver)
    local Target = RSGCore.Functions.GetPlayer(target)
    -- Check if the target player exists and is not dead, in last stand, or handcuffed
    if not Target or Target.PlayerData.metadata.isdead or Target.PlayerData.metadata.inlaststand or Target.PlayerData.metadata.ishandcuffed then
        return false
    end

    -- Check if the distance between source and target is within 5 units
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(target))) > Inventory.MAX_DIST then
        return false
    end

    -- Get item information from the shared items list
    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then
        return false
    end

    -- Initialize a flag to track if the item is a weapon
    local isMove = false
    if itemInfo.type == 'weapon' then
        isMove = true
        Inventory.CheckWeapon(source, item) -- Check or remove the weapon from the source
    end

    -- Check if the source has the item
    if not Inventory.HasItem(source, item) then
        return false
    end

    -- Get the inventory entry for the item
    local invItem = Inventory.GetItemByName(source, item)
    -- Verify the item exists and the amount to give is valid
    if not invItem or invItem.amount <= 0 or tonumber(amount) > invItem.amount then
        return false
    end

    -- Try to add the item to the target player's inventory
    if not Inventory.AddItem(target, item, amount, false, info, ('Item given from ID #%s'):format(source)) then
        return false
    end

    -- Remove the item from the source player's inventory
    if not Inventory.RemoveItem(source, item, amount, slot, ('Item given to ID #%s'):format(target), isMove) then
        return false
    end

    -- Trigger give animation for both players
    TriggerClientEvent('rsg-inventory:client:giveAnim', source)
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, itemInfo, 'remove', amount)
    TriggerClientEvent('rsg-inventory:client:giveAnim', target)
    TriggerClientEvent('rsg-inventory:client:ItemBox', target, itemInfo, 'add', amount)

    -- Update the target's inventory if they are marked as busy
    if Player(target).state.inv_busy then
        TriggerClientEvent('rsg-inventory:client:updateInventory', target)
    end

    -- Return true to indicate success
    return true
end)