RSGCore = exports['rsg-core']:GetCoreObject()

CreateThread(function()
    if not #Config.VendingObjects then return end

    exports.ox_target:addModel(Config.VendingObjects, {
        label = Lang:t('menu.vending'),
        icon = 'fa-solid fa-cash-register',
        distance = 2.5,
        onSelect = function(data)
            data.coords = GetEntityCoords(data.entity)
            TriggerServerEvent('rsg-inventory:server:openVending', data)
        end,
    })
end)

CreateThread(function()
    local commands = {
        [Config.Keybinds.Open] = { command = "inventory", disabled = false },
        [Config.Keybinds.Hotbar] = { command = "hotbar", disabled = false },
        [RSGCore.Shared.Keybinds["1"]] = { command = "slot_1", disabled = true },
        [RSGCore.Shared.Keybinds["2"]] = { command = "slot_2", disabled = true },
        [RSGCore.Shared.Keybinds["3"]] = { command = "slot_3", disabled = true },
        [RSGCore.Shared.Keybinds["4"]] = { command = "slot_4", disabled = true },
        [RSGCore.Shared.Keybinds["5"]] = { command = "slot_5", disabled = true }
    }

    while true do
        Wait(0)
        for key, data in pairs(commands) do
            if data.disabled then
                DisableControlAction(0, key)
                if IsDisabledControlPressed(0, key) then
                    if Inventory.CanPlayerUseInventory() then
                        ExecuteCommand(data.command)
                    end
                    break
                end
            else
                if IsControlJustReleased(0, key) then
                    if Inventory.CanPlayerUseInventory() then
                        ExecuteCommand(data.command)
                    end
                    break
                end
            end
        end
    end
end)


