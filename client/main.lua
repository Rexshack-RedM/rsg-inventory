local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local isOpen     = false
local loggedIn   = LocalPlayer.state.isLoggedIn or false
local Drops      = {}   -- [id] = { coords = vector3, obj = entity|nil }

--------------------------------------------------------------------------------
-- NUI helpers
--------------------------------------------------------------------------------
local function Send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function PlayerItems()
    local pd = RSGCore.Functions.GetPlayerData()
    return pd and pd.items or {}
end

local function HotbarItems()
    local out = {}
    for slot, it in pairs(PlayerItems()) do
        slot = tonumber(slot)
        if slot and slot <= Config.HotbarSlots then it.slot = slot out[#out + 1] = it end
    end
    return out
end

local labelKeys = {
    'ui_satchel', 'ui_belongings', 'ui_ground', 'ui_drop_here', 'ui_storage', 'ui_shop_hint', 'ui_searching',
    'ui_amount', 'ui_use', 'ui_give', 'ui_hint', 'ui_inspect', 'ui_weight', 'ui_price', 'ui_sells_for',
    'ui_all', 'ui_misc', 'ui_no_matches',
    'ui_drop', 'ui_split', 'ui_take', 'ui_move_to', 'ui_buy', 'ui_sell', 'ui_copy_serial',
    'ui_one', 'ui_half', 'ui_all_amount', 'ui_enter_amount', 'ui_max', 'ui_cancel', 'ui_confirm',
    'ui_kg', 'ui_close', 'ui_amount_tip', 'info_serie', 'info_quality',
}
local labels
local function UiLabels()
    if not labels then
        labels = {}
        for _, k in ipairs(labelKeys) do labels[k] = locale(k) end
    end
    return labels
end

local function Close()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    Send('close')
    TriggerServerEvent('rsg-inventory:server:close')
end

local function CanUse()
    local pd = RSGCore.Functions.GetPlayerData()
    local meta = pd and pd.metadata or {}
    if meta.isdead or meta.ishandcuffed or meta.inlaststand then return false end
    local ped = cache.ped or PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or GetEntityHealth(ped) <= 0 then return false end
    return true
end

local function CanOpen()
    return loggedIn and not isOpen and not IsNuiFocused() and not IsPauseMenuActive() and CanUse()
end

local function NearestDrop()
    local pc = GetEntityCoords(cache.ped)
    local best, bestDist
    for id, d in pairs(Drops) do
        local dist = #(pc - d.coords)
        if dist <= Config.Drop.OpenDistance and (not bestDist or dist < bestDist) then
            best, bestDist = id, dist
        end
    end
    return best
end

local function OpenInventory()
    if not CanOpen() then return end
    TriggerServerEvent('rsg-inventory:server:open', NearestDrop())
end

--------------------------------------------------------------------------------
-- Server -> client
--------------------------------------------------------------------------------
RegisterNetEvent('rsg-inventory:client:open', function(player, other)
    isOpen = true
    SetNuiFocus(true, true)
    Send('open', { player = player, other = other, imagePath = Config.ImagePath, hotbarSlots = Config.HotbarSlots, labels = UiLabels(), categoryLabels = Config.CategoryLabels })
end)

RegisterNetEvent('rsg-inventory:client:refresh', function(player, other)
    if isOpen then
        Send('refresh', { player = player, other = other })
    end
end)

RegisterNetEvent('rsg-inventory:client:close', Close)

-- a weapon left the inventory: holster it if it is in the player's hands
RegisterNetEvent('rsg-inventory:client:checkWeapon', function(weaponName)
    local hash = joaat(weaponName)
    local _, current = GetCurrentPedWeapon(cache.ped, true, 0, true)
    if current == hash then
        RemoveWeaponFromPed(cache.ped, hash, true, 0)
        TriggerEvent('rsg-weapons:client:UseWeapon', { name = weaponName }, false)
    end
end)

-- item added / removed / used feedback (ox_lib notify)
local itemBoxStyle = {
    add    = { key = 'item_received', type = 'success', icon = 'plus' },
    remove = { key = 'item_removed',  type = 'error',   icon = 'minus' },
    use    = { key = 'item_used',     type = 'inform',  icon = 'hand' },
}

RegisterNetEvent('rsg-inventory:client:ItemBox', function(item, kind, amount)
    local style = item and itemBoxStyle[kind]
    if not style then return end
    -- image item box (old inventory style)
    if Config.ItemBox ~= false then
        local labels = { add = locale('itembox_received'), remove = locale('itembox_removed'), use = locale('itembox_used') }
        Send('itembox', {
            item = { name = item.name, label = item.label or item.name, image = item.image },
            kind = kind,
            text = labels[kind],
            amount = amount or 1,
            imagePath = Config.ImagePath,
            position = Config.ItemBoxPosition or 'bottom',
        })
    end
    if not Config.Notifications then return end
    lib.notify({
        title = locale('inventory'),
        description = kind == 'use' and locale(style.key, item.label or item.name)
            or locale(style.key, amount or 1, item.label or item.name),
        type = style.type,
        icon = style.icon,
        duration = 3000,
    })
end)

RegisterNetEvent('rsg-inventory:client:giveAnim', function()
    lib.requestAnimDict('mp_common')
    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 0, 0, false, false, false)
end)

