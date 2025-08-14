-- server/inventory_shops.lua

RegisteredShops = RegisteredShops or {}
Shops = Shops or {}

local function cloneItems(list)
    local out = {}
    for i = 1, #list do
        out[i] = table.clone and table.clone(list[i]) or { table.unpack(list[i]) }
    end
    return out
end

--- @param shopData table The data of the shop to create or update.
Shops.CreateShop = function(shopData)
    if not shopData then return end
    local overwrite = shopData.overwrite or shopData.replace or false

    if shopData.name then
        if RegisteredShops[shopData.name] and not overwrite then
            return
        end

        RegisteredShops[shopData.name] = {
            name = shopData.name,
            label = shopData.label,
            coords = shopData.coords,
            slots = #(shopData.items or {}),
            items = Shops.SetupShopItems(cloneItems(shopData.items or {}), shopData),
            persistentStock = shopData.persistentStock,
        }
        return
    end

    for key, data in pairs(shopData) do
        if type(data) == 'table' then
            if data.name then
                local shopName = type(key) == 'number' and data.name or key
                if RegisteredShops[shopName] and not (data.overwrite or data.replace) then
                    goto continue
                end
                RegisteredShops[shopName] = {
                    name = shopName,
                    label = data.label,
                    coords = data.coords,
                    slots = #(data.items or {}),
                    items = Shops.SetupShopItems(cloneItems(data.items or {}), data),
                    persistentStock = data.persistentStock,
                }
            else
                Shops.CreateShop(data)
            end
        end
        ::continue::
    end
end
exports('CreateShop', Shops.CreateShop)

--- @param shopName string Name of the shop
--- @param items table New items list
--- @param opts table Optional settings to update
Shops.UpdateShop = function(shopName, items, opts)
    local shop = RegisteredShops[shopName]
    if not shop then return false end
    shop.items = Shops.SetupShopItems(cloneItems(items or {}), { name = shopName })
    shop.slots = #(shop.items or {})
    if opts then
        if opts.label ~= nil then shop.label = opts.label end
        if opts.coords ~= nil then shop.coords = opts.coords end
        if opts.persistentStock ~= nil then shop.persistentStock = opts.persistentStock end
    end
    return true
end
exports('UpdateShop', Shops.UpdateShop)

--- @param source number The player's server ID.
--- @param name string The identifier of the inventory to open.
Shops.OpenShop = function(source, name)
    if not name then return end
    local player = RSGCore.Functions.GetPlayer(source)
    if not player then return end
    if not RegisteredShops[name] then return end
    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if RegisteredShops[name].coords then
        local shopDistance = vector3(
            RegisteredShops[name].coords.x,
            RegisteredShops[name].coords.y,
            RegisteredShops[name].coords.z
        )
        if shopDistance then
            local distance = #(playerCoords - shopDistance)
            if distance > 5.0 then return end
        end
    end
    local formattedInventory = {
        name = 'shop-' .. RegisteredShops[name].name,
        label = RegisteredShops[name].label,
        maxweight = 5000000,
        slots = #RegisteredShops[name].items,
        inventory = RegisteredShops[name].items,
        persistentStock = RegisteredShops[name].persistentStock,
    }

    Player(source).state.inv_busy = true
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
    
    for slot, item in pairs(shopData.items) do 
        if item.amount then 
            local restock = math.round(item.defaultstock * mult, 0)
            item.amount = math.min(item.defaultstock, item.amount + restock)
        end
    end
end
exports('RestockShop', Shops.RestockShop)