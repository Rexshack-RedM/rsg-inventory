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

---Fetches all current world drops from the server and adds ox_target interactions to each bag.
function Drops.GetDrops()
    local drops = lib.callback.await('rsg-inventory:server:GetCurrentDrops', false)
    if not drops then return end
    for _, netId in pairs(drops) do
        CreateThread(function() Drops.SetupTarget(netId) end)
    end
end
