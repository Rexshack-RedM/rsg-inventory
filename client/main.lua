RSGCore = exports['rsg-core']:GetCoreObject()
PlayerData = nil
local hotbarShown = false
local lastItemBoxCall = 0

-- Handlers

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set('inv_busy', false, true)
    PlayerData = RSGCore.Functions.GetPlayerData()
    GetDrops()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set('inv_busy', true, true)
    PlayerData = {}
end)

RegisterNetEvent('RSGCore:Client:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        PlayerData = RSGCore.Functions.GetPlayerData()
    end
end)

-- Functions

function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function FormatWeaponAttachments(itemdata)
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

--- Checks if the player has a certain item or items in their inventory with a specified amount.
--- @param items string|table - The item(s) to check for. Can be a table of items or a single item as a string.
--- @param amount number [optional] - The minimum amount required for each item. If not provided, any amount greater than 0 will be considered.
--- @return boolean - Returns true if the player has the item(s) with the specified amount, false otherwise.
function HasItem(items, amount)
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = isArray and #items or 0
    local count = 0

    if isTable and not isArray then
        for _ in pairs(items) do totalItems = totalItems + 1 end
    end

    for _, itemData in pairs(PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                if itemData and itemData.name == (isArray and v or k) and ((amount and itemData.amount >= amount) or (not isArray and itemData.amount >= v) or (not amount and isArray)) then
                    count = count + 1
                    if count == totalItems then
                        return true
                    end
                end
            end
        else -- Single item as string
            if itemData and itemData.name == items and (not amount or (itemData and amount and itemData.amount >= amount)) then
                return true
            end
        end
    end

    return false
end

exports('HasItem', HasItem)

-- Events

RegisterNetEvent('rsg-inventory:client:requiredItems', function(items, bool)
    local itemTable = {}
    if bool then
        for k in pairs(items) do
            itemTable[#itemTable + 1] = {
                item = items[k].name,
                label = RSGCore.Shared.Items[items[k].name]['label'],
                image = items[k].image,
            }
        end
    end

    SendNUIMessage({
        action = 'requiredItem',
        items = itemTable,
        toggle = bool
    })
end)

RegisterNetEvent('rsg-inventory:client:hotbar', function(items)
    local token = lib.callback.await('RSGCore:Server:GenerateToken', false)
    hotbarShown = not hotbarShown
    SendNUIMessage({
        action = 'toggleHotbar',
        open = hotbarShown,
        items = items,
        token = token,
    })
end)

RegisterNetEvent('rsg-inventory:client:closeInv', function()
    SendNUIMessage({
        action = 'close',
    })
end)

RegisterNetEvent('rsg-inventory:client:updateInventory', function()
    local token = lib.callback.await('RSGCore:Server:GenerateToken', false)
    SendNUIMessage({
        action = 'update',
        inventory = PlayerData.items,
        token = token,
    })
end)

RegisterNetEvent('rsg-inventory:client:ItemBox', function(itemData, type, amount)
    local function sendItemBox()
        SendNUIMessage({
            action = 'itemBox',
            item = itemData,
            type = type,
            amount = amount
        })
    end

    local currentTime = GetGameTimer()
    local timeElapsed = currentTime - lastItemBoxCall

    if timeElapsed >= 1000 then
        sendItemBox()
        lastItemBoxCall = currentTime
    else
        local delay = 1000 - timeElapsed
        lib.timer(delay, function()
            sendItemBox()
        end, true)
        lastItemBoxCall = currentTime + delay
    end

    if type == 'remove' then
        TriggerServerEvent('rsg-inventory:server:updateHotbar')
    end
end)

RegisterNetEvent('rsg-inventory:client:updateHotbar', function(items)
    local token = lib.callback.await('RSGCore:Server:GenerateToken', false)
    SendNUIMessage({
        action = 'updateHotbar',
        items = items,
        token = token,
    })
end)

RegisterNetEvent('rsg-inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = 'RobMoney',
        TargetId = TargetId,
    })
end)

