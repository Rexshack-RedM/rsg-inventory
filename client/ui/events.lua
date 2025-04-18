--[[ RegisterNetEvent('rsg-inventory:client:requiredItems', function(items, bool)
    local itemTable = {}
    if bool then
        for k in pairs(items) do
            itemTable[#itemTable + 1] = {
                item = items[k].name,
                label = RSGCore.Shared.Items[items[k].name]['label'],
                image = items[k].image,
            }
        end
    end

    SendNUIMessage({
        action = 'requiredItem',
        items = itemTable,
        toggle = bool
    })
end) ]]

RegisterNetEvent('rsg-inventory:client:hotbar', function(items)
    local token = exports['rsg-core']:GenerateCSRFToken()
    LocalPlayer.state.hotbarShown = not LocalPlayer.state.hotbarShown
    SendNUIMessage({
        action = 'toggleHotbar',
        open = LocalPlayer.state.hotbarShown,
        items = items,
        token = token,
    })
end)

RegisterNetEvent('rsg-inventory:client:closeInv', function()
    SendNUIMessage({
        action = 'close',
    })
end)

RegisterNetEvent('rsg-inventory:client:updateInventory', function()
    local token = exports['rsg-core']:GenerateCSRFToken()
    local playerData = RSGCore.Functions.GetPlayerData()
    SendNUIMessage({
        action = 'update',
        inventory = playerData.items,
        token = token,
    })
end)

RegisterNetEvent('rsg-inventory:client:ItemBox', function(itemData, type, amount)
    local function sendItemBox()
        SendNUIMessage({
            action = 'itemBox',
            item = itemData,
            type = type,
            amount = amount
        })
        
        if type == 'remove' or type == 'add' then
            TriggerServerEvent('rsg-inventory:server:updateHotbar')
        end
    end

    local lastItemBoxCall = LocalPlayer.state.lastItemBoxCall or 0
    local currentTime = GetGameTimer()
    local timeElapsed = currentTime - lastItemBoxCall

    if timeElapsed >= 1000 then
        sendItemBox()
        lastItemBoxCall = currentTime
    else
        local delay = 1000 - timeElapsed
        lib.timer(delay, function()
            sendItemBox()
        end, true)
        lastItemBoxCall = currentTime + delay
    end

    LocalPlayer.state.lastItemBoxCall = lastItemBoxCall
end)

RegisterNetEvent('rsg-inventory:client:updateHotbar', function(items)
    local token = exports['rsg-core']:GenerateCSRFToken()
    SendNUIMessage({
        action = 'updateHotbar',
        items = items,
        token = token,
    })
end)

RegisterNetEvent('rsg-inventory:client:openInventory', function(items, other)
    local token = exports['rsg-core']:GenerateCSRFToken()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        inventory = items,
        slots = Config.MaxSlots,
        maxweight = Config.MaxWeight,
        other = other,
        token = token,
        closeKey = Config.Keybinds.Close,
    })
end)