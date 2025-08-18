local RSGCore = exports['rsg-core']:GetCoreObject()
--- @param items string|table - The item(s) to check for. Can be a table of items or a single item as a string.
--- @param amount number [optional] - The minimum amount required for each item. If not provided, any amount greater than 0 will be considered.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
function HasItem(items, amount)
    local function isArray(t)
        if type(t) ~= 'table' then return false end
        if table.type then return table.type(t) == 'array' end
        local n = 0
        for k in pairs(t) do
            if type(k) ~= 'number' then return false end
            if k > n then n = k end
        end
        return n == #t
    end

    local playerData = RSGCore.Functions.GetPlayerData()
    local inv = playerData and playerData.items
    if not inv then return false end

    local itemsType = type(items)

    if itemsType ~= 'table' then
        for _, item in pairs(inv) do
            if item and item.name == items and (amount == nil or item.amount >= amount) then
                return true
            end
        end
        return false
    end


    local maxByName = {}
    for _, item in pairs(inv) do
        if item and item.name then
            local amt = item.amount or 0
            if not maxByName[item.name] or amt > maxByName[item.name] then
                maxByName[item.name] = amt
            end
        end
    end

    if isArray(items) then
        for _, name in ipairs(items) do
            local have = maxByName[name]
            if have == nil or (amount ~= nil and have < amount) then
                return false
            end
        end
        return true
    else
        for name, reqAmount in pairs(items) do
            local have = maxByName[name]
            if have == nil or (reqAmount ~= nil and have < reqAmount) then
                return false
            end
        end
        return true
    end
end

exports('HasItem', HasItem)