Shops = Shops or {}

Shops.GetFirstFreeSlot = function(items, maxSlots)
    for i = 1, maxSlots do
        if items[i] == nil then
            return i
        end
    end
    return nil
end

Shops.SetupShopItems = function(shopItems, shopName)
    local items = {}
    local slot = 1
    if shopItems and next(shopItems) then
        for _, item in pairs(shopItems) do
            local itemInfo = RSGCore.Shared.Items[item.name:lower()]
            if itemInfo then
                local maxStock = nil
                if Config.ShopsStockEnabled then
                    maxStock = item.amount

                    if Config.ShopsStockPersistent then
                        if ShopsStockCache[shopName] and ShopsStockCache[shopName].items[itemInfo['name']] then
                            amount = tonumber(ShopsStockCache[shopName].items[itemInfo['name']].stock)
                        else 
                            amount = maxStock
                        end
                    else
                        amount = maxStock
                    end
                else
                    amount = nil
                end

                items[slot] = {
                    name = itemInfo['name'],
                    amount = amount,
                    info = item.info or {},
                    label = itemInfo['label'],
                    description = itemInfo['description'] or '',
                    weight = itemInfo['weight'],
                    type = itemInfo['type'],
                    unique = itemInfo['unique'],
                    useable = itemInfo['useable'],
                    price = item.price,
                    image = itemInfo['image'],
                    slot = slot,
                }

                if Config.ShopsEnableBuybackStockLimit then 
                    items[slot].maxStock = maxStock
                end

                slot = slot + 1
            end
        end
    end
    return items
end

Shops.SaveItemsInStock = function()
    local saveData = {}
    for shopName, shopData in pairs(RegisteredShops) do 
        for slot, item in pairs(shopData.items) do 
            saveData[#saveData + 1] = {
                shop_name = shopName,
                item_name = item.name,
                stock = item.amount,
            }
        end
    end

    if #saveData == 0 then return end

    local values = {}
    local placeholders = {}

    for _, item in ipairs(saveData) do
        table.insert(placeholders, "(?, ?, ?)")
        table.insert(values, item.shop_name)
        table.insert(values, item.item_name)
        table.insert(values, item.stock)
    end

    local query = [[
        REPLACE INTO shop_stock (shop_name, item_name, stock)
        VALUES ]] .. table.concat(placeholders, ", ")

    MySQL.query(query, values)
end

Shops.LoadItemsInStock = function()
    local query = "SELECT shop_name, item_name, stock FROM shop_stock"

    MySQL.query(query, {}, function(result)
        if not result or #result == 0 then return end

        for _, row in ipairs(result) do
            if not ShopsStockCache[row.shop_name] then
                ShopsStockCache[row.shop_name] = { items = {} }
            end

            ShopsStockCache[row.shop_name].items[row.item_name] = {
                name = row.item_name,
                stock = row.stock
            }
        end
    end)
end

Shops.ClearStockDb = function()
    local query = "TRUNCATE TABLE shop_stock"
    exports.oxmysql:execute(query)
end