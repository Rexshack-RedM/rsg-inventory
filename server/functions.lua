local RSGCore = exports['rsg-core']:GetCoreObject()
Inventory = Inventory or {}
local config = require 'shared.config'

Inventory.TYPES = {
    PLAYER = 1,
    OTHER_PLAYER = 2,
    DROP = 3,
    STASH = 4,
}
Inventory.MAX_DIST = 5.0

Inventory.InitializeInventory = function(inventoryId, data)
    Inventories[inventoryId] = {
        coords = data and data.coords,
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or config.StashSize.maxweight,
        slots = data and data.slots or config.StashSize.slots
    }
    return Inventories[inventoryId]
end

Inventory.GetItem = function(inventoryId, src, slot)
    local items
    if inventoryId == 'player' then
        local Player = RSGCore.Functions.GetPlayer(src)
        items = Player and Player.PlayerData.items
    elseif inventoryId:find('^otherplayer%-') then
        local targetPlayer = RSGCore.Functions.GetPlayer(tonumber(inventoryId:match('^otherplayer%-(%d+)$')))
        items = targetPlayer and targetPlayer.PlayerData.items
    elseif Drops[inventoryId] then
        items = Drops[inventoryId].items
    elseif Inventories[inventoryId] then
        items = Inventories[inventoryId].items
    end
    return items and items[slot] or nil
end

