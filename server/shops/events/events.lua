local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'

RegisterNetEvent('rsg-inventory:server:openVending', function(data)
    local src = source
    if not RSGCore.Functions.GetPlayer(src) then return end
    local coords = type(data) == 'table' and data.coords
    if type(coords) ~= 'vector3' then return end

    -- Must be standing at the machine
    if #(GetEntityCoords(GetPlayerPed(src)) - coords) > 3.0 then return end

    -- Round so the same machine always maps to the same shop (prevents unbounded shop creation)
    local key = ('%.0f_%.0f_%.0f'):format(coords.x, coords.y, coords.z)
    local shopName = 'vending-' .. key
    if not Shops.DoesShopExist(shopName) then
        Shops.CreateShop({
            name = shopName,
            label = locale('info.vending'),
            coords = coords,
            items = config.VendingItems,
        })
    end
    Shops.OpenShop(src, shopName)
end)
