local config = require 'shared.config'

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
--- Waits (max ~5s) for a networked entity to exist locally
local function waitForEntity(netId)
    local timeout = GetGameTimer() + 5000
    while not NetworkDoesNetworkIdExist(netId) do
        if GetGameTimer() > timeout then return end
        Wait(50)
    end
    local entity = NetworkGetEntityFromNetworkId(netId)
    while not DoesEntityExist(entity) do
        if GetGameTimer() > timeout then return end
        Wait(50)
        entity = NetworkGetEntityFromNetworkId(netId)
    end
    return entity
end

RegisterNetEvent('rsg-inventory:client:removeDropTarget', function(dropId)
    local bag = waitForEntity(dropId)
    if bag then exports.ox_target:removeLocalEntity(bag) end
end)

---Adds ox_target interactions (open / pickup) to a dropped bag entity.
---@param dropId number Network ID of the bag entity
function Drops.SetupTarget(dropId)
    local bag = waitForEntity(dropId)
    if not bag then return end

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
                local weapon = GetPedCurrentHeldWeapon(cache.ped)

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
                TaskStartScenarioInPlaceHash(cache.ped, GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"), 0, 1, GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"), -1.0, 0)

                Wait(1000)

                -- Attach bag to player's bone
                local boneIndex = GetEntityBoneIndexByName(cache.ped, config.ItemDropObjectBone)

                AttachEntityToEntity(
                    bag,
                    cache.ped,
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
end

RegisterNetEvent('rsg-inventory:client:setupDropTarget', Drops.SetupTarget)
