local config = require 'shared.config'
local items = RSGCore.Shared.Items


lib.addCommand(Config.CommandNames.GiveItem, {
    help = locale('info.giveitem_help'),
    restricted = 'group.admin',
    params = {
        { name = 'target', type = 'playerId', help = locale('info.param_target') },
        { name = 'item', type = 'string', help = locale('info.param_item') },
        { name = 'amount', type = 'number', help = locale('info.param_amount'), optional = true },
    }
}, function(source, args)
    local player = RSGCore.Functions.GetPlayer(args.target)
    if not player then
        return TriggerClientEvent('ox_lib:notify', source, { title = locale('error.pdne'), type = 'error', duration = 5000 })
    end

    local itemName = tostring(args.item):lower()
    local itemData = items[itemName]
    if not itemData then
        return TriggerClientEvent('ox_lib:notify', source, { title = locale('error.idne'), type = 'error', duration = 5000 })
    end

    local amount = tonumber(args.amount) or 1
    local info = {}

    if itemData.name == 'id_card' then
        local char = player.PlayerData.charinfo
        info = {
            citizenid = player.PlayerData.citizenid,
            firstname = char.firstname,
            lastname = char.lastname,
            birthdate = char.birthdate,
            gender = char.gender,
            nationality = char.nationality
        }
    elseif itemData.type == 'weapon' then
        amount = 1
        info.serie = string.format(
            "%s%s%s%s%s%s",
            RSGCore.Shared.RandomInt(2),
            RSGCore.Shared.RandomStr(3),
            RSGCore.Shared.RandomInt(1),
            RSGCore.Shared.RandomStr(2),
            RSGCore.Shared.RandomInt(3),
            RSGCore.Shared.RandomStr(4)
        )
        info.quality = 100
    end

    if Inventory.AddItem(args.target, itemData.name, amount, false, info, 'give item command') then
        TriggerClientEvent('ox_lib:notify', source, {
            title = locale('info.yhg') .. GetPlayerName(args.target) .. ' ' .. amount .. ' ' .. itemData.label,
            type = 'success',
            duration = 5000
        })
        TriggerClientEvent('rsg-inventory:client:ItemBox', args.target, itemData, 'add', amount)
        if Player(args.target).state.inv_busy then
            TriggerClientEvent('rsg-inventory:client:updateInventory', args.target)
        end
    else
        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.cgitem'), type = 'error', duration = 5000 })
    end
end)


lib.addCommand(Config.CommandNames.RandomItems, {
    help = locale('info.randomitems_help'),
    restricted = 'group.god'
}, function(source)
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return end

    local filteredItems = {}
    for _, v in pairs(items) do
        if v.type ~= 'weapon' then
            filteredItems[#filteredItems+1] = v
        end
    end

    local playerInventory = player.PlayerData.items
    for _ = 1, 10 do
        local randItem = filteredItems[math.random(#filteredItems)]
        local amount = randItem.unique and 1 or math.random(1, 10)

        local emptySlot
        for i = 1, player.PlayerData.slots do
            if not playerInventory[i] then
                emptySlot = i
                break
            end
        end

        if emptySlot and Inventory.AddItem(source, randItem.name, amount, emptySlot, false, 'random items command') then
            TriggerClientEvent('rsg-inventory:client:ItemBox', source, randItem, 'add')
            playerInventory = RSGCore.Functions.GetPlayer(source).PlayerData.items
            if Player(source).state.inv_busy then
                TriggerClientEvent('rsg-inventory:client:updateInventory', source)
            end
        end
        Wait(1000)
    end
end)


lib.addCommand(Config.CommandNames.ClearInv, {
    help = locale('info.clearinv_help'),
    restricted = 'group.admin',
    params = {
        { name = 'target', type = 'playerId', help = locale('info.param_target'), optional = true }
    }
}, function(source, args)
    Inventory.ClearInventory(args.target or source)
end)


RegisterCommand(Config.CommandNames.CloseInv, function(source)
    Inventory.CloseInventory(source)
end, false)


RegisterCommand(Config.CommandNames.Hotbar, function(source)
    if Player(source).state.inv_busy then return end
    local RSGPlayer = RSGCore.Functions.GetPlayer(source)
    if not RSGPlayer then return end
    if RSGPlayer.PlayerData.metadata.isdead or RSGPlayer.PlayerData.metadata.inlaststand or RSGPlayer.PlayerData.metadata.ishandcuffed then return end

    local hotbarItems = {}
    for i = 1, 5 do
        hotbarItems[i] = RSGPlayer.PlayerData.items[i]
    end
    TriggerClientEvent('rsg-inventory:client:hotbar', source, hotbarItems)
end, false)

-- Inventory
RegisterCommand(Config.CommandNames.Inventory, function(source)
    if Player(source).state.inv_busy then return end
    local RSGPlayer = RSGCore.Functions.GetPlayer(source)
    if not RSGPlayer then return end
    if RSGPlayer.PlayerData.metadata.isdead or RSGPlayer.PlayerData.metadata.ishandcuffed then return end
    if not inventory then Inventory.OpenInventory(source) end
end, false)