lib.callback.register('rsg-inventory:openDrop', function(source, dropId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local ped = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(ped)
    local drop = Drops[dropId]
    if not drop or drop.isOpen then return end
    if #(playerCoords - drop.coords) > 2.5 then return end
    Inventory.CheckItemsDecay(drop.items)
    local formattedInventory = {
        name = dropId,
        label = dropId,
        maxweight = drop.maxweight,
        slots = drop.slots,
        inventory = drop.items
    }
    drop.isOpen = true
    return {playerItems = Player.PlayerData.items, dropInventory = formattedInventory}
end)
lib.callback.register('rsg-inventory:updateDrop', function(_, dropId, coords)
    if Drops[dropId] then
        Drops[dropId].coords = coords
        return true
    end
    return false
end)