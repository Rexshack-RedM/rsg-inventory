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
        [Config.Keybinds.Open] = "inventory",
        [Config.Keybinds.Hotbar] = "hotbar"
    }

    while true do
        Wait(0)
        for key, command in pairs(commands) do
            if IsControlJustReleased(0, key) then
                if Inventory.CanPlayerUseInventory() then
                    ExecuteCommand(command)
                end

                break
            end
        end
    end
end)

CreateThread(function()
    local keybinds = RSGCore.Shared.Keybinds
    local slots = { 
        ["1"] = "slot_1", 
        ["2"] = "slot_2", 
        ["3"] = "slot_3", 
        ["4"] = "slot_4", 
        ["5"] = "slot_5"
     }

    while true do
        Wait(0)

        for slot, _ in pairs(slots) do
            DisableControlAction(0, keybinds[slot])
        end
        
        for slot, bind in pairs(slots) do
            if IsDisabledControlPressed(0, keybinds[slot]) and IsInputDisabled(0) then
                if Inventory.CanPlayerUseInventory() then
                    ExecuteCommand(bind)
                end
            end
        end
    end
end)


