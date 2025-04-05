Inventory = {}

Inventory.CanPlayerUseInventory = function()
    local canUse = false

    RSGCore.Functions.GetPlayerData(function(playerData)
        local metadata = playerData and playerData.metadata
        canUse = metadata and not metadata["isdead"] and not metadata["ishandcuffed"]
    end)

    return canUse
end

Inventory.UseHotbarItem = function(slot)
    local currentTime = GetGameTimer()
    local lastUsed = LocalPlayer.state.hotbarLastUsed or 0

    if currentTime - lastUsed < Config.HotbarSpamProtectionTimeout then
        Inventory.NotifyHotbarSpamProtection()
        return
    end

    LocalPlayer.state.hotbarLastUsed = currentTime

    local playerData = RSGCore.Functions.GetPlayerData()
    local itemData = playerData.items[slot]
    if not itemData then return end

    if itemData.type == "weapon" and LocalPlayer.state.holdingDrop then
        return lib.notify({
            title = 'Error',
            description = 'You are already holding a bag, go drop it!',
            type = 'error',
            duration = 5000
        })
    end

    TriggerServerEvent('rsg-inventory:server:useItem', itemData)
end

Inventory.NotifyHotbarSpamProtection = function()
    if Config.HotbarSpamProtectionNotify then
        lib.notify({
            title = 'Error',
            description = 'You are pressing buttons too fast! Please wait a moment before trying again.',
            type = 'error',
            duration = 5000
        })
    end
end

Inventory.FormatWeaponAttachments = function(itemdata)
    if not itemdata.info or not itemdata.info.attachments or #itemdata.info.attachments == 0 then
        return {}
    end
    local attachments = {}
    local weaponName = itemdata.name
    local WeaponAttachments = exports['rsg-weapons']:getConfigWeaponAttachments()
    if not WeaponAttachments then return {} end
    for attachmentType, weapons in pairs(WeaponAttachments) do
        local componentHash = weapons[weaponName]
        if componentHash then
            for _, attachmentData in pairs(itemdata.info.attachments) do
                if attachmentData.component == componentHash then
                    local label = RSGCore.Shared.Items[attachmentType] and RSGCore.Shared.Items[attachmentType].label or 'Unknown'
                    attachments[#attachments + 1] = {
                        attachment = attachmentType,
                        label = label
                    }
                end
            end
        end
    end
    return attachments
end

