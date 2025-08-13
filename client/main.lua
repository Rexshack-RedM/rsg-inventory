
local RSGCore = exports['rsg-core']:GetCoreObject()
local config = lib.load("config.config")


CreateThread(function()
    local models = config.VendingObjects
    if not models or #models == 0 then return end

    exports.ox_target:addModel(models, {
        label = locale('info.vending'),
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
        [config.Keybinds.Open]             = { command = "inventory", disabled = false },
        [config.Keybinds.Hotbar]           = { command = "hotbar",    disabled = false },
        [RSGCore.Shared.Keybinds["1"]]     = { command = "slot_1",    disabled = true  },
        [RSGCore.Shared.Keybinds["2"]]     = { command = "slot_2",    disabled = true  },
        [RSGCore.Shared.Keybinds["3"]]     = { command = "slot_3",    disabled = true  },
        [RSGCore.Shared.Keybinds["4"]]     = { command = "slot_4",    disabled = true  },
        [RSGCore.Shared.Keybinds["5"]]     = { command = "slot_5",    disabled = true  },
    }
    while true do
        Wait(0)
        for control, meta in pairs(commands) do
            if meta.disabled then
                DisableControlAction(0, control, true)
                if IsDisabledControlPressed(0, control) then
                    if Inventory.CanPlayerUseInventory() then
                        ExecuteCommand(meta.command)
                    end
                    break
                end
            else
                if IsControlJustReleased(0, control) then
                    if Inventory.CanPlayerUseInventory() then
                        ExecuteCommand(meta.command)
                    end
                    break
                end
            end
        end
    end
end)