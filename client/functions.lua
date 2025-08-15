local RSGCore = exports['rsg-core']:GetCoreObject()
local config = require 'shared.config'
Inventory = {}

---Notifies the player that the hotbar was used too quickly (spam protection).
---@private
local function notifyHotbarSpamProtection()
    if not config.HotbarSpamProtectionNotify then return end
    lib.notify({
        title       = locale('error.error'),
        description = locale('error.SpamProtection'),
        type        = 'error',
        duration    = 5000
    })
end

---Checks if the player is allowed to use the inventory.
---This prevents opening while dead or handcuffed.
---@return boolean canUseInventory
function Inventory.CanPlayerUseInventory()
    local player = RSGCore.Functions.GetPlayerData()
    if not player or not player.metadata then return false end
    local meta = player.metadata
    return not meta.isdead and not meta.ishandcuffed
end

---Uses the item in the given hotbar slot if available.
---Includes a spam-protection check and verifies that the player
---is not currently holding a dropped weapon (weapon on the ground).
---@param slot integer Hotbar slot (1-5)
function Inventory.UseHotbarItem(slot)
    local currentTime = GetGameTimer()
    local lastUsed    = LocalPlayer.state.hotbarLastUsed or 0

    -- Spam protection
    if currentTime - lastUsed < config.HotbarSpamProtectionTimeout then
        return notifyHotbarSpamProtection()
    end

    LocalPlayer.state.hotbarLastUsed = currentTime

    local playerData = RSGCore.Functions.GetPlayerData()
    local itemData   = playerData.items and playerData.items[slot]
    if not itemData then return end

    -- Weapon + holding drop check
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