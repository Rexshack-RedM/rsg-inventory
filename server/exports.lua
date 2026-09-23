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
            local updated, quality, delete = Inventory.CheckItemDecay(item, itemInfo, currentTime, config.ItemsDecayWhileOffline and 1 or 0)
            local check = not (updated and delete and quality <= 0)

            if itemInfo and check then
                loadedInventory[item.slot] = {
                    name = itemInfo['name'],
                    amount = item.amount,
                    info = type(item.info) == 'table' and item.info or {},
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
    slot = tonumber(slot)
    if not slot then return end
    local item = Player.PlayerData.items[slot]
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
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or amount <= 0 then return false end
    local itemData = RSGCore.Shared.Items[item:lower()]
    if not itemData then return false end

    local inventory, maxWeight, maxSlots
    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        inventory, maxWeight, maxSlots = Player.PlayerData.items, Player.PlayerData.weight, Player.PlayerData.slots
    elseif Inventories[source] then
        inventory, maxWeight, maxSlots = Inventories[source].items, Inventories[source].maxweight, Inventories[source].slots
    elseif Drops[source] then
        inventory, maxWeight, maxSlots = Drops[source].items, Drops[source].maxweight, Drops[source].slots
    else
        return true
    end

    if Inventory.GetTotalWeight(inventory) + (itemData.weight * amount) > (maxWeight or config.StashSize.maxweight) then
        return false, 'weight'
    end

    -- A stackable item that already has a stack does not need a new slot
    if not itemData.unique and not itemData.decay and Inventory.GetFirstSlotByItem(inventory, item) then
        return true
    end

    local slotsUsed = 0
    for _ in pairs(inventory) do slotsUsed = slotsUsed + 1 end
    if slotsUsed >= (maxSlots or config.StashSize.slots) then
        return false, 'slots'
    end

    return true
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
    if not player then return end
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

--- Closes the player's inventory UI and releases the lock on the secondary inventory they had open.
--- @param source number
--- @param identifier string|nil
Inventory.CloseInventory = function(source, identifier)
    identifier = identifier or OpenedInventories[source]
    if identifier then
        local inv = Inventories[identifier] or Drops[identifier]
        if inv and (inv.isOpen == source or inv.isOpen == true) then
            inv.isOpen = false
            if Inventories[identifier] then Inventory.PersistStash(identifier, inv) end
        end
    end
    OpenedInventories[source] = nil
    Player(source).state.inv_busy = false
    TriggerClientEvent('rsg-inventory:client:closeInv', source)
end

exports('CloseInventory', Inventory.CloseInventory)

-- Opens the inventory of a player by their ID.
--- @param source number - The player's server ID.
--- @param targetId number - The ID of the player whose inventory will be opened.
Inventory.OpenInventoryById = function(source, targetId)
    targetId = tonumber(targetId)
    local RSGPlayer = RSGCore.Functions.GetPlayer(source)
    local TargetPlayer = RSGCore.Functions.GetPlayer(targetId)
    if not RSGPlayer or not TargetPlayer then return end

    -- Close the target's own UI first so they cannot move items while being searched
    if Player(targetId).state.inv_busy then
        Inventory.CloseInventory(targetId)
        Wait(250)
    end
    Player(targetId).state.inv_busy = true

    Inventory.CheckPlayerItemsDecay(RSGPlayer)
    Inventory.CheckPlayerItemsDecay(TargetPlayer)
    local charinfo = TargetPlayer.PlayerData.charinfo
    local formattedInventory = {
        name = 'otherplayer-' .. targetId,
        label = (charinfo and charinfo.firstname) and (charinfo.firstname .. ' ' .. charinfo.lastname) or GetPlayerName(targetId),
        maxweight = TargetPlayer.PlayerData.weight,
        slots = TargetPlayer.PlayerData.slots,
        inventory = TargetPlayer.PlayerData.items,
    }
    Player(source).state.inv_busy = true
    OpenedInventories[source] = formattedInventory.name
    TriggerClientEvent('rsg-inventory:client:openInventory', source, RSGPlayer.PlayerData.items, formattedInventory)
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
    local inventory = identifier and Inventories[identifier]
    if inventory then Inventory.PersistStash(identifier, inventory) end
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
        OpenedInventories[source] = nil
        Inventory.CheckPlayerItemsDecay(RSGPlayer)
        TriggerClientEvent('rsg-inventory:client:openInventory', source, RSGPlayer.PlayerData.items)
        return
    end

    if type(identifier) ~= 'string' then
        return
    end

    local inventory = Inventories[identifier]

    if inventory and inventory.isOpen and inventory.isOpen ~= source then
        TriggerClientEvent('ox_lib:notify', source, { title = locale('error.inventory_in_use'), type = 'error', duration = 5000 })
        return
    end

    if not inventory then 
        inventory = Inventory.InitializeInventory(identifier, data) 
    else
        local decayRate = Helpers.ParseDecayRate(identifier)
        Inventory.CheckItemsDecay(inventory.items, decayRate or 1)
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
    OpenedInventories[source] = identifier
    Inventory.CheckPlayerItemsDecay(RSGPlayer)
    TriggerClientEvent('rsg-inventory:client:openInventory', source, RSGPlayer.PlayerData.items, formattedInventory)
end

exports('OpenInventory', Inventory.OpenInventory)

-- Force drop function for when inventory is full (uses shared drop creation)
Inventory.ForceDropItem = function(source, item, amount, info, reason)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end

    local coords = GetEntityCoords(GetPlayerPed(source))
    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then return false end

    -- Create item data
    local itemData = {
        name = itemInfo.name,
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

    -- Spawn the bag via the shared drop helper
    local networkId = Helpers.CreateItemDrop(coords, itemData)

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

local function isValidAmount(amount)
    return type(amount) == 'number' and amount > 0 and amount == math.floor(amount) and amount < 2^31
end

local function resolveInventory(identifier)
    local player = RSGCore.Functions.GetPlayer(identifier)
    if player then
        return player.PlayerData.items, player.PlayerData.weight, player.PlayerData.slots, player, 1
    elseif Inventories[identifier] then
        local inv = Inventories[identifier]
        return inv.items, inv.maxweight or config.StashSize.maxweight, inv.slots or config.StashSize.slots, nil, Helpers.ParseDecayRate(identifier) or 1
    elseif Drops[identifier] then
        local drop = Drops[identifier]
        return drop.items, drop.maxweight or config.DropSize.maxweight, drop.slots or config.DropSize.slots, nil, 1
    end
end

local function generateSerial()
    return RSGCore.Shared.RandomInt(2) .. RSGCore.Shared.RandomStr(3) .. RSGCore.Shared.RandomInt(1) ..
        RSGCore.Shared.RandomStr(2) .. RSGCore.Shared.RandomInt(3) .. RSGCore.Shared.RandomStr(4)
end

local function logChange(title, colour, identifier, isPlayer, slot, item, amount, reason)
    local invName = isPlayer and ('%s (%s)'):format(GetPlayerName(identifier), identifier) or tostring(identifier)
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', title, colour,
        ('**Inventory:** %s (Slot: %s)\n**Item:** %s\n**Amount:** %s\n**Reason:** %s\n**Resource:** %s')
            :format(invName, slot, item, amount, reason or 'No reason specified', GetInvokingResource() or 'rsg-inventory'))
end

--- Adds an item to a player, stash or drop.
--- @param identifier number|string Player source or inventory identifier.
--- @param item string Item name.
--- @param amount number Amount (positive integer, defaults to 1).
--- @param slot number|nil Preferred slot. Falls back to a free slot if it cannot hold the item.
--- @param info table|nil Item metadata.
--- @param reason string|nil Log reason.
--- @param noForceDrop boolean|nil When true, a full player inventory returns false instead of dropping the item on the ground.
--- @return boolean success, string|nil 'dropped' when the item was placed on the ground because the player was full.
Inventory.AddItem = function(identifier, item, amount, slot, info, reason, noForceDrop)
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or not isValidAmount(amount) then return false end

    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then return false end
    item = itemInfo.name

    local inventory, maxWeight, maxSlots, player, decayRate = resolveInventory(identifier)
    if not inventory then return false end

    Inventory.CheckItemsDecay(inventory, decayRate)

    info = type(info) == 'table' and lib.table.deepclone(info) or {}
    if itemInfo.decay then
        info.quality = info.quality or 100
        info.lastUpdate = info.lastUpdate or os.time()
    end
    info = lib.table.merge(lib.table.deepclone(itemInfo.info or {}), info, false)

    local function fail(why)
        if player and not noForceDrop and Inventory.ForceDropItem(identifier, item, amount, info, reason or why) then
            return true, 'dropped'
        end
        return false
    end

    if Inventory.GetTotalWeight(inventory) + (itemInfo.weight * amount) > maxWeight then
        return fail('inventory full - weight')
    end

    slot = tonumber(slot)
    if slot and (slot < 1 or slot > maxSlots or slot ~= math.floor(slot)) then slot = nil end

    -- Try to stack onto an existing matching stack
    if not itemInfo.unique then
        local stackSlot = slot
        if not stackSlot then
            if itemInfo.decay or info.quality then
                stackSlot = Inventory.GetFirstSlotByItemWithQuality(inventory, item, info.quality)
            else
                stackSlot = Inventory.GetFirstSlotByItem(inventory, item)
            end
        end
        local existing = stackSlot and inventory[stackSlot]
        if existing and existing.name == item and existing.info.quality == info.quality then
            existing.amount = existing.amount + amount
            if player then player.Functions.SetPlayerData('items', inventory) end
            logChange('Item Added', 'green', identifier, player, stackSlot, item, amount, reason)
            return true
        end
    end

    -- Never overwrite an occupied slot
    if slot and inventory[slot] then slot = nil end
    slot = slot or Inventory.GetFirstFreeSlot(inventory, maxSlots)
    if not slot then
        return fail('inventory full - slots')
    end

    if itemInfo.type == 'weapon' then
        info.serie = info.serie or generateSerial()
        info.quality = info.quality or 100
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

    if player then player.Functions.SetPlayerData('items', inventory) end
    logChange('Item Added', 'green', identifier, player, slot, item, amount, reason)
    return true
end

exports('AddItem', Inventory.AddItem)

--- Removes an item from a player, stash or drop.
--- @param identifier number|string Player source or inventory identifier.
--- @param item string Item name.
--- @param amount number Amount (positive integer, defaults to 1).
--- @param slot number|nil Slot to remove from. If omitted, removes across all matching stacks.
--- @param reason string|nil Log reason.
--- @param isMove boolean|nil Whether the item is being moved (unequips weapons).
--- @return boolean success
Inventory.RemoveItem = function(identifier, item, amount, slot, reason, isMove)
    amount = tonumber(amount) or 1
    if type(item) ~= 'string' or not isValidAmount(amount) then return false end

    local itemInfo = RSGCore.Shared.Items[item:lower()]
    if not itemInfo then return false end
    item = item:lower()

    local inventory, _, _, player, decayRate = resolveInventory(identifier)
    if not inventory then return false end

    Inventory.CheckItemsDecay(inventory, decayRate)

    local removedInfo
    slot = tonumber(slot)
    if slot then
        local invItem = inventory[slot]
        if not invItem or invItem.name:lower() ~= item or invItem.amount < amount then
            return false
        end
        removedInfo = invItem.info
        invItem.amount = invItem.amount - amount
        if invItem.amount <= 0 then inventory[slot] = nil end
    else
        -- Verify the full amount exists before touching anything
        local total = 0
        for _, invItem in pairs(inventory) do
            if invItem.name:lower() == item then total = total + invItem.amount end
        end
        if total < amount then return false end

        local remaining = amount
        for key, invItem in pairs(inventory) do
            if invItem.name:lower() == item then
                local take = math.min(invItem.amount, remaining)
                invItem.amount = invItem.amount - take
                remaining = remaining - take
                removedInfo = invItem.info
                if invItem.amount <= 0 then inventory[key] = nil end
                if remaining <= 0 then break end
            end
        end
        slot = 'Multiple'
    end

    if player then
        if itemInfo.type == 'weapon' and isMove then
            TriggerClientEvent('rsg-core:client:RemoveWeaponFromTab', identifier, item)
        end
        player.Functions.SetPlayerData('items', inventory)
        -- Hook for third-party resources (not handled by rsg-inventory itself)
        TriggerEvent('rsg-inventory:server:itemRemovedFromPlayerInventory', identifier, item,
            { amount = amount, slot = slot, info = removedInfo }, reason, isMove)
    end

    logChange('Item Removed', 'red', identifier, player, slot, item, amount, reason)
    return true
end

exports('RemoveItem', Inventory.RemoveItem)

Inventory.GetInventory = function(identifier)
    if not Inventories[identifier] then
        return nil
    end
    local decayRate = Helpers.ParseDecayRate(identifier)
    Inventory.CheckItemsDecay(Inventories[identifier].items, decayRate or 1)
    return Inventories[identifier]
end

exports('GetInventory', Inventory.GetInventory)

--- Initialize or update inventory data
--- @param identifier string - The identifier of the inventory.
--- @param data table - The data of the inventory
Inventory.CreateInventory = function (identifier, data)
    data = data or {}
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
        Inventory.InitializeInventory(identifier, data)
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
