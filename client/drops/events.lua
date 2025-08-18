---Handles initialisation of drop system and resetting player drop state
---when the resource starts/restarts.
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Drops.ResetPlayerState()
    end
end)

---Triggered when the player successfully loads into the server.
---Resets drop state and fetches current world drops.
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Drops.ResetPlayerState()
    Drops.GetDrops()
end)

---Removes the target interaction from a dropped bag entity.
---@param dropId number Network ID of the entity that needs to have its ox_target removed
RegisterNetEvent('rsg-inventory:client:removeDropTarget', function(dropId)
    repeat Wait(10) until NetworkDoesNetworkIdExist(dropId)
    local bag = NetworkGetEntityFromNetworkId(dropId)
    repeat Wait(10) until DoesEntityExist(bag)
    exports.ox_target:removeLocalEntity(bag)
end)

---Adds ox_target interactions (open / pickup) to a dropped bag entity.
---@param dropId number Network ID of the bag entity
RegisterNetEvent('rsg-inventory:client:setupDropTarget', function(dropId)
    repeat Wait(10) until NetworkDoesNetworkIdExist(dropId)
    local bag = NetworkGetEntityFromNetworkId(dropId)
    repeat Wait(10) until DoesEntityExist(bag)

    local newDropId = Helpers.CreateDropId(dropId)

    exports.ox_target:addLocalEntity(bag, {
        {
            -- Open bag interaction
            name     = 'open_drop_' .. newDropId,
            icon     = 'fas fa-box',
            label    = locale('info.o_bag'),
            distance = 2.5,
            onSelect = function()
                TriggerServerEvent('rsg-inventory:server:openDrop', newDropId)
                LocalPlayer.state.currentDrop = newDropId
            end,
        },
        {
            -- Pickup bag interaction
            name     = 'pickup_drop_' .. newDropId,
            icon     = 'fas fa-hand-pointer',
            label    = locale('info.Pickup_bag'),
            distance = 2.5,
            onSelect = function()
                local weapon = GetPedCurrentHeldWeapon(PlayerPedId())

                -- Prevent picking up while holding weapon or another drop
                if weapon ~= `WEAPON_UNARMED` then
                    return lib.notify({
                        title       = locale('error.error'),
                        description = locale('error.error_gun_and_bag'),
                        type        = 'error',
                        duration    = 5500
                    })
                end
                if LocalPlayer.state.holdingDrop then
                    return lib.notify({
                        title       = locale('error.error'),
                        description = locale('error.error_already_holding_bag'),
                        type        = 'error',
                        duration    = 5500
                    })
                end

                -- Play pickup animation
                Citizen.InvokeNative(0x524B54361229154F, PlayerPedId(), GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"), 0, 1, GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"), -1.0, 0)

                Wait(1000)

                -- Attach bag to player's bone
                local config    = require 'shared.config'
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

                -- Set client state
                LocalPlayer.state.dropBagObject = bag
                LocalPlayer.state.holdingDrop   = true
                LocalPlayer.state.heldDrop      = newDropId
            end
        }
    })
end)