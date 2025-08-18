
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    Shops.SaveItemsInStock()
end)

AddEventHandler('onResourceStop', function(resourceName) 
    if resourceName ~= GetCurrentResourceName() then return end
    
    Shops.SaveItemsInStock()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Shops.LoadItemsInStock()
end)

local config = require 'shared.config'
lib.cron.new(config.ShopsRestockCycle, function() 
    for name, shopData in pairs(RegisteredShops) do 
        for slot, item in pairs(shopData.items) do 
            if item.restock and item.amount then 
                item.amount = math.min(item.defaultstock, item.amount + item.restock)
            end
        end
    end
end)