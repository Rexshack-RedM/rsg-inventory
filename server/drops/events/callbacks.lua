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
        -- Fetch the real item server-side by slot (don't trust client metadata)
        local realItem = Inventory.GetItemBySlot(source, itemData.fromSlot)
        if not realItem or realItem.name:lower() ~= itemData.name:lower() or realItem.amount < itemData.amount then
            return false
        end

        -- Use server-side item data for the drop payload
        itemData.name   = realItem.name
        itemData.amount = itemData.amount
        itemData.info   = realItem.info or {}
        itemData.type   = realItem.type
        itemData.label  = realItem.label
        itemData.weight = realItem.weight

        local isMove = realItem.type == 'weapon'
        if isMove then
            Inventory.CheckWeapon(source, itemData)
        end

        if not Inventory.RemoveItem(source, realItem.name, itemData.amount, itemData.fromSlot, 'dropped item', isMove) then
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

-- Rate limiting for drop creation
local dropCooldowns = {}

-- Callback to create a new item drop
lib.callback.register('rsg-inventory:server:createDrop', function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    -- Rate limit
    local now = os.time()
    if dropCooldowns[source] and now - dropCooldowns[source] < 1 then return false end
    dropCooldowns[source] = now

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)

    -- Use shared drop creation function
    return CreateItemDrop(playerCoords, item, true, source)
end)