RegisterNetEvent('rsg-inventory:client:removeDropTarget', function(dropId)
    repeat Wait(10) until NetworkDoesNetworkIdExist(dropId)
    local bag = NetworkGetEntityFromNetworkId(dropId)
    repeat Wait(10) until DoesEntityExist(bag)
    exports['rsg-target']:RemoveTargetEntity(bag)
end)

RegisterNetEvent('rsg-inventory:client:setupDropTarget', function(dropId)
    repeat Wait(10) until NetworkDoesNetworkIdExist(dropId)
    local bag = NetworkGetEntityFromNetworkId(dropId)
    repeat Wait(10) until DoesEntityExist(bag)
    local newDropId = CreateDropId(dropId)

    exports['rsg-target']:AddTargetEntity(bag, {
        options = {
            {
                icon = 'fas fa-backpack',
                label = Lang:t('menu.o_bag'),
                action = function()
                    TriggerServerEvent('rsg-inventory:server:openDrop', newDropId)
                    LocalPlayer.state.currentDrop = newDropId
                end,
            },
            {
                icon = 'fas fa-hand-pointer',
                label = 'Pick up bag',
                action = function()
                    local weapon = GetPedCurrentHeldWeapon(PlayerPedId())

                    if weapon ~= `WEAPON_UNARMED` then
                        return lib.notify({ title = 'Error!', description = 'You can not be holding a Gun and a Bag!', type = 'error', duration = 5500 })
                    end
                    if LocalPlayer.state.holdingDrop then
                        return lib.notify({ title = 'Error!', description = 'Your already holding a bag, Go Drop it!', type = 'error', duration = 5500 })
                    end

                    Citizen.InvokeNative(0x524B54361229154F, PlayerPedId(), GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"), 0, 1, GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"), -1.0, 0)
                    Wait(1000)
                    local boneIndex = GetEntityBoneIndexByName(PlayerPedId(), Config.ItemDropObjectBone)
                    AttachEntityToEntity(
                        bag,
                        PlayerPedId(),
                        boneIndex,
                        Config.ItemDropObjectOffset[1].x,
                        Config.ItemDropObjectOffset[1].y,
                        Config.ItemDropObjectOffset[1].z,
                        Config.ItemDropObjectOffset[2].x,
                        Config.ItemDropObjectOffset[2].y,
                        Config.ItemDropObjectOffset[2].z,
                        true, true, false, true, 1, true
                    )
                    LocalPlayer.state.dropBagObject = bag
                    LocalPlayer.state.holdingDrop = true
                    LocalPlayer.state.heldDrop = newDropId
                end,
            }
        },
        distance = 2.5,
    })
end)