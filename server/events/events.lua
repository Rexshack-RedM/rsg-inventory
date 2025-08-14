RegisterNetEvent('rsg-inventory:server:closeInventory', function(inventory)
    local src = source
    local RSGPlayer = RSGCore.Functions.GetPlayer(src)
    if not RSGPlayer then return end
    Player(source).state.inv_busy = false
    if inventory:find('shop-') then return end
    if inventory:find('otherplayer-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        Player(targetId).state.inv_busy = false
        return
    end
    if Drops[inventory] then
        Drops[inventory].isOpen = false
        if #Drops[inventory].items == 0 and not Drops[inventory].isOpen then 
            TriggerClientEvent('rsg-inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
            Wait(500)
            local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            Drops[inventory] = nil
        end
        return
    end
    if not Inventories[inventory] then return end
    Inventories[inventory].isOpen = false
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { inventory, json.encode(Inventories[inventory].items), json.encode(Inventories[inventory].items) })
end)

RegisterNetEvent('rsg-inventory:server:useItem', function(item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local itemData = Inventory.GetItemBySlot(src, item.slot)
    if not itemData then return end
    local itemInfo = RSGCore.Shared.Items[itemData.name]
    if itemData.type == 'weapon' then
        local result = MySQL.Sync.fetchAll('SELECT * FROM player_weapons WHERE serial = @serial and citizenid = @citizenid',{ serial = itemData.info.serie, citizenid = Player.PlayerData.citizenid })
        if result[1] == nil then
            local params = { serial = itemData.info.serie, citizenid = Player.PlayerData.citizenid }
            MySQL.Sync.execute("INSERT INTO player_weapons (serial, citizenid) values (@serial, @citizenid)", params)
            Wait(1000)
            TriggerClientEvent('rsg-weapons:client:UseWeapon', src, itemData)
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')
        else
            TriggerClientEvent('rsg-weapons:client:UseWeapon', src, itemData)
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')
        end
    elseif itemData.type == 'weapon_thrown' then
        TriggerClientEvent('rsg-weapons:client:UseThrownWeapon', src, itemData)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')
    elseif itemData.type == 'equipment' then
        TriggerClientEvent('rsg-weapons:client:UseEquipment', src, itemData)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')
    else
        Inventory.UseItem(itemData.name, src, itemData)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

RegisterNetEvent('rsg-inventory:server:updateHotbar', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local items = {}
    for slot = 1, 5 do
        local item = Player.Functions.GetItemBySlot(slot)
        items[slot] = item
    end
    
    TriggerClientEvent('rsg-inventory:client:updateHotbar', src, items)
end)

RegisterNetEvent('rsg-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    if toInventory:find('shop-') then return end
    if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount then return end
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local isMove = false
    fromSlot, toSlot, fromAmount, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(fromAmount), tonumber(toAmount)

    local fromItem = Inventory.GetItem(fromInventory, src, fromSlot)
    local toItem = Inventory.GetItem(toInventory, src, toSlot)

    if fromItem then
        if not toItem and toAmount > fromItem.amount then return end
        if fromInventory == 'player' and toInventory ~= 'player' then 
            isMove = true
            Inventory.CheckWeapon(src, fromItem) 
        end

        local fromId = Inventory.GetIdentifier(fromInventory, src)
        local toId = Inventory.GetIdentifier(toInventory, src)

        if fromId ~= toId then isMove = true end

        if toItem and fromItem.name == toItem.name and fromItem.info.quality == toItem.info.quality then
            if toId ~= fromId then
                if Inventory.AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'item empilhado') then
                    Inventory.RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'item empilhado', isMove)
                end
            else
                if Inventory.RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'item empilhado', isMove) then
                    Inventory.AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'item empilhado')
                end
            end
        elseif not toItem and toAmount < fromAmount then
            if fromId ~= toId then
                if Inventory.AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item') then
                    Inventory.RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item', isMove)
                end
            else
                if Inventory.RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item', isMove) then
                    Inventory.AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item')
                end
            end
        else
            if toItem then
                local fromItemAmount = fromItem.amount
                local toItemAmount = toItem.amount

                if toId ~= fromId then
                    local addSuccessFrom = false
                    local addSuccessTo = false
                    
                    if Inventory.CanAddItem(toId, fromItem.name, fromItemAmount) then
                        addSuccessFrom = true
                    end

                    if Inventory.CanAddItem(fromId, toItem.name, toItemAmount) then
                        addSuccessTo = true
                    end
                    
                    if not addSuccessFrom or not addSuccessTo then
                        Inventory.CloseInventory(src, toId)
                    end

                    if addSuccessFrom and addSuccessTo then
                        if Inventory.RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item', isMove) and Inventory.RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item', isMove) then
                            Inventory.AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item')
                            Inventory.AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item')
                        end
                    end
                else
                    if Inventory.RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item', isMove) and Inventory.RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item', isMove) then
                        Inventory.AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item')
                        Inventory.AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item')
                    end
                end
            else
                if toId ~= fromId then
                    local fromItemAmount = fromItem.amount
                    local addSuccessFrom = false
                    
                    if Inventory.CanAddItem(toId, fromItem.name, fromItemAmount) then
                        addSuccessFrom = true
                    end

                    if not addSuccessFrom then
                        Inventory.CloseInventory(src, toId)
                    end

                    if addSuccessFrom then
                        if Inventory.RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'moved item', isMove) then
                            Inventory.AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item')
                        end
                    end
                else
                    if Inventory.RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'moved item', isMove) then
                        Inventory.AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item')
                    end
                end
            end
        end
    end
end)