--#region Variables

local RSGCore = exports['rsg-core']:GetCoreObject()
local PlayerData = RSGCore.Functions.GetPlayerData()
local inInventory = false
local currentOtherInventory = nil
local Drops = {}
local CurrentDrop = nil
local DropsNear = {}
local CurrentStash = nil
local isHotbar = false

--#endregion Variables

--#region Functions

---Checks if you have an item or not
---@param items string | string[] | table<string, number> The items to check, either a string, array of strings or a key-value table of a string and number with the string representing the name of the item and the number representing the amount
---@param amount? number The amount of the item to check for, this will only have effect when items is a string or an array of strings
---@return boolean success Returns true if the player has the item
local function HasItem(items, amount)
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = #items
    local count = 0
    local kvIndex = 2
    local quantity = tonumber(amount)
    if isTable and not isArray then
        totalItems = 0
        for _ in pairs(items) do totalItems += 1 end
        kvIndex = 1
    end
    for _, itemData in pairs(PlayerData.items) do
        if isTable then
            for k, v in pairs(items) do
                local itemKV = {k, v}
                if itemData and itemData.name == itemKV[kvIndex] and ((quantity and itemData.amount >= quantity) or (not isArray and itemData.amount >= v) or (not quantity and isArray)) then
                    count += 1
                end
            end
            if count == totalItems then
                return true
            end
        else -- Single item as string
            if itemData and itemData.name == items and (not quantity or (itemData and quantity and itemData.amount >= quantity)) then
                return true
            end
        end
    end
    return false
end

exports("HasItem", HasItem)

---Load an animation dictionary before playing an animation from it
---@param dict string Animation dictionary to load
local function LoadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return end

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

---Closes the inventory NUI
local function closeInventory()
    SendNUIMessage({
        action = "close",
    })
end

---Toggles the hotbar of the inventory
---@param toggle boolean If this is true, the hotbar will open
local function ToggleHotbar(toggle)
    local HotbarItems = {
        [1] = PlayerData.items[1],
        [2] = PlayerData.items[2],
        [3] = PlayerData.items[3],
        [4] = PlayerData.items[4],
        [5] = PlayerData.items[5],
        [41] = PlayerData.items[41],
    }

    if toggle then
        SendNUIMessage({
            action = "toggleHotbar",
            open = true,
            items = HotbarItems
        })
    else
        SendNUIMessage({
            action = "toggleHotbar",
            open = false,
        })
    end
end

---Plays the opening animation of the inventory
local function openAnim()
    LoadAnimDict('pickup_object')
    TaskPlayAnim(PlayerPedId(),'pickup_object', 'putdown_low', 5.0, 1.5, 1.0, 48, 0.0, 0, 0, 0)
end

---Removes drops in the area of the client
---@param index integer The drop id to remove
local function RemoveNearbyDrop(index)
    if not DropsNear[index] then return end

    local dropItem = DropsNear[index].object
    if DoesEntityExist(dropItem) then
        DeleteEntity(dropItem)
    end

    DropsNear[index] = nil

    if not Drops[index] then return end

    Drops[index].object = nil
    Drops[index].isDropShowing = nil
end

---Removes all drops in the area of the client
local function RemoveAllNearbyDrops()
    for k in pairs(DropsNear) do
        RemoveNearbyDrop(k)
    end
end

---Creates a new item drop object on the ground
---@param index integer The drop id to save the object in
local function CreateItemDrop(index)
    local dropItem = CreateObject(Config.ItemDropObject, DropsNear[index].coords.x, DropsNear[index].coords.y, DropsNear[index].coords.z, false, false, false)
    DropsNear[index].object = dropItem
    DropsNear[index].isDropShowing = true
    PlaceObjectOnGroundProperly(dropItem)
    FreezeEntityPosition(dropItem, true)
    if Config.UseTarget then
        exports['rsg-target']:AddTargetEntity(dropItem, {
            options = {
                {
                    icon = 'fas fa-backpack',
                    label = Lang:t("menu.o_bag"),
                    action = function()
                        TriggerServerEvent("inventory:server:OpenInventory", "drop", index)
                    end,
                }
            },
            distance = 2.5,
        })
    end
end

--#endregion Functions

--#region Events

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    LocalPlayer.state:set("inv_busy", false, true)
    PlayerData = RSGCore.Functions.GetPlayerData()
    RSGCore.Functions.TriggerCallback("inventory:server:GetCurrentDrops", function(theDrops)
        Drops = theDrops
    end)
