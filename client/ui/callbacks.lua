--- Returns the local player ID for a given server ID
---@param serverId number The server ID of the player
---@return number|nil The local player ID if found, nil otherwise
local function GetPlayerFromServerID(serverId)
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) == serverId then
            return pid
        end
    end
    return nil
end

--- Returns a list of nearby players within a maximum distance
---@param maxDistance number? Maximum distance to check (default 3.0)
---@return table A list of nearby players with `value` = serverId and `label` = display name
local function GetNearbyPlayers(maxDistance)
    local options = {}
    local myPed = cache.ped
    local myCoords = GetEntityCoords(myPed)
    local maxDist = maxDistance or 3.0
    local myId = cache.playerId or PlayerId()

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= myId then
            local ped = GetPlayerPed(pid)
            if DoesEntityExist(ped) then
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist <= maxDist then
                    local sid = GetPlayerServerId(pid)
                    options[#options+1] = {
                        value = sid,
                        label = "Player : " .. sid,
                    }
                end
            end
        end
    end
    return options
end

--- Finds the closest player within a maximum distance
---@param maxDistance number? Maximum distance to check (default 3.0)
---@return number closestPid Local player ID of closest player, -1 if none found
---@return number closestDist Distance to closest player
local function GetClosestPlayerWithin(maxDistance)
    local myCoords = GetEntityCoords(cache.ped)
    local myId = cache.playerId or PlayerId()
    local maxDist = maxDistance or 3.0
    local closestPid, closestDist = -1, maxDist + 0.001

    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= myId then
            local ped = GetPlayerPed(pid)
            if DoesEntityExist(ped) then
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist < closestDist then
                    closestPid, closestDist = pid, dist
                end
            end
        end
    end
    return closestPid, closestDist
end

--- NUI callback to attempt a purchase
RegisterNUICallback('AttemptPurchase', function(data, cb)
    local ok = lib.callback.await('rsg-inventory:server:attemptPurchase', false, data)
    cb(ok)
end)

--- NUI callback to close the inventory
RegisterNUICallback('CloseInventory', function(data, cb)
    SetNuiFocus(false, false)
    if data and data.name then
        if data.name:find('trunk-') then
            CloseTrunk()
        end
        TriggerServerEvent('rsg-inventory:server:closeInventory', data.name)
    elseif LocalPlayer.state.currentDrop then
        TriggerServerEvent('rsg-inventory:server:closeInventory', LocalPlayer.state.currentDrop)
        LocalPlayer.state.currentDrop = nil
    end
    cb('ok')
end)

--- NUI callback to use an item
RegisterNUICallback('UseItem', function(data, cb)
    if data and data.item then
        TriggerServerEvent('rsg-inventory:server:useItem', data.item)
    end
    cb('ok')
end)

--- NUI callback to move items between inventories
RegisterNUICallback('SetInventoryData', function(data, cb)
    if data then
        TriggerServerEvent('rsg-inventory:server:SetInventoryData',
            data.fromInventory, data.toInventory,
            data.fromSlot, data.toSlot,
            data.fromAmount, data.toAmount
        )
    end
    cb('ok')
end)

--- NUI callback to give an item to another player
RegisterNUICallback('GiveItem', function(data, cb)
    if not data or not data.item or not data.item.name then
        cb(false)
        return
    end

    --- Notify the player that no nearby player was found
    local function notifyNoPlayer()
        lib.notify({
            title = locale('error.error'),
            description = locale('error.no_player_nearby'),
            type = 'error',
            duration = 7000
        })
    end

    local config = require 'shared.config'

    if config.GiveItemType == "nearby" then
        local pid, dist = GetClosestPlayerWithin(3.0)
        if pid ~= -1 and dist < 3.0 then
            local targetSid = GetPlayerServerId(pid)
            local success = lib.callback.await('rsg-inventory:server:giveItem', false,
                targetSid, data.item.name, data.amount, data.slot, data.info
            )
            cb(success)
        else
            notifyNoPlayer()
            cb(false)
        end

    elseif config.GiveItemType == "id" then
        local getplayerid = lib.inputDialog(locale('info.enter_player_id'), {
            { type = 'number', label = locale('info.number_input'), icon = 'hashtag' },
        })
        if not getplayerid or not getplayerid[1] then
            cb(false)
            return
        end
        local typedSid = tonumber(getplayerid[1])
        local pid, dist = GetClosestPlayerWithin(3.0)
        if pid ~= -1 and dist < 3.0 and GetPlayerServerId(pid) == typedSid then
            local success = lib.callback.await('rsg-inventory:server:giveItem', false,
                typedSid, data.item.name, data.amount, data.slot, data.info
            )
            cb(success)
        else
            notifyNoPlayer()
            cb(false)
        end

    elseif config.GiveItemType == "nearby_menu" then
        local input = lib.inputDialog(locale('info.select_player_nearby'), {
            { type = 'select', label = locale('info.nearby_players_label'), options = GetNearbyPlayers(3.0) },
        })
        if not input or not input[1] then
            cb(false)
            return
        end
        local selectedSid = tonumber(input[1])
        local selectedPid = GetPlayerFromServerID(selectedSid)
        if not selectedPid then
            notifyNoPlayer()
            cb(false)
            return
        end
        local dist = #(GetEntityCoords(GetPlayerPed(selectedPid)) - GetEntityCoords(cache.ped))
        if dist < 3.0 then
            local success = lib.callback.await('rsg-inventory:server:giveItem', false,
                selectedSid, data.item.name, data.amount, data.slot, data.info
            )
            cb(success)
        else
            notifyNoPlayer()
            cb(false)
        end
    else
        cb(false)
    end
end)

--- NUI callback to request the amount of an item to give
RegisterNUICallback('GiveItemAmount', function(_, cb)
    local input = lib.inputDialog(locale('info.enter_amount'), {
        { type = 'number', label = locale('info.number_input'), icon = 'hashtag' },
    })
    if input and input[1] then
        cb(math.abs(tonumber(input[1])))
    else
        cb(0)
    end
end)