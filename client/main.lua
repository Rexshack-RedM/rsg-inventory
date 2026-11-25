local RSGCore = exports['rsg-core']:GetCoreObject()

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
    for key, it in pairs(PlayerItems()) do
        local slot = tonumber(key)
        if slot and slot <= Config.HotbarSlots then it.slot = slot out[#out + 1] = it end
    end
    return out
end

-- slots holding the weapon the ped has in their hands (shown as "equipped" in the inventory and hotbar)
local function EquippedSlots()
    local _, current = GetCurrentPedWeapon(PlayerPedId(), true, 0, true)
    local out = {}
    if current and current ~= 0 and current ~= joaat('WEAPON_UNARMED') then
        for key, it in pairs(PlayerItems()) do
            if (it.type == 'weapon' or it.type == 'weapon_thrown') and joaat(it.name) == current then
                out[#out + 1] = tonumber(it.slot) or tonumber(key)
            end
        end
    end
    return out
end

-- keys that close the inventory from inside the NUI. With a rebindable key the mapping itself closes it
-- (so a rebound key works); the default key is only listed when the mapping cannot fire while the NUI has focus.
local function CloseKeys()
    local keys = { 'escape', 'tab' }
    if not (Config.UseKeyMapping == true and Config.AllowPushToTalkWhileOpen) then
        keys[#keys + 1] = tostring(Config.MappedKeys.Open or 'I'):lower()
    end
    return keys
end

local typing = false -- true while a text box or modal in the NUI is active: the open key must not close the inventory

local labelKeys = {
    'ui_satchel', 'ui_belongings', 'ui_ground', 'ui_drop_here', 'ui_storage', 'ui_shop_hint', 'ui_searching',
    'ui_amount', 'ui_use', 'ui_give', 'ui_hint', 'ui_inspect', 'ui_weight', 'ui_price', 'ui_sells_for',
    'ui_all', 'ui_misc', 'ui_no_matches', 'ui_sort', 'ui_search',
    'ui_give_to', 'ui_choose_player', 'ui_no_players', 'ui_back', 'ui_quantity', 'ui_player_left',
    'ui_drop', 'ui_trash', 'ui_trash_title', 'ui_trash_warning', 'ui_trash_confirm', 'ui_split', 'ui_take', 'ui_move_to', 'ui_buy', 'ui_sell', 'ui_copy_serial',
    'ui_one', 'ui_half', 'ui_all_amount', 'ui_enter_amount', 'ui_max', 'ui_cancel', 'ui_confirm',
    'ui_kg', 'ui_close', 'ui_amount_tip', 'info_serie', 'info_quality',
    'ui_take_all', 'ui_shop_pays', 'ui_equipped', 'ui_stashes', 'ui_open', 'ui_history', 'ui_nothing_found',
}
local labels
local function UiLabels()
    if not labels then
        labels = {}
        for _, k in ipairs(labelKeys) do labels[k] = locale(k) end
    end
    return labels
end

local function LoadModel(model, timeout)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then SetModelAsNoLongerNeeded(model) return false end
        Wait(10)
    end
    return true
end

local function LoadAnimDict(dict, timeout)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

local function Close()
    if not isOpen then return end
    isOpen = false
    typing = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    Send('close')
    TriggerServerEvent('rsg-inventory:server:close')
end

local function CanUse()
    local pd = RSGCore.Functions.GetPlayerData()
    local meta = pd and pd.metadata or {}
    if meta.isdead or meta.ishandcuffed or meta.inlaststand then return false end
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or GetEntityHealth(ped) <= 0 then return false end
    return true
end

local function CanOpen()
    return loggedIn and not isOpen and not IsNuiFocused() and not IsPauseMenuActive() and CanUse()
end

local function NearestDrop()
    local pc = GetEntityCoords(PlayerPedId())
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
    -- Keep game input alive only so we can whitelist push-to-talk (everything else is disabled in the loop below)
    if Config.AllowPushToTalkWhileOpen then
        SetNuiFocusKeepInput(true)
    end
    typing = false
    Send('open', { player = player, other = other, imagePath = Config.ImagePath, hotbarSlots = Config.HotbarSlots, trash = Config.Trash.Enabled, labels = UiLabels(), categoryLabels = Config.CategoryLabels, equipped = EquippedSlots(), closeKeys = CloseKeys() })
end)

RegisterNetEvent('rsg-inventory:client:refresh', function(player, other)
    if isOpen then
        Send('refresh', { player = player, other = other, equipped = EquippedSlots() })
    end
end)

RegisterNetEvent('rsg-inventory:client:close', Close)

-- a weapon left the inventory: holster it if it is in the player's hands
RegisterNetEvent('rsg-inventory:client:checkWeapon', function(weaponName)
    local ped, hash = PlayerPedId(), joaat(weaponName)
    local _, current = GetCurrentPedWeapon(ped, true, 0, true)
    if current == hash then
        RemoveWeaponFromPed(ped, hash, true, 0)
        TriggerEvent('rsg-weapons:client:UseWeapon', { name = weaponName }, false)
    end
end)

-- item added / removed / used feedback (NUI item box + optional rsg-core toast)
local itemBoxLabels
local itemBoxStyle = {
    add    = { key = 'item_received', type = 'success', icon = 'fa-solid fa-plus' },
    remove = { key = 'item_removed',  type = 'error',   icon = 'fa-solid fa-minus' },
    use    = { key = 'item_used',     type = 'inform',  icon = 'fa-solid fa-hand' },
}

RegisterNetEvent('rsg-inventory:client:ItemBox', function(item, kind, amount)
    local style = item and itemBoxStyle[kind]
    if not style then return end
    -- image item box (old inventory style)
    if Config.ItemBox ~= false then
        itemBoxLabels = itemBoxLabels or { add = locale('itembox_received'), remove = locale('itembox_removed'), use = locale('itembox_used') }
        Send('itembox', {
            item = { name = item.name, label = item.label or item.name, image = item.image },
            kind = kind,
            text = itemBoxLabels[kind],
            amount = amount or 1,
            imagePath = Config.ImagePath,
            position = Config.ItemBoxPosition or 'bottom',
        })
    end
    if not Config.ItemNotifications then return end
    RSGCore.Functions.Notify({
        title = locale('inventory'),
        description = kind == 'use' and locale(style.key, item.label or item.name)
            or locale(style.key, amount or 1, item.label or item.name),
        type = style.type,
        icon = style.icon,
        duration = 3000,
    })
end)

-- Admin stash browser (/stashes): a modal in the NUI, every request is re-checked by the server (admin permission)
local browserOpen = false

local function CloseBrowser()
    if not browserOpen then return end
    browserOpen = false
    typing = false
    SetNuiFocus(false, false)
    Send('stashBrowserClose')
end

RegisterNetEvent('rsg-inventory:client:stashBrowser', function()
    if isOpen or browserOpen or not loggedIn then return end
    browserOpen = true
    SetNuiFocus(true, true)
    Send('stashBrowser', { labels = UiLabels() })
end)

RegisterNUICallback('closeBrowser', function(_, cb) CloseBrowser() cb('ok') end)

RegisterNUICallback('stashList', function(data, cb)
    RSGCore.Functions.TriggerCallback('rsg-inventory:server:adminStashes', function(list) cb(list or {}) end,
        type(data) == 'table' and data.filter or '')
end)

RegisterNUICallback('stashHistory', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then return cb({}) end
    RSGCore.Functions.TriggerCallback('rsg-inventory:server:adminStashHistory', function(rows) cb(rows or {}) end, data.id)
end)

RegisterNUICallback('stashOpen', function(data, cb)
    cb('ok')
    if type(data) == 'table' and type(data.id) == 'string' then
        CloseBrowser()
        TriggerServerEvent('rsg-inventory:server:adminOpenStash', data.id)
    end
end)

RegisterNetEvent('rsg-inventory:client:giveAnim', function()
    local dict, anim = 'mech_inventory@item@fallbacks@tonic_potent@offhand', 'use_quick'
    if not LoadAnimDict(dict) then return end
    TaskPlayAnim(PlayerPedId(), dict, anim, 8.0, -8.0, 1500, 31, 0, false, false, false)
    RemoveAnimDict(dict)
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
        local pc = GetEntityCoords(PlayerPedId())
        for id, d in pairs(Drops) do
            local near = #(pc - d.coords) < Config.Drop.RenderDistance
            if near and not d.obj and LoadModel(Config.Drop.Prop) and Drops[id] == d then
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

-- stash header button (registered by the script that opened the stash)
RegisterNUICallback('action', function(data, cb)
    if type(data.id) == 'string' then TriggerServerEvent('rsg-inventory:server:stashAction', data.id) end
    cb('ok')
end)

-- sort button: which = 'player' | 'other' (the open stash); the server re-checks everything
RegisterNUICallback('sort', function(data, cb)
    if data.which == 'player' or data.which == 'other' then TriggerServerEvent('rsg-inventory:server:sort', data.which) end
    cb('ok')
end)

RegisterNUICallback('use', function(data, cb)
    TriggerServerEvent('rsg-inventory:server:useItem', data.slot)
    cb('ok')
end)

RegisterNUICallback('typing', function(data, cb)
    typing = type(data) == 'table' and data.state == true
    cb('ok')
end)

RegisterNUICallback('takeall', function(_, cb)
    TriggerServerEvent('rsg-inventory:server:takeAll')
    cb('ok')
end)

RegisterNUICallback('trash', function(data, cb)
    if type(data) == 'table' and data.slot and data.amount then
        TriggerServerEvent('rsg-inventory:server:trash', data.slot, data.amount, data.name)
    end
    cb('ok')
end)

RegisterNUICallback('drop', function(data, cb)
    TriggerServerEvent('rsg-inventory:server:drop', data.slot, data.amount)
    cb('ok')
end)

-- Give list: the server returns the players in range (name, id, distance) so the player picks the recipient
RegisterNUICallback('nearby', function(_, cb)
    RSGCore.Functions.TriggerCallback('rsg-inventory:server:getNearbyPlayers', function(list)
        cb(list or {})
    end)
end)

-- confirmed give: recipient id, slot, quantity and the item name the player picked (the server re-checks all of it)
RegisterNUICallback('give', function(data, cb)
    if type(data) == 'table' and data.id and data.slot and data.amount then
        TriggerServerEvent('rsg-inventory:server:give', data.id, data.slot, data.amount, data.name)
    end
    cb('ok')
end)

--------------------------------------------------------------------------------
-- Input
--------------------------------------------------------------------------------
local lastHotbar = 0

local function ShowHotbar()
    if not loggedIn or isOpen then return end
    Send('hotbar', { items = HotbarItems(), imagePath = Config.ImagePath, equipped = EquippedSlots() })
end

local function UseHotbarSlot(i)
    if not loggedIn or isOpen or IsNuiFocused() then return end
    if GetGameTimer() - lastHotbar <= Config.UseCooldown then return end
    lastHotbar = GetGameTimer()
    if (PlayerItems()[i] or PlayerItems()[tostring(i)]) and CanUse() then
        TriggerServerEvent('rsg-inventory:server:useItem', i)
    end
end

-- Rebindable keys (rsg-core RegisterKey). Players change them in the game's key settings;
-- Config.MappedKeys only holds the defaults. Set Config.UseKeyMapping = false to poll Config.Keys instead.
local mapped = Config.UseKeyMapping == true
if mapped then
    -- the same key opens and closes: allowWhileNui lets it close the inventory, even after a player rebinds it
    RSGCore.Functions.RegisterKey('rsginventory_open', locale('key_open'), Config.MappedKeys.Open, nil, function()
        if typing then return end
        if isOpen then Close() else OpenInventory() end
    end, { allowWhileNui = true })
    RSGCore.Functions.RegisterKey('rsginventory_hotbar', locale('key_hotbar'), Config.MappedKeys.Hotbar, nil, ShowHotbar)
    for i = 1, Config.HotbarSlots do
        local key = Config.MappedKeys.Slots[i]
        if key then
            RSGCore.Functions.RegisterKey('rsginventory_slot' .. i, locale('key_slot', i), key, nil, function() UseHotbarSlot(i) end)
        end
    end
end

CreateThread(function()
    while true do
        if loggedIn and not isOpen then
            if mapped and not Config.BlockNativeControls then
                Wait(250) -- nothing to poll: the key mappings do the work
            else
                Wait(0)
                -- a key mapping does not stop the game's own action on that key, so the native
                -- satchel menu (I) and the weapon quick-select (1-5) are still blocked here
                DisableControlAction(0, Config.Keys.Open, true)
                if not mapped then
                    if IsDisabledControlJustReleased(0, Config.Keys.Open) then OpenInventory() end
                    if IsControlJustReleased(0, Config.Keys.Hotbar) then ShowHotbar() end
                end
                for i, key in ipairs(Config.Keys.Slots) do
                    if i > Config.HotbarSlots then break end
                    DisableControlAction(0, key, true)
                    if not mapped and IsDisabledControlJustReleased(0, key) then UseHotbarSlot(i) end
                end
            end
        elseif isOpen then
            Wait(0)
            if not CanUse() then
                Close()
            elseif Config.AllowPushToTalkWhileOpen then
                -- Block movement / combat / look, but re-enable only push-to-talk controls
                DisableAllControlActions(0)
                DisableAllControlActions(1)
                DisableAllControlActions(2)
                local list = Config.PushToTalkControls
                if list then
                    for i = 1, #list do
                        local control = list[i]
                        EnableControlAction(0, control, true)
                        EnableControlAction(1, control, true)
                        EnableControlAction(2, control, true)
                    end
                end
            else
                Wait(250)
            end
        else
            Wait(250)
        end
    end
end)

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
local function ClearDrops()
    for _, d in pairs(Drops) do DeleteDropObj(d) end
    Drops = {}
end

local function Init()
    loggedIn = true
    ClearDrops() -- drops picked up / expired while we were away must not linger
    TriggerServerEvent('rsg-inventory:server:syncDrops') -- the server sends the drops around us (and keeps doing so as we move)
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', Init)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    Close()
    CloseBrowser()
    loggedIn = false
    ClearDrops()
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then Init() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    ClearDrops()
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
