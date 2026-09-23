local RSGCore = exports['rsg-core']:GetCoreObject()

local function notify(src, key, notifType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('error.error'),
        description = locale(key),
        type = notifType or 'error',
        duration = 5000
    })
end

local function isPositiveInt(n, max)
    return type(n) == 'number' and n >= 1 and n == math.floor(n) and (not max or n <= max)
end

--- Returns the slot count of any inventory the player can interact with
local function getMaxSlots(inventoryName, src)
    if inventoryName == 'player' then
        local Player = RSGCore.Functions.GetPlayer(src)
        return Player and Player.PlayerData.slots
    elseif inventoryName:find('^otherplayer%-') then
        local Target = RSGCore.Functions.GetPlayer(tonumber(inventoryName:match('^otherplayer%-(%d+)$')))
        return Target and Target.PlayerData.slots
    elseif Drops[inventoryName] then
        return Drops[inventoryName].slots
    elseif Inventories[inventoryName] then
        return Inventories[inventoryName].slots
    end
end

--[[
    Close a player's secondary inventory (stash, drop, other player)
--]]
RegisterNetEvent('rsg-inventory:server:closeInventory', function(inventory)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end

    Player(src).state.inv_busy = false
    local opened = OpenedInventories[src]
    OpenedInventories[src] = nil

    -- Only the inventory the player actually opened can be closed by them
    if type(inventory) ~= 'string' or inventory ~= opened then return end
    if inventory:find('^shop%-') then return end

    if inventory:find('^otherplayer%-') then
        local targetId = tonumber(inventory:match('^otherplayer%-(%d+)$'))
        if targetId and GetPlayerName(targetId) then
            Player(targetId).state.inv_busy = false
        end
        return
    end

    local drop = Drops[inventory]
    if drop then
        if drop.isOpen == src then drop.isOpen = false end
        if next(drop.items) == nil then
            TriggerClientEvent('rsg-inventory:client:removeDropTarget', -1, drop.entityId)
            Wait(500)
            -- Re-check after yield (another player may have opened the drop)
            drop = Drops[inventory]
            if not drop or drop.isOpen or next(drop.items) ~= nil then return end
            local entity = NetworkGetEntityFromNetworkId(drop.entityId)
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            Drops[inventory] = nil
        end
        return
    end

    local stash = Inventories[inventory]
    if not stash then return end
    if stash.isOpen == src then stash.isOpen = false end
    Inventory.PersistStash(inventory, stash)
end)

--[[
    Use an item from the player's inventory
--]]
local useCooldowns = {}
local allowedDuringMelee = { weapon = true, weapon_thrown = true }

RegisterNetEvent('rsg-inventory:server:useItem', function(item)
    local src = source
    if type(item) ~= 'table' then return end

    local now = GetGameTimer()
    if useCooldowns[src] and now - useCooldowns[src] < 250 then return end
    useCooldowns[src] = now

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local meta = Player.PlayerData.metadata
    if meta.isdead or meta.ishandcuffed then return end

    local itemData = Inventory.GetItemBySlot(src, item.slot)
    if not itemData then return end
    local itemInfo = RSGCore.Shared.Items[itemData.name]
    if not itemInfo then return end

    if not allowedDuringMelee[itemData.type] and lib.callback.await('rsg-inventory:client:isInMelee', src) then
        return notify(src, 'error.cannot_use_in_melee')
    end

    if itemData.type == 'weapon' then
        local serial = itemData.info and itemData.info.serie
        if serial then
            local exists = MySQL.scalar.await('SELECT 1 FROM player_weapons WHERE serial = ? AND citizenid = ? LIMIT 1',
                { serial, Player.PlayerData.citizenid })
            if not exists then
                MySQL.insert.await('INSERT INTO player_weapons (serial, citizenid) VALUES (?, ?)', { serial, Player.PlayerData.citizenid })
            end
        end
        TriggerClientEvent('rsg-weapons:client:UseWeapon', src, itemData)
    elseif itemData.type == 'weapon_thrown' then
        TriggerClientEvent('rsg-weapons:client:UseThrownWeapon', src, itemData)
    elseif itemData.type == 'equipment' then
        TriggerClientEvent('rsg-weapons:client:UseEquipment', src, itemData)
    else
        Inventory.UseItem(itemData.name, src, itemData)
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')
end)

