-- Callback triggered when a player drops an item from their inventory
RegisterNUICallback('DropItem', function(item, cb)
    -- Request the server to create a dropped item entity and get its network ID
    local dropId = lib.callback.await('rsg-inventory:server:createDrop', false, item)

    -- If the drop creation failed, return false to the UI
    if not dropId then
        cb(false)
        return
    end

    -- Instantly stop any current animation or task the player is doing
    ClearPedTasksImmediately(cache.ped)

    -- Start a pickup animation using a specific scenario hash
    TaskStartScenarioInPlaceHash(
        cache.ped,
        GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"), -- Main animation
        0,
        1,
        GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"), -- Sub animation
        -1.0,
        0
    )

    -- Wait for the network entity to be created, with a timeout of 100 cycles
    local timeout = 100
    while not NetworkDoesNetworkIdExist(dropId) and timeout > 0 do
        Wait(50)
        timeout -= 1
    end

    -- If the entity still doesn't exist after timeout, return false
    if not NetworkDoesNetworkIdExist(dropId) then
        cb(false)
        return
    end

    -- Get the actual entity from the network ID
    local bag = NetworkGetEntityFromNetworkId(dropId)

    -- Mark the model as no longer needed (frees memory)
    SetModelAsNoLongerNeeded(bag)

    -- Get the player's current position and forward direction
    local coords = GetEntityCoords(cache.ped)
    local forward = GetEntityForwardVector(cache.ped)

    -- Calculate drop position slightly in front of the player
    local x, y, z = table.unpack(coords + forward * 0.57)

    -- Set the bag's position and rotation
    SetEntityCoords(bag, x, y, z - 0.9, false, false, false, false)
    SetEntityRotation(bag, 0.0, 0.0, 0.0, 2)

    -- Ensure the object is placed properly on the ground
    PlaceObjectOnGroundProperly(bag)

    -- Freeze the object so it doesn't move
    FreezeEntityPosition(bag, true)

    -- Generate a new drop ID for tracking and return it to the UI
    local newDropId = Helpers.CreateDropId(dropId)
    cb(newDropId)
end)

-- Callback triggered when dropping an item fails (e.g., invalid or blocked)
RegisterNUICallback('PlayDropFail', function(_, cb)
    -- Play a failure sound to notify the player
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok') -- Return success to the UI even though the drop failed
end)