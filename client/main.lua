local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'

lib.callback.register('rsg-inventory:client:isInMelee', function()
    return IsPedInMeleeCombat(cache.ped)
end)

-- Vending machines (ox_target)
CreateThread(function()
    local models = config.VendingObjects
    if not models or #models == 0 then return end

    exports.ox_target:addModel(models, {
        label = locale('info.vending'),
        icon = 'fa-solid fa-cash-register',
        distance = 2.5,
        onSelect = function(data)
            TriggerServerEvent('rsg-inventory:server:openVending', { coords = GetEntityCoords(data.entity) })
        end,
    })
end)

-- Keybinds for inventory, hotbar and hotbar slots
CreateThread(function()
    local openKeys = {
        [config.Keybinds.Open]   = 'inventory',
        [config.Keybinds.Hotbar] = 'hotbar',
    }
    local slotKeys = {}
    for i = 1, 5 do
        slotKeys[RSGCore.Shared.Keybinds[tostring(i)]] = 'slot_' .. i
    end

    while true do
        Wait(0)
        if not IsNuiFocused() and not IsPauseMenuActive() then
            for control, command in pairs(slotKeys) do
                DisableControlAction(0, control, true)
                if IsDisabledControlJustPressed(0, control) and Inventory.CanPlayerUseInventory() then
                    ExecuteCommand(command)
                end
            end
            for control, command in pairs(openKeys) do
                if IsControlJustReleased(0, control) and Inventory.CanPlayerUseInventory() then
                    ExecuteCommand(command)
                end
            end
        end
    end
end)
