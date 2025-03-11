--- Checks if the player has a certain item or items in their inventory with a specified amount.
--- @param items string|table - The item(s) to check for. Can be a table of items or a single item as a string.
--- @param amount number [optional] - The minimum amount required for each item. If not provided, any amount greater than 0 will be considered.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
function HasItem(items, amount)
    local isTable = type(items) == "table"
    local isArray = isTable and table.type(items) == "array"
    local requiredItems = isArray and #items or (isTable and table.count(items) or 1)
    local foundItems = 0

    playerData = RSGCore.Functions.GetPlayerData()

    for _, item in pairs(playerData.items) do
        if not item then goto continue end

        if isTable then
            for key, value in pairs(items) do
                local itemName = isArray and value or key
                local requiredAmount = isArray and amount or value

                if item.name == itemName and (not requiredAmount or item.amount >= requiredAmount) then
                    foundItems = foundItems + 1
                    if foundItems == requiredItems then return true end
                end
            end
        elseif item.name == items and (not amount or item.amount >= amount) then
            return true
        end

        ::continue::
    end

    return false
end
exports('HasItem', HasItem)