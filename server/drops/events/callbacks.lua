RSGCore.Functions.CreateCallback('rsg-inventory:server:GetCurrentDrops', function(_, cb)
    cb(Drops)
end)

RSGCore.Functions.CreateCallback('rsg-inventory:server:createDrop', function(source, cb, item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local isMove = false
    if not Player then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
        if item.type == 'weapon' then
            isMove = true
            Inventory.CheckWeapon(src, item) 
        end
    if Inventory.RemoveItem(src, item.name, item.amount, item.fromSlot, 'dropped item', isMove) then
        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)
        local bag = CreateObjectNoOffset(Config.ItemDropObject, playerCoords.x + 0.5, playerCoords.y + 0.5, playerCoords.z, true, true, false)
        while not DoesEntityExist(bag) do Wait(0) end
        local dropId = NetworkGetNetworkIdFromEntity(bag)   
        local newDropId = Helpers.CreateDropId(dropId)
        local itemsTable = setmetatable({ item }, {
            __len = function(t)
                local length = 0
                for _ in pairs(t) do length += 1 end
                return length
            end
        })
        if not Drops[newDropId] then
            Drops[newDropId] = {
                name = newDropId,
                label = 'Drop',
                items = itemsTable,
                entityId = dropId,
                createdTime = os.time(),
                coords = playerCoords,
                maxweight = Config.DropSize.maxweight,
                slots = Config.DropSize.slots,
                isOpen = true
            }
            TriggerClientEvent('rsg-inventory:client:setupDropTarget', -1, dropId)
        else
            table.insert(Drops[newDropId].items, item)
        end
        cb(dropId)
    else
        cb(false)
    end
end)