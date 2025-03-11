RegisterNetEvent('rsg-inventory:server:openVending', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Inventory.Shops({
        name = 'vending',
        label = 'Vending Machine',
        coords = data.coords,
        slots = #Config.VendingItems,
        items = Config.VendingItems
    })
    Shops.OpenShop(src, 'vending')
end)