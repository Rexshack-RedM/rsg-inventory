local RSGCore = exports['rsg-core']:GetCoreObject()
-- Open drops
RegisterNetEvent('rsg-inventory:server:openDrop', function(dropId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Get player position
    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)

    -- Get the drop by ID
    local drop = Drops[dropId]
    if not drop or drop.isOpen then return end

    -- Check if player is close enough to the drop
    if #(playerCoords - drop.coords) > 2.5 then return end

    -- Check for item decay
    Inventory.CheckItemsDecay(drop.items)

    -- Format the drop inventory for the client
    local formattedInventory = {
        name      = dropId,
        label     = dropId,
        maxweight = drop.maxweight,
        slots     = drop.slots,
        inventory = drop.items
    }

    -- Mark the drop as open
    drop.isOpen = true

    -- Send both player inventory and drop inventory to client
    TriggerClientEvent('rsg-inventory:client:openInventory', src, Player.PlayerData.items, formattedInventory)
end)
    -- update drops
lib.callback.register('rsg-inventory:updateDrop', function(source, dropId, coords)
    local drop = Drops and Drops[dropId]
    if not drop then
        return false, 'no bag'
    end

    -- Validate coordinates (accepts vector3 or table with x/y/z)
    local newCoords = (type(coords) == 'vector3' and coords)
        or (type(coords) == 'table' and coords.x and coords.y and coords.z and vector3(coords.x, coords.y, coords.z))

    if not newCoords then
        return false, 'no coords'
    end

    -- Check if player is close enough to update the drop
    local ped = GetPlayerPed(source)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - newCoords) > Inventory.MAX_DIST then
        return false, 'error distance'
    end

    -- Update drop coordinates
    drop.coords = newCoords
    return true, 'Good'
end)