local RSGCore = exports['rsg-core']:GetCoreObject()
Inventory = Inventory or {}
local config = require 'shared.config'
Inventory.LoadInventory = function(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    inventory = json.decode(inventory)
    if not inventory or not next(inventory) then return {} end

    local loadedInventory = {}
    local missingItems = {}

    local currentTime = os.time()

    for _, item in pairs(inventory) do
        if item and item.name then
            local itemInfo = RSGCore.Shared.Items[item.name:lower()]
            local updated, quality, delete = Inventory.CheckItemDecay(item, itemInfo, currentTime)
            local check = not (updated and delete and quality <= 0)

            if itemInfo and check then
                loadedInventory[item.slot] = {
                    name = itemInfo['name'],
                    amount = item.amount,
                    info = item.info or '',
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    image = itemInfo['image'],
                    shouldClose = itemInfo['shouldClose'],
                    slot = item.slot,
                    combinable = itemInfo['combinable']
                }
            else
                missingItems[#missingItems + 1] = item.name:lower()
            end
        end
    end

    if #missingItems > 0 then
        print(('The following items were removed for player %s as they no longer exist: %s'):format(GetPlayerName(source), table.concat(missingItems, ', ')))
    end

    return loadedInventory
end

exports('LoadInventory', Inventory.LoadInventory)

Inventory.SaveInventory = function(source, offline)
    local PlayerData
    if offline then
        PlayerData = source
    else
        local Player = RSGCore.Functions.GetPlayer(source)
        if not Player then return end
        PlayerData = Player.PlayerData
    end

    local items = PlayerData.items
    local ItemsJson = {}

    if items and next(items) then
        for slot, item in pairs(items) do
            if item then
                ItemsJson[#ItemsJson + 1] = {
                    name = item.name,
                    amount = item.amount,
                    info = type(item.info) == "table" and item.info or {},
                    type = item.type,
                    slot = slot,
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(ItemsJson), PlayerData.citizenid })
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', PlayerData.citizenid })
    end
end

exports('SaveInventory', Inventory.SaveInventory)

--- Sets the inventory of a player.
--- @param source number The player's server ID.
--- @param items table The items to set in the player's inventory.
Inventory.SetInventory = function(source, items)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    Player.Functions.SetPlayerData('items', items)
    if not Player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** items set: %s', GetPlayerName(source), Player.PlayerData.citizenid, source, json.encode(items))
        TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'SetInventory', 'blue', logMessage)
    end
end

exports('SetInventory', Inventory.SetInventory)

-- Sets the value of a specific key in the data of an item for a player.
--- @param source number The player's server ID.
--- @param itemName string The name of the item.
--- @param key string The key to set the value for.
--- @param val any The value to set for the key.
--- @return boolean|nil - Returns true if the value was set successfully, false otherwise.
Inventory.SetItemData = function(source, itemName, key, val)
    if not itemName or not key then return false end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local item = Inventory.GetItemByName(source, itemName)
    if not item then return false end
    item[key] = val
    Player.PlayerData.items[item.slot] = item
    Player.Functions.SetPlayerData('items', Player.PlayerData.items)
    return true
end

exports('SetItemData', Inventory.SetItemData)

--- Retrieves the weight of an item from the shared item configuration.
--- @param itemName string - The name of the item to retrieve the weight for.
--- @return number|nil - The weight of the item, or nil if the item doesn't exist.
Inventory.GetItemWeight = function(itemName)
    itemName = itemName:lower()
    local itemInfo = RSGCore.Shared.Items[itemName]
    if itemInfo then
        return itemInfo.weight
    else
        return nil
    end
end

exports('GetItemWeight', Inventory.GetItemWeight)

Inventory.UseItem = function(itemName, ...)
    local itemData = RSGCore.Functions.CanUseItem(itemName)
    local callback = type(itemData) == 'table' and (rawget(itemData, '__cfx_functionReference') and itemData or itemData.cb or itemData.callback) or type(itemData) == 'function' and itemData
    if not callback then return end
    callback(...)
end

exports('UseItem', Inventory.UseItem)

-- Retrieves the slots in the items table that contain a specific item.
--- @param items table The table containing the items.
--- @param itemName string The name of the item to search for.
--- @return table A table containing the slots where the item was found.
Inventory.GetSlotsByItem = function(items, itemName)
    local slotsFound = {}
    if not items then return slotsFound end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound + 1] = slot
        end
    end
    return slotsFound
end

