local RSGCore = exports['rsg-core']:GetCoreObject()
Shops = Shops or {}

--- @param shopData table The data of the shop to create or update.
local function registerShop(shopName, data)
    local items = Shops.SetupShopItems(data.items, { name = shopName, persistentStock = data.persistentStock })
    local existing = RegisteredShops[shopName]
    if existing then
        existing.items = items
        existing.slots = #items
        if data.persistentStock ~= nil then existing.persistentStock = data.persistentStock end
        return
    end
    RegisteredShops[shopName] = {
        name = shopName,
        label = data.label,
        coords = data.coords,
        slots = #items,
        items = items,
        persistentStock = data.persistentStock,
    }
end

--- Creates or updates one shop ({ name = ..., items = ... }) or a table of shops.
--- @param shopData table
Shops.CreateShop = function(shopData)
    if shopData.name then
        return registerShop(shopData.name, shopData)
    end
    for key, data in pairs(shopData) do
        if type(data) == 'table' and data.items then
            registerShop(type(key) == 'number' and data.name or key, data)
        end
    end
end

exports('CreateShop', Shops.CreateShop)

--- @param source number The player's server ID.
--- @param name string The identifier of the inventory to open.
Shops.OpenShop = function(source, name)
    if not name then return end
    local player = RSGCore.Functions.GetPlayer(source)
    local shop = RegisteredShops[name]
    if not player or not shop then return end
    if shop.coords then
        local shopCoords = vector3(shop.coords.x, shop.coords.y, shop.coords.z)
        if #(GetEntityCoords(GetPlayerPed(source)) - shopCoords) > Inventory.MAX_DIST then return end
    end
    local formattedInventory = {
        name = 'shop-' .. shop.name,
        label = shop.label,
        maxweight = 5000000,
        slots = #shop.items,
        inventory = shop.items,
        persistentStock = shop.persistentStock,
    }

    Player(source).state.inv_busy = true
    OpenedInventories[source] = formattedInventory.name
    Inventory.CheckPlayerItemsDecay(player)
    TriggerClientEvent('rsg-inventory:client:openInventory', source, player.PlayerData.items, formattedInventory)
end

exports('OpenShop', Shops.OpenShop)

--- @param shopName string Name of the shop
--- @param percentage int Percentage of default amount to restock (for example 10% of default stock). Default 100
Shops.RestockShop = function(shopName, percentage)
    local shopData = RegisteredShops[shopName]
    if not shopData then return false end

    percentage = percentage or 100
    local mult = percentage / 100
    
    for _, item in pairs(shopData.items) do
        if item.amount and item.defaultstock then
            local restock = math.round(item.defaultstock * mult, 0)
            item.amount = math.min(item.defaultstock, item.amount + restock)
        end
    end
    return true
end

exports('RestockShop', Shops.RestockShop)

--- Check if a shop exists in the registry.
--- @param shopName string Name of the shop
--- @return boolean True if the shop exists, false otherwise
function Shops.DoesShopExist(shopName)
    if type(shopName) ~= "string" then return false end
    return RegisteredShops and RegisteredShops[shopName] ~= nil
end

exports('DoesShopExist', Shops.DoesShopExist)