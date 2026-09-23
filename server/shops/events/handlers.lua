local config = require 'shared.config'

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

lib.cron.new(config.ShopsRestockCycle, function()
    for _, shopData in pairs(RegisteredShops) do
        for _, item in pairs(shopData.items) do
            if item.restock and item.amount and item.defaultstock then
                item.amount = math.min(item.defaultstock, item.amount + item.restock)
            end
        end
    end
end)
