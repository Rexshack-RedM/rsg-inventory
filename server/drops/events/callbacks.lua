local config = lib.load("config.config")

lib.callback.register('rsg-inventory:server:GetCurrentDrops', function(source)
    return Drops
end)

lib.callback.register('rsg-inventory:server:createDrop', function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    local isMove = false

    if item.type == 'weapon' then
        isMove = true
        Inventory.CheckWeapon(source, item)
    end

    if not Inventory.RemoveItem(source, item.name, item.amount, item.fromSlot, 'dropped item', isMove) then
        return false
    end

    
    TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)

    
    local bag = CreateObjectNoOffset(config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5, playerCoords.z, true, true, false)

    local timeout = 100 
    while not DoesEntityExist(bag) and timeout > 0 do
        Wait(50)
        timeout -= 1
    end

    if not DoesEntityExist(bag) then return false end

    local dropId = NetworkGetNetworkIdFromEntity(bag)
    local newDropId = Helpers.CreateDropId(dropId)

    local itemsTable = { item }


    if not Drops[newDropId] then
        Drops[newDropId] = {
            name = newDropId,
            label = 'Drop',
            items = itemsTable,
            entityId = dropId,
            createdTime = os.time(),
            coords = playerCoords,
            maxweight = config.DropSize.maxweight,
            slots = config.DropSize.slots,
            isOpen = true
        }

        TriggerClientEvent('rsg-inventory:client:setupDropTarget', -1, dropId)
    else
        table.insert(Drops[newDropId].items, item)
    end

    return dropId
end)