local config     = require 'shared.config'
local RSGCore = exports['rsg-core']:GetCoreObject()
local PlayerData = RSGCore.Functions.GetPlayerData()



---Returns whether or not the player is allowed to open the inventory/hotbar.
---@return boolean
local function canOpen()
    local metadata   = PlayerData.metadata
    return (not IsNuiFocused() and not IsPauseMenuActive()) 
        and (not metadata.isdead and not metadata.ishandcuffed)
end


local function openErrorNotify()
    local metadata   = PlayerData.metadata
    if metadata.isdead then
        lib.notify({
            title       = 'rsg-inventory',
            description = locale('error.openinverror'),
            type        = 'error'
        })
    elseif metadata.ishandcuffed then
        lib.notify({
            title       = 'rsg-inventory',
            description = locale('error.cuffopeninv'),
            type        = 'error'
        })
    end
end

RegisterCommand(config.CommandNames.openInv, function()
    if canOpen() then
        ExecuteCommand(config.CommandNames.Inventory)
    else
        openErrorNotify()
    end
end, false)

RegisterCommand(config.CommandNames.Hotbar, function()
    if canOpen() then
        ExecuteCommand('serversidehotbar')
    else
        openErrorNotify()
    end
end, false)

for i = 1, 5 do
    RegisterCommand('slot_' .. i, function()
        Inventory.UseHotbarItem(i)
    end, false)
end