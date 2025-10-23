--[[ 
    Server Event: Close a player's inventory
    Handles regular inventories, other player inventories, shops, and dropped items.
--]]
local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterNetEvent('rsg-inventory:server:closeInventory', function(inventory)
    local src = source
    local RSGPlayer = RSGCore.Functions.GetPlayer(src)
    if not RSGPlayer then return end

    -- Mark player's inventory as no longer busy
    Player(src).state.inv_busy = false

    -- Do nothing if it's a shop inventory
    if inventory:find('shop-') then return end

    -- Handle other player's inventory
    if inventory:find('otherplayer-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        Player(targetId).state.inv_busy = false
        return
    end

    -- Handle dropped item inventories
    if Drops[inventory] then
        Drops[inventory].isOpen = false
        if next(Drops[inventory].items) == nil and not Drops[inventory].isOpen then 
            TriggerClientEvent('rsg-inventory:client:removeDropTarget', -1, Drops[inventory].entityId)
            Wait(500)
            local entity = NetworkGetEntityFromNetworkId(Drops[inventory].entityId)
            if DoesEntityExist(entity) then DeleteEntity(entity) end
            Drops[inventory] = nil
        end
        return
    end

    -- Handle persistent inventories (like storage)
    if not Inventories[inventory] then return end
    Inventories[inventory].isOpen = false
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', 
        { inventory, json.encode(Inventories[inventory].items), json.encode(Inventories[inventory].items) })
end)


--[[ 
    Server Event: Use an item from player's inventory
    Handles weapons, throwable weapons, equipment, and regular items
--]]
RegisterNetEvent('rsg-inventory:server:useItem', function(item)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local itemData = Inventory.GetItemBySlot(src, item.slot)
    if not itemData then return end
    local itemInfo = RSGCore.Shared.Items[itemData.name]
    local allowedDuringMelee = {
        weapon = true,
        weapon_thrown = true,
        -- equipment = true  you can add more 
    }

    local inMelee = lib.callback.await('rsg-inventory:client:isInMelee', src)
    if inMelee and not allowedDuringMelee[itemData.type] then
        TriggerClientEvent('lib:notify', src, {
            title = 'Inventory',
            description = locale('error.error'),
            type = 'error'
        })
        return
    end
    if itemData.type == 'weapon' then
        local result = MySQL.Sync.fetchAll(
            'SELECT * FROM player_weapons WHERE serial = @serial and citizenid = @citizenid',
            { serial = itemData.info.serie, citizenid = Player.PlayerData.citizenid }
        )
        if not result[1] then
            MySQL.Sync.execute(
                'INSERT INTO player_weapons (serial, citizenid) VALUES (@serial, @citizenid)',
                { serial = itemData.info.serie, citizenid = Player.PlayerData.citizenid }
            )
            Wait(1000)
        end
        TriggerClientEvent('rsg-weapons:client:UseWeapon', src, itemData)
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemInfo, 'use')

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


--[[ 
    Server Event: Update player's hotbar
    Sends the first 5 inventory slots to the client for UI update
--]]
RegisterNetEvent('rsg-inventory:server:updateHotbar', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local items = {}
    for slot = 1, 5 do
        items[slot] = Player.Functions.GetItemBySlot(slot)
    end

    TriggerClientEvent('rsg-inventory:client:updateHotbar', src, items)
end)