--[[
    Send the first 5 slots to the client for the hotbar
--]]
RegisterNetEvent('rsg-inventory:server:updateHotbar', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local items = {}
    for slot = 1, 5 do
        items[slot] = Player.PlayerData.items[slot]
    end
    TriggerClientEvent('rsg-inventory:client:updateHotbar', src, items)
end)

--[[
    Move / stack / split / swap items between the player inventory and the currently open secondary inventory
--]]
local moveCooldowns = {}

RegisterNetEvent('rsg-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    local src = source

    local now = GetGameTimer()
    if moveCooldowns[src] and now - moveCooldowns[src] < 100 then return Inventory.RefreshClient(src) end
    moveCooldowns[src] = now

    if type(fromInventory) ~= 'string' or type(toInventory) ~= 'string' then return end
    if fromInventory:find('^shop%-') or toInventory:find('^shop%-') then return end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Access: a player may only touch their own inventory and the one they currently have open
    local opened = OpenedInventories[src]
    for _, inv in ipairs({ fromInventory, toInventory }) do
        if inv ~= 'player' and inv ~= opened then
            return Inventory.CloseInventory(src, opened)
        end
    end

    fromSlot, toSlot, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(toAmount)
    local fromMax, toMax = getMaxSlots(fromInventory, src), getMaxSlots(toInventory, src)
    if not fromMax or not toMax or not isPositiveInt(fromSlot, fromMax) or not isPositiveInt(toSlot, toMax) then
        return Inventory.RefreshClient(src)
    end
    if fromInventory == toInventory and fromSlot == toSlot then return end

    -- Re-validate access to other players / restricted stashes on every move
    if opened then
        if opened:find('^otherplayer%-') then
            local ok, reason = Inventory.CanAccessOtherPlayer(src, Player, tonumber(opened:match('^otherplayer%-(%d+)$')))
            if not ok then
                if reason then notify(src, reason) end
                return Inventory.CloseInventory(src, opened)
            end
        elseif not Inventory.HasStashAccess(src, Player, opened) then
            notify(src, 'error.no_permission_stash')
            return Inventory.CloseInventory(src, opened)
        end
    end

    -- Distance check (admins exempt)
    if not RSGCore.Functions.HasPermission(src, 'admin') then
        local srcCoords = GetEntityCoords(GetPlayerPed(src))
        local function tooFar(inv)
            local coords = Inventory.GetCoords(inv, src)
            return coords and #(srcCoords - coords) > Inventory.MAX_DIST
        end
        local fromTooFar = tooFar(fromInventory)
        if fromTooFar or tooFar(toInventory) then
            notify(src, fromTooFar and 'error.source_inv_too_far' or 'error.target_inv_too_far')
            return Inventory.CloseInventory(src, opened)
        end
    end

    local fromItem = Inventory.GetItem(fromInventory, src, fromSlot)
    if not fromItem then return Inventory.RefreshClient(src) end
    local toItem = Inventory.GetItem(toInventory, src, toSlot)
    local canStack = toItem and toItem.name == fromItem.name and not fromItem.unique
        and toItem.info.quality == fromItem.info.quality

    -- Amount must be a whole number between 1 and the source stack size.
    -- (A swap sends the target stack size as toAmount and always moves both full stacks, so it is exempt.)
    local isSwap = toItem and not canStack
    if not isSwap and not isPositiveInt(toAmount, fromItem.amount) then
        return Inventory.RefreshClient(src)
    end

    local fromId = Inventory.GetIdentifier(fromInventory, src)
    local toId = Inventory.GetIdentifier(toInventory, src)
    local crossInventory = fromId ~= toId
    local isMove = crossInventory

    if fromInventory == 'player' and toInventory ~= 'player' then
        Inventory.CheckWeapon(src, fromItem)
    end

    local name, info = fromItem.name, fromItem.info
    local ok = false

    if not isSwap then
        -- Stack onto matching item, or move/split into an empty slot
        local amount = toAmount
        if not crossInventory or Inventory.CanAddItem(toId, name, amount) then
            if Inventory.RemoveItem(fromId, name, amount, fromSlot, 'moved item', isMove) then
                ok = Inventory.AddItem(toId, name, amount, toSlot, info, 'moved item', true)
                if not ok then
                    Inventory.AddItem(fromId, name, amount, fromSlot, info, 'rollback moved item', true)
                end
            end
        end
    else
        -- Swap two different stacks
        local fromAmt, toAmt, toName, toInfo = fromItem.amount, toItem.amount, toItem.name, toItem.info
        local canSwap = not crossInventory or (
            Inventory.CanAddItem(toId, name, fromAmt) and Inventory.CanAddItem(fromId, toName, toAmt))
        if canSwap
            and Inventory.RemoveItem(fromId, name, fromAmt, fromSlot, 'swapped item', isMove) then
            if Inventory.RemoveItem(toId, toName, toAmt, toSlot, 'swapped item', isMove) then
                local addedA = Inventory.AddItem(toId, name, fromAmt, toSlot, info, 'swapped item', true)
                local addedB = addedA and Inventory.AddItem(fromId, toName, toAmt, fromSlot, toInfo, 'swapped item', true)
                ok = addedA and addedB
                if not ok then
                    if addedA then Inventory.RemoveItem(toId, name, fromAmt, toSlot, 'swap rollback', true) end
                    Inventory.AddItem(fromId, name, fromAmt, fromSlot, info, 'swap rollback', true)
                    Inventory.AddItem(toId, toName, toAmt, toSlot, toInfo, 'swap rollback', true)
                end
            else
                Inventory.AddItem(fromId, name, fromAmt, fromSlot, info, 'swap rollback', true)
            end
        end
    end

    if not ok then
        if crossInventory then notify(src, 'error.not_enough_space') end
        Inventory.RefreshClient(src)
    end

    -- Keep the looted player's UI in sync
    if opened and opened:find('^otherplayer%-') then
        local targetId = tonumber(opened:match('^otherplayer%-(%d+)$'))
        TriggerClientEvent('rsg-inventory:client:updateInventory', targetId)
    end
end)

