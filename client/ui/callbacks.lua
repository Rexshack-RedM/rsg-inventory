RegisterNUICallback('AttemptPurchase', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-inventory:server:attemptPurchase', function(canPurchase)
        cb(canPurchase)
    end, data)
end)

RegisterNUICallback('CloseInventory', function(data, cb)
    SetNuiFocus(false, false)
    if data.name then
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

RegisterNUICallback('UseItem', function(data, cb)
    TriggerServerEvent('rsg-inventory:server:useItem', data.item)
    cb('ok')
end)

RegisterNUICallback('SetInventoryData', function(data, cb)
    TriggerServerEvent('rsg-inventory:server:SetInventoryData', data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

local function GetPlayerFromServerID(playerid)
    for _, player in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(player) == serverId then
            return player
        end
    end
    return nil
end

local function GetNearbyPlayers()
    local nearbyPlayers = {}
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            local dist = #(GetEntityCoords(ped) - myCoords)
            if dist < 3.0 then
                nearbyPlayers[#nearbyPlayers + 1] = {
                    value = GetPlayerServerId(player),
                    label = "Player : " .. GetPlayerServerId(player),
                }
            end
        end
    end

    return nearbyPlayers
end

RegisterNUICallback('GiveItem', function(data, cb)
    if Config.GiveItemType = "nearby" then
        local player, distance = RSGCore.Functions.GetClosestPlayer(GetEntityCoords(PlayerPedId()))
        if player ~= -1 and distance < 3 then
            local playerId = GetPlayerServerId(player)
            RSGCore.Functions.TriggerCallback('rsg-inventory:server:giveItem', function(success)
                cb(success)
            end, playerId, data.item.name, data.amount, data.slot, data.info)
        else
            lib.notify({ title = 'Error', description = Lang:t('notify.nonb'), type = 'error', duration = 7000 })
            cb(false)
        end
    elseif Config.GiveItemType = "id" then
        local getplayerid = lib.inputDialog('Enter Player ID', {
            {type = 'number', label = 'Number input', icon = 'hashtag'},
        })
        if not getplayerid[1] then
            cb(false)
            return
        end
        local player, distance = RSGCore.Functions.GetClosestPlayer(GetEntityCoords(PlayerPedId()))
        if player ~= -1 then
            local playerId = GetPlayerServerId(player)
            if distance < 3 and playerId == tonumber(getplayerid[1]) then
                RSGCore.Functions.TriggerCallback('rsg-inventory:server:giveItem', function(success)
                    cb(success)
                end, tonumber(getplayerid[1]), data.item.name, data.amount, data.slot, data.info)
            else
                lib.notify({ title = 'Error', description = Lang:t('notify.nonb'), type = 'error', duration = 7000 })
                cb(false)
            end
        else
            lib.notify({ title = 'Error', description = Lang:t('notify.nonb'), type = 'error', duration = 7000 })
            cb(false)
        end

    elseif Config.GiveItemType = "nearby_menu" then
        local input = lib.inputDialog('Select Player', {
            {type = 'select', label = 'Player Nearbys',  options = GetNearbyPlayers()},
        })

        if input then
            if input[1] then
                local getplayer = GetPlayerFromServerID(input[1])
                local ped = GetPlayerPed(getplayer)
                local myCoords = GetEntityCoords(PlayerPedId())
                local dist = #(GetEntityCoords(ped) - myCoords)
                if dist < 3.0 then
                    RSGCore.Functions.TriggerCallback('rsg-inventory:server:giveItem', function(success)
                        cb(success)
                    end, tonumber(input[1]), data.item.name, data.amount, data.slot, data.info)
                else
                    lib.notify({ title = 'Error', description = Lang:t('notify.nonb'), type = 'error', duration = 7000 })
                    cb(false)
                end
            else
                cb(false)
                return
            end
        end

    end
end)

RegisterNUICallback('GiveItemAmount', function(data, cb)
    local input = lib.inputDialog('Enter Amount', {
        {type = 'number', label = 'Number input', icon = 'hashtag'},
    })

    if input then
        cb(math.abs(tonumber(input[1])))
    end
end)

--[[ RegisterNUICallback('GetWeaponData', function(cData, cb)
    local data = {
        WeaponData = RSGCore.Shared.Items[cData.weapon],
        AttachmentData = Inventory.FormatWeaponAttachments(cData.ItemData),
    }
    cb(data)
end)

RegisterNUICallback('RemoveAttachment', function(data, cb)
    local ped = PlayerPedId()
    local WeaponData = data.WeaponData
    local allAttachments = exports['rsg-weapons']:getConfigWeaponAttachments()
    local Attachment = allAttachments[data.AttachmentData.attachment][WeaponData.name]
    local itemInfo = RSGCore.Shared.Items[data.AttachmentData.attachment]
    RSGCore.Functions.TriggerCallback('rsg-weapons:server:RemoveAttachment', function(NewAttachments)
        if NewAttachments ~= false then
            local Attachies = {}
            RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), joaat(Attachment))
            for _, v in pairs(NewAttachments) do
                for attachmentType, weapons in pairs(allAttachments) do
                    local componentHash = weapons[WeaponData.name]
                    if componentHash and v.component == componentHash then
                        local label = itemInfo and itemInfo.label or 'Unknown'
                        Attachies[#Attachies + 1] = {
                            attachment = attachmentType,
                            label = label,
                        }
                    end
                end
            end
            local DJATA = {
                Attachments = Attachies,
                WeaponData = WeaponData,
                itemInfo = itemInfo,
            }
            cb(DJATA)
        else
            RemoveWeaponComponentFromPed(ped, joaat(WeaponData.name), joaat(Attachment))
            cb({})
        end
    end, data.AttachmentData, WeaponData)
end) ]]
