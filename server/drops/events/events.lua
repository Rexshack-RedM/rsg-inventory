
RegisterNetEvent('rsg-inventory:server:openDrop', function(dropId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    local drop = Drops[dropId]

    if not drop or drop.isOpen then return end
    if #(playerCoords - drop.coords) > 2.5 then return end

    Inventory.CheckItemsDecay(drop.items)

    local formattedInventory = {
        name      = dropId,
        label     = dropId,
        maxweight = drop.maxweight,
        slots     = drop.slots,
        inventory = drop.items
    }

    drop.isOpen = true
    TriggerClientEvent('rsg-inventory:client:openInventory', src, Player.PlayerData.items, formattedInventory)
end)

RegisterNetEvent('rsg-inventory:server:updateDrop', function(dropId, coords)
    local drop = Drops[dropId]
    if not drop then return end
    drop.coords = coords
end)