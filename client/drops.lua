holdingDrop = false
local bagObject = nil
local heldDrop = nil
CurrentDrop = nil

-- Functions

function GetDrops()
    RSGCore.Functions.TriggerCallback('rsg-inventory:server:GetCurrentDrops', function(drops)
        if not drops then return end
        for k, v in pairs(drops) do
            local bag = NetworkGetEntityFromNetworkId(v.entityId)
            if DoesEntityExist(bag) then
                exports['rsg-target']:AddTargetEntity(bag, {
                    options = {
                        {
                            icon = 'fas fa-backpack',
                            label = Lang:t('menu.o_bag'),
                            action = function()
                                TriggerServerEvent('rsg-inventory:server:openDrop', k)
                                CurrentDrop = k
                            end,
                        },
                    },
                    distance = 2.5,
                })
            end
        end
    end)
end

-- Events

RegisterNetEvent('rsg-inventory:client:removeDropTarget', function(dropId)
    while not NetworkDoesNetworkIdExist(dropId) do Wait(10) end
    local bag = NetworkGetEntityFromNetworkId(dropId)
    while not DoesEntityExist(bag) do Wait(10) end
    exports['rsg-target']:RemoveTargetEntity(bag)
end)

RegisterNetEvent('rsg-inventory:client:setupDropTarget', function(dropId)
    while not NetworkDoesNetworkIdExist(dropId) do Wait(10) end
    local bag = NetworkGetEntityFromNetworkId(dropId)
    while not DoesEntityExist(bag) do Wait(10) end
    local newDropId = 'drop-' .. dropId
    exports['rsg-target']:AddTargetEntity(bag, {
        options = {
            {
                icon = 'fas fa-backpack',
                label = Lang:t('menu.o_bag'),
                action = function()
                    TriggerServerEvent('rsg-inventory:server:openDrop', newDropId)
                    CurrentDrop = newDropId
                end,
            },
            {
                icon = 'fas fa-hand-pointer',
                label = 'Pick up bag',
                action = function()
                    local weapon = GetPedCurrentHeldWeapon(PlayerPedId())
                    if weapon ~= `WEAPON_UNARMED` then
                        return RSGCore.Functions.Notify("You can not be holding a Gun and a Bag!", "error", 5500)
                    end
                    if holdingDrop then
                        return RSGCore.Functions.Notify("Your already holding a bag, Go Drop it!", "error", 5500)
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
                    bagObject = bag
                    holdingDrop = true
                    heldDrop = newDropId
                    exports['rsg-core']:DrawText('Press [G] to drop the bag')
                end,
            }
        },
        distance = 2.5,
    })
end)

-- NUI Callbacks

RegisterNUICallback('DropItem', function(item, cb)
    RSGCore.Functions.TriggerCallback('rsg-inventory:server:createDrop', function(dropId)
        if dropId then
            Citizen.InvokeNative(0x524B54361229154F, PlayerPedId(), GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"), 0, 1, GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"), -1.0, 0)
            while not NetworkDoesNetworkIdExist(dropId) do Wait(10) end
            local bag = NetworkGetEntityFromNetworkId(dropId)
            SetModelAsNoLongerNeeded(bag)
            local coords = GetEntityCoords(PlayerPedId())
            local forward = GetEntityForwardVector(PlayerPedId())
            local x, y, z = table.unpack(coords + forward * 0.57)
            SetEntityCoords(bag, x, y, z - 0.9, false, false, false, false)
            SetEntityRotation(bag, 0.0, 0.0, 0.0, 2)
            PlaceObjectOnGroundProperly(bag)
            FreezeEntityPosition(bag, true)
            local newDropId = 'drop-' .. dropId
            cb(newDropId)
        else
            cb(false)
        end
    end, item)
end)

-- Thread

CreateThread(function()
    while true do
        if holdingDrop then
            if IsControlJustPressed(0, 0x760A9C6F) then
                Citizen.InvokeNative(0x524B54361229154F, PlayerPedId(), GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH"), 0, 1, GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH"), -1.0, 0)
                Wait(1000)
                DetachEntity(bagObject, true, true)
                local coords = GetEntityCoords(PlayerPedId())
                local forward = GetEntityForwardVector(PlayerPedId())
                local x, y, z = table.unpack(coords + forward * 0.57)
                SetEntityCoords(bagObject, x, y, z - 0.9, false, false, false, false)
                SetEntityRotation(bagObject, 0.0, 0.0, 0.0, 2)
                PlaceObjectOnGroundProperly(bagObject)
                FreezeEntityPosition(bagObject, true)
                exports['rsg-core']:HideText()
                TriggerServerEvent('rsg-inventory:server:updateDrop', heldDrop, coords)
                holdingDrop = false
                bagObject = nil
                heldDrop = nil
            end
        end
        Wait(0)
    end
end)
