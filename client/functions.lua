local config = require 'shared.config'
Inventory = {}

local function notifyHotbarSpamProtection()
    if not config.HotbarSpamProtectionNotify then return end
    lib.notify({
        title       = locale('error.error'),
        description = locale('error.SpamProtection'),
        type        = 'error',
        duration    = 5000
    })
end

function Inventory.CanPlayerUseInventory()
    local playerData = RSGCore.Functions.GetPlayerData()
    if not playerData or not playerData.metadata then return false end
    local meta = playerData.metadata
    return not meta.isdead and not meta.ishandcuffed
end

function Inventory.UseHotbarItem(slot)
    local currentTime = GetGameTimer()
    local lastUsed = LocalPlayer.state.hotbarLastUsed or 0

    if currentTime - lastUsed < config.HotbarSpamProtectionTimeout then
        return notifyHotbarSpamProtection()
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