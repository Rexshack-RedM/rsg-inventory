RegisterNetEvent('rsg-inventory:server:openVending', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local key = string.format("%s_%s_%s", data.coords.x, data.coords.y, data.coords.z)
    Inventory.CreateShop({
        name = 'vending-'..key,
        label = 'Vending Machine',
        coords = data.coords,
        slots = #Config.VendingItems,
        items = Config.VendingItems
    })
    Shops.OpenShop(src, 'vending-'..key)
end)