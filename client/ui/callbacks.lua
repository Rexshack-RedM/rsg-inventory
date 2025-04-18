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

RegisterNUICallback('GiveItem', function(data, cb)
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