--[[ 
    Server Event: Move or swap items between inventories
    Handles stacking, splitting, moving, and swapping items between inventories
--]]
RegisterNetEvent('rsg-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    -- Prevent moving items to shops
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
        -- Prevent stacking more than available
        if not toItem and toAmount > fromItem.amount then return end

        -- Special handling when moving weapons out of player's inventory
        if fromInventory == 'player' and toInventory ~= 'player' then 
            isMove = true
            Inventory.CheckWeapon(src, fromItem) 
        end

        local fromId, fromType = Inventory.GetIdentifier(fromInventory, src)
        local toId, toType = Inventory.GetIdentifier(toInventory, src)
        if fromId ~= toId then isMove = true end

        -- Prevent interaction of source player with inventories on long distance (except admin)
        if not RSGCore.Functions.HasPermission(src, 'admin') then
            local srcCoords = GetEntityCoords(GetPlayerPed(src))
            local maxDist = Inventory.MAX_DIST
            local isInventoryTooFar = function(inventoryCoords)
                return inventoryCoords and #(srcCoords - inventoryCoords) > maxDist
            end
            
            local fromTooFar = isInventoryTooFar(Inventory.GetCoords(fromInventory, src))
            local toTooFar = isInventoryTooFar(Inventory.GetCoords(toInventory, src))
            
            if fromTooFar or toTooFar then
                Inventory.CloseInventory(src, fromId)
                Inventory.CloseInventory(src, toId)
                local message = fromTooFar and locale('error.source_inv_too_far') or locale('error.target_inv_too_far')
                TriggerClientEvent('ox_lib:notify', src, {
                    title = message,
                    type = 'error',
                    duration = 5000
                })
                return
            end
        end

        -- Stack items if same type & quality
        if toItem and fromItem.name == toItem.name and fromItem.info.quality == toItem.info.quality then
            if toId ~= fromId then
                if Inventory.AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item') then
                    Inventory.RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item', isMove)
                end
            else
                if Inventory.RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item', isMove) then
                    Inventory.AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item')
                end
            end

        -- Split items if moving part of the stack
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

        -- Swap items between slots
        else
            if toItem then
                local fromItemAmount = fromItem.amount
                local toItemAmount = toItem.amount

                if toId ~= fromId then
                    local addSuccessFrom = Inventory.CanAddItem(toId, fromItem.name, fromItemAmount)
                    local addSuccessTo = Inventory.CanAddItem(fromId, toItem.name, toItemAmount)

                    if not addSuccessFrom or not addSuccessTo then
                        Inventory.CloseInventory(src, toId)
                    end

                    if addSuccessFrom and addSuccessTo then
                        if Inventory.RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item', isMove) and
                           Inventory.RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item', isMove) then
                            Inventory.AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item')
                            Inventory.AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item')
                        end
                    end
                else
                    if Inventory.RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item', isMove) and
                       Inventory.RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item', isMove) then
                        Inventory.AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item')
                        Inventory.AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item')
                    end
                end

            -- Move items to empty slots
            else
                if toId ~= fromId then
                    local fromItemAmount = fromItem.amount
                    if not Inventory.CanAddItem(toId, fromItem.name, fromItemAmount) then
                        Inventory.CloseInventory(src, toId)
                    else
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
RegisterNetEvent('rsg-inventory:server:openPlayerInventory', function(targetId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Target = RSGCore.Functions.GetPlayer(targetId)

    if not Player or not Target then return end

    -- Security checks
    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(srcCoords - targetCoords)

    -- Check if target is close enough (max 3.0 units)
    if distance > 3.0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = locale('error.player_too_far'),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Check if target player is unconscious/dead (required for looting)
    local targetMeta = Target.PlayerData.metadata
    if not targetMeta.isdead and not targetMeta.ishandcuffed then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = locale('error.target_needs_restrained'),
            type = 'error',
            duration = 5000
        })
        return
    end

    -- Additional permission check for law enforcement
    local hasPermission = RSGCore.Functions.HasPermission(src, 'police') or
                         Player.PlayerData.job.name == 'police' or
                         Player.PlayerData.job.name == 'marshal'

    if not hasPermission and not targetMeta.isdead then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Insufficient permissions',
            type = 'error',
            duration = 5000
        })
        return
    end

    Inventory.OpenInventoryById(src, targetId)
end)

RegisterNetEvent('rsg-inventory:server:openStash', function(stashId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then return end

    -- Basic validation
    if not stashId or type(stashId) ~= 'string' then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = locale('error.invalid_stash_identifier'),
            type = 'error',
            duration = 5000
        })
    end

    -- Prevent access to restricted stashes (add your patterns here)
    local restrictedPatterns = {
        '^police%-',      -- Police stashes
        '^marshal%-',     -- Marshal stashes
        '^gang%-',        -- Gang stashes (unless player is in that gang)
        '^admin%-',       -- Admin stashes
        '^evidence%-'     -- Evidence stashes
    }

    local isRestricted = false
    local stashType = nil

    for _, pattern in ipairs(restrictedPatterns) do
        if stashId:match(pattern) then
            isRestricted = true
            stashType = pattern:gsub('[%-^]', ''):gsub('%-', '')
            break
        end
    end

    if isRestricted then
        local hasAccess = false

        -- Check specific permissions based on stash type
        if stashType == 'police' or stashType == 'marshal' then
            hasAccess = RSGCore.Functions.HasPermission(src, 'police') or
                       Player.PlayerData.job.name == 'police' or
                       Player.PlayerData.job.name == 'marshal'
        elseif stashType == 'gang' then
            -- Extract gang name from stash ID (e.g., 'gang-lemoyne-stash' -> 'lemoyne')
            local gangName = stashId:match('gang%-(.+)%-')
            hasAccess = Player.PlayerData.gang and Player.PlayerData.gang.name == gangName
        elseif stashType == 'admin' or stashType == 'evidence' then
            hasAccess = RSGCore.Functions.HasPermission(src, 'admin')
        end

        if not hasAccess then
            return TriggerClientEvent('ox_lib:notify', src, {
                title = locale('error.access_denied'),
                description = locale('error.no_permission_stash'),
                type = 'error',
                duration = 5000
            })
        end
    end

    -- Additional distance check for world stashes
    local stashCoords = Inventory.GetCoords(stashId, src)
    if stashCoords then
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local distance = #(playerCoords - stashCoords)

        if distance > Inventory.MAX_DIST then
            return TriggerClientEvent('ox_lib:notify', src, {
                title = 'Error',
                description = locale('error.stash_too_far'),
                type = 'error',
                duration = 5000
            })
        end
    end

    Inventory.OpenInventory(src, stashId)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for dropId, drop in pairs(Drops) do
        if drop.openedBy == src then
            drop.isOpen = false
            drop.openedBy = nil
        end
    end
end)
