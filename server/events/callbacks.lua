local RSGCore = exports['rsg-core']:GetCoreObject()

local function isBlocked(Player)
    local meta = Player.PlayerData.metadata
    return meta.isdead or meta.inlaststand or meta.ishandcuffed
end

lib.callback.register('rsg-inventory:server:getPlayerName', function(source, targetId)
    targetId = tonumber(targetId)
    if not targetId then return end
    -- Only resolve names of players standing near the requester
    local srcPed, targetPed = GetPlayerPed(source), GetPlayerPed(targetId)
    if not DoesEntityExist(targetPed) or #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > 10.0 then return end
    local Player = RSGCore.Functions.GetPlayer(targetId)
    local char = Player and Player.PlayerData.charinfo
    if char and char.firstname then
        return char.firstname .. ' ' .. char.lastname
    end
    return GetPlayerName(targetId)
end)

local giveCooldowns = {}
AddEventHandler('playerDropped', function() giveCooldowns[source] = nil end)

--- Give an item from one player to another
lib.callback.register('rsg-inventory:server:giveItem', function(source, target, item, amount, slot)
    local now = GetGameTimer()
    if giveCooldowns[source] and now - giveCooldowns[source] < 500 then return false end
    giveCooldowns[source] = now

    target, amount, slot = tonumber(target), tonumber(amount), tonumber(slot)
    if not target or target == source or type(item) ~= 'string' or not slot then return false end
    if not amount or amount < 1 or amount ~= math.floor(amount) then return false end

    local player = RSGCore.Functions.GetPlayer(source)
    local Target = RSGCore.Functions.GetPlayer(target)
    if not player or not Target or isBlocked(player) or isBlocked(Target) then return false end

    local targetPed = GetPlayerPed(target)
    if not DoesEntityExist(targetPed) or #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(targetPed)) > Inventory.MAX_DIST then
        return false
    end

    -- Use the server-side item in that slot (never trust client name/metadata)
    local invItem = Inventory.GetItemBySlot(source, slot)
    if not invItem or invItem.name:lower() ~= item:lower() or amount > invItem.amount then return false end
    local itemInfo = RSGCore.Shared.Items[invItem.name]
    if not itemInfo then return false end

    if not Inventory.CanAddItem(target, invItem.name, amount) then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.error'), description = locale('error.target_cannot_carry'), type = 'error', duration = 5000 })
        return false
    end

    local serverInfo = invItem.info or {}
    local isWeapon = itemInfo.type == 'weapon'
    if isWeapon then Inventory.CheckWeapon(source, invItem.name) end

    if not Inventory.RemoveItem(source, invItem.name, amount, slot, ('Item given to ID #%s'):format(target), isWeapon) then
        return false
    end
    if not Inventory.AddItem(target, invItem.name, amount, false, serverInfo, ('Item given from ID #%s'):format(source), true) then
        Inventory.AddItem(source, invItem.name, amount, slot, serverInfo, 'rollback give item')
        return false
    end

    TriggerClientEvent('rsg-inventory:client:giveAnim', source)
    TriggerClientEvent('rsg-inventory:client:ItemBox', source, itemInfo, 'remove', amount)
    TriggerClientEvent('rsg-inventory:client:giveAnim', target)
    TriggerClientEvent('rsg-inventory:client:ItemBox', target, itemInfo, 'add', amount)
    if Player(target).state.inv_busy then
        TriggerClientEvent('rsg-inventory:client:updateInventory', target)
    end
    return true
end)
