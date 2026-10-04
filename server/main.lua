local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local Inventories  = {}   -- [id] = { id, label, type = 'stash'|'drop'|'shop', slots, maxWeight, items, coords?, dirty?, touched? }
local OpenInv      = {}   -- [src] = secondary inventory the player has open (string id, player id or 'newdrop')
local UseCooldown  = {}
local GiveCooldown = {}
local PendingSave  = {}   -- [src] = true when the player moved items into/out of another saved inventory
local dropCount    = 0
local API          = {}

local function SharedItem(name)
    return name and RSGCore.Shared.Items[tostring(name):lower()]
end

local function Notify(src, key, kind)
    if not Config.Notifications then return end
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('inventory'), description = locale(key), type = kind or 'error', duration = 4000,
    })
end

local function Log(title, msg)
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', title, 'blue', msg)
end

--------------------------------------------------------------------------------
-- Item helpers
--------------------------------------------------------------------------------
local function BuildItem(name, amount, info, slot)
    local s = SharedItem(name)
    if not s then return nil end
    return {
        name = s.name, label = s.label, amount = amount,
        info = type(info) == 'table' and info or {},
        description = s.description or '', weight = s.weight or 0,
        type = s.type, unique = s.unique, useable = s.useable,
        image = s.image, shouldClose = s.shouldClose, slot = slot,
        category = s.category,
    }
end

local function TotalWeight(items)
    local w = 0
    for _, it in pairs(items or {}) do
        w = w + (it.weight or 0) * (it.amount or 0)
    end
    return math.floor(w)
end

