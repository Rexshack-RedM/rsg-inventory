local RSGCore = exports['rsg-core']:GetCoreObject()

Trades = Trades or {}
local pendingRequests = {} -- [initiator] = target
local tradeCooldowns = {}
local MAX_TRADE_SLOTS = 20

local function notify(src, key, notifType, ...)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('trade.title'),
        description = locale(key, ...),
        type = notifType or 'error',
        duration = 5000
    })
end

local function getCharName(src)
    local player = RSGCore.Functions.GetPlayer(src)
    local char = player and player.PlayerData.charinfo
    if char and char.firstname then
        return char.firstname .. ' ' .. char.lastname
    end
    return GetPlayerName(src) or tostring(src)
end

local function isOnCooldown(src)
    local now = GetGameTimer()
    if tradeCooldowns[src] and now - tradeCooldowns[src] < 200 then return true end
    tradeCooldowns[src] = now
    return false
end

local function isBlocked(Player)
    local meta = Player.PlayerData.metadata
    return meta.isdead or meta.inlaststand or meta.ishandcuffed
end

local function isInTrade(src)
    for _, trade in pairs(Trades) do
        if trade.initiator == src or trade.target == src then return true end
    end
    return false
end

local function withinRange(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    return DoesEntityExist(pedA) and DoesEntityExist(pedB)
        and #(GetEntityCoords(pedA) - GetEntityCoords(pedB)) <= Inventory.MAX_DIST
end

--- Returns 'initiator' / 'target' for a participant, nil for anyone else
local function getSide(trade, src)
    if trade.initiator == src then return 'initiator', 'target' end
    if trade.target == src then return 'target', 'initiator' end
end

local function broadcast(trade)
    local data = {
        id = trade.id,
        initiator = trade.initiator,
        initiatorItems = trade.initiatorItems,
        targetItems = trade.targetItems,
        initiatorAccepted = trade.initiatorAccepted,
        targetAccepted = trade.targetAccepted,
    }
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.initiator, data)
    TriggerClientEvent('rsg-inventory:client:updateTrade', trade.target, data)
end

--- Returns every escrowed item to its original owner (force-drops at their feet if full) and ends the trade
local function refundAndClose(trade, reasonText)
    for _, item in pairs(trade.initiatorItems) do
        Inventory.AddItem(trade.initiator, item.name, item.amount, false, item.info, reasonText)
    end
    for _, item in pairs(trade.targetItems) do
        Inventory.AddItem(trade.target, item.name, item.amount, false, item.info, reasonText)
    end
    trade.initiatorItems, trade.targetItems = {}, {}
    Trades[trade.id] = nil
    TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.initiator)
    TriggerClientEvent('rsg-inventory:client:cancelTrade', trade.target)
end

RegisterNetEvent('rsg-inventory:server:initiateTrade', function(targetId)
    local src = source
    if isOnCooldown(src) then return end
    targetId = tonumber(targetId)
    if not targetId or targetId == src then return end

    local player = RSGCore.Functions.GetPlayer(src)
    if not player then return end
    if isBlocked(player) then return notify(src, 'trade.cannot_trade_now') end

    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target then return notify(src, 'error.no_player_nearby') end
    if isBlocked(Target) then return notify(src, 'trade.target_cannot_trade') end
    if not withinRange(src, targetId) then return notify(src, 'error.player_too_far') end

    if isInTrade(src) then return notify(src, 'trade.already_trading') end
    if isInTrade(targetId) then return notify(src, 'trade.target_already_trading') end

    pendingRequests[src] = targetId
    SetTimeout(30000, function()
        if pendingRequests[src] == targetId then pendingRequests[src] = nil end
    end)

    TriggerClientEvent('rsg-inventory:client:tradeRequest', targetId, src, getCharName(src))
    notify(src, 'trade.request_sent', 'inform', getCharName(targetId))
end)

