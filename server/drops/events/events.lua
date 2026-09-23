local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterNetEvent('rsg-inventory:server:openDrop', function(dropId)
    local src = source
    local RSGPlayer = RSGCore.Functions.GetPlayer(src)
    if not RSGPlayer or type(dropId) ~= 'string' then return end
    if Player(src).state.inv_busy then return end

    local drop = Drops[dropId]
    if not drop then return end
    if drop.isOpen and drop.isOpen ~= src then
        return TriggerClientEvent('ox_lib:notify', src, { title = locale('error.inventory_in_use'), type = 'error', duration = 4000 })
    end
    if #(GetEntityCoords(GetPlayerPed(src)) - drop.coords) > 2.5 then return end

    Inventory.CheckItemsDecay(drop.items)

    drop.isOpen = src
    OpenedInventories[src] = dropId
    Player(src).state.inv_busy = true

    TriggerClientEvent('rsg-inventory:client:openInventory', src, RSGPlayer.PlayerData.items, {
        name = dropId,
        label = drop.label,
        maxweight = drop.maxweight,
        slots = drop.slots,
        inventory = drop.items,
    })
end)

--- Updates a drop's position after a player carried and placed the bag.
--- Position comes from the server-side entity; the client value is only a fallback.
lib.callback.register('rsg-inventory:updateDrop', function(source, dropId, coords)
    local drop = type(dropId) == 'string' and Drops[dropId]
    if not drop then return false end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local entity = NetworkGetEntityFromNetworkId(drop.entityId)
    local newCoords = DoesEntityExist(entity) and GetEntityCoords(entity)
    if not newCoords then
        if type(coords) ~= 'vector3' and not (type(coords) == 'table' and coords.x and coords.y and coords.z) then return false end
        newCoords = vector3(coords.x, coords.y, coords.z)
    end

    if #(playerCoords - newCoords) > Inventory.MAX_DIST then return false end
    drop.coords = newCoords
    return true
end)