exports('GetSlotsByItem', Inventory.GetSlotsByItem)

-- Retrieves the first slot number that contains an item with the specified name.
--- @param items table The table of items to search through.
--- @param itemName string The name of the item to search for.
--- @return number|nil - The slot number of the first matching item, or nil if no match is found.
Inventory.GetFirstSlotByItem = function(items, itemName)
    if not items then return end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end

exports('GetFirstSlotByItem', Inventory.GetFirstSlotByItem)

--- Retrieves an item from a player's inventory based on the specified slot.
--- @param source number The player's server ID.
--- @param slot number The slot number of the item.
--- @return table|nil - item data if found, or nil if not found.
Inventory.GetItemBySlot = function(source, slot)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local item = Player.PlayerData.items[tonumber(slot)]
    if not item then return end
    return Inventory.CheckPlayerItemDecay(Player, item)
end

exports('GetItemBySlot', Inventory.GetItemBySlot)

Inventory.GetTotalWeight = function(items)
    if not items then return 0 end
    local weight = 0
    for _, item in pairs(items) do
        weight = weight + (item.weight * item.amount)
    end
    return tonumber(weight)
end

exports('GetTotalWeight', Inventory.GetTotalWeight)

-- Retrieves an item from a player's inventory by its name.
--- @param source number - The player's server ID.
--- @param item string - The name of the item to retrieve.
--- @return table|nil - item data if found, nil otherwise.
Inventory.GetItemByName = function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local items = Player.PlayerData.items
    local slot = Inventory.GetFirstSlotByItem(items, tostring(item):lower())
    return items[slot]
end

exports('GetItemByName', Inventory.GetItemByName)

