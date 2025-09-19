local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'
local items = RSGCore.Shared.Items

-- Helper function to notify players
local function notify(source, messageKey, type)
    TriggerClientEvent('ox_lib:notify', source, { title = locale(messageKey), type = type or 'error', duration = 5000 })
end

-- Helper function to get a valid player object
local function getPlayer(source, notifyIfMissing)
    local ply = RSGCore.Functions.GetPlayer(source)
    if not ply and notifyIfMissing then notify(source, 'error.pdne') end
    return ply
end

-- Helper function to add item to inventory with proper feedback
local function addItemToInventory(target, itemData, amount, info, context)
    amount = amount or 1
    local success = Inventory.AddItem(target, itemData.name, amount, false, info or {}, context or 'server command')
    if success then
        TriggerClientEvent('rsg-inventory:client:ItemBox', target, itemData, 'add', amount)
        if Player(target).state.inv_busy then
            TriggerClientEvent('rsg-inventory:client:updateInventory', target)
        end
    else
        notify(target, 'error.cgitem')
    end
    return success
end

-- /giveitem command
lib.addCommand(config.CommandNames.GiveItem, {
    help = locale('info.giveitem_help'),
    restricted = 'group.admin',
    params = {
        { name = 'target', type = 'playerId', help = locale('info.param_target') },
        { name = 'item', type = 'string', help = locale('info.param_item') },
        { name = 'amount', type = 'number', help = locale('info.param_amount'), optional = true },
    }
}, function(source, args)
    local player = getPlayer(args.target, true)
    if not player then return end

    local itemName = tostring(args.item):lower()
    local itemData = items[itemName]
    if not itemData then return notify(source, 'error.idne') end

    local amount = tonumber(args.amount) or 1
    local info = {}

    -- Specific info for ID cards
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

    -- Specific info for weapons
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
 if addItemToInventory(args.target, itemData, amount, info, 'give item command') then
    local message = string.format(locale('info.yhg'), itemData.name, amount)
    -- Notify giver with item name and amount
    notify(source, message, 'success')
    end
end)

-- /randomitems command
lib.addCommand(config.CommandNames.RandomItems, {
    help = locale('info.randomitems_help'),
    restricted = 'group.god'
}, function(source)
    local player = getPlayer(source)
    if not player then return end

    local filteredItems = {}
    for _, v in pairs(items) do
        if v.type ~= 'weapon' then table.insert(filteredItems, v) end
    end

    local playerInventory = player.PlayerData.items

    for _ = 1, 10 do
        local randItem = filteredItems[math.random(#filteredItems)]
        local amount = randItem.unique and 1 or math.random(1, 10)

        -- Find an empty slot
        local emptySlot
        for i = 1, player.PlayerData.slots do
            if not playerInventory[i] then
                emptySlot = i
                break
            end
        end

        if emptySlot then
            addItemToInventory(source, randItem, amount, false, 'random items command')
            playerInventory = RSGCore.Functions.GetPlayer(source).PlayerData.items
        end

        Wait(1000)
    end
end)

-- /clearinv command
lib.addCommand(config.CommandNames.ClearInv, {
    help = locale('info.clearinv_help'),
    restricted = 'group.admin',
    params = {
        { name = 'target', type = 'playerId', help = locale('info.param_target'), optional = true }
    }
}, function(source, args)
    local target = args.target or source
    Inventory.ClearInventory(target)
    if target == source then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('info.inventory_cleared'), type = 'success', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', target, { title = locale('info.inventory_cleared'), type = 'success', duration = 5000 })
        TriggerClientEvent('ox_lib:notify', source, { title = locale('info.inventory_cleared_for') .. GetPlayerName(target), type = 'success', duration = 5000 })
    end
end)

-- /closeinv command
RegisterCommand(config.CommandNames.CloseInv, function(source)
    Inventory.CloseInventory(source)
    TriggerClientEvent('ox_lib:notify', source, { title = locale('info.inventory_closed'), type = 'success', duration = 5000 })
end, false)

-- serversidehotbar
RegisterCommand('serversidehotbar', function(source)
    if Player(source).state.inv_busy then return end
    local ply = getPlayer(source)
    if not ply then return end
    if ply.PlayerData.metadata.isdead or ply.PlayerData.metadata.inlaststand or ply.PlayerData.metadata.ishandcuffed then return end

    local hotbarItems = {}
    for i = 1, 5 do
        hotbarItems[i] = ply.PlayerData.items[i]
    end
    TriggerClientEvent('rsg-inventory:client:hotbar', source, hotbarItems)
end, false)

-- /inventory command
RegisterCommand(config.CommandNames.Inventory, function(source)
    if Player(source).state.inv_busy then return end
    local ply = getPlayer(source)
    if not ply then return end
    if ply.PlayerData.metadata.isdead or ply.PlayerData.metadata.ishandcuffed then return end

    if not inventory then
        Inventory.OpenInventory(source)
    end
end, false)