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
    local items = {}
    if inventoryId == 'player' then
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = RSGCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
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
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)')), Inventory.TYPES.OTHER_PLAYER
    elseif inventoryId:find('drop-') then
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
        if item.name:lower() == itemName:lower() and item.info.quality == quality then
            return tonumber(slot)
        end
    end
    return nil
end


--- @param item table The item table.
--- @param itemInfo table|nil Optional item definition from RSGCore.Shared.Items.
--- @param currentTime number|nil Optional timestamp (defaults to os.time()).
--- @return boolean shouldUpdate Whether the item metadata was updated.
--- @return number|nil newQuality The new quality of the item after decay.
--- @return boolean shouldDelete Whether the item should be deleted when quality reaches 0.
Inventory.CheckItemDecay = function(item, itemInfo, currentTime)
    itemInfo = itemInfo or RSGCore.Shared.Items[item.name:lower()]
    currentTime = currentTime or os.time()

    if not itemInfo or not itemInfo.decay then return false, nil, false end

    if not item.info.quality or not item.info.lastUpdate then
        item.info.quality = item.info.quality or 100
        item.info.lastUpdate = currentTime
        return true, item.info.quality, itemInfo.delete == true
    end

    local timeElapsed = currentTime - item.info.lastUpdate
    local decayRate = 100 / (itemInfo.decay * 60)
    local newQuality = math.max(0, item.info.quality - timeElapsed * decayRate)

    item.info.quality = math.round(newQuality, 1)
    item.info.lastUpdate = currentTime

    return true, math.round(newQuality, 1), itemInfo.delete == true
end


--- @param items table<number, table> Inventory items (indexed by slot).
--- @return boolean needsUpdate Returns true if any item was updated or deleted.
--- @return table removedItems Returns removed items.
Inventory.CheckItemsDecay = function(items)
    local needsUpdate = false
    local currentTime = os.time()
    local removedItems = {}

    for slot, item in pairs(items) do
        local updated, quality, delete = Inventory.CheckItemDecay(item, nil, currentTime)
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
    local _,inventoryType = Inventory.GetIdentifier(inventoryId)
    if inventoryType == Inventory.TYPES.PLAYER then
        local ped = GetPlayerPed(src)
        return DoesEntityExist(ped) and GetEntityCoords(ped)
    elseif inventoryType == Inventory.TYPES.OTHER_PLAYER then
        local ped = GetPlayerPed(_)
        return DoesEntityExist(ped) and GetEntityCoords(ped)
    elseif inventoryType == Inventory.TYPES.DROP then
        return Drops[inventoryId]?.coords
    elseif inventoryType == Inventory.TYPES.STASH then
        return Inventories[inventoryId]?.coords
    else
        warn(("Unexpected inventory type - '%s'"):format(inventoryType))
    end
end
