local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'


lib.callback.register('rsg-inventory:client:isInMelee', function()
    local ped = cache.ped
    return IsPedInMeleeCombat(ped)
end)

-- Thread to using ox_target
CreateThread(function()
    local models = config.VendingObjects
    if not models or #models == 0 then return end -- exit if no vending models defined

    exports.ox_target:addModel(models, {
        label = locale('info.vending'),             -- label displayed in the target menu
        icon = 'fa-solid fa-cash-register',        -- icon for the interaction
        distance = 2.5,                             -- maximum distance to interact
        onSelect = function(data)                   -- function triggered when player selects the vending machine
            data.coords = GetEntityCoords(data.entity) -- get the coords of the vending machine entity
            TriggerServerEvent('rsg-inventory:server:openVending', data) -- request the vending inventory from server
        end,
    })
end)

-- Thread to handle keybinds for inventory and hotbar
CreateThread(function()
    -- Mapping of keys to commands and whether the key is disabled (hold vs press)
    local commands = {
        [config.Keybinds.Open]             = { command = "inventory", disabled = false }, -- open inventory
        [config.Keybinds.Hotbar]           = { command = "hotbar",    disabled = false }, -- toggle hotbar
        [RSGCore.Shared.Keybinds["1"]]     = { command = "slot_1",    disabled = true  }, -- use slot 1 (hold)
        [RSGCore.Shared.Keybinds["2"]]     = { command = "slot_2",    disabled = true  }, -- use slot 2 (hold)
        [RSGCore.Shared.Keybinds["3"]]     = { command = "slot_3",    disabled = true  }, -- use slot 3 (hold)
        [RSGCore.Shared.Keybinds["4"]]     = { command = "slot_4",    disabled = true  }, -- use slot 4 (hold)
        [RSGCore.Shared.Keybinds["5"]]     = { command = "slot_5",    disabled = true  }, -- use slot 5 (hold)
    }

    -- Main loop to check key inputs every frame
    while true do
        Wait(0)
        for control, meta in pairs(commands) do
            if meta.disabled then
                -- If the key is disabled, prevent default behavior
                DisableControlAction(0, control, true)
                if IsDisabledControlPressed(0, control) then
                    if Inventory.CanPlayerUseInventory() then -- check if player can interact with inventory
                        ExecuteCommand(meta.command)        -- execute the associated command
                    end
                    break
                end
            else
                -- If the key is enabled, execute command on key release
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
