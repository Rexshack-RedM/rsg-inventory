local RSGCore = exports['rsg-core']:GetCoreObject()
-- Player Disconnect Handler
AddEventHandler('playerDropped', function()
    for _, inv in pairs(Inventories) do
        if inv.isOpen == source then
            inv.isOpen = false
        end
    end
end)

-- Server Shutdown Handler
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        if data.isOpen then
            MySQL.prepare(
                'INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
                { inventory, json.encode(data.items), json.encode(data.items) }
            )
        end
    end
end)


-- Player Loaded Event
AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source

    -- Voeg inventaris functies toe aan de speler
    local methods = {
        AddItem = function(item, amount, slot, info, reason)
            return Inventory.AddItem(src, item, amount, slot, info, reason)
        end,
        RemoveItem = function(item, amount, slot, reason)
            return Inventory.RemoveItem(src, item, amount, slot, reason)
        end,
        GetItemBySlot = function(slot)
            return Inventory.GetItemBySlot(src, slot)
        end,
        GetItemByName = function(item)
            return Inventory.GetItemByName(src, item)
        end,
        GetItemsByName = function(item)
            return Inventory.GetItemsByName(src, item)
        end,
        ClearInventory = function(filterItems)
            Inventory.ClearInventory(src, filterItems)
        end,
        SetInventory = function(items)
            Inventory.SetInventory(src, items)
        end
    }

    for methodName, methodFunc in pairs(methods) do
        RSGCore.Functions.AddPlayerMethod(src, methodName, methodFunc)
    end
end)

-- Resource Start Event
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    local Players = RSGCore.Functions.GetRSGPlayers()
    for k in pairs(Players) do
        local methods = {
            AddItem = function(item, amount, slot, info)
                return Inventory.AddItem(k, item, amount, slot, info)
            end,
            RemoveItem = function(item, amount, slot)
                return Inventory.RemoveItem(k, item, amount, slot)
            end,
            GetItemBySlot = function(slot)
                return Inventory.GetItemBySlot(k, slot)
            end,
            GetItemByName = function(item)
                return Inventory.GetItemByName(k, item)
            end,
            GetItemsByName = function(item)
                return Inventory.GetItemsByName(k, item)
            end,
            ClearInventory = function(filterItems)
                Inventory.ClearInventory(k, filterItems)
            end,
            SetInventory = function(items)
                Inventory.SetInventory(k, items)
            end
        }

        for methodName, methodFunc in pairs(methods) do
            RSGCore.Functions.AddPlayerMethod(k, methodName, methodFunc)
        end

        -- Reset inventory busy state
        Player(k).state.inv_busy = false
    end
end)
