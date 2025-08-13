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
    local drops = lib.callback.await('rsg-inventory:server:GetCurrentDrops', false)
    if not drops then return end

    for k, v in pairs(drops) do
        local bag = NetworkGetEntityFromNetworkId(v.entityId)
        if DoesEntityExist(bag) then
            exports['ox_target']:addLocalEntity(bag, {
                {
                    name = 'open_drop_' .. k,
                    icon = 'fas fa-backpack',
                    label = locale('menu.o_bag'),
                    onSelect = function()
                        TriggerServerEvent('rsg-inventory:server:openDrop', k)
                        LocalPlayer.state.currentDrop = k
                    end,
                    distance = 2.5
                }
            })
        end
    end
end