-- Retrieves a list of items with a specific name from a player's inventory.
--- @param source number The player's server ID.
--- @param item string The name of the item to search for.
--- @return table|nil - containing the items with the specified name.
Inventory.GetItemsByName = function(source, item)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    local PlayerItems = Player.PlayerData.items
    item = tostring(item):lower()
    local items = {}
    for _, slot in pairs(Inventory.GetSlotsByItem(PlayerItems, item)) do
        if slot then
            items[#items + 1] = PlayerItems[slot]
        end
    end
    return items
end

exports('GetItemsByName', Inventory.GetItemsByName)

--- Retrieves the total count of used and free slots for a player or an inventory.
--- @param identifier number|string The player's identifier or the identifier of an inventory or drop.
--- @return number, number - The total count of used slots and the total count of free slots. If no inventory is found, returns 0 and the maximum slots.
Inventory.GetSlots = function(identifier)
    local inventory, maxSlots
    local player = RSGCore.Functions.GetPlayer(identifier)
    if player then
        inventory = player.PlayerData.items
        maxSlots = player.PlayerData.slots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        maxSlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        maxSlots = Drops[identifier].slots
    end
    if not inventory then return 0, maxSlots end
    local slotsUsed = 0
    for _, v in pairs(inventory) do
        if v then
            slotsUsed = slotsUsed + 1
        end
    end
    local slotsFree = maxSlots - slotsUsed
    return slotsUsed, slotsFree
end

exports('GetSlots', Inventory.GetSlots)

--- Retrieves the total count of specified items for a player.
--- @param source number The player's source ID.
--- @param items table|string The items to count. Can be either a table of item names or a single item name.
--- @return number|nil - The total count of the specified items.
Inventory.GetItemCount = function(source, items)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return end
    Inventory.CheckPlayerItemsDecay(Player)
    local isTable = type(items) == 'table'
    local itemsSet = isTable and {} or nil
    if isTable then
        for _, item in pairs(items) do
            itemsSet[item] = true
        end
    end
    local count = 0
    for _, item in pairs(Player.PlayerData.items) do
        if (isTable and itemsSet[item.name]) or (not isTable and items == item.name) then
            count = count + item.amount
        end
    end
    return count
end

exports('GetItemCount', Inventory.GetItemCount)

--- Checks if an item can be added to a player's inventory.
--- @param source number The player's server ID.
--- @param item string The item name.
--- @param amount number The amount of the item.
--- @return boolean - Returns true if the item can be added, false otherwise.
--- @return string|nil - Returns a string indicating the reason why the item cannot be added (e.g., 'weight' or 'slots'), or nil if it can be added.
Inventory.CanAddItem = function(source, item, amount)
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        local itemData = RSGCore.Shared.Items[item:lower()]
        if not itemData then return false end

        local weight = itemData.weight * amount
        local totalWeight = Inventory.GetTotalWeight(Player.PlayerData.items) + weight

        if totalWeight > Player.PlayerData.weight then
            return false, 'weight'
        end

        local slotsUsed = 0
        for _, v in pairs(Player.PlayerData.items) do
            if v then
                slotsUsed = slotsUsed + 1
            end
        end
        
        if slotsUsed >= Player.PlayerData.slots then
            return false, 'slots'
        end

        return true

    elseif Inventories[source] then
        local inventory = Inventories[source].items
        local inventoryWeight = Inventories[source].maxweight or 250000
        local itemData = RSGCore.Shared.Items[item:lower()]
        
        if not itemData then return false end
        
        local weight = itemData.weight * amount
        local totalWeight = Inventory.GetTotalWeight(inventory) + weight
        
        if totalWeight > inventoryWeight then
            return false, 'weight'
        end

        return true
    else
        return true
    end
end

exports('CanAddItem', Inventory.CanAddItem)

--- Gets the total free weight of the player's inventory.
--- @param source number The player's server ID.
--- @return number - Returns the free weight of the players inventory. Error will return 0
Inventory.GetFreeWeight = function(source)
    if not source then
        warn('Source was not passed into GetFreeWeight')
        return 0
    end
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return 0 end

    local totalWeight = Inventory.GetTotalWeight(Player.PlayerData.items)
    local freeWeight = Player.PlayerData.weight - totalWeight
    return freeWeight
end

exports('GetFreeWeight', Inventory.GetFreeWeight)

Inventory.ClearInventory = function(source, filterItems)
    local player = RSGCore.Functions.GetPlayer(source)
    local savedItemData = {}
    if filterItems then
        if type(filterItems) == 'string' then
            local item = Inventory.GetItemByName(source, filterItems)
            if item then savedItemData[item.slot] = item end
        elseif type(filterItems) == 'table' then
            for _, itemName in ipairs(filterItems) do
                local item = Inventory.GetItemByName(source, itemName)
                if item then savedItemData[item.slot] = item end
            end
        end
    end
    player.Functions.SetPlayerData('items', savedItemData)
    if not player.Offline then
        local logMessage = string.format('**%s (citizenid: %s | id: %s)** inventory cleared', GetPlayerName(source), player.PlayerData.citizenid, source)
        TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', logMessage)
        local ped = GetPlayerPed(source)
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= `WEAPON_UNARMED` then
            RemoveWeaponFromPed(ped, weapon)
        end
        if Player(source).state.inv_busy then TriggerClientEvent('rsg-inventory:client:updateInventory', source) end
    end
end

exports('ClearInventory', Inventory.ClearInventory)

--- Checks if a player has a certain item or items in their inventory.
--- @param source number The player's server ID.
--- @param items string|table The name of the item or a table of item names.
--- @param amount number (optional) The minimum amount required for each item.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
Inventory.HasItem = function(source, items, amount)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    Inventory.CheckPlayerItemsDecay(Player)

    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do totalItems = totalItems + 1 end
    end

    for _, itemData in pairs(Player.PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                if itemData and itemData.name == (isArray and v or k) and ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or (not amount and isArray)) then
                    count = count + 1
                    if count == totalItems then
                        return true
                    end
                end
            end
        else -- Single item as string
            if itemData and itemData.name == items and (not amount or (itemData and amount and itemData.amount >= amount)) then
                return true
            end
        end
    end

    return false
end

exports('HasItem', Inventory.HasItem)

-- CloseInventory function closes the inventory for a given source and identifier.
-- It sets the isOpen flag of the inventory identified by the given identifier to false.
-- It also sets the inv_busy flag of the player identified by the given source to false.
-- Finally, it triggers the 'rsg-inventory:client:closeInv' event for the given source.
Inventory.CloseInventory = function(source, identifier)
    if identifier and Inventories[identifier] then
        Inventories[identifier].isOpen = false
    end
    Player(source).state.inv_busy = false
    TriggerClientEvent('rsg-inventory:client:closeInv', source)
end

exports('CloseInventory', Inventory.CloseInventory)

-- Opens the inventory of a player by their ID.
--- @param source number - The player's server ID.
--- @param targetId number - The ID of the player whose inventory will be opened.
Inventory.OpenInventoryById = function(source, targetId)
    local RSGPlayer = RSGCore.Functions.GetPlayer(source)
    local TargetPlayer = RSGCore.Functions.GetPlayer(tonumber(targetId))
    if not RSGPlayer or not TargetPlayer then return end
    if Player(targetId).state.inv_busy then Inventory.CloseInventory(targetId) end
    Inventory.CheckPlayerItemsDecay(RSGPlayer)
    Inventory.CheckPlayerItemsDecay(TargetPlayer)
    local playerItems = RSGPlayer.PlayerData.items
    local targetItems = TargetPlayer.PlayerData.items
    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = GetPlayerName(targetId),
        maxweight = TargetPlayer.PlayerData.weight,
        slots = TargetPlayer.PlayerData.slots,
        inventory = targetItems
    }
    Wait(1500)
    Player(targetId).state.inv_busy = true
    TriggerClientEvent('rsg-inventory:client:openInventory', source, playerItems, formattedInventory)
