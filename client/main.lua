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
        local sleep = 0
        Wait(sleep)

        if Inventory.CanPlayerUseInventory() then
            for key, command in pairs(commands) do
                if IsControlJustReleased(0, key) then
                    ExecuteCommand(command)
                    sleep = 1000
                    break
                end
            end
        end
    end
end)

CreateThread(function()
    local keybinds = RSGCore.Shared.Keybinds
    local slots = { "slot_1", "slot_2", "slot_3", "slot_4", "slot_5" }

    while true do
        Wait(0)

        for i = 1, #slots do
            DisableControlAction(0, keybinds[tostring(i)])
        end
        
        if Inventory.CanPlayerUseInventory() then
            for i = 1, #slots do
                if IsDisabledControlPressed(0, keybinds[tostring(i)]) and IsInputDisabled(0) then
                    ExecuteCommand(slots[i])
                end
            end
        end
    end
end)


