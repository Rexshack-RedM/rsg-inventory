local config = require 'shared.config'


RegisterCommand(config.CommandNames.openInv, function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if IsNuiFocused() or IsPauseMenuActive() then return end
    if PlayerData.metadata.isdead then
        lib.notify({
            title = 'rsg-inventory',
            description = locale('error.openinverror'),
            type = 'error'
        })
        return
    end
    if PlayerData.metadata.ishandcuffed then
        lib.notify({
            title = 'rsg-inventory',
            description = locale('error.cuffopeninv'),
            type = 'error'
        })
        return
    end
    ExecuteCommand('inventory')
end, false)

RegisterCommand(config.CommandNames.toggleHotbar, function()
    local PlayerData = RSGCore.Functions.GetPlayerData()

    if PlayerData.metadata.isdead then
        lib.notify({
            title = 'Hotbar', 
            description = locale('error.hotbarerror'),
            type = 'error'
        })
        return
    end
    if PlayerData.metadata.ishandcuffed then
        lib.notify({   
            title = 'Hotbar',
            description = locale('error.hotbarerror1'),
            type = 'error'
        })
        return
    end
    ExecuteCommand('hotbar')
end, false)


for i = 1, 5 do
    RegisterCommand(config.CommandNames["slot_" .. i], function()
        Inventory.UseHotbarItem(i)
    end, false)
end