end

exports('OpenInventoryById', Inventory.OpenInventoryById)

-- Clears a given stash of all items inside
--- @param identifier string
Inventory.ClearStash = function(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    inventory.items = {}
    MySQL.prepare('UPDATE inventories SET items = ? WHERE identifier = ?', { json.encode(inventory.items), identifier })
end

exports('ClearStash', Inventory.ClearStash)

-- Save a given stash
--- @param identifier string
Inventory.SaveStash = function(identifier)
    if not identifier then return end
    local inventory = Inventories[identifier]
    if not inventory then return end
    local items = json.encode(inventory.items)
    MySQL.prepare("INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?",
        { identifier, items, items })
end

exports("SaveStash", Inventory.SaveStash)

--- @param source number The player's server ID.
--- @param identifier string|nil The identifier of the inventory to open.
--- @param data table|nil Additional data for initializing the inventory.
Inventory.OpenInventory = function (source, identifier, data)
    if Player(source).state.inv_busy then return end
    local RSGPlayer = RSGCore.Functions.GetPlayer(source)
    if not RSGPlayer then return end

    if not identifier then
        Player(source).state.inv_busy = true
        Inventory.CheckPlayerItemsDecay(RSGPlayer)
        TriggerClientEvent('rsg-inventory:client:openInventory', source, RSGPlayer.PlayerData.items)
        return
    end

    if type(identifier) ~= 'string' then
        return
    end

    local inventory = Inventories[identifier]

    if inventory and inventory.isOpen then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.access_denied') or locale('error.error'), type = 'error', duration = 5000 })
        return
    end

    if not inventory then 
        inventory = Inventory.InitializeInventory(identifier, data) 
    else
        Inventory.CheckItemsDecay(inventory.items)
    end
    inventory.maxweight = (data and data.maxweight) or (inventory and inventory.maxweight) or config.StashSize.maxweight
    inventory.slots = (data and data.slots) or (inventory and inventory.slots) or config.StashSize.slots
    inventory.label = (data and data.label) or (inventory and inventory.label) or identifier
    inventory.isOpen = source

    local formattedInventory = {
        name = identifier,
        label = inventory.label,
        maxweight = inventory.maxweight,
        slots = inventory.slots,
        inventory = inventory.items
    }
    
    Player(source).state.inv_busy = true
    Inventory.CheckPlayerItemsDecay(RSGPlayer)
    TriggerClientEvent('rsg-inventory:client:openInventory', source, RSGPlayer.PlayerData.items, formattedInventory)
end

exports('OpenInventory', Inventory.OpenInventory)

-- Force drop function for when inventory is full (uses shared drop creation)
Inventory.ForceDropItem = function(source, item, amount, info, reason)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)

    -- Get item info
    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then return false end

    -- Create item data
    local itemData = {
        name = item,
        amount = amount,
        info = info or {},
        slot = 1,
        label = itemInfo.label,
        description = itemInfo.description or '',
        weight = itemInfo.weight,
        type = itemInfo.type,
        unique = itemInfo.unique,
        useable = itemInfo.useable,
        image = itemInfo.image,
        shouldClose = itemInfo.shouldClose,
        combinable = itemInfo.combinable
    }

    -- Use the shared drop creation function
    local networkId = Helpers.CreateItemDrop(coords, itemData, false, nil)

    if not networkId then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            title = locale('error.error'),
            description = locale('error.inventory_force_drop_failed'),
            duration = 7000
        })
        return false
    end

    -- Log the forced drop
    local logMessage = string.format('**%s (citizenid: %s | id: %s)** item force dropped due to full inventory: %s x%s at %s',
        GetPlayerName(source), Player.PlayerData.citizenid, source, item, amount, coords)
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', 'Force Drop', 'orange', logMessage)

    -- Notify the player
    TriggerClientEvent('ox_lib:notify', source, {
        type = 'warning',
        title = locale('error.inventory_full'),
        description = locale('error.inventory_force_drop'),
        duration = 5000
    })

    return networkId
