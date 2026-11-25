local RSGCore = exports['rsg-core']:GetCoreObject()

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local Inventories  = {}   -- [id] = { id, label, type = 'stash'|'drop'|'shop', slots, maxWeight, items, coords?, dirty?, touched? }
local OpenInv      = {}   -- [src] = secondary inventory the player has open (string id, player id or 'newdrop')
local UseCooldown  = {}
local GiveCooldown = {}
local DropCooldown = {}
local TrashCooldown = {}
local ActionCooldown = {}
local MoveCooldown = {}
local OpenCooldown = {}
local SortCooldown = {}
local NearbyCooldown = {}
local AdminView    = {}   -- [admin src] = player id being viewed remotely (/viewinv)
local CapacityBonus = {}  -- [src] = { [key] = { slots, weight } } extra capacity granted by other resources
local DropSeen     = {}   -- [src] = { [dropId] = true } drops that client currently knows about
local KnownSerials = {}  -- weapon serials already written to player_weapons this session
local SyncCooldown = {}
local TakeAllCooldown = {}
local AdminCooldown = { list = {}, act = {} }
local dropCount    = 0
local API          = {}

local function SharedItem(name)
    return name and RSGCore.Shared.Items[tostring(name):lower()]
end

local function DeepClone(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = DeepClone(v) end
    return out
end

local function Notify(src, key, kind)
    if not Config.Notifications or not src or src <= 0 then return end
    TriggerClientEvent('RSGCore:Client:Notify', src, {
        title = locale('inventory'), description = locale(key), type = kind or 'error', duration = 4000,
    })
end

local function Log(title, msg)
    TriggerEvent('rsg-log:server:CreateLog', 'playerinventory', title, 'blue', msg)
end

-- dead, in last stand or handcuffed players cannot use, move, give or drop items
local function IsIncapacitated(Player)
    local meta = Player and Player.PlayerData.metadata or {}
    return meta.isdead or meta.inlaststand or meta.ishandcuffed or false
end

local function EachConnected(fn)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src then fn(src) end
    end
end

-- decay rule for a shared item or an inventory item (nil = does not decay)
local function DecayRule(item)
    local d = Config.Decay
    if not d or not d.Enabled or not item or item.type == 'weapon' then return nil end
    return (d.Items and d.Items[item.name]) or (item.category and d.Categories and d.Categories[item.category]) or nil
end

-- Config.ItemLimits: biggest stack per slot and biggest total a player may carry, per item or category.
-- A `maxStack` / `maxCarry` field on the rsg-core shared item works too.
local function LimitFor(rule, s, field)
    if not s then return nil end
    local n = (rule and ((rule.Items and rule.Items[s.name]) or (s.category and rule.Categories and rule.Categories[s.category]) or rule.Default)) or s[field]
    n = math.tointeger(tonumber(n))
    return n and n >= 1 and n or nil
end

local function StackCap(s)
    if not s or s.unique then return nil end
    return LimitFor(Config.ItemLimits and Config.ItemLimits.MaxStack, s, 'maxStack')
end

local function CarryCap(s)
    return LimitFor(Config.ItemLimits and Config.ItemLimits.MaxCarry, s, 'maxCarry')
end

-- total extra slots / weight other resources granted to a player
local function BonusFor(src)
    local slots, weight = 0, 0
    for _, b in pairs(CapacityBonus[src] or {}) do
        slots, weight = slots + b.slots, weight + b.weight
    end
    return slots, weight
end

-- who put / took what in a stash
local function LogStash(src, stashId, action, item, amount)
    if not Config.Stash.History then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    local pd = Player and Player.PlayerData
    local ci = pd and pd.charinfo
    local name = ci and ci.firstname and (ci.firstname .. ' ' .. (ci.lastname or '')) or GetPlayerName(src) or ''
    MySQL.insert('INSERT INTO inventory_stash_log (stash, citizenid, name, action, item, amount) VALUES (?, ?, ?, ?, ?, ?)',
        { stashId, pd and pd.citizenid or '', name, action, item, amount })
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
    name = tostring(name):lower()
    local first
    for key, it in pairs(items or {}) do
        local slot = tonumber(key)
        if it.name == name and slot and (not first or slot < first) then first = slot end
    end
    return first
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
    if type(id) == 'string' and id:match('^%d+$') then id = tonumber(id) end -- '12' is player 12, never a stash called "12"
    if type(id) == 'number' then
        local Player = RSGCore.Functions.GetPlayer(id)
        if not Player then return nil end
        local ci = Player.PlayerData.charinfo
        local bonusSlots, bonusWeight = BonusFor(id)
        return {
            id = id, type = 'player', player = Player,
            label = ci and ci.firstname and (ci.firstname .. ' ' .. ci.lastname) or locale('player'),
            items = Normalize(Player.PlayerData.items),
            slots = (Player.PlayerData.slots or Config.PlayerSlots) + bonusSlots,
            maxWeight = (Player.PlayerData.weight or Config.PlayerMaxWeight) + bonusWeight,
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
        if c.type == 'stash' or c.type == 'drop' then c.dirty = true end
        c.touched = os.time()
    end
end

-- Stash access rules: { citizenids = { 'ABC123' }, jobs = { police = 0 }, gangs = { vagos = 2 }, ace = 'group.admin' }
-- (jobs / gangs map a name to the minimum grade level). Any matching rule grants access; a rules table that
-- matches nobody locks the stash for everyone. `owner = citizenid` is shorthand for one citizenid.
local function SanitizeAccess(access, owner)
    if access == false or (access == nil and owner == nil) then return nil end
    local out = { citizenids = {}, jobs = {}, gangs = {} }
    local function add(cid)
        if type(cid) == 'string' and cid ~= '' and #cid <= 50 then out.citizenids[#out.citizenids + 1] = cid end
    end
    local function ranks(into, from)
        if type(from) ~= 'table' then return end
        for k, v in pairs(from) do
            if type(k) == 'string' then into[k] = math.tointeger(tonumber(v)) or 0
            elseif type(v) == 'string' then into[v] = 0 end
        end
    end
    add(owner)
    if type(access) == 'table' then
        add(access.owner)
        for _, cid in ipairs(type(access.citizenids) == 'table' and access.citizenids or {}) do add(cid) end
        ranks(out.jobs, access.jobs)
        ranks(out.gangs, access.gangs)
        if type(access.ace) == 'string' and access.ace ~= '' then out.ace = access.ace end
    end
    return out
end

local function HasStashAccess(src, access)
    if not access then return true end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end
    local pd = Player.PlayerData
    for _, cid in ipairs(access.citizenids) do
        if cid == pd.citizenid then return true end
    end
    local job, gang = pd.job, pd.gang
    if job and access.jobs[job.name] and (tonumber(job.grade and job.grade.level) or 0) >= access.jobs[job.name] then return true end
    if gang and access.gangs[gang.name] and (tonumber(gang.grade and gang.grade.level) or 0) >= access.gangs[gang.name] then return true end
    return access.ace ~= nil and IsPlayerAceAllowed(src, access.ace) or false
end

-- Extra header buttons a script can give a stash: { { id = 'sort', label = 'Sort' }, ... } (max 3)
local function SanitizeActions(actions)
    if type(actions) ~= 'table' then return nil end
    local out = {}
    for _, a in ipairs(actions) do
        if #out >= 3 then break end
        if type(a) == 'table' and type(a.id) == 'string' and #a.id <= 32 and a.id:match('^[%w_%-]+$')
            and type(a.label) == 'string' and a.label ~= '' and #a.label <= 64 then
            out[#out + 1] = { id = a.id, label = a.label }
        end
    end
    return #out > 0 and out or nil
end

local function ClientInv(c)
    return {
        id = c.id, label = c.label, type = c.type, slots = c.slots,
        maxWeight = c.maxWeight, items = ItemList(c.items),
        actions = c.type == 'stash' and c.actions or nil,
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

local function CountIn(c, name)
    local n = 0
    for _, it in pairs(c.items) do
        if it.name == name then n = n + it.amount end
    end
    return n
end

-- adds `amount` of a stack-capped item: tops up matching stacks first, then fills empty slots. All or nothing.
local function AddCapped(c, s, amount, info, slot, cap)
    local probe = { name = s.name, info = info }
    local plan, used, left = {}, {}, amount
    local function try(sl)
        if left <= 0 or used[sl] then return end
        local cur = c.items[sl]
        if cur then
            if CanStack(cur, probe) and cur.amount < cap then
                local put = math.min(left, cap - cur.amount)
                plan[#plan + 1] = { sl, put }
                used[sl], left = true, left - put
            end
        else
            local put = math.min(left, cap)
            plan[#plan + 1] = { sl, put }
            used[sl], left = true, left - put
        end
    end
    if slot and slot >= 1 and slot <= c.slots then try(slot) end
    for _, sl in ipairs(SlotsByItem(c.items, s.name)) do try(sl) end
    for i = 1, c.slots do
        if left <= 0 then break end
        try(i)
    end
    if left > 0 then return false, 'no_space' end
    for _, p in ipairs(plan) do
        local cur = c.items[p[1]]
        if cur then cur.amount = cur.amount + p[2] else c.items[p[1]] = BuildItem(s.name, p[2], DeepClone(info), p[1]) end
    end
    return true
end

local function AddTo(c, name, amount, info, slot)
    local s = SharedItem(name)
    amount = math.tointeger(tonumber(amount)) or 1
    if not s or amount < 1 then return false, 'invalid_item' end
    if TotalWeight(c.items) + (s.weight or 0) * amount > c.maxWeight then return false, 'too_heavy' end
    if c.type == 'player' then
        local carry = CarryCap(s)
        if carry and CountIn(c, s.name) + amount > carry then return false, 'carry_limit' end
    end
    info = type(info) == 'table' and info or {}
    if info.quality == nil and DecayRule(s) then
        info = DeepClone(info)
        info.quality = 100 -- decaying items start fresh
    end
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
            c.items[free[i]] = BuildItem(s.name, 1, WeaponDefaults(s, DeepClone(info)), free[i])
        end
        return true
    end

    local cap = StackCap(s)
    if cap then return AddCapped(c, s, amount, info, slot, cap) end

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
        if Config.LogItems ~= false then Log('AddItem', ('%s received %sx %s (%s) [%s]'):format(GetPlayerName(target), amount, name, reason or 'unknown', GetInvokingResource() or 'rsg-inventory')) end
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
        if Config.LogItems ~= false then Log('RemoveItem', ('%s lost %sx %s (%s) [%s]'):format(GetPlayerName(target), amount, name, reason or 'unknown', GetInvokingResource() or 'rsg-inventory')) end
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
            if CountIn(c, tostring(name):lower()) < (tonumber(need) or 1) then return false end
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
    if c.type == 'player' then
        local carry = CarryCap(s)
        if carry and CountIn(c, s.name) + amount > carry then return false, 'carry_limit' end
    end
    local cap = StackCap(s)
    if s.unique then
        local free = 0
        for i = 1, c.slots do if not c.items[i] then free = free + 1 end end
        if free < amount then return false, 'no_space' end
    elseif cap then
        local probe = { name = s.name, info = DecayRule(s) and { quality = 100 } or {} }
        local room = 0
        for _, sl in ipairs(SlotsByItem(c.items, s.name)) do
            local it = c.items[sl]
            if CanStack(it, probe) then room = room + math.max(0, cap - it.amount) end
        end
        for i = 1, c.slots do if not c.items[i] then room = room + cap end end
        if room < amount then return false, 'no_space' end
    elseif not FirstEmpty(c.items, c.slots) then
        -- no empty slot: only OK if a plain (no metadata) stack exists to merge into
        local probe = { name = s.name, info = DecayRule(s) and { quality = 100 } or {} }
        local canMerge = false
        for _, sl in ipairs(SlotsByItem(c.items, s.name)) do
            if CanStack(c.items[sl], probe) then canMerge = true break end
        end
        if not canMerge then return false, 'no_space' end
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

--- AdjustQuality(target, slot, delta, removeAtZero?) -> ok, newQuality, slot
--- Changes info.quality (0-100) of ONE item. A stack is split first so only one unit is damaged / repaired.
function API.AdjustQuality(target, slot, delta, removeAtZero)
    local c = GetContainer(target)
    slot, delta = math.tointeger(tonumber(slot)), tonumber(delta)
    local it = c and slot and c.items[slot]
    if not it or not delta or delta ~= delta then return false end
    local q = tonumber(it.info and it.info.quality) or 100
    local nq = math.max(0, math.min(100, q + delta))
    if nq == q then return true, q, slot end
    if it.amount > 1 then
        local free = FirstEmpty(c.items, c.slots)
        if not free then return false, 'no_space' end
        it.amount = it.amount - 1
        it = BuildItem(it.name, 1, DeepClone(it.info), free)
        c.items[free], slot = it, free
    end
    local info = DeepClone(it.info or {})
    info.quality = nq
    it.info = info
    if removeAtZero and nq <= 0 then
        c.items[slot] = nil
        if c.type == 'player' then CheckWeapon(target, it) end
    end
    Commit(c)
    Refresh(target)
    return true, nq, slot
end

--- RepairItem(target, slot, amount?) restores `amount` quality points (default: fully)
function API.RepairItem(target, slot, amount)
    return API.AdjustQuality(target, slot, math.abs(tonumber(amount) or 100))
end

--- DamageItem(target, slot, amount?, removeAtZero?) wears an item down (default 1 point)
function API.DamageItem(target, slot, amount, removeAtZero)
    return API.AdjustQuality(target, slot, -math.abs(tonumber(amount) or 1), removeAtZero)
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
    inv.slots     = math.max(1, math.min(tonumber(opts.slots) or inv.slots or Config.Stash.DefaultSlots, Config.Stash.MaxSlots))
    inv.maxWeight = math.max(1, math.min(tonumber(opts.maxWeight) or inv.maxWeight or Config.Stash.DefaultMaxWeight, Config.Stash.MaxWeight))
    if opts.actions ~= nil then inv.actions = SanitizeActions(opts.actions) end -- false / {} removes the buttons
    if opts.access ~= nil or opts.owner ~= nil then inv.access = SanitizeAccess(opts.access, opts.owner) end -- false removes the lock
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
-- Drops are only sent to players within Config.Drop.SyncDistance (instead of everyone).
local function DropInRange(src, coords)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= Config.Drop.SyncDistance
end

local function AnnounceDrop(id)
    local inv = Inventories[id]
    if not inv then return end
    EachConnected(function(src)
        local seen = DropSeen[src] or {}
        DropSeen[src] = seen
        if not seen[id] and DropInRange(src, inv.coords) then
            seen[id] = true
            TriggerClientEvent('rsg-inventory:client:addDrop', src, id, inv.coords)
        end
    end)
end

-- sends a client the drops that came into range and removes the ones that left it
local function SyncDropsFor(src, drops)
    local seen = DropSeen[src] or {}
    DropSeen[src] = seen
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local pc = GetEntityCoords(ped)
    local near = {}
    for id, inv in pairs(drops or Inventories) do
        if inv.type == 'drop' and #(pc - inv.coords) <= Config.Drop.SyncDistance then near[id] = inv.coords end
    end
    for id, coords in pairs(near) do
        if not seen[id] then
            seen[id] = true
            TriggerClientEvent('rsg-inventory:client:addDrop', src, id, coords)
        end
    end
    for id in pairs(seen) do
        if not near[id] then
            seen[id] = nil
            TriggerClientEvent('rsg-inventory:client:removeDrop', src, id)
        end
    end
end

function API.CreateDrop(coords, items)
    if type(coords) ~= 'vector3' then
        if type(coords) ~= 'table' or not tonumber(coords.x) or not tonumber(coords.y) or not tonumber(coords.z) then return nil end
        coords = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0) -- a table would crash the drop sync loop
    end
    dropCount = dropCount + 1
    local id = ('drop-%d-%d'):format(os.time(), dropCount)
    Inventories[id] = {
        id = id, type = 'drop', label = locale('ground'),
        slots = Config.Drop.Slots, maxWeight = Config.Drop.MaxWeight,
        items = items or {}, coords = coords, touched = os.time(),
    }
    Inventories[id].dirty = true
    AnnounceDrop(id)
    return id
end

local function RemoveDrop(id)
    if not Inventories[id] or Inventories[id].type ~= 'drop' then return end
    Inventories[id] = nil
    for src, seen in pairs(DropSeen) do
        if seen[id] then
            seen[id] = nil
            TriggerClientEvent('rsg-inventory:client:removeDrop', src, id)
        end
    end
    if Config.Drop.Persist then MySQL.prepare('DELETE FROM inventory_drops WHERE id = ?', { id }) end
    for src, openId in pairs(OpenInv) do
        if openId == id then
            OpenInv[src] = 'newdrop'
            TriggerClientEvent('rsg-inventory:client:refresh', src, nil, EmptyGround())
        end
    end
end

-- the closest existing ground pile within Config.Drop.MergeDistance of coords (0 / nil = never merge)
local function NearbyDrop(coords)
    local radius = tonumber(Config.Drop.MergeDistance) or 0
    if radius <= 0 then return nil end
    local best, bestDist
    for id, inv in pairs(Inventories) do
        if inv.type == 'drop' and inv.coords then
            local d = #(inv.coords - coords)
            if d <= radius and (not bestDist or d < bestDist) then best, bestDist = id, d end
        end
    end
    return best
end

local function CleanupDropIfEmpty(id)
    local inv = Inventories[id]
    if inv and inv.type == 'drop' and not next(inv.items) then RemoveDrop(id) end
end

-- optional persistence (Config.Drop.Persist): changed drops are written to inventory_drops
local function SaveDrops()
    if not Config.Drop.Persist then return end
    for id, inv in pairs(Inventories) do
        if inv.type == 'drop' and inv.dirty and next(inv.items) then
            inv.dirty = false
            MySQL.prepare('INSERT INTO inventory_drops (id, coords, items, touched) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE coords = VALUES(coords), items = VALUES(items), touched = VALUES(touched)',
                { id, json.encode({ x = inv.coords.x, y = inv.coords.y, z = inv.coords.z }), Serialize(inv.items), inv.touched or os.time() })
        end
    end
end

local function LoadDrops()
    if not Config.Drop.Persist then return end
    local ok, rows = pcall(MySQL.query.await, 'SELECT id, coords, items FROM inventory_drops')
    if not ok then
        print(('^1[rsg-inventory] could not load saved drops: %s^7'):format(tostring(rows)))
        return
    end
    local now, loaded = os.time(), 0
    for _, row in ipairs(rows or {}) do
        local c = row.coords and json.decode(row.coords)
        local items = LoadItems(row.items and json.decode(row.items))
        if c and c.x and next(items) then
            Inventories[row.id] = {
                id = row.id, type = 'drop', label = locale('ground'),
                slots = Config.Drop.Slots, maxWeight = Config.Drop.MaxWeight,
                items = items, coords = vector3(c.x, c.y, c.z), touched = now, dirty = true, -- lifetime restarts
            }
            loaded = loaded + 1
        else
            MySQL.prepare('DELETE FROM inventory_drops WHERE id = ?', { row.id })
        end
    end
    if loaded > 0 then print(('^2[rsg-inventory] restored %d ground drops^7'):format(loaded)) end
end

--------------------------------------------------------------------------------
-- Capacity bonuses: other resources (satchels, horses, wagons) add slots / weight
--------------------------------------------------------------------------------
-- items that no longer fit move into free slots; whatever is left goes on the ground
local function EnforceCapacity(src)
    local c = GetContainer(src)
    if not c then return end
    local over = {}
    for slot in pairs(c.items) do
        if slot > c.slots then over[#over + 1] = slot end
    end
    local excess = TotalWeight(c.items) - c.maxWeight -- a removed bonus can leave the player carrying too much
    if #over == 0 and excess <= 0 then return end
    table.sort(over)
    local dropId, dropped
    local function ground()
        if not dropId then dropId = API.CreateDrop(GetEntityCoords(GetPlayerPed(src)), {}) end
        return Inventories[dropId]
    end
    for _, slot in ipairs(over) do
        local it = c.items[slot]
        local free = FirstEmpty(c.items, c.slots)
        if free then
            c.items[slot] = nil
            it.slot = free
            c.items[free] = it
        elseif AddTo(ground(), it.name, it.amount, DeepClone(it.info)) then
            c.items[slot] = nil
            CheckWeapon(src, it)
            dropped = true
        end
    end
    if excess > 0 then -- put the surplus weight on the ground, starting with the highest slots
        local order = {}
        for slot in pairs(c.items) do order[#order + 1] = slot end
        table.sort(order, function(x, y) return x > y end)
        for _, slot in ipairs(order) do
            if excess <= 0 then break end
            local it = c.items[slot]
            local unit = it and it.weight or 0
            if it and unit > 0 then
                local n = math.min(it.amount, math.ceil(excess / unit))
                if AddTo(ground(), it.name, n, DeepClone(it.info)) then
                    RemoveFrom(c, it.name, n, slot)
                    excess = excess - n * unit
                    if not c.items[slot] then CheckWeapon(src, it) end
                    dropped = true
                end
            end
        end
    end
    Commit(c)
    if dropId then
        Commit(Inventories[dropId])
        CleanupDropIfEmpty(dropId)
    end
    if dropped then Notify(src, 'capacity_dropped', 'inform') end
end

--- AddCapacityBonus(src, key, slots, weight): `key` names the source (e.g. 'satchel'); calling again with
--- the same key replaces it. Bonuses live in memory only: re-apply them when the player loads / equips.
function API.AddCapacityBonus(src, key, slots, weight)
    src = tonumber(src)
    if not src or type(key) ~= 'string' or key == '' or not RSGCore.Functions.GetPlayer(src) then return false end
    slots  = math.min(math.max(0, math.floor(tonumber(slots) or 0)), Config.Capacity.MaxBonusSlots)
    weight = math.min(math.max(0, math.floor(tonumber(weight) or 0)), Config.Capacity.MaxBonusWeight)
    CapacityBonus[src] = CapacityBonus[src] or {}
    CapacityBonus[src][key] = { slots = slots, weight = weight }
    EnforceCapacity(src)
    Refresh(src)
    return true
end

function API.RemoveCapacityBonus(src, key)
    src = tonumber(src)
    local set = src and CapacityBonus[src]
    if not set or not set[key] then return false end
    set[key] = nil
    if not next(set) then CapacityBonus[src] = nil end
    EnforceCapacity(src)
    Refresh(src)
    return true
end

--- GetCapacityBonus(src) -> extra slots, extra weight
function API.GetCapacityBonus(src)
    return BonusFor(tonumber(src))
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
        if ped == 0 then return false end
        if AdminView[src] == id then return true end -- /viewinv works from any distance
        return Dist(src, GetEntityCoords(ped)) <= Config.GiveDistance + 2.0
    end
    if id == 'newdrop' then return true end
    local inv = Inventories[id]
    if not inv then return false end
    if inv.coords then return Dist(src, inv.coords) <= Config.Drop.OpenDistance + 3.0 end
    return true
end

-- Stash and player rows are written together so a server crash can't leave an
-- item saved in both places (dupe) or in neither (loss).
local function OnClosed(src)
    local id = OpenInv[src]
    OpenInv[src] = nil
    AdminView[src] = nil
    if id then SaveStash(id) CleanupDropIfEmpty(id) end
end

local function OpenFor(src, otherId, bypassAccess)
    local me = GetContainer(src)
    if not me or IsIncapacitated(me.player) then return false end
    if otherId and otherId ~= 'newdrop' and not bypassAccess then
        local oc = GetContainer(otherId)
        if oc and oc.type == 'stash' and oc.access and not HasStashAccess(src, oc.access) then
            Notify(src, 'no_access')
            return false, 'no_access'
        end
    end
    if OpenInv[src] ~= nil and OpenInv[src] ~= otherId then OnClosed(src) end -- switching container: flush the old one
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

function API.OpenStash(src, id, opts)
    if not API.RegisterStash(id, opts) then return false end
    return OpenFor(src, id)
end

--- OpenInventory(src)  or legacy  OpenInventory(src, stashId, { label, maxweight, slots, actions })
function API.OpenInventory(src, id, data)
    if not id then return OpenFor(src, nil) end
    if type(id) ~= 'string' then return false end
    data = data or {}
    return API.OpenStash(src, id, { label = data.label, slots = data.slots, maxWeight = data.maxweight or data.maxWeight, actions = data.actions, access = data.access, owner = data.owner })
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
    local now = GetGameTimer()
    if OpenCooldown[src] and now - OpenCooldown[src] < 250 then return end
    OpenCooldown[src] = now
    local drop = type(dropId) == 'string' and Inventories[dropId]
    if drop and drop.type == 'drop' and Dist(src, drop.coords) <= Config.Drop.OpenDistance + 1.0 then
        return OpenFor(src, dropId)
    end
    OpenFor(src, 'newdrop')
end)

RegisterNetEvent('rsg-inventory:server:close', function()
    OnClosed(source)
end)

-- A stash header button was clicked. Only fires for an action registered on the stash the
-- player has open; the owning script listens with AddEventHandler('rsg-inventory:stashAction').
RegisterNetEvent('rsg-inventory:server:stashAction', function(actionId)
    local src = source
    local id = OpenInv[src]
    local inv = type(id) == 'string' and Inventories[id]
    if type(actionId) ~= 'string' or not inv or inv.type ~= 'stash' or not inv.actions then return end
    local now = GetGameTimer()
    if ActionCooldown[src] and now - ActionCooldown[src] < 1000 then return end
    for _, action in ipairs(inv.actions) do
        if action.id == actionId then
            ActionCooldown[src] = now
            TriggerEvent('rsg-inventory:stashAction', src, id, actionId)
            return
        end
    end
end)

--------------------------------------------------------------------------------
-- Move / split / swap / merge
--------------------------------------------------------------------------------
RegisterNetEvent('rsg-inventory:server:move', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local now = GetGameTimer()
    if MoveCooldown[src] and now - MoveCooldown[src] < (tonumber(Config.MoveCooldown) or 100) then return Refresh(src) end -- every move can write to the database
    MoveCooldown[src] = now
    if IsIncapacitated(RSGCore.Functions.GetPlayer(src)) then return Refresh(src) end
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
        if toSlot < 1 or toSlot > Config.Drop.Slots then return Refresh(src) end -- don't create an empty drop for a bad slot
        toId = API.CreateDrop(GetEntityCoords(GetPlayerPed(src)), {})
        OpenInv[src] = toId
    end

    local same = fromId == toId
    local to = same and from or GetContainer(toId)
    if not to or toSlot < 1 or toSlot > to.slots or (same and fromSlot == toSlot) then return Refresh(src) end

    local item = from.items[fromSlot]
    local amount = data.amount == nil and item.amount or math.tointeger(tonumber(data.amount))
    if not amount or amount < 1 or amount > item.amount then -- a bad quantity is refused, never widened to the whole stack
        if toId ~= fromId and type(toId) == 'string' then CleanupDropIfEmpty(toId) end
        return Refresh(src)
    end

    local dest = to.items[toSlot]
    local swapped = false
    local moveWeight = (item.weight or 0) * amount
    local function reject()
        Notify(src, 'too_heavy')
        if type(toId) == 'string' then CleanupDropIfEmpty(toId) end
        Refresh(src)
    end

    local itemShared = SharedItem(item.name)
    if not same and to.type == 'player' then -- Config.ItemLimits.MaxCarry
        local carry = CarryCap(itemShared)
        if carry and CountIn(to, item.name) + amount > carry then
            Notify(src, 'carry_limit')
            if type(toId) == 'string' then CleanupDropIfEmpty(toId) end
            return Refresh(src)
        end
    end
    local stackCap = StackCap(itemShared) -- Config.ItemLimits.MaxStack
    if not dest and stackCap and amount > stackCap then
        amount = stackCap -- a new stack never starts above the cap
        moveWeight = (item.weight or 0) * amount
    end

    if not dest then
        if not same and TotalWeight(to.items) + moveWeight > to.maxWeight then return reject() end
        if amount == item.amount then
            from.items[fromSlot] = nil
            item.slot = toSlot
            to.items[toSlot] = item
        else
            item.amount = item.amount - amount
            to.items[toSlot] = BuildItem(item.name, amount, DeepClone(item.info), toSlot)
        end
    elseif CanStack(dest, item) then
        if stackCap then
            amount = math.min(amount, stackCap - dest.amount) -- only what still fits on the stack
            if amount < 1 then return Refresh(src) end
            moveWeight = (item.weight or 0) * amount
        end
        if not same and TotalWeight(to.items) + moveWeight > to.maxWeight then return reject() end
        dest.amount = dest.amount + amount
        item.amount = item.amount - amount
        if item.amount <= 0 then from.items[fromSlot] = nil end
    else
        if amount ~= item.amount then return Refresh(src) end -- only whole stacks swap
        if not same and from.type == 'player' then -- the destination item comes to this player
            local carry = CarryCap(SharedItem(dest.name))
            local have = CountIn(from, dest.name) - (item.name == dest.name and item.amount or 0)
            if carry and have + dest.amount > carry then
                Notify(src, 'carry_limit')
                return Refresh(src)
            end
        end
        if not same then
            local destWeight = (dest.weight or 0) * dest.amount
            if TotalWeight(to.items) - destWeight + moveWeight > to.maxWeight
            or TotalWeight(from.items) - moveWeight + destWeight > from.maxWeight then
                return reject()
            end
        end
        from.items[fromSlot], to.items[toSlot] = dest, item
        dest.slot, item.slot = fromSlot, toSlot
        swapped = true
    end

    Commit(from)
    if not same then
        Commit(to)
        -- stash/player <-> player: write both rows right now so a crash can't leave the
        -- item saved in both places (dupe) or in neither (loss). Drops are memory-only.
        if from.type ~= 'drop' and to.type ~= 'drop' then
            if from.type == 'stash' then SaveStash(fromId) end
            if to.type == 'stash' then SaveStash(toId) end
            if from.type == 'player' then SavePlayer(fromId) end
            if to.type == 'player' then SavePlayer(toId) end
        end
        if from.type == 'player' and from.items[fromSlot] ~= item then CheckWeapon(fromId, item) end
        if to.type == 'player' and dest and from.items[fromSlot] == dest then CheckWeapon(toId, dest) end
        Log('Move', ('%s moved %sx %s from %s to %s'):format(GetPlayerName(src), amount, item.name, tostring(fromId), tostring(toId)))
        if from.type == 'stash' then LogStash(src, fromId, 'take', item.name, amount) end
        if to.type == 'stash' then LogStash(src, toId, 'put', item.name, amount) end
        if swapped then -- the item that was in the destination slot travels the other way
            if to.type == 'stash' then LogStash(src, toId, 'take', dest.name, dest.amount) end
            if from.type == 'stash' then LogStash(src, fromId, 'put', dest.name, dest.amount) end
        end
    end

    Refresh(src)
    if fromId ~= src then Refresh(fromId) end
    if toId ~= src and toId ~= fromId then Refresh(toId) end
    if type(fromId) == 'string' then CleanupDropIfEmpty(fromId) end
end)

--------------------------------------------------------------------------------
-- Auto-stack + sort (own inventory or the open stash)
--------------------------------------------------------------------------------
-- merges stackable stacks, then orders by category and label. Slots below `from` are left alone.
local function SortItems(c, from)
    local list = {}
    for slot, it in pairs(c.items) do
        if slot >= from then
            list[#list + 1] = it
            c.items[slot] = nil
        end
    end
    local merged = {}
    for _, it in ipairs(list) do
        local target
        local cap = not it.unique and StackCap(SharedItem(it.name))
        if not it.unique then
            for _, m in ipairs(merged) do
                if CanStack(m, it) and (not cap or m.amount < cap) then target = m break end
            end
        end
        if target then
            local put = cap and math.min(it.amount, cap - target.amount) or it.amount
            target.amount = target.amount + put
            it.amount = it.amount - put
            if it.amount > 0 then merged[#merged + 1] = it end -- what did not fit starts the next stack
        else
            merged[#merged + 1] = it
        end
    end
    table.sort(merged, function(a, b)
        local ca, cb = a.category or 'misc', b.category or 'misc'
        if ca ~= cb then return ca < cb end
        local la, lb = tostring(a.label or a.name):lower(), tostring(b.label or b.name):lower()
        if la ~= lb then return la < lb end
        if a.name ~= b.name then return a.name < b.name end
        return a.amount > b.amount
    end)
    local slot = from
    for _, it in ipairs(merged) do
        while c.items[slot] do slot = slot + 1 end
        it.slot = slot
        c.items[slot] = it
        slot = slot + 1
    end
end

RegisterNetEvent('rsg-inventory:server:sort', function(which)
    local src = source
    local now = GetGameTimer()
    if SortCooldown[src] and now - SortCooldown[src] < 1000 then return end
    SortCooldown[src] = now
    if IsIncapacitated(RSGCore.Functions.GetPlayer(src)) then return end

    local id
    if which == 'player' then
        id = src
    elseif which == 'other' then
        id = OpenInv[src]
        local inv = type(id) == 'string' and Inventories[id]
        if not inv or inv.type ~= 'stash' or not CanAccess(src, id) then return end -- stashes only
    else
        return
    end

    local c = GetContainer(id)
    if not c then return end
    SortItems(c, id == src and Config.HotbarSlots + 1 or 1) -- the hotbar keeps its order
    Commit(c)
    Refresh(src)
    if id ~= src then Refresh(id) end
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
    if not cb then return end
    local ok, err = pcall(cb, src, item)
    if not ok then
        print(('^1[rsg-inventory] usable item "%s" errored in its own resource: %s^7'):format(
            tostring(name), type(err) == 'table' and json.encode(err) or tostring(err)))
    end
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
    if not Player or IsIncapacitated(Player) then return end

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
        local serie = item.type == 'weapon' and item.info and item.info.serie
        if serie and not KnownSerials[serie] then
            KnownSerials[serie] = true
            MySQL.insert('INSERT IGNORE INTO player_weapons (serial, citizenid) VALUES (?, ?)', { serie, Player.PlayerData.citizenid })
        end
        TriggerClientEvent(weaponEvents[item.type], src, item)
    else
        if not RSGCore.Functions.CanUseItem(item.name) then return end -- not a usable item: no 'used' box
        API.UseItem(item.name, src, item)
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, s, 'use', 1)
    if s.shouldClose then API.CloseInventory(src) end
end)

--- The recipient is chosen by the player in the Give list. Everything is checked again here:
--- the recipient must still be online and in range, the slot must still hold the item the
--- player picked, and the quantity must be a whole number the player really has.
RegisterNetEvent('rsg-inventory:server:give', function(targetId, slot, amount, itemName)
    local src = source
    targetId, slot = math.tointeger(tonumber(targetId)), math.tointeger(tonumber(slot))
    if not targetId or not slot or targetId == src then return end
    local now = GetGameTimer()
    if GiveCooldown[src] and now - GiveCooldown[src] < 1000 then return end
    GiveCooldown[src] = now

    local me, them = GetContainer(src), GetContainer(targetId)
    if not me or IsIncapacitated(me.player) then return end
    if not them then return Notify(src, 'no_player') end -- chosen player left the server: cancel
    local tped = GetPlayerPed(targetId)
    if tped == 0 or Dist(src, GetEntityCoords(tped)) > Config.GiveDistance then return Notify(src, 'too_far') end

    local item = me.items[slot]
    if not item or (itemName ~= nil and item.name ~= tostring(itemName):lower()) then
        return Notify(src, 'invalid_item') -- the slot changed while the player was choosing
    end
    amount = math.tointeger(tonumber(amount))
    if not amount or amount < 1 or amount > item.amount then return Notify(src, 'invalid_amount') end

    local name, info = item.name, DeepClone(item.info)
    local added, why = AddTo(them, name, amount, info)
    if not added then return Notify(src, why == 'carry_limit' and 'carry_limit' or 'target_full') end
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

-- Give list: players within Config.GiveDistance of the caller, closest first, with their character name
RSGCore.Functions.CreateCallback('rsg-inventory:server:getNearbyPlayers', function(src, cb)
    local now = GetGameTimer()
    if NearbyCooldown[src] and now - NearbyCooldown[src] < 400 then return cb({}) end
    NearbyCooldown[src] = now

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or IsIncapacitated(Player) then return cb({}) end
    local pc = GetEntityCoords(GetPlayerPed(src))
    local list = {}
    EachConnected(function(id)
        local ped = id ~= src and GetPlayerPed(id) or 0
        if ped == 0 then return end
        local dist = #(pc - GetEntityCoords(ped))
        if dist > Config.GiveDistance then return end
        local other = RSGCore.Functions.GetPlayer(id)
        if not other then return end -- no character loaded yet
        local ci = other.PlayerData.charinfo
        list[#list + 1] = {
            id = id,
            name = ci and ci.firstname and (ci.firstname .. ' ' .. (ci.lastname or '')) or GetPlayerName(id),
            distance = math.floor(dist * 10 + 0.5) / 10,
        }
    end)
    table.sort(list, function(a, b) return a.distance < b.distance end)
    for i = #list, (tonumber(Config.GiveMaxPlayers) or 12) + 1, -1 do list[i] = nil end
    cb(list)
end)

-- right-click "Drop": put items on the ground at the player's feet
-- Trash: permanently destroys items from the player's own inventory (the client shows a confirmation first)
RegisterNetEvent('rsg-inventory:server:trash', function(slot, amount, itemName)
    local src = source
    slot = math.tointeger(tonumber(slot))
    if not slot then return end
    local now = GetGameTimer()
    if TrashCooldown[src] and now - TrashCooldown[src] < 500 then return end
    TrashCooldown[src] = now
    if not Config.Trash.Enabled then return end

    local me = GetContainer(src)
    if not me or IsIncapacitated(me.player) then return end
    local item = me.items[slot]
    if not item or (itemName ~= nil and item.name ~= tostring(itemName):lower()) then return Notify(src, 'invalid_item') end
    amount = math.tointeger(tonumber(amount))
    if not amount or amount < 1 or amount > item.amount then return Notify(src, 'invalid_amount') end

    local name = item.name
    RemoveFrom(me, name, amount, slot)
    Commit(me)
    SavePlayer(src)
    if not me.items[slot] then CheckWeapon(src, item) end
    Refresh(src)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, SharedItem(name), 'remove', amount)
    Notify(src, 'item_trashed')
    Log('Trash', ('%s trashed %sx %s'):format(GetPlayerName(src), amount, name))
end)

RegisterNetEvent('rsg-inventory:server:drop', function(slot, amount)
    local src = source
    slot = math.tointeger(tonumber(slot))
    if not slot then return end
    local now = GetGameTimer()
    if DropCooldown[src] and now - DropCooldown[src] < 500 then return end
    DropCooldown[src] = now

    local me = GetContainer(src)
    if not me or IsIncapacitated(me.player) then return end

    local item = me.items[slot]
    if not item then return end
    if amount == nil then amount = item.amount else amount = math.tointeger(tonumber(amount)) end
    if not amount or amount < 1 or amount > item.amount then return Notify(src, 'invalid_amount') end

    -- reuse the ground pile the player has open, then a pile already at their feet, otherwise start a new one
    local name, info = item.name, DeepClone(item.info)
    local dropId = OpenInv[src]
    local drop = type(dropId) == 'string' and Inventories[dropId]
    local added = drop and drop.type == 'drop' and CanAccess(src, dropId) and AddTo(drop, name, amount, info)
    if not added then
        local pc = GetEntityCoords(GetPlayerPed(src))
        dropId = NearbyDrop(pc)
        drop = dropId and Inventories[dropId]
        added = drop and AddTo(drop, name, amount, info)
        if not added then
            dropId = API.CreateDrop(pc, {})
            drop = Inventories[dropId]
            added = AddTo(drop, name, amount, info)
        end
        if not added then
            CleanupDropIfEmpty(dropId)
            return Notify(src, 'too_heavy')
        end
        if OpenInv[src] == 'newdrop' or OpenInv[src] == nil then OpenInv[src] = dropId end
    end
    RemoveFrom(me, name, amount, slot)
    Commit(me) Commit(drop)
    if not me.items[slot] then CheckWeapon(src, item) end
    Refresh(src) Refresh(dropId)
    Log('Drop', ('%s dropped %sx %s'):format(GetPlayerName(src), amount, name))
end)

-- a client (re)started: forget what it knew and send the drops around it
RegisterNetEvent('rsg-inventory:server:syncDrops', function()
    local src = source
    local now = GetGameTimer()
    if SyncCooldown[src] and now - SyncCooldown[src] < 2000 then return end
    SyncCooldown[src] = now
    DropSeen[src] = {}
    SyncDropsFor(src)
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
    RemoveDrop = RemoveDrop, Notify = Notify, Log = Log, DeepClone = DeepClone,
}

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    OnClosed(src)
    UseCooldown[src], GiveCooldown[src], DropCooldown[src], ActionCooldown[src], TrashCooldown[src] = nil, nil, nil, nil, nil
    MoveCooldown[src], OpenCooldown[src], SortCooldown[src], NearbyCooldown[src] = nil, nil, nil, nil
    AdminView[src], CapacityBonus[src], DropSeen[src], SyncCooldown[src] = nil, nil, nil, nil
    TakeAllCooldown[src], AdminCooldown.list[src], AdminCooldown.act[src] = nil, nil, nil
    for watcher, openId in pairs(OpenInv) do
        if openId == src then API.CloseInventory(watcher) end -- stop searches of this player
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SaveAllStashes()
        SaveDrops()
    end
end)
AddEventHandler('txAdmin:events:serverShuttingDown', function()
    SaveAllStashes()
    SaveDrops()
end)

-- bonuses belong to a character: they are re-applied by the resource that grants them when it loads
AddEventHandler('RSGCore:Server:OnPlayerUnload', function(src)
    CapacityBonus[src] = nil
end)

-- Tables are built on start (same schema as install.sql). Set Config.AutoDatabase = false to import install.sql by hand.
local dbReady -- nil = not finished, true / false = result
local schema = {
    [[CREATE TABLE IF NOT EXISTS `inventories` (
        `id` INT(11) NOT NULL AUTO_INCREMENT,
        `identifier` VARCHAR(100) NOT NULL,
        `items` LONGTEXT NULL,
        PRIMARY KEY (`identifier`),
        KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `shop_stock` (
        `shop_name` VARCHAR(100) NOT NULL,
        `item_name` VARCHAR(100) NOT NULL,
        `stock` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`shop_name`, `item_name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `inventory_stash_log` (
        `id` BIGINT NOT NULL AUTO_INCREMENT,
        `stash` VARCHAR(100) NOT NULL,
        `citizenid` VARCHAR(50) NOT NULL DEFAULT '',
        `name` VARCHAR(100) NOT NULL DEFAULT '',
        `action` VARCHAR(8) NOT NULL,
        `item` VARCHAR(100) NOT NULL,
        `amount` INT NOT NULL DEFAULT 1,
        `time` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `stash_idx` (`stash`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `inventory_drops` (
        `id` VARCHAR(64) NOT NULL,
        `coords` VARCHAR(120) NOT NULL,
        `items` LONGTEXT NULL,
        `touched` INT NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local function ensureDatabase()
    if not Config.AutoDatabase then return true end
    local ok, err = pcall(function()
        for _, query in ipairs(schema) do MySQL.query.await(query) end
    end)
    if not ok then
        print(('^1[rsg-inventory] could not create the database tables: %s^7'):format(tostring(err)))
        return false
    end
    print('^2[rsg-inventory] database tables ready^7')
    return true
end

-- server/shops.lua waits for this before reading shop_stock
function InvCore.WaitForDatabase()
    while dbReady == nil do Wait(50) end
    return dbReady
end

-- keep the stash history table small
local function PruneHistory()
    if not Config.Stash.History then return end
    local days = math.max(1, math.floor(tonumber(Config.Stash.HistoryDays) or 14))
    local ok, err = pcall(MySQL.query.await, ('DELETE FROM inventory_stash_log WHERE `time` < NOW() - INTERVAL %d DAY'):format(days))
    if not ok then print(('^1[rsg-inventory] could not prune the stash history: %s^7'):format(tostring(err))) end
end

MySQL.ready(function()
    dbReady = ensureDatabase()
    if dbReady then
        PruneHistory()
        LoadDrops()
    end
end)

--------------------------------------------------------------------------------
-- Item decay
--------------------------------------------------------------------------------
-- lowers info.quality of every decaying item; returns whether anything changed and the labels of removed items
local function DecayContainer(c)
    local changed, spoiled = false, nil
    for slot, it in pairs(c.items) do
        local rule = DecayRule(it)
        if rule then
            local info = DeepClone(it.info or {})
            local q = tonumber(info.quality) or 100
            local nq = math.max(0, q - (tonumber(rule.rate) or 1))
            if nq ~= q or info.quality == nil then
                info.quality = nq
                it.info = info
                changed = true
            end
            if rule.remove and nq <= 0 then
                spoiled = spoiled or {}
                spoiled[#spoiled + 1] = slot
            end
        end
    end
    local labels
    for _, slot in ipairs(spoiled or {}) do
        labels = labels or {}
        labels[#labels + 1] = c.items[slot].label
        c.items[slot] = nil
    end
    return changed or labels ~= nil, labels
end

local function ApplyDecay()
    EachConnected(function(src)
        local c = GetContainer(src)
        if not c then return end
        local changed, labels = DecayContainer(c)
        if not changed then return end
        Commit(c)
        Refresh(src)
        for _, label in ipairs(labels or {}) do
            if Config.Notifications then
                TriggerClientEvent('RSGCore:Client:Notify', src, {
                    title = locale('inventory'), description = locale('item_spoiled', label), type = 'warning', duration = 5000,
                })
            end
        end
    end)
    if Config.Decay.Stashes then
        for id, inv in pairs(Inventories) do
            if inv.type == 'stash' and DecayContainer(inv) then
                inv.dirty = true -- not Commit: decay must not keep an idle stash loaded
                Refresh(id)
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(math.max(1, tonumber(Config.Decay.Interval) or 10) * 60000)
        if Config.Decay.Enabled then ApplyDecay() end
    end
end)

-- nearby-drop sync: every player gets the drops around them and loses the ones they walked away from
CreateThread(function()
    while true do
        Wait(math.max(1, tonumber(Config.Drop.SyncInterval) or 3) * 1000)
        local drops, any = {}, false
        for id, inv in pairs(Inventories) do
            if inv.type == 'drop' then drops[id], any = inv, true end
        end
        EachConnected(function(src)
            if any or next(DropSeen[src] or {}) then SyncDropsFor(src, drops) end -- nothing on the ground and nothing to forget: skip
        end)
    end
end)

-- housekeeping: save dirty stashes, expire old drops, unload idle stashes
local minutes = 0
CreateThread(function()
    while true do
        Wait(60000)
        minutes = minutes + 1
        if minutes % 1440 == 0 then PruneHistory() end
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
        SaveDrops()
    end
end)

--------------------------------------------------------------------------------
-- Admin commands
--------------------------------------------------------------------------------
RSGCore.Commands.Add('giveitem', locale('cmd_giveitem'), {
    { name = 'id', help = locale('cmd_param_target') },
    { name = 'item', help = locale('cmd_param_item') },
    { name = 'amount', help = locale('cmd_param_amount') },
}, false, function(src, args)
    local target, item = tonumber(args[1]), args[2] and tostring(args[2]):lower()
    local amount = math.tointeger(tonumber(args[3] or 1))
    if not target or not item or not amount or amount < 1 or not RSGCore.Functions.GetPlayer(target) then
        return Notify(src, 'invalid_item')
    end
    local ok, err = API.AddItem(target, item, amount, nil, nil, 'admin giveitem by ' .. src)
    Notify(src, ok and 'given' or (err or 'invalid_item'), ok and 'success' or 'error')
end, 'admin')

RSGCore.Commands.Add('clearinv', locale('cmd_clearinv'), {
    { name = 'id', help = locale('cmd_param_target') },
}, true, function(src, args)
    local target = tonumber(args[1])
    if not target or not RSGCore.Functions.GetPlayer(target) then return Notify(src, 'no_inventory') end
    API.ClearInventory(target)
    SavePlayer(target)
    Log('ClearInventory', ('%s cleared the inventory of %s'):format(src > 0 and GetPlayerName(src) or 'console', GetPlayerName(target)))
    Notify(src, 'cleared', 'success')
end, 'admin')

--------------------------------------------------------------------------------
-- Stash history + admin inventory viewer
--------------------------------------------------------------------------------
--- GetStashHistory(stashId, limit?) -> { { citizenid, name, action = 'put'|'take', item, amount, time }, ... } newest first
function API.GetStashHistory(id, limit)
    if type(id) ~= 'string' then return {} end
    limit = math.min(math.max(math.floor(tonumber(limit) or 20), 1), 200)
    local ok, rows = pcall(MySQL.query.await,
        ('SELECT citizenid, name, action, item, amount, UNIX_TIMESTAMP(`time`) AS time FROM inventory_stash_log WHERE stash = ? ORDER BY id DESC LIMIT %d'):format(limit), { id })
    return ok and rows or {}
end

RSGCore.Commands.Add('stashlog', locale('cmd_stashlog'), {
    { name = 'stash', help = locale('cmd_param_stash') },
    { name = 'amount', help = locale('cmd_param_amount') },
}, true, function(src, args)
    local id = args[1]
    local rows = API.GetStashHistory(id, args[2])
    if #rows == 0 then return Notify(src, 'stash_log_empty') end
    print(('^3[rsg-inventory] last %d actions in stash "%s" (newest first)^7'):format(#rows, id))
    for _, r in ipairs(rows) do
        print(('  %s  %s (%s) %s %sx %s'):format(os.date('%Y-%m-%d %H:%M:%S', tonumber(r.time) or 0), r.name, r.citizenid, r.action, r.amount, r.item))
    end
    Notify(src, 'stash_log_console', 'inform')
end, 'admin')

RSGCore.Commands.Add('viewinv', locale('cmd_viewinv'), {
    { name = 'id', help = locale('cmd_param_target') },
}, true, function(src, args)
    local target = tonumber(args[1])
    if src <= 0 or not target or target == src or not RSGCore.Functions.GetPlayer(target) then
        return Notify(src, 'no_inventory')
    end
    if not API.OpenPlayerInventory(src, target) then return Notify(src, 'no_inventory') end
    AdminView[src] = target -- set after opening: opening closes any previous container and clears it
    Log('AdminView', ('%s opened the inventory of %s'):format(GetPlayerName(src), GetPlayerName(target)))
end, 'admin')

--------------------------------------------------------------------------------
-- Take all: empty the open stash / ground pile into the player's inventory as far as it fits
--------------------------------------------------------------------------------
RegisterNetEvent('rsg-inventory:server:takeAll', function()
    local src = source
    local now = GetGameTimer()
    if TakeAllCooldown[src] and now - TakeAllCooldown[src] < 1000 then return end
    TakeAllCooldown[src] = now

    local id = OpenInv[src]
    local inv = type(id) == 'string' and Inventories[id]
    if not inv or (inv.type ~= 'stash' and inv.type ~= 'drop') or not CanAccess(src, id) then return end
    local me = GetContainer(src)
    if not me or IsIncapacitated(me.player) then return end

    local order = {}
    for slot in pairs(inv.items) do order[#order + 1] = slot end
    table.sort(order)
    local took, blocked = {}, false
    for _, slot in ipairs(order) do
        local it = inv.items[slot]
        if it then
            local want = it.amount
            local n = want
            local unit = it.weight or 0
            if unit > 0 then n = math.min(n, math.floor((me.maxWeight - TotalWeight(me.items)) / unit)) end
            local carry = CarryCap(SharedItem(it.name))
            if carry then n = math.min(n, carry - CountIn(me, it.name)) end
            if n >= 1 and AddTo(me, it.name, n, DeepClone(it.info)) then
                RemoveFrom(inv, it.name, n, slot)
                took[#took + 1] = { it.name, n }
                if n < want then blocked = true end
            else
                blocked = true
            end
        end
    end
    if #took == 0 then return Notify(src, 'too_heavy') end

    Commit(me) Commit(inv)
    SavePlayer(src)
    if inv.type == 'stash' then SaveStash(id) end
    for _, t in ipairs(took) do
        if inv.type == 'stash' then LogStash(src, id, 'take', t[1], t[2]) end
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, SharedItem(t[1]), 'add', t[2])
    end
    Log('TakeAll', ('%s took %d item stacks from %s'):format(GetPlayerName(src), #took, id))
    Refresh(src)
    if inv.type == 'stash' then Refresh(id) end
    CleanupDropIfEmpty(id)
    if blocked then Notify(src, 'too_heavy', 'inform') end
end)

--------------------------------------------------------------------------------
-- Admin stash browser (/stashes): list every stash, read its history, open it in the inventory
--------------------------------------------------------------------------------
local function IsStashAdmin(src)
    return src > 0 and RSGCore.Functions.HasPermission(src, 'admin')
end

local function AdminThrottle(kind, src)
    local now = GetGameTimer()
    local last = AdminCooldown[kind][src]
    if last and now - last < (kind == 'list' and 150 or 300) then return true end -- the list is searched as you type
    AdminCooldown[kind][src] = now
    return false
end

RSGCore.Commands.Add('stashes', locale('cmd_stashes'), {}, false, function(src)
    if src > 0 then TriggerClientEvent('rsg-inventory:client:stashBrowser', src) end
end, 'admin')

RSGCore.Functions.CreateCallback('rsg-inventory:server:adminStashes', function(src, cb, filter)
    if not IsStashAdmin(src) or AdminThrottle('list', src) then return cb({}) end
    filter = type(filter) == 'string' and filter:sub(1, 40) or ''
    local like = '%' .. filter:gsub('[\\%%_]', '\\%0') .. '%'
    local ok, rows = pcall(MySQL.query.await, 'SELECT identifier FROM inventories WHERE identifier LIKE ? ORDER BY identifier LIMIT 200', { like })
    local list, seen = {}, {}
    for _, r in ipairs(ok and rows or {}) do
        seen[r.identifier] = true
        list[#list + 1] = { id = r.identifier, loaded = Inventories[r.identifier] ~= nil }
    end
    local needle = filter:lower()
    for id, inv in pairs(Inventories) do -- loaded but not saved yet
        if inv.type == 'stash' and not seen[id] and #list < 200 and (needle == '' or id:lower():find(needle, 1, true)) then
            list[#list + 1] = { id = id, loaded = true }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    cb(list)
end)

RSGCore.Functions.CreateCallback('rsg-inventory:server:adminStashHistory', function(src, cb, id)
    if not IsStashAdmin(src) or type(id) ~= 'string' or #id > 100 or AdminThrottle('act', src) then return cb({}) end
    cb(API.GetStashHistory(id, 30))
end)

RegisterNetEvent('rsg-inventory:server:adminOpenStash', function(id)
    local src = source
    if not IsStashAdmin(src) or type(id) ~= 'string' or id == '' or #id > 100 then return end
    if id:find('^drop%-') or id:find('^shop%-') or AdminThrottle('act', src) then return end
    if not Inventories[id] and not MySQL.scalar.await('SELECT 1 FROM inventories WHERE identifier = ?', { id }) then
        return Notify(src, 'no_inventory')
    end
    local inv = API.RegisterStash(id)
    if not inv then return end
    local top = 0
    for slot in pairs(inv.items) do if slot > top then top = slot end end
    if top > inv.slots then inv.slots = math.min(top, Config.Stash.MaxSlots) end -- the owning script's size is unknown here: show every item
    if OpenFor(src, id, true) then
        Log('AdminStash', ('%s opened stash %s'):format(GetPlayerName(src), id))
    end
end)