RegisterNetEvent('rsg-inventory:server:acceptTradeRequest', function(initiatorId)
    local src = source
    if isOnCooldown(src) then return end
    initiatorId = tonumber(initiatorId)
    if not initiatorId or pendingRequests[initiatorId] ~= src then return end
    pendingRequests[initiatorId] = nil

    local player = RSGCore.Functions.GetPlayer(src)
    local initiator = RSGCore.Functions.GetPlayer(initiatorId)
    if not player or not initiator then return end
    if isInTrade(src) or isInTrade(initiatorId) then return notify(src, 'trade.already_trading') end
    if not withinRange(src, initiatorId) then return notify(src, 'error.player_too_far') end

    local tradeId = ('trade-%s-%s'):format(initiatorId, src)
    Trades[tradeId] = {
        id = tradeId,
        initiator = initiatorId,
        target = src,
        initiatorItems = {},
        targetItems = {},
        initiatorAccepted = false,
        targetAccepted = false,
        nextSlot = { initiator = 1, target = 1 },
        executing = false,
    }

    TriggerClientEvent('rsg-inventory:client:openTrade', initiatorId, tradeId, src, getCharName(src), initiator.PlayerData.items)
    TriggerClientEvent('rsg-inventory:client:openTrade', src, tradeId, initiatorId, getCharName(initiatorId), player.PlayerData.items)
end)

RegisterNetEvent('rsg-inventory:server:declineTradeRequest', function(initiatorId)
    local src = source
    initiatorId = tonumber(initiatorId)
    if initiatorId and pendingRequests[initiatorId] == src then
        pendingRequests[initiatorId] = nil
        notify(initiatorId, 'trade.request_declined')
    end
end)

RegisterNetEvent('rsg-inventory:server:addTradeItem', function(tradeId, item, amount)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade or trade.executing then return end
    local side, otherSide = getSide(trade, src)
    if not side or trade[side .. 'Accepted'] then return end

    amount = tonumber(amount)
    if type(item) ~= 'table' or not amount or amount < 1 or amount ~= math.floor(amount) then return end

    local slotIndex = trade.nextSlot[side]
    if slotIndex > MAX_TRADE_SLOTS then return notify(src, 'trade.too_many_items') end

    local invItem = Inventory.GetItemBySlot(src, item.slot)
    if not invItem or invItem.name ~= item.name or invItem.amount < amount then return end

    local escrowInfo = invItem.info
    if invItem.type == 'weapon' then Inventory.CheckWeapon(src, invItem.name) end

    -- ESCROW: remove from player immediately
    if not Inventory.RemoveItem(src, invItem.name, amount, invItem.slot, 'trade escrow', true) then return end

    trade[side .. 'Items'][slotIndex] = {
        name = invItem.name,
        amount = amount,
        slot = slotIndex,
        info = escrowInfo,
        label = invItem.label,
        description = invItem.description,
        weight = invItem.weight,
        type = invItem.type,
        unique = invItem.unique,
        useable = invItem.useable,
        image = invItem.image,
        shouldClose = invItem.shouldClose,
        combinable = invItem.combinable,
    }
    trade.nextSlot[side] = slotIndex + 1
    trade[side .. 'Accepted'] = false
    trade[otherSide .. 'Accepted'] = false

    broadcast(trade)
    TriggerClientEvent('rsg-inventory:client:updateInventory', src)
end)

RegisterNetEvent('rsg-inventory:server:removeTradeItem', function(tradeId, tradeSlot)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade or trade.executing then return end
    local side, otherSide = getSide(trade, src) -- participants only
    if not side or trade[side .. 'Accepted'] then return end

    local tradeItems = trade[side .. 'Items']
    tradeSlot = tonumber(tradeSlot)
    local escrowed = tradeSlot and tradeItems[tradeSlot]
    if not escrowed then return end
    tradeItems[tradeSlot] = nil

    Inventory.AddItem(src, escrowed.name, escrowed.amount, false, escrowed.info, 'trade remove return')

    trade[side .. 'Accepted'] = false
    trade[otherSide .. 'Accepted'] = false
    broadcast(trade)
    TriggerClientEvent('rsg-inventory:client:updateInventory', src)
end)

