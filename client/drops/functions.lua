Drops = {}

Drops.ResetPlayerState = function() 
    -- we run loadskin to drop lootbag if possible
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
                                LocalPlayer.state.currentDrop = k
                            end,
                        },
                    },
                    distance = 2.5,
                })
            end
        end
    end)
end




