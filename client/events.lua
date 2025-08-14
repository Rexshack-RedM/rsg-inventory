RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
end)

RegisterNetEvent('RSGCore:Client:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

RegisterNetEvent('rsg-inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(cache.ped, false) or IsPedOnMount(cache.ped) then 
        return
    end

    local dict = 'mech_butcher'
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, 'small_fish_give_player', 8.0, 1.0, -1, 16, 0, false, false, false)
    RemoveAnimDict(dict)
end)