end)

RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    LocalPlayer.state:set("inv_busy", true, true)
    PlayerData = {}
    RemoveAllNearbyDrops()
end)

RegisterNetEvent('RSGCore:Client:UpdateObject', function()
    RSGCore = exports['rsg-core']:GetCoreObject()
end)

RegisterNetEvent('RSGCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if Config.UseItemDrop then RemoveAllNearbyDrops() end
end)

RegisterNetEvent("rsg-inventory:client:closeinv", function()
    closeInventory()
end)

RegisterNetEvent('inventory:client:CheckOpenState', function(type, id, label)
    local name = RSGCore.Shared.SplitStr(label, "-")[2]
    if type == "stash" then
        if name ~= CurrentStash or CurrentStash == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    elseif type == "drop" then
        if name ~= CurrentDrop or CurrentDrop == nil then
            TriggerServerEvent('inventory:server:SetIsOpenState', false, type, id)
        end
    end
end)

RegisterNetEvent('inventory:client:ItemBox', function(itemData, type, amount)
    SendNUIMessage({
        action = "itemBox",
        item = itemData,
        type = type,
        amount = amount or 1
    })
end)

RegisterNetEvent('inventory:client:requiredItems', function(items, bool)
    local itemTable = {}
    if bool then
        for k in pairs(items) do
            itemTable[#itemTable+1] = {
                item = items[k].name,
                label = RSGCore.Shared.Items[items[k].name]["label"],
                image = items[k].image,
            }
        end
    end

    SendNUIMessage({
        action = "requiredItem",
        items = itemTable,
        toggle = bool
    })
end)

RegisterNetEvent('inventory:server:RobPlayer', function(TargetId)
    SendNUIMessage({
        action = "RobMoney",
        TargetId = TargetId,
    })
end)

RegisterNetEvent('inventory:client:OpenInventory', function(PlayerAmmo, inventory, other)
    local ped = PlayerPedId()
    local dead = IsEntityDead(ped)

    if dead then return end

    ToggleHotbar(false)

    SetNuiFocus(true, true)

    if other then
        currentOtherInventory = other.name
    end

    RSGCore.Functions.TriggerCallback('inventory:server:ConvertQuality', function(data)
        inventory = data.inventory
        other = data.other

        SendNUIMessage(
        {
            action = "open",
            inventory = inventory,
            slots = Config.MaxInventorySlots,
            other = other,
            maxweight = Config.MaxInventoryWeight,
            Ammo = PlayerAmmo,
            maxammo = Config.MaximumAmmoValues,
            pid = GetPlayerServerId(PlayerId()),
            pname = PlayerData.charinfo.firstname..' '..PlayerData.charinfo.lastname
        })
    end, inventory, other)

    inInventory = true
end)

RegisterNetEvent('inventory:client:UpdatePlayerInventory', function(isError)
    SendNUIMessage({
        action = "update",
        inventory = PlayerData.items,
        maxweight = Config.MaxInventoryWeight,
        slots = Config.MaxInventorySlots,
        error = isError,
    })
end)

-- This needs to be changed to do a raycast so items arent placed in walls
RegisterNetEvent('inventory:client:AddDropItem', function(dropId, player, coords)
    local forward = GetEntityForwardVector(GetPlayerPed(GetPlayerFromServerId(player)))
    local x, y, z = table.unpack(coords + forward * 0.5)
    Drops[dropId] = {
        id = dropId,
        coords = {
            x = x,
            y = y,
            z = z - 0.3,
        },
    }
end)

RegisterNetEvent('inventory:client:RemoveDropItem', function(dropId)
    Drops[dropId] = nil
    if Config.UseItemDrop then
        RemoveNearbyDrop(dropId)
    else
        DropsNear[dropId] = nil
    end
end)

RegisterNetEvent('inventory:client:DropItemAnim', function()
    local ped = PlayerPedId()
    SendNUIMessage({
        action = "close",
    })
    local dict = "amb_camp@world_camp_jack_throw_rocks_casual@male_a@idle_a"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
    TaskPlayAnim(ped, dict, "idle_a", 1.0, 8.0, -1, 1, 0, false, false, false)
    Wait(1200)
    ClearPedTasks(ped)
end)

