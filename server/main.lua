-- globals
math = lib.math

Inventories = {}
Drops = {}
RegisteredShops = {}
ShopsStockCache = {}
OpenedInventories = {} -- [source] = identifier of the secondary inventory the player currently has open

local config = require 'shared.config'

--- Re-keys an items table by numeric slot (JSON round-trips turn sparse slot keys into strings)
--- @param items table
--- @return table
function NormalizeItems(items)
    local normalized = {}
    if type(items) ~= 'table' then return normalized end
    for key, item in pairs(items) do
        if type(item) == 'table' then
            local slot = tonumber(item.slot) or tonumber(key)
            if slot then
                item.slot = slot
                item.info = type(item.info) == 'table' and item.info or {}
                normalized[slot] = item
            end
        end
    end
    return normalized
end

CreateThread(function()
    local result = MySQL.query.await('SELECT identifier, items FROM inventories')
    if not result then return end

    for i = 1, #result do
        local row = result[i]
        local items = NormalizeItems(json.decode(row.items or '[]'))
        local inventory = Inventories[row.identifier]
        if inventory then
            inventory.items = items
        else
            Inventories[row.identifier] = { items = items, isOpen = false }
        end
    end

    print(('%s inventories successfully loaded'):format(#result))
end)

-- Cleanup expired drops
CreateThread(function()
    while true do
        Wait(config.CleanupDropInterval * 60000)
        local now = os.time()
        for dropId, drop in pairs(Drops) do
            if not drop.isOpen and drop.createdTime + (config.CleanupDropTime * 60) < now then
                local entity = NetworkGetEntityFromNetworkId(drop.entityId)
                if DoesEntityExist(entity) then DeleteEntity(entity) end
                TriggerClientEvent('rsg-inventory:client:removeDropTarget', -1, drop.entityId)
                Drops[dropId] = nil
            end
        end
    end
end)