--------------------------------------------------------------------------------
-- Drops (local props)
--------------------------------------------------------------------------------
local function DeleteDropObj(d)
    if d.obj and DoesEntityExist(d.obj) then DeleteObject(d.obj) end
    d.obj = nil
end

RegisterNetEvent('rsg-inventory:client:addDrop', function(id, coords)
    Drops[id] = { coords = vector3(coords.x, coords.y, coords.z) }
end)

RegisterNetEvent('rsg-inventory:client:removeDrop', function(id)
    if Drops[id] then DeleteDropObj(Drops[id]) end
    Drops[id] = nil
end)

CreateThread(function()
    while true do
        Wait(1000)
        local pc = GetEntityCoords(cache.ped)
        for _, d in pairs(Drops) do
            local near = #(pc - d.coords) < Config.Drop.RenderDistance
            if near and not d.obj then
                lib.requestModel(Config.Drop.Prop)
                d.obj = CreateObject(Config.Drop.Prop, d.coords.x, d.coords.y, d.coords.z - 1.0, false, false, false)
                PlaceObjectOnGroundProperly(d.obj)
                FreezeEntityPosition(d.obj, true)
                SetEntityCollision(d.obj, false, false)
                SetModelAsNoLongerNeeded(Config.Drop.Prop)
            elseif not near and d.obj then
                DeleteDropObj(d)
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- NUI callbacks
--------------------------------------------------------------------------------
RegisterNUICallback('close', function(_, cb) Close() cb('ok') end)

RegisterNUICallback('move', function(data, cb)
    TriggerServerEvent('rsg-inventory:server:move', data)
    cb('ok')
end)

RegisterNUICallback('use', function(data, cb)
    TriggerServerEvent('rsg-inventory:server:useItem', data.slot)
    cb('ok')
end)

RegisterNUICallback('drop', function(data, cb)
    TriggerServerEvent('rsg-inventory:server:drop', data.slot, data.amount)
    cb('ok')
end)

RegisterNUICallback('give', function(data, cb)
    local player, dist = lib.getClosestPlayer(GetEntityCoords(cache.ped), Config.GiveDistance, false)
    if not player then
        if Config.Notifications then lib.notify({ title = locale('inventory'), description = locale('no_player'), type = 'error', duration = 4000 }) end
        return cb('ok')
    end
    TriggerServerEvent('rsg-inventory:server:give', GetPlayerServerId(player), data.slot, data.amount)
    cb('ok')
end)

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------
local lastHotbar = 0
CreateThread(function()
    while true do
        Wait(0)
        if loggedIn and not isOpen then
            DisableControlAction(0, Config.Keys.Open, true)
            if IsDisabledControlJustReleased(0, Config.Keys.Open) then
                OpenInventory()
            end
            if IsControlJustReleased(0, Config.Keys.Hotbar) then
                Send('hotbar', { items = HotbarItems(), imagePath = Config.ImagePath })
            end
            for i, key in ipairs(Config.Keys.Slots) do
                if i > Config.HotbarSlots then break end
                if IsControlJustReleased(0, key) and not IsNuiFocused() and GetGameTimer() - lastHotbar > Config.UseCooldown then
                    lastHotbar = GetGameTimer()
                    if (PlayerItems()[i] or PlayerItems()[tostring(i)]) and CanUse() then
                        TriggerServerEvent('rsg-inventory:server:useItem', i)
                    end
                end
            end
        else
            if isOpen and not CanUse() then Close() end -- died or got cuffed with the bag open
            Wait(250)
        end
    end
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
local function Init()
    loggedIn = true
    local list = lib.callback.await('rsg-inventory:server:getDrops', false) or {}
    for id, coords in pairs(list) do
        Drops[id] = { coords = vector3(coords.x, coords.y, coords.z) }
    end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', Init)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    Close()
    loggedIn = false
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then Init() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    for _, d in pairs(Drops) do DeleteDropObj(d) end
end)

--------------------------------------------------------------------------------
-- Client exports
--------------------------------------------------------------------------------
exports('HasItem', function(items, amount)
    amount = tonumber(amount) or 1
    local inv, counts = PlayerItems(), {}
    for _, it in pairs(inv) do counts[it.name] = (counts[it.name] or 0) + it.amount end
    if type(items) == 'string' then return (counts[items:lower()] or 0) >= amount end
    if type(items) ~= 'table' then return false end
    for k, v in pairs(items) do
        local name, need = k, v
        if type(k) == 'number' then name, need = v, amount end
        if (counts[tostring(name):lower()] or 0) < need then return false end
    end
    return true
end)

exports('GetItemCount', function(name)
    local n = 0
    for _, it in pairs(PlayerItems()) do if it.name == name then n = n + it.amount end end
    return n
end)

exports('CloseInventory', Close)
exports('IsOpen', function() return isOpen end)
