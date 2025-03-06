AddEventHandler('playerDropped', function()
    for _, inv in pairs(Inventories) do
        if inv.isOpen == source then
            inv.isOpen = false
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        if data.isOpen then
            MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { inventory, json.encode(data.items), json.encode(data.items) })
        end
    end
end)

RegisterNetEvent('RSGCore:Server:UpdateObject', function()
    if source ~= '' then return end
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    RSGCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'AddItem', function(item, amount, slot, info, reason)
        return Inventory.AddItem(Player.PlayerData.source, item, amount, slot, info, reason)
    end)

    RSGCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'RemoveItem', function(item, amount, slot, reason)
        return Inventory.RemoveItem(Player.PlayerData.source, item, amount, slot, reason)
    end)

    RSGCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemBySlot', function(slot)
        return Inventory.GetItemBySlot(Player.PlayerData.source, slot)
    end)

    RSGCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemByName', function(item)
        return Inventory.GetItemByName(Player.PlayerData.source, item)
    end)

    RSGCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemsByName', function(item)
        return Inventory.GetItemsByName(Player.PlayerData.source, item)
    end)

    RSGCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'ClearInventory', function(filterItems)
        Inventory.ClearInventory(Player.PlayerData.source, filterItems)
    end)

    RSGCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'SetInventory', function(items)
        Inventory.SetInventory(Player.PlayerData.source, items)
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local Players = RSGCore.Functions.GetRSGPlayers()
    for k in pairs(Players) do
        RSGCore.Functions.AddPlayerMethod(k, 'AddItem', function(item, amount, slot, info)
            return Inventory.AddItem(k, item, amount, slot, info)
        end)

        RSGCore.Functions.AddPlayerMethod(k, 'RemoveItem', function(item, amount, slot)
            return Inventory.RemoveItem(k, item, amount, slot)
        end)

        RSGCore.Functions.AddPlayerMethod(k, 'GetItemBySlot', function(slot)
            return Inventory.GetItemBySlot(k, slot)
        end)

        RSGCore.Functions.AddPlayerMethod(k, 'GetItemByName', function(item)
            return Inventory.GetItemByName(k, item)
        end)

        RSGCore.Functions.AddPlayerMethod(k, 'GetItemsByName', function(item)
            return Inventory.GetItemsByName(k, item)
        end)

        RSGCore.Functions.AddPlayerMethod(k, 'ClearInventory', function(filterItems)
            Inventory.ClearInventory(k, filterItems)
        end)

        RSGCore.Functions.AddPlayerMethod(k, 'SetInventory', function(items)
            Inventory.SetInventory(k, items)
        end)

        Player(k).state.inv_busy = false
    end
end)