RegisterNetEvent('rsg-inventory:client:openInventory', function(items, other)
    local token = lib.callback.await('RSGCore:Server:GenerateToken', false)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        inventory = items,
        slots = Config.MaxSlots,
        maxweight = Config.MaxWeight,
        other = other,
        token = token,
    })
end)

RegisterNetEvent('rsg-inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end
    LoadAnimDict('mp_common')
    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, false, false, false)
end)

-- NUI Callbacks

RegisterNUICallback('PlayDropFail', function(_, cb)
    PlaySound(-1, 'Place_Prop_Fail', 'DLC_Dmod_Prop_Editor_Sounds', 0, 0, 1)
    cb('ok')
end)

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
    elseif CurrentDrop then
        TriggerServerEvent('rsg-inventory:server:closeInventory', CurrentDrop)
        CurrentDrop = nil
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

RegisterNUICallback('GetWeaponData', function(cData, cb)
    local data = {
        WeaponData = RSGCore.Shared.Items[cData.weapon],
        AttachmentData = FormatWeaponAttachments(cData.ItemData)
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
end)

-- Vending

CreateThread(function()
    exports.ox_target:addModel(Config.VendingObjects, {
        label = Lang:t('menu.vending'),
        icon = 'fa-solid fa-cash-register',
        distance = 2.5,
        onSelect = function(data)
            data.coords = GetEntityCoords(data.entity)
            TriggerServerEvent('rsg-inventory:server:openVending', data)
        end,
    })
end)

-- Commands

RegisterCommand('openInv', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if IsNuiFocused() or IsPauseMenuActive() then return end
    if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
        ExecuteCommand('inventory')
    end
end, false)

RegisterCommand('toggleHotbar', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
        ExecuteCommand('hotbar')
    end
end, false)

CreateThread(function()
    while true do
        local sleep = 0
        Wait(sleep)   
        if IsControlJustReleased(0, Config.Keybinds.Open) then
            local PlayerData = RSGCore.Functions.GetPlayerData()
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                ExecuteCommand('inventory')
                sleep = 1000
            end
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 0
        Wait(sleep)
        if IsControlJustReleased(0, Config.Keybinds.Hotbar) then
            local PlayerData = RSGCore.Functions.GetPlayerData()
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                ExecuteCommand('hotbar')
                sleep = 1000
            end
        end
    end
end)

-- hotbar slot commands
CreateThread(function()
    while true do
        Wait(0)

        DisableControlAction(0, RSGCore.Shared.Keybinds['1'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['2'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['3'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['4'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['5'])

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['1']) and IsInputDisabled(0) then  -- 1  slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                ExecuteCommand('slot_1')
            end
        end

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['2']) and IsInputDisabled(0) then  -- 2 slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                ExecuteCommand('slot_2')
            end
        end

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['3']) and IsInputDisabled(0) then -- 3 slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                ExecuteCommand('slot_3')
            end
        end

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['4']) and IsInputDisabled(0) then  -- 4 slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                ExecuteCommand('slot_4')
            end
        end

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['5']) and IsInputDisabled(0) then -- 5 slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                ExecuteCommand('slot_5')
            end
        end

    end
end)

local lastUsed = 0
for i = 1, 5 do
    RegisterCommand('slot_' .. i, function()
        local currentTime = GetGameTimer()

        if lastUsed and currentTime - lastUsed < Config.HotbarSpamProtectionTimeout then
            if Config.HotbarSpamProtectionNotify then
                lib.notify({ 
                    title = 'Error', 
                    description = 'You are pressing buttons too fast! Please wait a moment before trying again.', 
                    type = 'error', 
                    duration = 5000 
                })
                
            end

            return
        end

        lastUsed = currentTime

        local itemData = PlayerData.items[i]
        if not itemData then return end
        
        if itemData.type == "weapon" then
            if holdingDrop then
                return lib.notify({ title = 'Error', description = 'You are already holding a bag, go drop it!', type = 'error', duration = 5000 })
            end
        end
        
        TriggerServerEvent('rsg-inventory:server:useItem', itemData)
    end, false)
end