--- Moves all escrowed items to their new owners. Pre-checks capacity so nothing is lost.
local function executeTrade(trade)
    local transfers = {}
    for _, item in pairs(trade.initiatorItems) do transfers[#transfers + 1] = { to = trade.target, item = item } end
    for _, item in pairs(trade.targetItems) do transfers[#transfers + 1] = { to = trade.initiator, item = item } end

    local done = {}
    for i = 1, #transfers do
        local t = transfers[i]
        if Inventory.AddItem(t.to, t.item.name, t.item.amount, false, t.item.info, 'trade', true) then
            done[#done + 1] = t
        else
            -- Undo what was delivered; escrow still holds the originals, refundAndClose returns them once
            for j = #done, 1, -1 do
                local d = done[j]
                Inventory.RemoveItem(d.to, d.item.name, d.item.amount, false, 'trade rollback', true)
            end
            return false, t.item.name
        end
    end

    local gave1, gave2 = {}, {}
    for _, item in pairs(trade.initiatorItems) do gave1[#gave1 + 1] = item.name .. ' x' .. item.amount end
    for _, item in pairs(trade.targetItems) do gave2[#gave2 + 1] = item.name .. ' x' .. item.amount end
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'Trade Completed', 'green',
        ('**%s (%s)** gave: %s\n**%s (%s)** gave: %s'):format(
            getCharName(trade.initiator), trade.initiator, table.concat(gave1, ', '),
            getCharName(trade.target), trade.target, table.concat(gave2, ', ')))
    return true
end

RegisterNetEvent('rsg-inventory:server:confirmTrade', function(tradeId)
    local src = source
    if isOnCooldown(src) then return end

    local trade = Trades[tradeId]
    if not trade or trade.executing then return end
    local side = getSide(trade, src)
    if not side then return end

    trade[side .. 'Accepted'] = true
    broadcast(trade)
    if not (trade.initiatorAccepted and trade.targetAccepted) then return end

    if not RSGCore.Functions.GetPlayer(trade.initiator) or not RSGCore.Functions.GetPlayer(trade.target) then
        return refundAndClose(trade, 'trade cancel return')
    end
    if not withinRange(trade.initiator, trade.target) then
        notify(trade.initiator, 'error.player_too_far')
        notify(trade.target, 'error.player_too_far')
        return refundAndClose(trade, 'trade cancel return')
    end

    trade.executing = true
    local success, failedItem = executeTrade(trade)
    trade.executing = false

    if success then
        Trades[trade.id] = nil
        TriggerClientEvent('rsg-inventory:client:completeTrade', trade.initiator)
        TriggerClientEvent('rsg-inventory:client:completeTrade', trade.target)
        notify(trade.initiator, 'trade.completed', 'success')
        notify(trade.target, 'trade.completed', 'success')
    else
        -- Keep the trade open so players can adjust their offers
        trade.initiatorAccepted, trade.targetAccepted = false, false
        broadcast(trade)
        local info = RSGCore.Shared.Items[failedItem]
        local label = info and info.label or failedItem
        notify(trade.initiator, 'trade.failed_item', 'error', label)
        notify(trade.target, 'trade.failed_item', 'error', label)
    end
end)

RegisterNetEvent('rsg-inventory:server:cancelTrade', function(tradeId)
    local src = source
    local trade = Trades[tradeId]
    if not trade or trade.executing or not getSide(trade, src) then return end
    refundAndClose(trade, 'trade cancel return')
    notify(src, 'trade.cancelled', 'inform')
end)

local function cleanupPlayer(src)
    tradeCooldowns[src] = nil
    for _, trade in pairs(Trades) do
        if trade.initiator == src or trade.target == src then
            refundAndClose(trade, 'trade disconnect return')
        end
    end
    for initiatorId, targetId in pairs(pendingRequests) do
        if initiatorId == src or targetId == src then
            TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', initiatorId)
            TriggerClientEvent('rsg-inventory:client:tradeRequestCancelled', targetId)
            pendingRequests[initiatorId] = nil
        end
    end
end

-- OnPlayerUnload fires before rsg-core saves/removes the player, so escrowed items are returned in time
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src) cleanupPlayer(src) end)
AddEventHandler('playerDropped', function() cleanupPlayer(source) end)
