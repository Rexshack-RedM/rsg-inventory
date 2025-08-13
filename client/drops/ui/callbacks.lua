RegisterNUICallback('DropItem', function(item, cb)
    local dropId = lib.callback.await('rsg-inventory:server:createDrop', false, item)

    if not dropId then
        cb(false)
        return
    end
    ClearPedTasksImmediately(cache.ped)
    TaskStartScenarioInPlaceHash(
        cache.ped,
        GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"),
        0,
        1,
        GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"),
        -1.0,
        0
    )
    local timeout = 100
    while not NetworkDoesNetworkIdExist(dropId) and timeout > 0 do
        Wait(50)
        timeout -= 1
    end

    if not NetworkDoesNetworkIdExist(dropId) then
        cb(false)
        return
    end

    local bag = NetworkGetEntityFromNetworkId(dropId)
    SetModelAsNoLongerNeeded(bag)
    local coords = GetEntityCoords(cache.ped)
    local forward = GetEntityForwardVector(cache.ped)
    local x, y, z = table.unpack(coords + forward * 0.57)
    SetEntityCoords(bag, x, y, z - 0.9, false, false, false, false)
    SetEntityRotation(bag, 0.0, 0.0, 0.0, 2)
    PlaceObjectOnGroundProperly(bag)
    FreezeEntityPosition(bag, true)
    local newDropId = Helpers.CreateDropId(dropId)
    cb(newDropId)
end)

RegisterNUICallback('PlayDropFail', function(_, cb)
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)