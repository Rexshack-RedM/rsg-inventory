-- Triggered when the player has fully loaded into the server
-- Sets the 'inv_busy' state to false, meaning the inventory is not busy
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
end)

-- Triggered when the player unloads (disconnects, dies, or leaves)
-- Sets the 'inv_busy' state to true to prevent inventory interactions
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
end)

-- Plays the "give item" animation on the player
-- Only works if the player is not in a vehicle or on a mount
RegisterNetEvent('rsg-inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(cache.ped, false) or IsPedOnMount(cache.ped) then 
        return -- do nothing if in vehicle or on horse
    end

    local dict = 'mech_butcher' -- animation dictionary
    lib.requestAnimDict(dict) -- ensure animation dict is loaded
    TaskPlayAnim(cache.ped, dict, 'small_fish_give_player', 8.0, 1.0, -1, 16, 0, false, false, false)
    RemoveAnimDict(dict) -- clean up animation dict from memory
end)

