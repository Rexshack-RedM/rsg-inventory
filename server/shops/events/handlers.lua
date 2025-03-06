AddEventHandler('txAdmin:events:serverShuttingDown', function()
    if Config.ShopsStockEnabled and Config.ShopsStockPersistent then
        Shops.SaveItemsInStock()
    end
end)

AddEventHandler('onResourceStop', function(resourceName) 
    if resourceName ~= GetCurrentResourceName() then return end
    
    if Config.ShopsStockEnabled and Config.ShopsStockPersistent then
        Shops.SaveItemsInStock()
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if Config.ShopsStockEnabled and Config.ShopsStockPersistent then
        Shops.LoadItemsInStock()
    else
        Shops.ClearStockDb()
    end
end)