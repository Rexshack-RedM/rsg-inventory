local config = require 'shared.config'
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Drops.ResetPlayerState()
    end
end)


RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Drops.ResetPlayerState()
    Drops.GetDrops()
end)


RegisterNetEvent('rsg-inventory:client:removeDropTarget', function(dropId)
    local start = GetGameTimer()
    repeat
        Wait(10)
        if GetGameTimer() - start > 5000 then return end 
    until NetworkDoesNetworkIdExist(dropId)

    local bag = NetworkGetEntityFromNetworkId(dropId)
    start = GetGameTimer()
    repeat
        Wait(10)
        if GetGameTimer() - start > 5000 then return end
    until DoesEntityExist(bag)

    exports.ox_target:removeEntity(bag)
end)


RegisterNetEvent('rsg-inventory:client:setupDropTarget', function(dropId)
    local start = GetGameTimer()
    repeat
        Wait(10)
        if GetGameTimer() - start > 5000 then return end
    until NetworkDoesNetworkIdExist(dropId)

    local bag = NetworkGetEntityFromNetworkId(dropId)
    start = GetGameTimer()
    repeat
        Wait(10)
        if GetGameTimer() - start > 5000 then return end
    until DoesEntityExist(bag)

    local newDropId = Helpers.CreateDropId(dropId)

    exports.ox_target:addEntity(bag, {
        {
            icon = 'fas fa-backpack',
            label = locale('info.o_bag'),
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('rsg-inventory:server:openDrop', newDropId)
                LocalPlayer.state.currentDrop = newDropId
            end
        },
        {
            icon = 'fas fa-hand-pointer',
            label = locale('info.menu_pickup_bag'),
            distance = 2.5,
            onSelect = function()
                local weapon = GetPedCurrentHeldWeapon(PlayerPedId())

                if weapon ~= `WEAPON_UNARMED` then
                    return lib.notify({
                        title = locale('error.error'),
                        description = locale('error.menu.error_gun_and_bag'),
                        type = 'error',
                        duration = 5500
                    })
                end

                if LocalPlayer.state.holdingDrop then
                    return lib.notify({
                        title = locale('error.error'),
                        description = locale('error.error_already_holding_bag'),
                        type = 'error',
                        duration = 5500
                    })
                end

               
                Citizen.InvokeNative(
                    0x524B54361229154F, 
                    PlayerPedId(), 
                    GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"), 
                    0, 1, 
                    GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"), 
                    -1.0, 0
                )

                Wait(1000)

                local boneIndex = GetEntityBoneIndexByName(PlayerPedId(), config.ItemDropObjectBone)
                AttachEntityToEntity(
                    bag,
                    PlayerPedId(),
                    boneIndex,
                    config.ItemDropObjectOffset[1].x,
                    config.ItemDropObjectOffset[1].y,
                    config.ItemDropObjectOffset[1].z,
                    config.ItemDropObjectOffset[2].x,
                    config.ItemDropObjectOffset[2].y,
                    config.ItemDropObjectOffset[2].z,
                    true, true, false, true, 1, true
                )

                LocalPlayer.state.dropBagObject = bag
                LocalPlayer.state.holdingDrop = true
                LocalPlayer.state.heldDrop = newDropId
            end
        }
    })
end)