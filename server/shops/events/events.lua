local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'

RegisterNetEvent('rsg-inventory:server:openVending', function(data)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local key = string.format("%s_%s_%s", data.coords.x, data.coords.y, data.coords.z)
    local shopName = 'vending-'..key 
    if not Shops.DoesShopExist(shopName) then
        Shops.CreateShop({
            name = shopName,
            label = locale('info.vending'),
            coords = data.coords,
            slots = #config.VendingItems,
            items = config.VendingItems
        })
    end
    Shops.OpenShop(src, shopName)
end)