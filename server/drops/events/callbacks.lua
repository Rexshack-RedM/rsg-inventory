local RSGCore = exports['rsg-core']:GetCoreObject()
-- Callback to get all current item drops
lib.callback.register('rsg-inventory:server:GetCurrentDrops', function(source)
    return Drops -- return the table containing all active drops
end)

-- Shared function to create drops (eliminates code duplication)
local function CreateItemDrop(coords, itemData, shouldRemoveFromInventory, source)
    local config = require 'shared.config'

    -- Remove item from inventory if requested (for manual drops)
    if shouldRemoveFromInventory and source then
        local isMove = itemData.type == 'weapon'
        if isMove then
            Inventory.CheckWeapon(source, itemData)
        end

        if not Inventory.RemoveItem(source, itemData.name, itemData.amount, itemData.fromSlot, 'dropped item', isMove) then
            return false
        end

        -- Play pickup animation
        local playerPed = GetPlayerPed(source)
        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)
    end

    -- Create the bag entity
    local bag = CreateObjectNoOffset(
        config.ItemDropObject,
        coords.x + 0.5,
        coords.y + 0.5,
        coords.z,
        true, true, false
    )

    -- Wait for entity to spawn with timeout
    local timeout = 100
    while not DoesEntityExist(bag) and timeout > 0 do
        Wait(50)
        timeout -= 1
    end

    if not DoesEntityExist(bag) then return false end

    -- Get network ID and create drop ID
    local networkId = NetworkGetNetworkIdFromEntity(bag)
    local newDropId = Helpers.CreateDropId(networkId)

    -- Create itemsTable
    local itemsTable = { itemData }

    -- Create or update drop
    if not Drops[newDropId] then
        Drops[newDropId] = {
            name = newDropId,
            label = 'Drop',
            items = itemsTable,
            entityId = networkId,
            createdTime = os.time(),
            coords = coords,
            maxweight = config.DropSize.maxweight,
            slots = config.DropSize.slots,
            isOpen = false
        }

        -- Setup client target
        TriggerClientEvent('rsg-inventory:client:setupDropTarget', -1, networkId)
    else
        -- Add to existing drop
        table.insert(Drops[newDropId].items, itemData)
    end

    return networkId
end

Helpers.CreateItemDrop = CreateItemDrop

-- Callback to create a new item drop
lib.callback.register('rsg-inventory:server:createDrop', function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)

    -- Use shared drop creation function
    return CreateItemDrop(playerCoords, item, true, source)
end)