local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'

--- Only network ids are sent to clients (not drop contents)
lib.callback.register('rsg-inventory:server:GetCurrentDrops', function()
    local list = {}
    for dropId, drop in pairs(Drops) do
        list[dropId] = drop.entityId
    end
    return list
end)

--- Builds a clean drop item from server-side item definitions
local function buildDropItem(name, amount, info)
    local itemInfo = RSGCore.Shared.Items[name:lower()]
    if not itemInfo then return end
    return {
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
        combinable = itemInfo.combinable,
    }
end

--- Spawns a bag and registers a drop containing itemData.
--- @param coords vector3
--- @param itemData table built by buildDropItem
--- @return number|false networkId
local function CreateItemDrop(coords, itemData)
    local bag = CreateObjectNoOffset(config.ItemDropObject, coords.x + 0.5, coords.y + 0.5, coords.z, true, true, false)

    local timeout = 100
    while not DoesEntityExist(bag) and timeout > 0 do
        Wait(50)
        timeout -= 1
    end
    if not DoesEntityExist(bag) then return false end

    local networkId = NetworkGetNetworkIdFromEntity(bag)
    local dropId = Helpers.CreateDropId(networkId)
    itemData.slot = 1

    Drops[dropId] = {
        name = dropId,
        label = locale('info.drop_label'),
        items = { [1] = itemData },
        entityId = networkId,
        createdTime = os.time(),
        coords = coords,
        maxweight = config.DropSize.maxweight,
        slots = config.DropSize.slots,
        isOpen = false,
    }

    TriggerClientEvent('rsg-inventory:client:setupDropTarget', -1, networkId)
    return networkId
end

--- Shared helper (used by ForceDropItem): accepts a pre-built server item table
Helpers.CreateItemDrop = function(coords, itemData)
    local clean = buildDropItem(itemData.name, itemData.amount, itemData.info)
    if not clean then return false end
    return CreateItemDrop(coords, clean)
end

local dropCooldowns = {}
AddEventHandler('playerDropped', function() dropCooldowns[source] = nil end)

--- Player drops an item from their inventory onto the ground
lib.callback.register('rsg-inventory:server:createDrop', function(source, data)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player or type(data) ~= 'table' then return false end

    local now = GetGameTimer()
    if dropCooldowns[source] and now - dropCooldowns[source] < 1000 then return false end
    dropCooldowns[source] = now

    local fromSlot, amount = tonumber(data.fromSlot), tonumber(data.amount)
    if not fromSlot or not amount or amount < 1 or amount ~= math.floor(amount) then return false end

    -- Real item from the server; client only chooses slot + amount
    local realItem = Inventory.GetItemBySlot(source, fromSlot)
    if not realItem or realItem.amount < amount then return false end

    local itemData = buildDropItem(realItem.name, amount, realItem.info)
    if not itemData then return false end

    local isWeapon = realItem.type == 'weapon'
    if isWeapon then Inventory.CheckWeapon(source, realItem.name) end

    -- Remove first so a failed spawn can be refunded instead of duplicating
    if not Inventory.RemoveItem(source, realItem.name, amount, fromSlot, 'dropped item', isWeapon) then return false end

    local networkId = CreateItemDrop(GetEntityCoords(GetPlayerPed(source)), itemData)
    if not networkId then
        Inventory.AddItem(source, itemData.name, amount, fromSlot, itemData.info, 'drop failed refund', true)
        return false
    end

    -- The new drop becomes the player's open secondary inventory in the UI
    local dropId = Helpers.CreateDropId(networkId)
    Drops[dropId].isOpen = source
    OpenedInventories[source] = dropId
    return networkId
end)
