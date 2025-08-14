local config = require 'shared.config'


local function getPlayerMeta()
    local pd = RSGCore and RSGCore.Functions and RSGCore.Functions.GetPlayerData()
    return pd and pd.metadata or nil
end
do
    local cmd = config.CommandNames and config.CommandNames.openInv
    if cmd then
        RegisterCommand(cmd, function()
            if IsNuiFocused() or IsPauseMenuActive() then return end

            local meta = getPlayerMeta()
            if not meta then return end

            if meta.isdead then
                lib.notify({
                    title = 'rsg-inventory',
                    description = locale('error.openinverror'),
                    type = 'error'
                })
                return
            end

            if meta.ishandcuffed then
                lib.notify({
                    title = 'rsg-inventory',
                    description = locale('error.cuffopeninv'),
                    type = 'error'
                })
                return
            end

            ExecuteCommand('inventory')
        end, false)
    else
        print('[rsg-inventory] Missing CommandNames.openInv in config')
    end
end
do
    local cmd = config.CommandNames and config.CommandNames.toggleHotbar
    if cmd then
        RegisterCommand(cmd, function()
            if IsNuiFocused() or IsPauseMenuActive() then return end

            local meta = getPlayerMeta()
            if not meta then return end

            if meta.isdead then
                lib.notify({
                    title = 'Hotbar',
                    description = locale('error.hotbarerror'),
                    type = 'error'
                })
                return
            end

            if meta.ishandcuffed then
                lib.notify({
                    title = 'Hotbar',
                    description = locale('error.hotbarerror1'),
                    type = 'error'
                })
                return
            end

            ExecuteCommand('hotbar')
        end, false)
    else
        print('[rsg-inventory] Missing CommandNames.toggleHotbar in config')
    end
end
for i = 1, 5 do
    local key = "slot_" .. i
    local cmdName = config.CommandNames and config.CommandNames[key]
    if cmdName then
        RegisterCommand(cmdName, function()
            if Inventory and Inventory.UseHotbarItem then
                Inventory.UseHotbarItem(i)
            else
                print(string.format('[rsg-inventory] Inventory.UseHotbarItem missing (slot %d)', i))
            end
        end, false)
    else
        print(string.format('[rsg-inventory] Missing CommandNames.%s in config', key))
    end
end