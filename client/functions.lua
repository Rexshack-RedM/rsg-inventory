Inventory = {}
local config = require 'shared.config'

function Inventory.CanPlayerUseInventory()
    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.metadata then return false end
    local meta = playerData.metadata
    return not meta.isdead and not meta.ishandcuffed
end

function Inventory.NotifyHotbarSpamProtection()
    if not config.HotbarSpamProtectionNotify then return end
    lib.notify({
        title       = locale('error.error'),
        description = locale('error.SpamProtection'),
        type        = 'error',
        duration    = 5000
    })
end

function Inventory.UseHotbarItem(slot)
    local currentTime = GetGameTimer()
    local lastUsed = LocalPlayer.state.hotbarLastUsed or 0
    if currentTime - lastUsed < config.HotbarSpamProtectionTimeout then
        return Inventory.NotifyHotbarSpamProtection()
    end
    LocalPlayer.state.hotbarLastUsed = currentTime

    local playerData = RSGCore.Functions.GetPlayerData()
    local itemData = playerData.items and playerData.items[slot]
    if not itemData then return end

    if itemData.type == "weapon" and LocalPlayer.state.holdingDrop then
        return lib.notify({
            title       = locale('error.error'),
            description = locale('error.error.fullbag'),
            type        = 'error',
            duration    = 5000
        })
    end

    TriggerServerEvent('rsg-inventory:server:useItem', itemData)
end




-- Optioneel: wapens attachments formatteren
--[[ 
function Inventory.FormatWeaponAttachments(itemData)
    if not (itemData.info and itemData.info.attachments and #itemData.info.attachments > 0) then
        return {}
    end

    local attachments = {}
    local weaponName = itemData.name
    local WeaponAttachments = exports['rsg-weapons']:getConfigWeaponAttachments()
    if not WeaponAttachments then return {} end

    for attachmentType, weapons in pairs(WeaponAttachments) do
        local componentHash = weapons[weaponName]
        if componentHash then
            for _, attachment in pairs(itemData.info.attachments) do
                if attachment.component == componentHash then
                    local label = RSGCore.Shared.Items[attachmentType] and RSGCore.Shared.Items[attachmentType].label or 'Unknown'
                    table.insert(attachments, {
                        attachment = attachmentType,
                        label = label
                    })
                end
            end
        end
    end
    return attachments
end
]]