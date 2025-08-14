
RegisterNetEvent('rsg-inventory:server:openDrop', function(dropId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    local drop = Drops[dropId]
    if not drop or drop.isOpen then return end
    if #(playerCoords - drop.coords) > 2.5 then return end
    Inventory.CheckItemsDecay(drop.items)
    local formattedInventory = {
        name      = dropId,
        label     = dropId,
        maxweight = drop.maxweight,
        slots     = drop.slots,
        inventory = drop.items
    }
    drop.isOpen = true
    TriggerClientEvent('rsg-inventory:client:openInventory', src, Player.PlayerData.items, formattedInventory)
end)

lib.callback.register('rsg-inventory:updateDrop', function(source, dropId, coords)
    local drop = Drops and Drops[dropId]
    if not drop then
        return false, 'no bag'
    end
    local newCoords = (type(coords) == 'vector3' and coords)
        or (type(coords) == 'table' and coords.x and coords.y and coords.z and vector3(coords.x, coords.y, coords.z))
    if not newCoords then
        return false, 'no coords'
    end
    local ped = GetPlayerPed(source)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - newCoords) > 5.0 then
        return false, 'error distance'
    end
    drop.coords = newCoords
    return true, 'Good'
end)