RegisterNetEvent('inventory:client:SetCurrentStash', function(stash)
    CurrentStash = stash
end)

RegisterNetEvent('rsg-inventory:client:giveAnim', function()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
    return
    else
    LoadAnimDict('mp_common')
    TaskPlayAnim(PlayerPedId(), 'mp_common', 'givetake1_b', 8.0, 1.0, -1, 16, 0, 0, 0, 0)
    end
end)

--#endregion Events

--#region Commands

RegisterCommand('closeinv', function()
    closeInventory()
end, false)

RegisterCommand('inventory', function()
    if not inInventory then
        if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
            local ped = PlayerPedId()
            openAnim()
            TriggerServerEvent("inventory:server:OpenInventory")
        end
    end
end, false)

RegisterCommand('hotbar', function()
    isHotbar = not isHotbar
    if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
        ToggleHotbar(isHotbar)
    end
end, false)

--[[
for i = 1, 6 do
    RegisterCommand('slot' .. i,function()
        if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
            if i == 6 then
                i = Config.MaxInventorySlots
            end
            TriggerServerEvent("inventory:server:UseItemSlot", i)
        end
    end, false)
    RegisterKeyMapping('slot' .. i, Lang:t("inf_mapping.use_item") .. i, 'keyboard', i)
end
--]]

--#endregion Commands

--#region NUI

RegisterNUICallback('RobMoney', function(data, cb)
    TriggerServerEvent("police:server:RobPlayer", data.TargetId)
    cb('ok')
end)

RegisterNUICallback('Notify', function(data, cb)
    RSGCore.Functions.Notify(data.message, data.type)
    cb('ok')
end)

RegisterNUICallback('getCombineItem', function(data, cb)
    cb(RSGCore.Shared.Items[data.item])
end)

RegisterNUICallback("CloseInventory", function(_, cb)
    if currentOtherInventory == "none-inv" then
        CurrentDrop = nil
        CurrentStash = nil
        SetNuiFocus(false, false)
        inInventory = false
        ClearPedTasks(PlayerPedId())
        return
    end
    if CurrentStash ~= nil then
        TriggerServerEvent("inventory:server:SaveInventory", "stash", CurrentStash)
        CurrentStash = nil
    else
        TriggerServerEvent("inventory:server:SaveInventory", "drop", CurrentDrop)
        CurrentDrop = nil
    end
    SetNuiFocus(false, false)
    inInventory = false
    cb('ok')
end)

RegisterNUICallback("UseItem", function(data, cb)
    TriggerServerEvent("inventory:server:UseItem", data.inventory, data.item)
    cb('ok')
end)

RegisterNUICallback("combineItem", function(data, cb)
    Wait(150)
    TriggerServerEvent('inventory:server:combineItem', data.reward, data.fromItem, data.toItem)
    cb('ok')
end)

RegisterNUICallback('combineWithAnim', function(data, cb)
    local ped = PlayerPedId()
    local combineData = data.combineData
    local aDict = combineData.anim.dict
    local aLib = combineData.anim.lib
    local animText = combineData.anim.text
    local animTimeout = combineData.anim.timeOut
    RSGCore.Functions.Progressbar("combine_anim", animText, animTimeout, false, true, {
        disableMovement = false,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = aDict,
        anim = aLib,
        flags = 16,
    }, {}, {}, function() -- Done
        StopAnimTask(ped, aDict, aLib, 1.0)
        TriggerServerEvent('inventory:server:combineItem', combineData.reward, data.requiredItem, data.usedItem)
    end, function() -- Cancel
        StopAnimTask(ped, aDict, aLib, 1.0)
        RSGCore.Functions.Notify(Lang:t("notify.failed"), "error")
    end)
    cb('ok')
end)

RegisterNUICallback("SetInventoryData", function(data, cb)
    TriggerServerEvent("inventory:server:SetInventoryData", data.fromInventory, data.toInventory, data.fromSlot, data.toSlot, data.fromAmount, data.toAmount)
    cb('ok')
end)

