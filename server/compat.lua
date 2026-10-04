local RSGCore = exports['rsg-core']:GetCoreObject()

-- Legacy rsg-inventory exports and player methods, so existing RSG scripts keep working.
-- All of these are thin wrappers over the API in server/main.lua.

local API = InvCore.API

local function GetItemsByName(target, name)
    local c = InvCore.GetContainer(target)
    local out = {}
    if not c or not name then return out end
    name = tostring(name):lower()
    for _, it in pairs(c.items) do
        if it.name == name then out[#out + 1] = it end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end

local function GetSlots(target)
    local c = InvCore.GetContainer(target)
    if not c then return 0, 0 end
    local used = 0
    for _ in pairs(c.items) do used = used + 1 end
    return used, c.slots - used
end

local function GetFreeWeight(target)
    local c = InvCore.GetContainer(target)
    return c and (c.maxWeight - InvCore.TotalWeight(c.items)) or 0
end

local function SetInventory(src, items)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.SetPlayerData('items', items or {})
    InvCore.Refresh(src)
end

local function SetItemData(src, itemName, key, val)
    local c = InvCore.GetContainer(src)
    if not c or not itemName or not key then return false end
    itemName = tostring(itemName):lower()
    local item
    for _, it in pairs(c.items) do
        if it.name == itemName and (not item or it.slot < item.slot) then item = it end
    end
    if not item then return false end
    item[key] = val
    InvCore.Commit(c)
    InvCore.Refresh(src)
    return true
end

local function GetItemWeight(name)
    local s = InvCore.SharedItem(name)
    return s and s.weight or nil
end

local function CreateInventory(id, data)
    data = data or {}
    API.RegisterStash(id, { label = data.label, slots = data.slots, maxWeight = data.maxweight or data.maxWeight })
end

local function DeleteInventory(id)
    local inv = InvCore.Inventories[id]
    if not inv or inv.type ~= 'stash' then return false end
    API.SaveStash(id)
    InvCore.Inventories[id] = nil
    return true
end

local function ClearStash(id)
    local c = InvCore.GetContainer(id)
    if c and c.type == 'stash' then API.ClearInventory(id) end
end

local function ForceDropItem(src, item, amount, info, reason)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    local id = API.CreateDrop(GetEntityCoords(ped), {})
    if not InvCore.AddTo(InvCore.Inventories[id], item, amount, info) then
        InvCore.RemoveDrop(id)
        return false
    end
    InvCore.Log('ForceDrop', ('%sx %s dropped for %s (%s)'):format(amount or 1, item, GetPlayerName(src), reason or 'unknown'))
    return true
end

exports('CanAddItem', API.CanCarry)
exports('OpenInventoryById', API.OpenPlayerInventory)
exports('GetItemsByName', GetItemsByName)
exports('GetSlots', GetSlots)
exports('GetFreeWeight', GetFreeWeight)
exports('SetInventory', SetInventory)
exports('SetItemData', SetItemData)
exports('GetItemWeight', GetItemWeight)
exports('CreateInventory', CreateInventory)
exports('DeleteInventory', DeleteInventory)
exports('ClearStash', ClearStash)
exports('ForceDropItem', ForceDropItem)

-- the main API (AddItem, RemoveItem, HasItem, OpenInventory, ...)
for name, fn in pairs(API) do exports(name, fn) end

--------------------------------------------------------------------------------
-- Player.Functions.AddItem / RemoveItem / ... (used by rsg-core money items and most scripts)
--------------------------------------------------------------------------------
local function RegisterPlayerMethods(src)
    local methods = {
        AddItem        = function(item, amount, slot, info, reason) return API.AddItem(src, item, amount, slot, info, reason) end,
        RemoveItem     = function(item, amount, slot, reason) return API.RemoveItem(src, item, amount, slot, reason) end,
        GetItemBySlot  = function(slot) return API.GetItemBySlot(src, slot) end,
        GetItemByName  = function(item) return API.GetItemByName(src, item) end,
        GetItemsByName = function(item) return GetItemsByName(src, item) end,
        ClearInventory = function(keep) return API.ClearInventory(src, keep) end,
        SetInventory   = function(items) return SetInventory(src, items) end,
    }
    for name, fn in pairs(methods) do
        RSGCore.Functions.AddPlayerMethod(src, name, fn)
    end
end

AddEventHandler('RSGCore:Server:PlayerLoaded', function(Player)
    RegisterPlayerMethods(Player.PlayerData.source)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(RSGCore.Functions.GetRSGPlayers()) do
        RegisterPlayerMethods(src)
    end
end)
