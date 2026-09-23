local RSGCore = exports['rsg-core']:GetCoreObject()

--- Attaches inventory helper methods to an RSGCore player object
local function registerPlayerMethods(src)
    local methods = {
        AddItem        = function(item, amount, slot, info, reason) return Inventory.AddItem(src, item, amount, slot, info, reason) end,
        RemoveItem     = function(item, amount, slot, reason) return Inventory.RemoveItem(src, item, amount, slot, reason) end,
        GetItemBySlot  = function(slot) return Inventory.GetItemBySlot(src, slot) end,
        GetItemByName  = function(item) return Inventory.GetItemByName(src, item) end,
        GetItemsByName = function(item) return Inventory.GetItemsByName(src, item) end,
        ClearInventory = function(filterItems) Inventory.ClearInventory(src, filterItems) end,
        SetInventory   = function(items) Inventory.SetInventory(src, items) end,
    }
    for methodName, methodFunc in pairs(methods) do
        RSGCore.Functions.AddPlayerMethod(src, methodName, methodFunc)
    end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    registerPlayerMethods(Player.PlayerData.source)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for src in pairs(RSGCore.Functions.GetRSGPlayers()) do
        registerPlayerMethods(src)
        Player(src).state.inv_busy = false
    end
end)

-- Persist every loaded stash on shutdown / resource stop
local function saveAllStashes()
    for identifier, inv in pairs(Inventories) do
        Inventory.PersistStash(identifier, inv)
    end
end

AddEventHandler('txAdmin:events:serverShuttingDown', saveAllStashes)
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then saveAllStashes() end
end)
