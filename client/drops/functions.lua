Drops = {}
Drops.ResetPlayerState = function() 
    if LocalPlayer.state.holdingDrop then
        ExecuteCommand('loadskin')
    end
    LocalPlayer.state.holdingDrop = nil
    LocalPlayer.state.dropBagObject = nil
    LocalPlayer.state.heldDrop = nil
end
Drops.GetDrops = function()
    RSGCore.Functions.TriggerCallback('rsg-inventory:server:GetCurrentDrops', function(drops)
        if not drops then return end

        for dropId, dropData in pairs(drops) do
            local bag = NetworkGetEntityFromNetworkId(dropData.entityId)

            if DoesEntityExist(bag) then
                exports.ox_target:addEntity(bag, {
                    {
                        icon = 'fas fa-backpack',
                        label = locale('o_bag'),
                        onSelect = function()
                            TriggerServerEvent('rsg-inventory:server:openDrop', dropId)
                            LocalPlayer.state.currentDrop = dropId
                        end,
                        distance = 2.5
                    }
                })
            end
        end
    end)
end