end

exports('ForceDropItem', Inventory.ForceDropItem)

--- Adds an item to the player's inventory or a specific inventory.
--- @param identifier string The identifier of the player or inventory.
--- @param item string The name of the item to add.
--- @param amount number The amount of the item to add.
--- @param slot number (optional) The slot to add the item to. If not provided, it will find the first available slot.
--- @param info table (optional) Additional information about the item.
--- @param reason string (optional) The reason for adding the item.
--- @return boolean Returns true if the item was successfully added, false otherwise.
Inventory.AddItem = function(identifier, item, amount, slot, info, reason)
    amount = tonumber(amount) or 1
    if amount <= 0 then
        return false
    end

    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then
        return false
    end

    local inventory, inventoryWeight, inventorySlots
    local player = RSGCore.Functions.GetPlayer(identifier)

    if player then
        inventory = player.PlayerData.items
        inventoryWeight = player.PlayerData.weight
        inventorySlots = player.PlayerData.slots
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
        inventoryWeight = Inventories[identifier].maxweight
        inventorySlots = Inventories[identifier].slots
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
        inventoryWeight = Drops[identifier].maxweight
        inventorySlots = Drops[identifier].slots
    end

    if not inventory then
        return false
    end

    Inventory.CheckItemsDecay(inventory)
    
    local totalWeight = Inventory.GetTotalWeight(inventory)
    if totalWeight + (itemInfo.weight * amount) > inventoryWeight then
        -- If this is a player and not a forced add, try to drop on ground
        if player then
            return Inventory.ForceDropItem(identifier, item, amount, info, reason or 'inventory full - weight')
        end
        return false
    end

    info = info or {}
    if itemInfo.decay then
        info.quality = info.quality or 100
        info.lastUpdate = info.lastUpdate or os.time()
    end

    local updated = false
    if not itemInfo.unique then
        if not slot then
            if itemInfo.decay or info.quality then
                slot = Inventory.GetFirstSlotByItemWithQuality(inventory, item, info.quality)
            else
                slot = Inventory.GetFirstSlotByItem(inventory, item)
            end
        end
        if slot then
            for _, invItem in pairs(inventory) do
                if invItem.slot == slot and info.quality == invItem.info.quality then
                    invItem.amount = invItem.amount + amount
                    updated = true
                    break
                end
            end
        end
    end

    if not updated then
        slot = slot or Inventory.GetFirstFreeSlot(inventory, inventorySlots)
        if not slot then
            -- If this is a player and not a forced add, try to drop on ground
            if player then
                return Inventory.ForceDropItem(identifier, item, amount, info, reason or 'inventory full - slots')
            end
            return false
        end

        inventory[slot] = {
            name = item,
            amount = amount,
            info = info,
            label = itemInfo.label,
            description = itemInfo.description or '',
            weight = itemInfo.weight,
            type = itemInfo.type,
            unique = itemInfo.unique,
            useable = itemInfo.useable,
            image = itemInfo.image,
            shouldClose = itemInfo.shouldClose,
            slot = slot,
            combinable = itemInfo.combinable
        }

        if itemInfo.type == 'weapon' then
            if not inventory[slot].info.serie then
                inventory[slot].info.serie = tostring(
                    RSGCore.Shared.RandomInt(2) .. 
                    RSGCore.Shared.RandomStr(3) .. 
                    RSGCore.Shared.RandomInt(1) .. 
                    RSGCore.Shared.RandomStr(2) .. 
                    RSGCore.Shared.RandomInt(3) .. 
                    RSGCore.Shared.RandomStr(4)
                )
            end
            if not inventory[slot].info.quality then
                inventory[slot].info.quality = 100
            end
        end
    end

    if player then player.Functions.SetPlayerData('items', inventory) end
    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local addReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'rsg-inventory'
    TriggerEvent(
        'rsg-log:server:CreateLog',
        'playerinventory',
        'Item Added',
        'green',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. addReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )
    return true
end

exports('AddItem', Inventory.AddItem)