local function SlotsByItem(items, name)
    local out = {}
    name = tostring(name):lower()
    for slot, it in pairs(items or {}) do
        if it.name == name then out[#out + 1] = tonumber(slot) end
    end
    table.sort(out)
    return out
end

local function FirstSlotByItem(items, name)
    return SlotsByItem(items, name)[1]
end

local function FirstEmpty(items, slots)
    for i = 1, slots do
        if not items[i] then return i end
    end
end

local function DeepEqual(a, b)
    if a == b then return true end
    if type(a) ~= 'table' or type(b) ~= 'table' then return false end
    for k, v in pairs(a) do if not DeepEqual(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- stacks only merge when their metadata matches (stops mixing qualities, serials, etc.)
local function CanStack(a, b)
    return a.name == b.name and not a.unique and DeepEqual(a.info or {}, b.info or {})
end

-- cross-resource calls can turn slot keys into strings; always re-key by number
local function Normalize(items)
    local out = {}
    for key, it in pairs(items or {}) do
        if type(it) == 'table' and it.name then
            local slot = tonumber(it.slot) or tonumber(key)
            if slot then
                it.slot = slot
                it.info = type(it.info) == 'table' and it.info or {}
                out[slot] = it
            end
        end
    end
    return out
end

-- slot-keyed tables are sparse and do not survive JSON/msgpack reliably, so send a list
local function ItemList(items)
    local list = {}
    for _, it in pairs(items or {}) do list[#list + 1] = it end
    return list
end

--------------------------------------------------------------------------------
-- Containers: one view over player inventories, stashes, drops and shops.
-- rsg-core hands out a *copy* of the player on every GetPlayer call, so an
-- operation must fetch a player's container once and Commit that same table.
--------------------------------------------------------------------------------
local function GetContainer(id)
    if type(id) == 'number' then
        local Player = RSGCore.Functions.GetPlayer(id)
        if not Player then return nil end
        local ci = Player.PlayerData.charinfo
        return {
            id = id, type = 'player', player = Player,
            label = ci and ci.firstname and (ci.firstname .. ' ' .. ci.lastname) or locale('player'),
            items = Normalize(Player.PlayerData.items),
            slots = Player.PlayerData.slots or Config.PlayerSlots,
            maxWeight = Player.PlayerData.weight or Config.PlayerMaxWeight,
        }
    end
    if type(id) ~= 'string' or id == 'newdrop' then return nil end
    if not Inventories[id] and not id:find('^drop%-') and not id:find('^shop%-') then
        return API.RegisterStash(id)
    end
    return Inventories[id]
end

local ConvertCoins -- defined after AddTo / RemoveFrom

local function Commit(c)
    if c.type ~= 'shop' then ConvertCoins(c) end
    if c.type == 'player' then
        c.player.Functions.SetPlayerData('items', c.items)
    else
        if c.type == 'stash' then c.dirty = true end
        c.touched = os.time()
    end
end

local function ClientInv(c)
    return {
        id = c.id, label = c.label, type = c.type, slots = c.slots,
        maxWeight = c.maxWeight, items = ItemList(c.items),
    }
end

local function EmptyGround()
    return { id = 'newdrop', label = locale('ground'), type = 'drop', slots = Config.Drop.Slots, maxWeight = Config.Drop.MaxWeight, items = {} }
end

-- push fresh data to the owner (if a player) and everyone looking at a container
local function Refresh(id)
    local c = GetContainer(id)
    if type(id) == 'number' and c then
        local otherId = OpenInv[id]
        local other = otherId and otherId ~= 'newdrop' and GetContainer(otherId)
        TriggerClientEvent('rsg-inventory:client:refresh', id, ClientInv(c), other and ClientInv(other) or nil)
    end
    for watcher, openId in pairs(OpenInv) do
        if openId == id and watcher ~= id then
            TriggerClientEvent('rsg-inventory:client:refresh', watcher, nil, c and ClientInv(c) or false)
        end
    end
end

-- a weapon leaving the player's inventory must also leave their hands
local function CheckWeapon(src, item)
    if item and item.type == 'weapon' then
        TriggerClientEvent('rsg-inventory:client:checkWeapon', src, item.name)
    end
end

--------------------------------------------------------------------------------
-- Core add / remove on a container
--------------------------------------------------------------------------------
-- rsg-weapons expects every weapon to carry a serial and a quality
local function WeaponDefaults(s, info)
    if s and s.type == 'weapon' then
        if not info.serie then
            info.serie = tostring(RSGCore.Shared.RandomInt(2) .. RSGCore.Shared.RandomStr(3) .. RSGCore.Shared.RandomInt(1) .. RSGCore.Shared.RandomStr(2) .. RSGCore.Shared.RandomInt(3) .. RSGCore.Shared.RandomStr(4))
        end
        info.quality = tonumber(info.quality) or 100
    end
    return info
end

local function AddTo(c, name, amount, info, slot)
    local s = SharedItem(name)
    amount = math.tointeger(tonumber(amount)) or 1
    if not s or amount < 1 then return false, 'invalid_item' end
    if TotalWeight(c.items) + (s.weight or 0) * amount > c.maxWeight then return false, 'too_heavy' end
    info = type(info) == 'table' and info or {}
    slot = math.tointeger(tonumber(slot))

    if s.unique then
        local free = {}
        if slot and slot >= 1 and slot <= c.slots and not c.items[slot] then free[1] = slot end
        for i = 1, c.slots do
            if #free >= amount then break end
            if not c.items[i] and i ~= free[1] then free[#free + 1] = i end
        end
        if #free < amount then return false, 'no_space' end
        for i = 1, amount do
            c.items[free[i]] = BuildItem(s.name, 1, WeaponDefaults(s, lib.table.deepclone(info)), free[i])
        end
        return true
    end

    local probe = { name = s.name, info = info }
    local target
    if slot and slot >= 1 and slot <= c.slots then
        local cur = c.items[slot]
        if not cur or CanStack(cur, probe) then target = slot end
    end
    if not target then
        for _, sl in ipairs(SlotsByItem(c.items, s.name)) do
            if CanStack(c.items[sl], probe) then target = sl break end
        end
    end
    target = target or FirstEmpty(c.items, c.slots)
    if not target then return false, 'no_space' end

    if c.items[target] then
        c.items[target].amount = c.items[target].amount + amount
    else
        c.items[target] = BuildItem(s.name, amount, info, target)
    end
    return true
end

local function CountIn(c, name)
    local n = 0
    for _, it in pairs(c.items) do
        if it.name == name then n = n + it.amount end
    end
    return n
end

local function RemoveFrom(c, name, amount, slot)
    name = tostring(name):lower()
    amount = math.tointeger(tonumber(amount)) or 1
    if amount < 1 then return false end
    slot = math.tointeger(tonumber(slot))

    if slot then
        local it = c.items[slot]
        if not it or it.name ~= name or it.amount < amount then return false end
        it.amount = it.amount - amount
        if it.amount <= 0 then c.items[slot] = nil end
        return true
    end

    if CountIn(c, name) < amount then return false end
    local left = amount
    for _, s in ipairs(SlotsByItem(c.items, name)) do
        local it = c.items[s]
        local take = math.min(it.amount, left)
        it.amount = it.amount - take
        if it.amount <= 0 then c.items[s] = nil end
        left = left - take
        if left <= 0 then break end
    end
    return true
end

-- 100 cents -> 1 dollar (per Config.CoinConversion). Total value is unchanged,
-- so rsg-core's money-item sync sees the same balance.
function ConvertCoins(c)
    if not Config.CoinConversion then return end
    for _, pair in ipairs(Config.CoinConversion) do
        local cents = CountIn(c, pair.cent)
        local dollars = cents // 100
        if dollars > 0 and SharedItem(pair.dollar) then
            RemoveFrom(c, pair.cent, dollars * 100)
            if not AddTo(c, pair.dollar, dollars) then
                AddTo(c, pair.cent, dollars * 100) -- no room for the dollars: put the cents back
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Public API (target = player server id, or stash/drop id)
--------------------------------------------------------------------------------
--- AddItem(target, name, amount?, info?, slot?, reason?)
--- The legacy order (target, name, amount, slot, info, reason) is detected automatically.
function API.AddItem(target, name, amount, info, slot, reason)
    if type(info) ~= 'table' and (type(slot) == 'table' or type(info) == 'number' or type(info) == 'boolean') then
        info, slot = slot, info
    end
    if slot == false then slot = nil end

    local c = GetContainer(target)
    if not c then return false, 'no_inventory' end
    amount = math.tointeger(tonumber(amount)) or 1
    local ok, err = AddTo(c, name, amount, info, slot)
    if not ok then return false, err end
    Commit(c)
    Refresh(target)
    if c.type == 'player' then
        TriggerClientEvent('rsg-inventory:client:ItemBox', target, SharedItem(name), 'add', amount)
        Log('AddItem', ('%s received %sx %s (%s) [%s]'):format(GetPlayerName(target), amount, name, reason or 'unknown', GetInvokingResource() or 'rsg-inventory'))
    end
    return true
end

function API.RemoveItem(target, name, amount, slot, reason)
    local c = GetContainer(target)
    if not c or not name then return false end
    amount = math.tointeger(tonumber(amount)) or 1
    local first = FirstSlotByItem(c.items, name)
    local item = c.items[math.tointeger(tonumber(slot)) or first or -1]
    if not RemoveFrom(c, name, amount, slot) then return false end
    Commit(c)
    Refresh(target)
    if c.type == 'player' then
        if CountIn(c, tostring(name):lower()) == 0 then CheckWeapon(target, item) end
        TriggerClientEvent('rsg-inventory:client:ItemBox', target, SharedItem(name), 'remove', amount)
        Log('RemoveItem', ('%s lost %sx %s (%s) [%s]'):format(GetPlayerName(target), amount, name, reason or 'unknown', GetInvokingResource() or 'rsg-inventory'))
    end
    return true
end

function API.GetItemCount(target, name)
    local c = GetContainer(target)
    if not c then return 0 end
    if type(name) == 'table' then
        local n = 0
        for _, v in ipairs(name) do n = n + CountIn(c, tostring(v):lower()) end
        return n
    end
    return CountIn(c, tostring(name):lower())
end

--- HasItem(target, 'bread', amount?) | HasItem(target, {'a','b'}, amount?) | HasItem(target, {a=2, b=1})
function API.HasItem(target, items, amount)
    local c = GetContainer(target)
    if not c then return false end
    amount = tonumber(amount) or 1
    if type(items) == 'string' then
        return CountIn(c, items:lower()) >= amount
    elseif type(items) == 'table' then
        for k, v in pairs(items) do
            local name, need = k, v
            if type(k) == 'number' then name, need = v, amount end
            if CountIn(c, tostring(name):lower()) < need then return false end
        end
        return true
    end
    return false
end

function API.CanCarry(target, name, amount)
    local c = GetContainer(target)
    local s = SharedItem(name)
    if not c or not s then return false, 'invalid_item' end
    amount = math.tointeger(tonumber(amount)) or 1
    if amount < 1 then return false, 'invalid_item' end
    if TotalWeight(c.items) + (s.weight or 0) * amount > c.maxWeight then return false, 'too_heavy' end
    if s.unique then
        local free = 0
        for i = 1, c.slots do if not c.items[i] then free = free + 1 end end
        if free < amount then return false, 'no_space' end
    elseif not FirstSlotByItem(c.items, s.name) and not FirstEmpty(c.items, c.slots) then
        return false, 'no_space'
    end
    return true
end

function API.GetItemBySlot(target, slot)
    local c = GetContainer(target)
    return c and c.items[math.tointeger(tonumber(slot)) or -1] or nil
end

function API.GetItemByName(target, name)
    local c = GetContainer(target)
    if not c then return nil end
    local s = FirstSlotByItem(c.items, name)
    return s and c.items[s] or nil
end

function API.SetItemInfo(target, slot, info)
    local c = GetContainer(target)
    slot = math.tointeger(tonumber(slot))
    if not c or not slot or not c.items[slot] then return false end
    c.items[slot].info = type(info) == 'table' and info or {}
    Commit(c)
    Refresh(target)
    return true
end

function API.ClearInventory(target, keep)
    local c = GetContainer(target)
    if not c then return false end
    local keepSet = {}
    if type(keep) == 'string' then keepSet[keep] = true
    elseif type(keep) == 'table' then for _, k in ipairs(keep) do keepSet[k] = true end end
    for slot, it in pairs(c.items) do
        if not keepSet[it.name] then
            if c.type == 'player' then CheckWeapon(target, it) end
            c.items[slot] = nil
        end
    end
    Commit(c)
    if c.type == 'stash' then API.SaveStash(target) end
    Refresh(target)
    return true
end

function API.GetInventory(target)
    local c = GetContainer(target)
    if not c then return nil end
    if c.type == 'player' then return c.items end
    c.maxweight = c.maxWeight -- legacy field name
    return c
end

--------------------------------------------------------------------------------
-- Stashes (stored in the `inventories` table, same as the original rsg-inventory)
--------------------------------------------------------------------------------
local function LoadItems(raw)
    local out = {}
    for _, it in pairs(raw or {}) do
        local slot = type(it) == 'table' and math.tointeger(tonumber(it.slot))
        if slot and it.name and SharedItem(it.name) then
            out[slot] = BuildItem(it.name, math.tointeger(tonumber(it.amount)) or 1, it.info, slot)
        end
    end
    return out
end

local function Serialize(items)
    local out = {}
    for slot, it in pairs(items or {}) do
        out[#out + 1] = { name = it.name, amount = it.amount, info = it.info or {}, slot = tonumber(slot) }
    end
    return json.encode(out)
end

-- writes a player's current items straight to the database
local function SavePlayerItems(pd)
    if not pd or not pd.citizenid then return end
    MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { Serialize(Normalize(pd.items)), pd.citizenid })
end

local function SavePlayer(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then SavePlayerItems(Player.PlayerData) end
end

function API.RegisterStash(id, opts)
    if type(id) ~= 'string' or id == '' or #id > 100 then return nil end
    opts = opts or {}
    local inv = Inventories[id]
    if not inv then
        local row = MySQL.scalar.await('SELECT items FROM inventories WHERE identifier = ?', { id })
        inv = Inventories[id] -- another call may have loaded it while we awaited
        if not inv then
            inv = { id = id, type = 'stash', items = LoadItems(row and json.decode(row)), touched = os.time() }
            Inventories[id] = inv
        end
    end
    inv.label     = opts.label or inv.label or id
    inv.slots     = math.min(tonumber(opts.slots) or inv.slots or Config.Stash.DefaultSlots, Config.Stash.MaxSlots)
    inv.maxWeight = math.min(tonumber(opts.maxWeight) or inv.maxWeight or Config.Stash.DefaultMaxWeight, Config.Stash.MaxWeight)
    return inv
end

--- Saves a stash now (only if it changed).
function API.SaveStash(id)
    local inv = Inventories[id]
    if not inv or inv.type ~= 'stash' or not inv.dirty then return end
    inv.dirty = false
    MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = VALUES(items)',
        { id, Serialize(inv.items) })
end
local SaveStash = API.SaveStash

local function SaveAllStashes()
    for id, inv in pairs(Inventories) do
        if inv.type == 'stash' then SaveStash(id) end
    end
end

local function IsOpenByAnyone(id)
    for _, openId in pairs(OpenInv) do
        if openId == id then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Drops (memory only)
--------------------------------------------------------------------------------
function API.CreateDrop(coords, items)
    dropCount = dropCount + 1
    local id = ('drop-%d-%d'):format(os.time(), dropCount)
    Inventories[id] = {
        id = id, type = 'drop', label = locale('ground'),
        slots = Config.Drop.Slots, maxWeight = Config.Drop.MaxWeight,
        items = items or {}, coords = coords, touched = os.time(),
    }
    TriggerClientEvent('rsg-inventory:client:addDrop', -1, id, coords)
    return id
end

local function RemoveDrop(id)
    if not Inventories[id] or Inventories[id].type ~= 'drop' then return end
    Inventories[id] = nil
    TriggerClientEvent('rsg-inventory:client:removeDrop', -1, id)
    for src, openId in pairs(OpenInv) do
        if openId == id then
            OpenInv[src] = 'newdrop'
            TriggerClientEvent('rsg-inventory:client:refresh', src, nil, EmptyGround())
        end
    end
end

local function CleanupDropIfEmpty(id)
    local inv = Inventories[id]
    if inv and inv.type == 'drop' and not next(inv.items) then RemoveDrop(id) end
end

--------------------------------------------------------------------------------
-- Opening / closing
--------------------------------------------------------------------------------
local function Dist(src, coords)
    return #(GetEntityCoords(GetPlayerPed(src)) - coords)
end

local function CanAccess(src, id)
    if id == src then return true end
    if id == nil or OpenInv[src] ~= id then return false end
    if type(id) == 'number' then
        local ped = GetPlayerPed(id)
        return ped ~= 0 and Dist(src, GetEntityCoords(ped)) <= Config.GiveDistance + 2.0
    end
    if id == 'newdrop' then return true end
    local inv = Inventories[id]
    if not inv then return false end
    if inv.coords then return Dist(src, inv.coords) <= Config.Drop.OpenDistance + 3.0 end
    return true
end

local function OpenFor(src, otherId)
    local me = GetContainer(src)
    if not me then return false end
    local meta = me.player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return false end
    local other
    if otherId == 'newdrop' then
        other = EmptyGround()
    elseif otherId then
        local oc = GetContainer(otherId)
        if not oc then return false end
        other = ClientInv(oc)
    end
    OpenInv[src] = otherId
    TriggerClientEvent('rsg-inventory:client:open', src, ClientInv(me), other)
    return true
end

-- Stash and player rows are written together so a server crash can't leave an
-- item saved in both places (dupe) or in neither (loss).
local function OnClosed(src)
    local id = OpenInv[src]
    OpenInv[src] = nil
    if id then SaveStash(id) CleanupDropIfEmpty(id) end
    if PendingSave[src] then
        PendingSave[src] = nil
        SavePlayer(src)
        if type(id) == 'number' then SavePlayer(id) end -- searched player
    end
end

function API.OpenStash(src, id, opts)
    if not API.RegisterStash(id, opts) then return false end
    return OpenFor(src, id)
end

--- OpenInventory(src)  or legacy  OpenInventory(src, stashId, { label, maxweight, slots })
function API.OpenInventory(src, id, data)
    if not id then return OpenFor(src, nil) end
    if type(id) ~= 'string' then return false end
    data = data or {}
    return API.OpenStash(src, id, { label = data.label, slots = data.slots, maxWeight = data.maxweight or data.maxWeight })
end

--- Lets src search another player's inventory.
function API.OpenPlayerInventory(src, targetId)
    targetId = tonumber(targetId)
    if not targetId or targetId == src or not RSGCore.Functions.GetPlayer(targetId) then return false end
    return OpenFor(src, targetId)
end

function API.CloseInventory(src)
    OnClosed(src)
    TriggerClientEvent('rsg-inventory:client:close', src)
end

RegisterNetEvent('rsg-inventory:server:open', function(dropId)
    local src = source
    local drop = type(dropId) == 'string' and Inventories[dropId]
    if drop and drop.type == 'drop' and Dist(src, drop.coords) <= Config.Drop.OpenDistance + 1.0 then
        return OpenFor(src, dropId)
    end
    OpenFor(src, 'newdrop')
end)

RegisterNetEvent('rsg-inventory:server:close', function()
    OnClosed(source)
end)

--------------------------------------------------------------------------------
-- Move / split / swap / merge
--------------------------------------------------------------------------------
RegisterNetEvent('rsg-inventory:server:move', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local fromId = data.from == 'player' and src or data.from
    local toId   = data.to   == 'player' and src or data.to
    local fromSlot, toSlot = math.tointeger(tonumber(data.fromSlot)), math.tointeger(tonumber(data.toSlot))
    if not fromSlot or not toSlot or fromId == 'newdrop' then return end
    if not CanAccess(src, fromId) or not CanAccess(src, toId) then
        if Config.Debug then
            print(('[rsg-inventory] %s: move denied %s -> %s (open=%s)'):format(src, tostring(fromId), tostring(toId), tostring(OpenInv[src])))
        end
        return Refresh(src)
    end

    local from = GetContainer(fromId)
    if not from or not from.items[fromSlot] then return Refresh(src) end

    -- shops: shop -> own inventory buys, own inventory -> shop sells
    local toShop = type(toId) == 'string' and Inventories[toId] and Inventories[toId].type == 'shop'
    if from.type == 'shop' or toShop then
        if from.type == 'shop' and toId == src then
            Shops.Buy(src, from, fromSlot, data.amount, toSlot)
        elseif toShop and fromId == src then
            Shops.Sell(src, Inventories[toId], fromSlot, data.amount)
        end
        Refresh(src)
        return Refresh(toShop and toId or fromId)
    end

    if toId == 'newdrop' then
        toId = API.CreateDrop(GetEntityCoords(GetPlayerPed(src)), {})
        OpenInv[src] = toId
    end

    local same = fromId == toId
    local to = same and from or GetContainer(toId)
    if not to or toSlot < 1 or toSlot > to.slots or (same and fromSlot == toSlot) then return Refresh(src) end

    local item = from.items[fromSlot]
    local amount = math.tointeger(tonumber(data.amount)) or item.amount
    if amount < 1 or amount > item.amount then amount = item.amount end

    local dest = to.items[toSlot]
    local moveWeight = (item.weight or 0) * amount
    local function reject()
        Notify(src, 'too_heavy')
        if type(toId) == 'string' then CleanupDropIfEmpty(toId) end
        Refresh(src)
    end

    if not dest then
        if not same and TotalWeight(to.items) + moveWeight > to.maxWeight then return reject() end
        if amount == item.amount then
            from.items[fromSlot] = nil
            item.slot = toSlot
            to.items[toSlot] = item
        else
            item.amount = item.amount - amount
            to.items[toSlot] = BuildItem(item.name, amount, lib.table.deepclone(item.info), toSlot)
        end
    elseif CanStack(dest, item) then
        if not same and TotalWeight(to.items) + moveWeight > to.maxWeight then return reject() end
        dest.amount = dest.amount + amount
        item.amount = item.amount - amount
        if item.amount <= 0 then from.items[fromSlot] = nil end
    else
        if amount ~= item.amount then return Refresh(src) end -- only whole stacks swap
        if not same then
            local destWeight = (dest.weight or 0) * dest.amount
            if TotalWeight(to.items) - destWeight + moveWeight > to.maxWeight
            or TotalWeight(from.items) - moveWeight + destWeight > from.maxWeight then
                return reject()
            end
        end
        from.items[fromSlot], to.items[toSlot] = dest, item
        dest.slot, item.slot = fromSlot, toSlot
    end

    Commit(from)
    if not same then
        Commit(to)
        if from.type ~= 'drop' and to.type ~= 'drop' then PendingSave[src] = true end
        if from.type == 'player' and from.items[fromSlot] ~= item then CheckWeapon(fromId, item) end
        if to.type == 'player' and dest and from.items[fromSlot] == dest then CheckWeapon(toId, dest) end
        Log('Move', ('%s moved %sx %s from %s to %s'):format(GetPlayerName(src), amount, item.name, tostring(fromId), tostring(toId)))
    end

    Refresh(src)
    if fromId ~= src then Refresh(fromId) end
    if toId ~= src and toId ~= fromId then Refresh(toId) end
    if type(fromId) == 'string' then CleanupDropIfEmpty(fromId) end
end)

--------------------------------------------------------------------------------
-- Use / give
--------------------------------------------------------------------------------
--- UseItem(itemName, src, item)  (also accepts rsg-core's UseItem(src, itemName|item))
function API.UseItem(a, b, c)
    local name, src, item
    if type(a) == 'number' then
        src = a
        item = type(b) == 'table' and b or API.GetItemByName(src, b)
        name = item and item.name or b
    else
        name, src, item = a, b, c
    end
    local data = RSGCore.Functions.CanUseItem(name)
    local cb = type(data) == 'function' and data
        or (type(data) == 'table' and (rawget(data, '__cfx_functionReference') and data or data.cb or data.callback))
    if cb then cb(src, item) end
end

local weaponEvents = {
    weapon        = 'rsg-weapons:client:UseWeapon',
    weapon_thrown = 'rsg-weapons:client:UseThrownWeapon',
    equipment     = 'rsg-weapons:client:UseEquipment',
}

RegisterNetEvent('rsg-inventory:server:useItem', function(slot)
    local src = source
    local now = GetGameTimer()
    if UseCooldown[src] and now - UseCooldown[src] < Config.UseCooldown then return end
    UseCooldown[src] = now

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local meta = Player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return end

    slot = math.tointeger(tonumber(slot))
    local item = slot and Normalize(Player.PlayerData.items)[slot]
    local s = item and SharedItem(item.name)
    if not s then return end

    if weaponEvents[item.type] then
        -- backfill weapons created before serial/quality defaults existed
        if item.type == 'weapon' and (not item.info.serie or not tonumber(item.info.quality)) then
            WeaponDefaults(s, item.info) -- item is the live table from PlayerData (Normalize keeps references)
            Player.Functions.SetPlayerData('items', Player.PlayerData.items)
        end
        if item.type == 'weapon' and item.info and item.info.serie then
            MySQL.insert('INSERT IGNORE INTO player_weapons (serial, citizenid) VALUES (?, ?)', { item.info.serie, Player.PlayerData.citizenid })
        end
        TriggerClientEvent(weaponEvents[item.type], src, item)
    else
        if not RSGCore.Functions.CanUseItem(item.name) then return end
        API.UseItem(item.name, src, item)
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, s, 'use', 1)
    if s.shouldClose then API.CloseInventory(src) end
end)

RegisterNetEvent('rsg-inventory:server:give', function(targetId, slot, amount)
    local src = source
    targetId, slot = tonumber(targetId), math.tointeger(tonumber(slot))
    if not targetId or not slot or targetId == src then return end
    local now = GetGameTimer()
    if GiveCooldown[src] and now - GiveCooldown[src] < 1000 then return end
    GiveCooldown[src] = now

    local me, them = GetContainer(src), GetContainer(targetId)
    if not me or not them then return end
    local meta = me.player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return end
    if Dist(src, GetEntityCoords(GetPlayerPed(targetId))) > Config.GiveDistance then return Notify(src, 'too_far') end

    local item = me.items[slot]
    if not item then return end
    amount = math.tointeger(tonumber(amount)) or item.amount
    if amount < 1 or amount > item.amount then amount = item.amount end

    local name, info = item.name, lib.table.deepclone(item.info)
    if not AddTo(them, name, amount, info) then return Notify(src, 'target_full') end
    RemoveFrom(me, name, amount, slot)
    Commit(me) Commit(them)
    SavePlayer(src) SavePlayer(targetId) -- both sides persisted together
    if not me.items[slot] then CheckWeapon(src, item) end
    Refresh(src) Refresh(targetId)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, SharedItem(name), 'remove', amount)
    TriggerClientEvent('rsg-inventory:client:ItemBox', targetId, SharedItem(name), 'add', amount)
    TriggerClientEvent('rsg-inventory:client:giveAnim', src)
    Log('Give', ('%s gave %sx %s to %s'):format(GetPlayerName(src), amount, name, GetPlayerName(targetId)))
end)

-- right-click "Drop": put items on the ground at the player's feet
local DropCooldown = {}
RegisterNetEvent('rsg-inventory:server:drop', function(slot, amount)
    local src = source
    slot = math.tointeger(tonumber(slot))
    if not slot then return end
    local now = GetGameTimer()
    if DropCooldown[src] and now - DropCooldown[src] < 500 then return end
    DropCooldown[src] = now

    local me = GetContainer(src)
    if not me then return end
    local meta = me.player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand or meta.ishandcuffed then return end

    local item = me.items[slot]
    if not item then return end
    amount = math.tointeger(tonumber(amount)) or item.amount
    if amount < 1 or amount > item.amount then amount = item.amount end

    -- reuse the ground pile the player has open, otherwise start a new one
    local dropId = OpenInv[src]
    local drop = type(dropId) == 'string' and Inventories[dropId]
    if not drop or drop.type ~= 'drop' or not CanAccess(src, dropId) then
        dropId = API.CreateDrop(GetEntityCoords(GetPlayerPed(src)), {})
        drop = Inventories[dropId]
        if OpenInv[src] == 'newdrop' or OpenInv[src] == nil then OpenInv[src] = dropId end
    end

    local name, info = item.name, lib.table.deepclone(item.info)
    if not AddTo(drop, name, amount, info) then
        CleanupDropIfEmpty(dropId)
        return Notify(src, 'too_heavy')
    end
    RemoveFrom(me, name, amount, slot)
    Commit(me) Commit(drop)
    if not me.items[slot] then CheckWeapon(src, item) end
    Refresh(src) Refresh(dropId)
    Log('Drop', ('%s dropped %sx %s'):format(GetPlayerName(src), amount, name))
end)

lib.callback.register('rsg-inventory:server:getDrops', function()
    local list = {}
    for id, inv in pairs(Inventories) do
        if inv.type == 'drop' then list[id] = inv.coords end
    end
    return list
end)

--------------------------------------------------------------------------------
-- rsg-core bridge (rsg-core calls these by name)
--------------------------------------------------------------------------------
local function LoadInventory(_, citizenid)
    local raw = MySQL.scalar.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
    return LoadItems(raw and json.decode(raw))
end

local function SaveInventory(srcOrData, offline)
    local pd
    if offline then
        pd = srcOrData
    else
        local Player = RSGCore.Functions.GetPlayer(srcOrData)
        pd = Player and Player.PlayerData
    end
    SavePlayerItems(pd)
end

exports('LoadInventory', LoadInventory)
exports('SaveInventory', SaveInventory)
exports('GetTotalWeight', TotalWeight)
exports('GetSlotsByItem', function(items, name) return SlotsByItem(Normalize(items), name) end)
exports('GetFirstSlotByItem', function(items, name) return FirstSlotByItem(Normalize(items), name) end)

-- internals shared with server/shops.lua and server/compat.lua
InvCore = {
    API = API, Inventories = Inventories, OpenInv = OpenInv,
    GetContainer = GetContainer, Commit = Commit, Refresh = Refresh, OpenFor = OpenFor,
    AddTo = AddTo, BuildItem = BuildItem, TotalWeight = TotalWeight, SharedItem = SharedItem,
    RemoveDrop = RemoveDrop, Notify = Notify, Log = Log,
}

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    OnClosed(src)
    UseCooldown[src], GiveCooldown[src], DropCooldown[src] = nil, nil, nil
    for watcher, openId in pairs(OpenInv) do
        if openId == src then API.CloseInventory(watcher) end -- stop searches of this player
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SaveAllStashes() end
end)
AddEventHandler('txAdmin:events:serverShuttingDown', SaveAllStashes)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `inventories` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(100) NOT NULL,
            `items` LONGTEXT NULL,
            PRIMARY KEY (`identifier`),
            KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

-- housekeeping: save dirty stashes, expire old drops, unload idle stashes
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, inv in pairs(Inventories) do
            if inv.type ~= 'shop' and not IsOpenByAnyone(id) then
                local idle = now - (inv.touched or now)
                if inv.type == 'drop' then
                    if idle > Config.Drop.Lifetime * 60 then RemoveDrop(id) end
                elseif idle > Config.Stash.SaveInterval * 60 then
                    SaveStash(id)
                    if idle > Config.Stash.UnloadAfter * 60 then Inventories[id] = nil end
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Admin commands
--------------------------------------------------------------------------------
lib.addCommand('giveitem', {
    help = locale('cmd_giveitem'),
    restricted = 'group.admin',
    params = {
        { name = 'target', type = 'playerId', help = locale('cmd_param_target') },
        { name = 'item', type = 'string', help = locale('cmd_param_item') },
        { name = 'amount', type = 'number', optional = true, help = locale('cmd_param_amount') },
    },
}, function(src, args)
    local ok, err = API.AddItem(args.target, args.item, args.amount or 1, nil, nil, 'admin giveitem by ' .. src)
    if src > 0 then Notify(src, ok and 'given' or (err or 'invalid_item'), ok and 'success' or 'error') end
end)

lib.addCommand('clearinv', {
    help = locale('cmd_clearinv'),
    restricted = 'group.admin',
    params = { { name = 'target', type = 'playerId', help = locale('cmd_param_target') } },
}, function(src, args)
    API.ClearInventory(args.target)
    if src > 0 then Notify(src, 'cleared', 'success') end
end)
