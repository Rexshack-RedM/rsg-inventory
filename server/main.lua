
-- globals
math = lib.math
--
Inventories = {}
Drops = {}
RegisteredShops = {}
ShopsStockCache = {}

CreateThread(function()
    MySQL.query('SELECT * FROM inventories', {}, function(result)
        if result and #result > 0 then
            for i = 1, #result do
                local inventory = result[i]
                local cacheKey = inventory.identifier
                Inventories[cacheKey] = {
                    items = json.decode(inventory.items) or {},
                    isOpen = false
                }
            end
            print(#result .. ' inventories successfully loaded')
        end
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