Inventory = Inventory or {}

Inventory.InitializeInventory = function(inventoryId, data)
    Inventories[inventoryId] = {
        items = {},
        isOpen = false,
        label = data and data.label or inventoryId,
        maxweight = data and data.maxweight or Config.StashSize.maxweight,
        slots = data and data.slots or Config.StashSize.slots
    }
    return Inventories[inventoryId]
end

Inventory.GetItem = function(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = RSGCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = RSGCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

Inventory.GetIdentifier = function(inventoryId, src)
    if inventoryId == 'player' then
        return src
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)'))
    else
        return inventoryId
    end
end

Inventory.CheckWeapon = function(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = RSGCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('rsg-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end