Inventory.GetFirstFreeSlot = function(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then
            return i
        end
    end
    return nil
end

Inventory.GetIdentifier = function(inventoryId, src)
    if inventoryId == 'player' then
        return src, Inventory.TYPES.PLAYER
    elseif inventoryId:find('^otherplayer%-') then
        return tonumber(inventoryId:match('^otherplayer%-(%d+)$')), Inventory.TYPES.OTHER_PLAYER
    elseif inventoryId:find('^drop%-') then
        return inventoryId, Inventory.TYPES.DROP
    else
        return inventoryId, Inventory.TYPES.STASH
    end
end

Inventory.CheckWeapon = function(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = RSGCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('rsg-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end

-- Retrieves the first slot number that contains an item with the specified name and matches quality
--- @param items table The table of items to search through.
--- @param itemName string The name of the item to search for.
--- @param quality number item quality to match
--- @return number|nil - The slot number of the first matching item, or nil if no match is found.
Inventory.GetFirstSlotByItemWithQuality = function(items, itemName, quality)
    if not items then return end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() and item.info and item.info.quality == quality then
            return tonumber(slot)
        end
    end
    return nil
end


--- @param item table The item table.
--- @param itemInfo table|nil Optional item definition from RSGCore.Shared.Items.
--- @param currentTime number|nil Optional timestamp (defaults to os.time()).
--- @param decayRateModifier number|nil Optional modifier for configured decay rate
--- @return boolean shouldUpdate Whether the item metadata was updated.
--- @return number|nil newQuality The new quality of the item after decay.
--- @return boolean shouldDelete Whether the item should be deleted when quality reaches 0.
Inventory.CheckItemDecay = function(item, itemInfo, currentTime, decayRateModifier)
    itemInfo = itemInfo or RSGCore.Shared.Items[item.name:lower()]
    currentTime = currentTime or os.time()

    if not itemInfo or not itemInfo.decay then return false, nil, false end
    if type(item.info) ~= 'table' then item.info = {} end

    if not item.info.quality or not item.info.lastUpdate then
        item.info.quality = item.info.quality or 100
        item.info.lastUpdate = currentTime
        return true, item.info.quality, itemInfo.delete == true
    end
    decayRateModifier = decayRateModifier or 1
    local timeElapsed = currentTime - item.info.lastUpdate
    local decayRate = (100 / (itemInfo.decay * 60)) * decayRateModifier
    local newQuality = math.max(0, item.info.quality - timeElapsed * decayRate)
    item.info.quality = math.round(newQuality, 1)
    item.info.lastUpdate = currentTime

    return true, item.info.quality, itemInfo.delete == true
end


--- @param items table<number, table> Inventory items (indexed by slot).
--- @param decayRateModifier number|nil Optional modifier for configured decay rate
--- @return boolean needsUpdate Returns true if any item was updated or deleted.
--- @return table removedItems Returns removed items.
Inventory.CheckItemsDecay = function(items, decayRateModifier)
    local needsUpdate = false
    local currentTime = os.time()
    local removedItems = {}

    for slot, item in pairs(items) do
        local updated, quality, delete = Inventory.CheckItemDecay(item, nil, currentTime, decayRateModifier)
        if updated then
            if delete and quality <= 0 then
                removedItems[slot] = items[slot]
                items[slot] = nil
            end
            needsUpdate = true
        end
    end

    return needsUpdate, removedItems
end


--- @param player table The player object.
Inventory.CheckPlayerItemsDecay = function(player)
    local needsUpdate, removedItems = Inventory.CheckItemsDecay(player.PlayerData.items)

    if needsUpdate then
        player.Functions.SetPlayerData('items', player.PlayerData.items)
        for _, item in pairs(removedItems) do
            TriggerClientEvent('rsg-inventory:client:ItemBox', player.PlayerData.source, RSGCore.Shared.Items[item.name], 'remove', item.amount)
        end
    end
end


--- @param player table The player object.
--- @param item table item object.
Inventory.CheckPlayerItemDecay = function(player, item)
    local updated, quality, delete = Inventory.CheckItemDecay(item)
    if updated then
        if delete and quality <= 0 then
            player.PlayerData.items[item.slot] = nil
            TriggerClientEvent('rsg-inventory:client:ItemBox', player.PlayerData.source, RSGCore.Shared.Items[item.name], 'remove', item.amount)
        end
        player.Functions.SetPlayerData('items', player.PlayerData.items)
    end

    return player.PlayerData.items[item.slot]
end


--- @param inventoryId string
--- @param src? any
--- @return vector3|nil
Inventory.GetCoords = function(inventoryId, src)
    local id, inventoryType = Inventory.GetIdentifier(inventoryId, src)
    if inventoryType == Inventory.TYPES.PLAYER then
        local ped = GetPlayerPed(src)
        return DoesEntityExist(ped) and GetEntityCoords(ped)
    elseif inventoryType == Inventory.TYPES.OTHER_PLAYER then
        local ped = GetPlayerPed(id)
        return DoesEntityExist(ped) and GetEntityCoords(ped)
    elseif inventoryType == Inventory.TYPES.DROP then
        return Drops[inventoryId]?.coords
    elseif inventoryType == Inventory.TYPES.STASH then
        return Inventories[inventoryId]?.coords
    else
        warn(("Unexpected inventory type - '%s'"):format(inventoryType))
    end
end


local RESTRICTED_STASHES = { 'police', 'marshal', 'gang', 'admin', 'evidence' }

--- Returns false if the stash identifier is restricted and the player lacks access.
--- @param src number
--- @param Player table RSGCore player
--- @param identifier string
--- @return boolean
Inventory.HasStashAccess = function(src, Player, identifier)
    for _, prefix in ipairs(RESTRICTED_STASHES) do
        if identifier:find('^' .. prefix .. '%-') then
            if prefix == 'police' or prefix == 'marshal' then
                local job = Player.PlayerData.job and Player.PlayerData.job.name
                return RSGCore.Functions.HasPermission(src, 'police') or job == 'police' or job == 'marshal'
            elseif prefix == 'gang' then
                -- e.g. 'gang-lemoyne-stash' -> 'lemoyne'
                local gangName = identifier:match('^gang%-(.+)%-')
                return Player.PlayerData.gang ~= nil and Player.PlayerData.gang.name == gangName
            end
            return RSGCore.Functions.HasPermission(src, 'admin')
        end
    end
    return true
end

--- Validates that src may loot/search the target player.
--- Dead players can be looted by anyone; handcuffed players only by law enforcement.
--- @return boolean ok, string|nil localeKey
Inventory.CanAccessOtherPlayer = function(src, Player, targetId)
    local Target = RSGCore.Functions.GetPlayer(targetId)
    if not Target or targetId == src then return false end
    local srcPed, targetPed = GetPlayerPed(src), GetPlayerPed(targetId)
    if not DoesEntityExist(srcPed) or not DoesEntityExist(targetPed) then return false end
    if #(GetEntityCoords(srcPed) - GetEntityCoords(targetPed)) > 3.0 then
        return false, 'error.player_too_far'
    end
    local meta = Target.PlayerData.metadata
    if meta.isdead then return true end
    if not meta.ishandcuffed then return false, 'error.target_needs_restrained' end
    local job = Player.PlayerData.job and Player.PlayerData.job.name
    if RSGCore.Functions.HasPermission(src, 'police') or job == 'police' or job == 'marshal' then
        return true
    end
    return false, 'error.no_permission'
end

--- Pushes the current state of the player's (and the open secondary) inventory to the NUI.
--- Used to resync the UI after a server-side rejection.
Inventory.RefreshClient = function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local otherId = OpenedInventories[src]
    local otherItems
    if otherId then
        if otherId:find('^otherplayer%-') then
            local target = RSGCore.Functions.GetPlayer(tonumber(otherId:match('^otherplayer%-(%d+)$')))
            otherItems = target and target.PlayerData.items
        elseif Drops[otherId] then
            otherItems = Drops[otherId].items
        elseif Inventories[otherId] then
            otherItems = Inventories[otherId].items
        end
    end
    TriggerClientEvent('rsg-inventory:client:refreshInventory', src, Player.PlayerData.items, otherItems)
end

--- Persists a stash to the database.
Inventory.PersistStash = function(identifier, inv)
    local items = json.encode(inv.items)
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
        { identifier, items, items })
end
