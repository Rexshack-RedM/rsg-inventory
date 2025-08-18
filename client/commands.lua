local config  = require 'shared.config'
local RSGCore = exports['rsg-core']:GetCoreObject()

-- Helper to always retrieve the latest player metadata from RSG Core
-- Avoids stale data if the player's state changes mid-session (e.g., death, cuffs)
local function getMeta()
    local data = RSGCore.Functions.GetPlayerData()
    return data and data.metadata or {}
end

-- Checks if the inventory/hotbar can be opened right now
-- Conditions:
--  - NUI not focused
--  - Pause menu not open
--  - Player is alive
--  - Player is not handcuffed
local function canOpen()
    local meta = getMeta()
    return (not IsNuiFocused() and not IsPauseMenuActive())
        and (not meta.isdead and not meta.ishandcuffed)
end

-- Displays an error notification if the player cannot open inventory/hotbar
-- Reason shown depends on whether they are dead or cuffed
local function openErrorNotify()
    local meta = getMeta()
    if meta.isdead then
        lib.notify({
            title       = 'rsg-inventory',
            description = locale('error.openinverror'),
            type        = 'error'
        })
    elseif meta.ishandcuffed then
        lib.notify({
            title       = 'rsg-inventory',
            description = locale('error.cuffopeninv'),
            type        = 'error'
        })
    end
end

-- Command to open full inventory
-- If opening is allowed, runs the configured inventory command
-- If not, shows an appropriate error notification
RegisterCommand(config.CommandNames.openInv, function()
    if canOpen() then
        ExecuteCommand(config.CommandNames.Inventory)
    else
        openErrorNotify()
    end
end, false)

-- Command to open hotbar
-- Uses a fixed command for serverside hotbar handling
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