RegisterNUICallback("PlayDropSound", function(_, cb)
    PlaySound(-1, "CLICK_BACK", "WEB_NAVIGATION_SOUNDS_PHONE", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback("PlayDropFail", function(_, cb)
    PlaySound(-1, "Place_Prop_Fail", "DLC_Dmod_Prop_Editor_Sounds", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback("GiveItem", function(data, cb)
    local player, distance = RSGCore.Functions.GetClosestPlayer(GetEntityCoords(PlayerPedId()))
    if player ~= -1 and distance < 3 then
        if data.inventory == 'player' then
            local playerId = GetPlayerServerId(player)
            SetCurrentPedWeapon(PlayerPedId(),'WEAPON_UNARMED',true)
            TriggerServerEvent("inventory:server:GiveItem", playerId, data.item.name, data.amount, data.item.slot)
        else
            RSGCore.Functions.Notify(Lang:t("notify.notowned"), "error")
        end
    else
        RSGCore.Functions.Notify(Lang:t("notify.nonb"), "error")
    end
    cb('ok')
end)

--#endregion NUI

--#region Threads

CreateThread(function()
    while true do
        local sleep = 100
        if DropsNear ~= nil then
            local ped = PlayerPedId()
            local closestDrop = nil
            local closestDistance = nil
            for k, v in pairs(DropsNear) do

                if DropsNear[k] ~= nil then
                    if Config.UseItemDrop then
                        if not v.isDropShowing then
                            CreateItemDrop(k)
                        end
                    else
                        sleep = 0
                        DrawMarker(0x07DCE236, v.coords.x, v.coords.y, v.coords.z - 0.7, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.15, 255, 215, 0, 155, false, false, false, 1, false, false, false)
                    end

                    local coords = (v.object ~= nil and GetEntityCoords(v.object)) or vector3(v.coords.x, v.coords.y, v.coords.z)
                    local distance = #(GetEntityCoords(ped) - coords)
                    if distance < 2 and (not closestDistance or distance < closestDistance) then
                        closestDrop = k
                        closestDistance = distance
                    end
                end
            end
            if not closestDrop then
                CurrentDrop = 0
            else
                CurrentDrop = closestDrop
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if Drops ~= nil and next(Drops) ~= nil then
            local pos = GetEntityCoords(PlayerPedId(), true)
            for k, v in pairs(Drops) do
                if Drops[k] ~= nil then
                    local dist = #(pos - vector3(v.coords.x, v.coords.y, v.coords.z))
                    if dist < Config.MaxDropViewDistance then
                        DropsNear[k] = v
                    else
                        if Config.UseItemDrop and DropsNear[k] then
                            RemoveNearbyDrop(k)
                        else
                            DropsNear[k] = nil
                        end
                    end
                end
            end
        else
            DropsNear = {}
        end
        Wait(500)
    end
end)

--#endregion Threads

-- toggle inventory
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustReleased(0, RSGCore.Shared.Keybinds['I']) then -- key open inventory I
            if not PlayerData.metadata["ishandcuffed"] and not IsPauseMenuActive() then
                if CurrentDrop ~= 0 then
                    TriggerServerEvent("inventory:server:OpenInventory", "drop", CurrentDrop)
                else
                    TriggerServerEvent("inventory:server:OpenInventory")
                end
            end
        end
    end
end)

-- toggle hotbar
CreateThread(function()
    while true do
        Wait(0)
        DisableControlAction(0, RSGCore.Shared.Keybinds['1'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['2'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['3'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['4'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['5'])
        DisableControlAction(0, RSGCore.Shared.Keybinds['Z'])
        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['1']) and IsInputDisabled(0) then  -- 1  slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                TriggerServerEvent("inventory:server:UseItemSlot", 1)
            end
        end

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['2']) and IsInputDisabled(0) then  -- 2 slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                TriggerServerEvent("inventory:server:UseItemSlot", 2)
            end
        end

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['3']) and IsInputDisabled(0) then -- 3 slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                TriggerServerEvent("inventory:server:UseItemSlot", 3)
            end
        end

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['4']) and IsInputDisabled(0) then  -- 4 slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                TriggerServerEvent("inventory:server:UseItemSlot", 4)
            end
        end

        if IsDisabledControlPressed(0, RSGCore.Shared.Keybinds['5']) and IsInputDisabled(0) then -- 5 slot
            if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
                TriggerServerEvent("inventory:server:UseItemSlot", 5)
            end
        end

        if IsDisabledControlJustPressed(0, RSGCore.Shared.Keybinds['Z']) and IsInputDisabled(0) then -- z  Hotbar
            isHotbar = not isHotbar
            ToggleHotbar(isHotbar)
        end
    end
end)
