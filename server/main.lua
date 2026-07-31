
-- globals
math = lib.math
--
Inventories = {}
Drops = {}
RegisteredShops = {}
ShopsStockCache = {}

CreateThread(function()
    MySQL.query('SELECT * FROM inventories', {}, function(result)
        if not result or #result <= 0 then
            return
        end

        for i = 1, #result do
            local storedInventory = result[i]

            local identifier = storedInventory.identifier
            local items = json.decode(storedInventory.items) or {}

            local inventory = Inventories[identifier]
            if not inventory then
                Inventories[identifier] = {
                    items = items,
                    isOpen = false
                }
            else
                inventory.items = items
            end
        end

        print(#result .. ' inventories successfully loaded')
    end)
end)

local config = require 'shared.config'
CreateThread(function()
    while true do
        for k, v in pairs(Drops) do
            if v and (v.createdTime + (config.CleanupDropTime * 60) < os.time()) and not Drops[k].isOpen then
                local entity = NetworkGetEntityFromNetworkId(v.entityId)
                if DoesEntityExist(entity) then DeleteEntity(entity) end
                Drops[k] = nil
            end
        end
        Wait(config.CleanupDropInterval * 60000)
    end
end)