-- Removes an item from a player's inventory.
--- @param identifier string - The identifier of the player.
--- @param item string - The name of the item to remove.
--- @param amount number - The amount of the item to remove.
--- @param slot number - The slot number of the item in the inventory. If not provided, it will find the first slot with the item.
--- @param reason string - The reason for removing the item. Defaults to 'No reason specified' if not provided.
--- @return boolean - Returns true if the item was successfully removed, false otherwise.
Inventory.RemoveItem = function(identifier, item, amount, slot, reason, isMove)
    if not RSGCore.Shared.Items[item:lower()] then
        return false
    end

    local inventory
    local player = RSGCore.Functions.GetPlayer(identifier)
    local inventoryItem = nil

    if player then
        inventory = player.PlayerData.items
    elseif Inventories[identifier] then
        inventory = Inventories[identifier].items
    elseif Drops[identifier] then
        inventory = Drops[identifier].items
    end

    if not inventory then
        return false
    end

    Inventory.CheckItemsDecay(inventory)

    amount = tonumber(amount) or 1
    
    if slot then
        slot = tonumber(slot)
        local itemKey = nil

        for key, invItem in pairs(inventory) do
            if invItem.slot == slot then
                inventoryItem = invItem
                itemKey = key
                break
            end
        end

        if not inventoryItem or inventoryItem.name:lower() ~= item:lower() then
            return false
        end

        if inventoryItem.amount < amount then
            return false
        end

        inventoryItem.amount = inventoryItem.amount - amount
        if inventoryItem.amount <= 0 then
            inventory[itemKey] = nil
        else
            inventory[itemKey] = inventoryItem
        end

    else
        local totalRemoved = 0

        for itemKey, invItem in pairs(inventory) do
            if invItem.name:lower() == item:lower() then
                local available = invItem.amount
                local removeAmount = math.min(available, amount - totalRemoved)
                invItem.amount = invItem.amount - removeAmount
                totalRemoved = totalRemoved + removeAmount
                inventoryItem = invItem

                if invItem.amount <= 0 then
                    inventory[itemKey] = nil
                else
                    inventory[itemKey] = invItem
                end

                if totalRemoved >= amount then
                    break
                end
            end
        end

        if totalRemoved < amount then
            return false
        end

        slot = 'Multiple'
    end

    if RSGCore.Shared.Items[item:lower()]['type'] == 'weapon' and player and isMove then
        TriggerClientEvent('rsg-core:client:RemoveWeaponFromTab', identifier, item)
    end

    if player then 
        player.Functions.SetPlayerData('items', inventory)
         local data = {
            amount = amount,
            slot = slot,
            info = inventoryItem.info
        }
        TriggerEvent("rsg-inventory:server:itemRemovedFromPlayerInventory", identifier, item, data, reason, isMove)
    end

    local invName = player and GetPlayerName(identifier) .. ' (' .. identifier .. ')' or identifier
    local removeReason = reason or 'No reason specified'
    local resourceName = GetInvokingResource() or 'rsg-inventory'

    TriggerEvent(
        'rsg-log:server:CreateLog',
        'playerinventory',
        'Item Removed',
        'red',
        '**Inventory:** ' .. invName .. ' (Slot: ' .. slot .. ')\n' ..
        '**Item:** ' .. item .. '\n' ..
        '**Amount:** ' .. amount .. '\n' ..
        '**Reason:** ' .. removeReason .. '\n' ..
        '**Resource:** ' .. resourceName
    )

    return true
end

exports('RemoveItem', Inventory.RemoveItem)

Inventory.GetInventory = function(identifier)
    if not Inventories[identifier] then
        return nil
    end
    Inventory.CheckItemsDecay(Inventories[identifier].items)
    return Inventories[identifier]
end

exports('GetInventory', Inventory.GetInventory)

--- Initialize or update inventory data
--- @param identifier string - The identifier of the inventory.
--- @param data table - The data of the inventory
Inventory.CreateInventory = function (identifier, data)
    if Inventories[identifier] then 
        if data.label then
            Inventories[identifier].label = data.label
        end

        if data.maxweight then
            Inventories[identifier].maxweight = data.maxweight
        end

        if data.slots then
            Inventories[identifier].slots = data.slots
        end
    else
        Inventories[identifier] = Inventory.InitializeInventory(identifier, data)
    end
end

exports('CreateInventory', Inventory.CreateInventory)

-- Deletes an inventory from the global Inventories table
--- @param identifier string - The identifier of the inventory to delete
Inventory.DeleteInventory = function(identifier)
    if Inventories[identifier] then
        Inventories[identifier] = nil
        return true
    end
    return false
end

exports('DeleteInventory', Inventory.DeleteInventory)
