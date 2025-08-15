-- Callback to get all current item drops
lib.callback.register('rsg-inventory:server:GetCurrentDrops', function(source)
    return Drops -- return the table containing all active drops
end)

-- Callback to create a new item drop
lib.callback.register('rsg-inventory:server:createDrop', function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source) -- get the player object
    if not Player then return false end

    local playerPed = GetPlayerPed(source) -- get player's ped
    local playerCoords = GetEntityCoords(playerPed) -- get player's coordinates
    local isMove = false -- flag if the item is a weapon (for special handling)

    -- Special handling for weapons
    if item.type == 'weapon' then
        isMove = true
        Inventory.CheckWeapon(source, item) -- check/remove weapon if needed
    end

    -- Remove the item from the player's inventory
    if not Inventory.RemoveItem(source, item.name, item.amount, item.fromSlot, 'dropped item', isMove) then
        return false -- stop if item could not be removed
    end

    -- Play pickup animation for player
    TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)

    local config = require 'shared.config'
    -- Create the physical object in the world for the drop
    local bag = CreateObjectNoOffset(
        config.ItemDropObject,                       -- object model (bag/box)
        playerCoords.x + 0.5,                        -- slightly offset X
        playerCoords.y + 0.5,                        -- slightly offset Y
        playerCoords.z,                              -- Z coordinate
        true, true, false                             -- dynamic, networked, not visible initially
    )

    -- Wait until the object actually exists in the world (timeout 5s)
    local timeout = 100 
    while not DoesEntityExist(bag) and timeout > 0 do
        Wait(50)
        timeout -= 1
    end

    if not DoesEntityExist(bag) then return false end -- fail if object still doesn't exist

    -- Get network ID for the object (used to sync with clients)
    local dropId = NetworkGetNetworkIdFromEntity(bag)
    local newDropId = Helpers.CreateDropId(dropId) -- generate a unique ID for the drop

    local itemsTable = { item } -- table of items in this drop

    -- If this is a new drop, initialize it
    if not Drops[newDropId] then
        Drops[newDropId] = {
            name = newDropId,
            label = 'Drop',
            items = itemsTable,               -- items inside the drop
            entityId = dropId,                -- networked entity ID
            createdTime = os.time(),          -- timestamp of creation
            coords = playerCoords,            -- coordinates of the drop
            maxweight = config.DropSize.maxweight, -- max weight the drop can hold
            slots = config.DropSize.slots,    -- number of item slots
            isOpen = true                     -- whether the drop can be looted
        }

        -- Tell all clients to add this object as an interactable target
        TriggerClientEvent('rsg-inventory:client:setupDropTarget', -1, dropId)
    else
        -- If drop already exists (stacking items), add item to it
        table.insert(Drops[newDropId].items, item)
    end

    return dropId -- return the network ID of the dropped object
end)