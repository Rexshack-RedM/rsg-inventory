Drops = {}

---Resets the player drop-related state.
---If the player is currently holding a dropped bag, it will trigger a skin reload
---to detach/remove the object and then reset all drop state values.
function Drops.ResetPlayerState()
    if LocalPlayer.state.holdingDrop then
        -- Forces a skin reload so the bag gets detached if still attached
        ExecuteCommand('loadskin')
    end

    LocalPlayer.state.holdingDrop   = nil
    LocalPlayer.state.dropBagObject = nil
    LocalPlayer.state.heldDrop      = nil
end

---Fetches all current world drops from the server and adds a target interaction
---(`ox_target`) for each entity that still exists.
function Drops.GetDrops()
    local drops = lib.callback.await('rsg-inventory:server:GetCurrentDrops', false)
    if not drops then return end

    for k, v in pairs(drops) do
        local bag = NetworkGetEntityFromNetworkId(v.entityId)
        if DoesEntityExist(bag) then
            exports.ox_target:addLocalEntity(bag, {
                {
                    name     = 'open_drop_' .. k,
                    icon     = 'fas fa-backpack',
                    label    = locale('info.o_bag'),
                    distance = 2.5,
                    onSelect = function()
                        TriggerServerEvent('rsg-inventory:server:openDrop', k)
                        LocalPlayer.state.currentDrop = k
                    end
                }
            })
        end
    end
end