--[[
    Open another player's inventory (loot / search)
--]]
RegisterNetEvent('rsg-inventory:server:openPlayerInventory', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not targetId then return end

    local ok, reason = Inventory.CanAccessOtherPlayer(src, Player, targetId)
    if not ok then
        if reason then notify(src, reason) end
        return
    end

    Inventory.OpenInventoryById(src, targetId)
end)

--[[
    Open a stash by name.
    NOTE: stashes without coords are only protected by the restricted-prefix list below.
    Scripts that own private stashes (houses, businesses) should open them server-side via
    exports['rsg-inventory']:OpenInventory(src, id, data) after their own checks instead of relying on this event.
--]]
RegisterNetEvent('rsg-inventory:server:openStash', function(stashId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(stashId) ~= 'string' or #stashId > 100 or stashId:find('^otherplayer%-') or stashId:find('^drop%-') or stashId:find('^shop%-') then
        return notify(src, 'error.invalid_stash_identifier')
    end

    if not Inventory.HasStashAccess(src, Player, stashId) then
        return notify(src, 'error.no_permission_stash')
    end

    local stashCoords = Inventory.GetCoords(stashId, src)
    if stashCoords and #(GetEntityCoords(GetPlayerPed(src)) - stashCoords) > Inventory.MAX_DIST then
        return notify(src, 'error.stash_too_far')
    end

    Inventory.OpenInventory(src, stashId)
end)

--[[
    Cleanup when a player leaves
--]]
AddEventHandler('playerDropped', function()
    local src = source
    OpenedInventories[src] = nil
    moveCooldowns[src] = nil
    useCooldowns[src] = nil

    for invId, inv in pairs(Inventories) do
        if inv.isOpen == src then
            inv.isOpen = false
            Inventory.PersistStash(invId, inv)
        end
    end
    for _, drop in pairs(Drops) do
        if drop.isOpen == src then drop.isOpen = false end
    end
end)
