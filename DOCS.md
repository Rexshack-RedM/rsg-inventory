# rsg-inventory — Documentation

Guide for server owners and developers. For a feature overview and installation see [README.md](README.md).

## Contents
1. [Architecture](#1-architecture)
2. [Inventory types & ids](#2-inventory-types--ids)
3. [Item format](#3-item-format)
4. [Server exports](#4-server-exports)
5. [Stashes](#5-stashes)
6. [Shops](#6-shops)
7. [Usable items & weapons](#7-usable-items--weapons)
8. [Client exports & events](#8-client-exports--events)
9. [Legacy compatibility](#9-legacy-compatibility)
10. [Saving & persistence](#10-saving--persistence)
11. [Security model](#11-security-model)
12. [Database](#12-database)
13. [Server owner guide](#13-server-owner-guide)
14. [Troubleshooting](#14-troubleshooting)
15. [Configuration reference](#15-configuration-reference)
16. [Commands](#16-commands)
17. [Events & callbacks](#17-events--callbacks)
18. [Using the inventory (player guide)](#18-using-the-inventory-player-guide)

---

## 1. Architecture

| File | Purpose |
|---|---|
| `shared/config.lua` | All configuration |
| `server/main.lua` | Core: containers, add/remove, move, give, drop, use, stashes, drops, saving, commands |
| `server/shops.lua` | Shop registration, buy / sell, stock persistence and restock |
| `server/compat.lua` | Legacy exports, `Player.Functions.*` methods, export registration |
| `server/versionchecker.lua` | Version check on start |
| `client/main.lua` | Keybinds, NUI bridge, drop props, item box, client exports |
| `html/` | NUI (index.html, style.css, app.js, images/) |
| `locales/*.json` | Translations (loaded through `@rsg-core/shared/locale.lua`) |

Every inventory — player, stash, drop or shop — is handled as a **container** with `id`, `type`, `label`, `slots`, `maxWeight` and `items`. All logic runs on the server; the client only sends requests and renders what the server returns.

## 2. Inventory types & ids

The `target` argument of the exports decides which inventory is used:

| `target` | Type | Storage |
|---|---|---|
| number (server id) | `player` | `players.inventory` (via rsg-core) |
| string (any id) | `stash` | `inventories` table, created on first use |
| `drop-<time>-<n>` | `drop` | memory (optionally `inventory_drops`, see `Config.Drop.Persist`), expires after `Config.Drop.Lifetime` |
| `shop-<name>` | `shop` | memory, stock optionally in `shop_stock` |

> Any unknown string id (that doesn't start with `drop-` or `shop-`) is treated as a stash and created automatically. Use clear, unique ids such as `house_<id>`, `gang_<name>`, `trunk_<plate>` (max 100 chars).

## 3. Item format

Items are built from `RSGCore.Shared.Items`:

```lua
{
    name = 'bread', label = 'Bread', amount = 3, slot = 4,
    info = {},               -- metadata (quality, serie, etc.)
    description = '', weight = 100, type = 'item',
    unique = false, useable = true, image = 'bread.png',
    shouldClose = true, category = 'food',
}
```

- **Stacking:** two stacks merge only when `name` matches, the item isn't `unique`, and `info` is deep-equal.
- **`category`** drives the filter chips; label it via `Config.CategoryLabels`.
- **`shouldClose`** closes the inventory after use.
- **Weapons** (`type = 'weapon'`) automatically get `info.serie` and `info.quality = 100`.
- **Decay** (`Config.Decay`): items matching an `Items[name]` or `Categories[category]` rule start with `info.quality = 100` and lose `rate` points every `Interval` minutes. With `remove = true` the item is deleted at 0 and the player is notified. Stacks of different quality don't merge. Only online players and loaded stashes decay; weapons never do.

## 4. Server exports

Called as `exports['rsg-inventory']:Name(...)`.

### Items
| Export | Returns | Notes |
|---|---|---|
| `AddItem(target, name, amount?, info?, slot?, reason?)` | `ok, err` | `err`: `too_heavy`, `no_space`, `invalid_item`. Legacy order `(target, name, amount, slot, info, reason)` also accepted |
| `RemoveItem(target, name, amount?, slot?, reason?)` | `ok` | |
| `HasItem(target, items, amount?)` | `bool` | `items`: `'name'`, `{'a','b'}` or `{ a = 2, b = 1 }` |
| `GetItemCount(target, name \| {names})` | `number` | |
| `CanCarry(target, name, amount?)` | `ok, err` | Weight + slot check |
| `GetItemBySlot(target, slot)` | item / nil | |
| `GetItemByName(target, name)` | item / nil | Lowest slot first |
| `SetItemInfo(target, slot, info)` | `ok` | Replace metadata |
| `GetInventory(target)` | table | Player items or stash table |
| `ClearInventory(target, keep?)` | `ok` | `keep`: item name or list to keep |

### Opening
| Export | Notes |
|---|---|
| `OpenInventory(src)` | Own inventory |
| `OpenInventory(src, id, { label, maxweight, slots, actions })` | Legacy stash open |
| `OpenStash(src, id, { label, slots, maxWeight, actions })` | Preferred stash open. `actions` adds header buttons, see [Stashes](#5-stashes) |
| `OpenPlayerInventory(src, targetId)` | Search another player. The viewer must stay within `GiveDistance + 2` m of them (admin `/viewinv` has no distance limit) |
| `CloseInventory(src)` | |

### Other
| Export | Notes |
|---|---|
| `RegisterStash(id, opts)` / `SaveStash(id)` | See [Stashes](#5-stashes) |
| `CreateDrop(coords, items?)` | Returns drop id |
| `UseItem(itemName, src, item)` | Run a usable item's callback (also accepts rsg-core's `UseItem(src, nameOrItem)`) |
| `GetStashHistory(stashId, limit?)` | Newest first: `{ citizenid, name, action = 'put'\|'take', item, amount, time }` (limit 1–200, default 20) |

### Capacity bonuses
| Export | Notes |
|---|---|
| `AddCapacityBonus(src, key, slots, weight)` | Adds (or replaces, same `key`) extra slots and weight for a player. Each bonus is capped by `Config.Capacity`. Returns `true` / `false` |
| `RemoveCapacityBonus(src, key)` | Removes it. Items in slots that no longer exist move to free slots; if none are free they are put on the ground and the player is told |
| `GetCapacityBonus(src)` | Returns total extra `slots, weight` |

Bonuses live in memory only and are cleared on logout / drop: the resource that grants them (a satchel script, for example) must re-apply them when the character loads or the item is equipped.

```lua
-- a wearable satchel: +10 slots and +5 kg while it is equipped
AddEventHandler('myscript:server:satchelEquipped', function(src)
    exports['rsg-inventory']:AddCapacityBonus(src, 'satchel', 10, 5000)
end)
AddEventHandler('myscript:server:satchelRemoved', function(src)
    exports['rsg-inventory']:RemoveCapacityBonus(src, 'satchel') -- overflow items move to free slots or onto the ground
end)
AddEventHandler('RSGCore:Server:OnPlayerLoaded', function(Player) -- bonuses are not saved: re-apply on login
    if exports['rsg-inventory']:GetItemCount(Player.PlayerData.source, 'satchel') > 0 then
        exports['rsg-inventory']:AddCapacityBonus(Player.PlayerData.source, 'satchel', 10, 5000)
    end
end)
```

### Examples
```lua
-- reward with metadata
local ok, err = exports['rsg-inventory']:AddItem(src, 'pelt_wolf', 1, { quality = 75 }, nil, 'hunting reward')
if not ok then
    TriggerClientEvent('RSGCore:Client:Notify', src, { description = err, type = 'error' })
end

-- crafting check
if exports['rsg-inventory']:HasItem(src, { resource_wood = 5, resource_coal = 2 }) then
    exports['rsg-inventory']:RemoveItem(src, 'resource_wood', 5)
    exports['rsg-inventory']:RemoveItem(src, 'resource_coal', 2)
    exports['rsg-inventory']:AddItem(src, 'charcoal', 1)
end

-- check before giving
if exports['rsg-inventory']:CanCarry(src, 'fullbucket', 1) then ... end
```

## 5. Stashes

```lua
-- server
RegisterNetEvent('myscript:server:openStorage', function(houseId)
    local src = source
    -- your own access / distance checks here!
    exports['rsg-inventory']:OpenStash(src, 'house_' .. houseId, {
        label = 'House Storage', slots = 60, maxWeight = 400000,
    })
end)
```

- Stashes load from the DB on first access and stay cached.
- `slots` / `maxWeight` are clamped to `Config.Stash.MaxSlots` / `MaxWeight`.
- Use `RegisterStash` to set limits without opening; `SaveStash` to force a save.
- **History:** with `Config.Stash.History`, every put / take between a player and a stash is stored in `inventory_stash_log` (stash id, citizenid, character name, action, item, amount, time). Read it with `GetStashHistory` or `/stashlog [stash] [amount]` (prints to the server console). Entries older than `Config.Stash.HistoryDays` are pruned on start and daily.
- **Sort:** players can sort an open stash from its panel; scripts can't disable it per stash.
- **There is no client event to open a stash.** Always open from the server after your own checks.

### Stash action buttons

A script can put up to 3 of its own buttons in the header of a stash (under the stash name) and react when a player clicks one.

```lua
-- server: open the stash with a button
exports['rsg-inventory']:OpenStash(src, 'crate_' .. crateId, {
    label = 'Crate',
    actions = {
        { id = 'empty', label = locale('empty_crate') }, -- id: letters, numbers, _ and - (max 32); label: max 64 bytes
    },
})

-- server: handle the click (a plain local event, NOT a net event - never RegisterNetEvent it)
AddEventHandler('rsg-inventory:stashAction', function(src, stashId, actionId)
    if actionId ~= 'empty' or not stashId:find('^crate_') then return end
    -- your own access checks, then change the stash with AddItem / RemoveItem (the open UI refreshes itself)
end)
```

- `actions` is accepted by `OpenStash`, `RegisterStash` and the legacy `OpenInventory`. It is remembered on the stash while it is loaded; pass `actions = false` to remove the buttons, leave it out to keep them unchanged.
- The label is shown as given, so translate it yourself before passing it.
- rsg-inventory only fires `rsg-inventory:stashAction` when the player currently has that stash open, the action id is registered on it, and at most once a second per player. Everything else (who may use the button, what it does) is up to your script.
- The event goes to every resource, so always check `stashId` and `actionId` belong to you.
- Stashes only: shops, drops and player searches never show action buttons.

## 6. Shops

```lua
exports['rsg-inventory']:CreateShop({
    name = 'valentine_general',
    label = 'Valentine General Store',
    coords = vector3(-322.3, 803.9, 117.9), -- optional: buying/selling only within 10m
    persistentStock = true,                 -- save stock to shop_stock
    currency = 'cash',                      -- any rsg-core money type
    items = {
        { name = 'bread', price = 0.5, amount = 50, restock = 10, buyPrice = 0.2, maxStock = 100, minQuality = 25 },
        { name = 'water', price = 0.25 },   -- no amount = unlimited stock
    },
})

exports['rsg-inventory']:OpenShop(src, 'valentine_general')
```

| Item field | Meaning |
|---|---|
| `price` | Buy price per unit (omit = not for sale) |
| `amount` | Starting / default stock (nil = unlimited) |
| `restock` | Units added every `Config.ShopRestockMinutes` (capped at `amount`) |
| `buyPrice` | Price the shop pays per unit when players sell (× quality / 100) |
| `maxStock` | Shop refuses to buy beyond this stock |
| `minQuality` | Minimum item quality the shop accepts |
| `info` | Metadata given with purchased items |

Also: `CreateShop({ shopA = {...}, shopB = {...} })` for several at once, `RestockShop(name, percent?)`, `DoesShopExist(name)`. Calling `CreateShop` again with the same name updates the shop. Purchases that fail to add the item are refunded automatically.

## 7. Usable items & weapons

Register usable items in your own resource as normal:

```lua
RSGCore.Functions.CreateUseableItem('bread', function(source, item)
    -- item = the slot's item table (with info)
end)
```

When used from the inventory, rsg-inventory calls the callback inside `pcall` — errors are printed with the item name and don't break the inventory. Non-usable items do nothing (no "used" box).

Weapon types are forwarded to rsg-weapons:

| Item `type` | Client event |
|---|---|
| `weapon` | `rsg-weapons:client:UseWeapon` |
| `weapon_thrown` | `rsg-weapons:client:UseThrownWeapon` |
| `equipment` | `rsg-weapons:client:UseEquipment` |

Weapon serials are registered in `player_weapons` on use.

## 8. Client exports & events

| Export | Returns |
|---|---|
| `HasItem(items, amount?)` | bool (client-side, from PlayerData — use the server export for anything that matters) |
| `GetItemCount(name)` | number |
| `CloseInventory()` | |
| `IsOpen()` | bool |

| Event | Use |
|---|---|
| `rsg-inventory:client:ItemBox (item, 'add'\|'remove'\|'use', amount)` | Show the NUI item box. `item` = shared item table |

```lua
TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['bread'], 'add', 2)
```

## 9. Legacy compatibility

Older RSG scripts work without changes.

**Exports:** `CanAddItem`, `OpenInventoryById`, `GetItemsByName`, `GetSlots` (→ used, free), `GetFreeWeight`, `SetInventory`, `SetItemData`, `GetItemWeight`, `CreateInventory`, `DeleteInventory`, `ClearStash`, `ForceDropItem`.

`DeleteInventory(id)` closes the stash for anyone viewing it, removes it from memory **and deletes its row from `inventories`**, so a new stash with the same id starts empty. `ClearStash(id)` only empties it.

**rsg-core bridge:** `LoadInventory`, `SaveInventory`, `GetTotalWeight`, `GetSlotsByItem`, `GetFirstSlotByItem`.

**Player methods** (added on player load and on resource restart):
```lua
Player.Functions.AddItem(item, amount, slot, info, reason)
Player.Functions.RemoveItem(item, amount, slot, reason)
Player.Functions.GetItemBySlot(slot)
Player.Functions.GetItemByName(item)
Player.Functions.GetItemsByName(item)
Player.Functions.ClearInventory(keep)
Player.Functions.SetInventory(items)
```

**Migrating from ox_lib-based versions:** `ShopRestockCycle` (cron string) is replaced by `Config.ShopRestockMinutes`. ox_lib is no longer needed.

## 10. Saving & persistence

| Data | When saved |
|---|---|
| Player items | By rsg-core (logout / `UpdateInterval`) **and** immediately on any player ↔ stash or player ↔ player move |
| Stashes | On close, after `SaveInterval` minutes idle, on resource stop, on txAdmin shutdown |
| Shop stock (persistent) | Every `ShopRestockMinutes`, on resource stop, on txAdmin shutdown (only shops whose stock changed) |
| Drops | Memory only by default. With `Config.Drop.Persist` changed drops are saved every minute, on resource stop and on txAdmin shutdown, and reloaded on start with a fresh `Drop.Lifetime` |

Housekeeping runs every minute: saves idle dirty stashes, unloads stashes idle for `UnloadAfter` minutes, removes drops older than `Drop.Lifetime`.

> Developer note: rsg-core returns a copy of the player on each `GetPlayer`. Inside the inventory a player container is fetched once and committed once per operation — if you modify items yourself, use the exports rather than editing `PlayerData.items`.

## 11. Security model

- All moves, gives, drops, uses, buys and sells are validated on the server.
- A player can only touch their own inventory and the one container the server opened for them.
- Distance checks: other players (`GiveDistance`), drops (`Drop.OpenDistance`), shops with coords (10 m).
- Dead, last stand and handcuffed players can't open, move, use, give or drop.
- **Trash:** the NUI asks for confirmation (warning modal; Enter never confirms), then sends `rsg-inventory:server:trash(slot, amount, itemName)`. The server only touches the sender's own inventory, requires a matching item name, a whole quantity between 1 and the stack size, a 500 ms cooldown, and a non-incapacitated player; the deletion is saved immediately and logged. Disable with `Config.Trash.Enabled = false`.
- **Give:** the client asks the server for the nearby list (`rsg-inventory:server:getNearbyPlayers`, rsg-core callback: `{ id, name, distance }`, closest first, within `GiveDistance`, max `GiveMaxPlayers`). The chosen id, slot, quantity and item name go to `rsg-inventory:server:give`, which re-checks that the recipient is still online and in range, that the slot still holds that item, and that the quantity is a whole number between 1 and what the player has. Anything else is rejected with a notification instead of being corrected (a bad quantity never turns into "give everything").
- Cooldowns on open (0.25 s), move (50 ms, every move can write to the database), use (`UseCooldown`), give (1 s), drop (0.5 s), trash (0.5 s), the nearby-player list (0.4 s) and shop actions.
- Amounts are integer-checked. A quantity that is not a whole number between 1 and the stack size is **refused**, never widened to the whole stack (give, trash, drop, move and sell all behave this way); leaving the amount out means "the whole stack" for move / drop. Shop buys are limited to 1000 per action.
- Stashes can only be opened by server exports.
- Sort (1 s cooldown): your own inventory or the stash you have open — never shops, ground piles or other players' inventories.
- `/viewinv` is admin-only; the admin can reach only the player they opened (any distance) and every move is logged.
- Drops are sent only to players within `Drop.SyncDistance`; opening a drop is still checked on the server (`Drop.OpenDistance`).
- Stash action buttons: the server only accepts an action id registered on the stash the player has open (1 s cooldown) and passes it on as a local server event; the click carries no other client data.
- Actions are logged to `rsg-log` (`playerinventory`).

**Your responsibility:** check job / ownership / distance in your own script *before* calling `OpenStash`, `OpenShop` or `OpenPlayerInventory`.

## 12. Database

Created automatically on start while `Config.AutoDatabase = true` (default). Set it to `false` and import `install.sql` to install the tables manually. The schema in `install.sql` and `server/main.lua` is identical:

```sql
CREATE TABLE IF NOT EXISTS `inventories` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(100) NOT NULL,
    `items` LONGTEXT NULL,
    PRIMARY KEY (`identifier`), KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `shop_stock` (
    `shop_name` VARCHAR(100) NOT NULL,
    `item_name` VARCHAR(100) NOT NULL,
    `stock` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`shop_name`, `item_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Optional tables (also created automatically, and in `install.sql`):

```sql
CREATE TABLE IF NOT EXISTS `inventory_stash_log` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `inventory_drops` (
    `id` VARCHAR(64) NOT NULL,
    `coords` VARCHAR(120) NOT NULL,
    `items` LONGTEXT NULL,
    `touched` INT NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Player items use the existing `players.inventory` column.

## 13. Server owner guide

- **Adding items:** define them in rsg-core shared items (with `category` for filtering) and add the PNG to `html/images/`.
- **Bigger player inventory:** set slots/weight in rsg-core; the config values are only fallbacks.
- **Change keys:** edit `Config.Keys` with RedM control hashes.
- **Disable coin exchange:** `Config.CoinConversion = false`.
- **Translating:** edit or add files in `locales/`; set the language with `setr rsg:locale "de"`.
- **Wiping a stash:** `DELETE FROM inventories WHERE identifier = 'house_12';` while it isn't loaded, or use `ClearStash('house_12')` in-game.
- **Debugging rejected moves:** set `Config.Debug = true` and watch the server console.
- **Enable decay:** set `Config.Decay.Enabled = true` and list items (`Items = { bread = { rate = 2 } }`) or categories (`Categories = { food = { rate = 1, remove = true } }`).
- **Keep drops across restarts:** `Config.Drop.Persist = true` (table `inventory_drops`).
- **Check who emptied a stash:** `/stashlog house_12 30` prints the last 30 actions to the server console.
- **Look at a player's inventory:** `/viewinv [id]`.
- **Extra storage from a script:** `AddCapacityBonus` / `RemoveCapacityBonus` (see [Server exports](#4-server-exports)).

## 14. Troubleshooting

| Problem | Fix |
|---|---|
| Items show no image | PNG missing in `html/images/` or `image` field mismatch |
| "Item is invalid" | Item not in rsg-core shared items (names are lower-cased) |
| Can't open inventory | Player dead / last stand / handcuffed, or rsg-core not started first |
| Shop won't sell | Player too far (coords set), out of stock, too heavy or not enough money — enable `Config.Debug` |
| Shop won't buy | No `buyPrice`, quality below `minQuality`, or `maxStock` reached |
| Stash empty after restart | Check the id is identical each time (case-sensitive) |
| Usable item errors | Error is printed with the item name — fix in the resource that registered it |
| Old script calls fail | Check the export is listed in [Legacy compatibility](#9-legacy-compatibility) |
| Drops don't appear until you walk close | They are only sent within `Config.Drop.SyncDistance`; keep it above `RenderDistance` |
| Items never decay | `Config.Decay.Enabled` is off, the item isn't in `Items` / `Categories`, or it is a weapon / in an unloaded stash |
| Stash history empty | `Config.Stash.History` is off, or the `inventory_stash_log` table is missing (`Config.AutoDatabase` / `install.sql`) |


## 15. Configuration reference

Everything lives in `shared/config.lua`.

| Option | Default | Description |
|---|---|---|
| `Config.ItemBox` | `true` | Image item box on add / remove / use |
| `Config.ItemBoxPosition` | `'right'` | `top`, `bottom`, `top-left`, `top-right`, `bottom-left`, `bottom-right`, `left`, `right` |
| `Config.Notifications` | `true` | rsg-core notifications for rejected actions |
| `Config.ItemNotifications` | `false` | Also an rsg-core toast for each item change |
| `Config.Debug` | `false` | Print why moves / purchases are rejected |
| `Config.AutoDatabase` | `true` | Build the tables on start; `false` = import `install.sql` yourself |
| `Config.ImagePath` | `nui://rsg-inventory/html/images/` | Item image folder |
| `Config.PlayerSlots`, `PlayerMaxWeight` | `25`, `35000` | Fallbacks when PlayerData has no slots / weight |
| `Config.HotbarSlots` | `5` | First N slots are the hotbar (also not moved by Sort) |
| `Config.Keys` | I, Z, 1-5 | `Open`, `Hotbar`, `Slots` (RedM control hashes) |
| `Config.UseCooldown` | `500` | ms between item uses |
| `Config.AllowPushToTalkWhileOpen`, `PushToTalkControls` | `true`, `{ 0x4BC9DABB }` | Keep push-to-talk working while the NUI has focus |
| `Config.Stash` | see file | `DefaultSlots`, `DefaultMaxWeight`, `MaxSlots`, `MaxWeight`, `SaveInterval`, `UnloadAfter`, `History`, `HistoryDays` |
| `Config.Drop` | see file | `Slots`, `MaxWeight`, `Prop`, `OpenDistance`, `RenderDistance`, `Lifetime`, `SyncDistance`, `SyncInterval`, `Persist` |
| `Config.Capacity` | `50`, `100000` | `MaxBonusSlots`, `MaxBonusWeight` per single capacity bonus |
| `Config.Decay` | disabled | `Enabled`, `Interval`, `Stashes`, `Items`, `Categories` |
| `Config.GiveDistance` | `3.0` | Players inside it appear in the Give list; checked again on the server |
| `Config.GiveMaxPlayers` | `12` | Most players listed (closest first) |
| `Config.Trash.Enabled` | `true` | Right-click Trash (permanent delete with confirmation) |
| `Config.CoinConversion` | cent to dollar, blood_cent to blood_dollar | `false` disables the 100-cents exchange |
| `Config.CategoryLabels` | `{}` | Display names for filter chips |
| `Config.ShopRestockMinutes` | `60` | Shop restock and stock-save interval |

Decay example:

```lua
Config.Decay = {
    Enabled = true,
    Interval = 10,                                  -- minutes
    Stashes = true,
    Items = { raw_meat = { rate = 5, remove = true } }, -- loses 5 quality per tick, deleted at 0
    Categories = { food = { rate = 1 } },
}
```

## 16. Commands

| Command | Permission | Description |
|---|---|---|
| `/giveitem [id] [item] [amount]` | `admin` | Give an item to a player (logged) |
| `/clearinv [id]` | `admin` | Empty a player's inventory and save it (logged) |
| `/stashlog [stash] [amount]` | `admin` | Print the last put / take actions of a stash to the server console |
| `/viewinv [id]` | `admin` | Open another player's inventory from any distance (logged, in-game only) |

Key `I` opens the inventory, `Z` shows the hotbar and `1`-`5` use the hotbar slots (all configurable in `Config.Keys`).

## 17. Events & callbacks

Events a script **listens** to:

| Event | Side | Arguments | When |
|---|---|---|---|
| `rsg-inventory:stashAction` | server (local) | `src, stashId, actionId` | A stash header button was clicked, see [Stash action buttons](#stash-action-buttons) |
| `RSGCore:Server:OnPlayerLoaded` | server | `Player` | Use it to re-apply capacity bonuses |

Events used by the NUI. They are **net events reachable by any client**, so each one validates everything again on the server. Other scripts should use the exports instead of triggering them.

| Event | Arguments | Server checks |
|---|---|---|
| `rsg-inventory:server:open` | `dropId?` | Cooldown, drop distance, not incapacitated |
| `rsg-inventory:server:close` | none | Saves the open stash, removes empty drops |
| `rsg-inventory:server:move` | `{ from, to, fromSlot, toSlot, amount? }` | Access to both containers, distance, weight, slots, whole-number quantity, shop rules |
| `rsg-inventory:server:sort` | `'player' \| 'other'` | Own inventory or the open stash only |
| `rsg-inventory:server:useItem` | `slot` | Slot holds a real item, cooldown |
| `rsg-inventory:server:give` | `targetId, slot, amount, itemName` | Recipient online and in range, slot still holds `itemName`, quantity 1..held |
| `rsg-inventory:server:trash` | `slot, amount, itemName` | Own inventory, slot still holds `itemName`, quantity 1..held, `Config.Trash.Enabled` |
| `rsg-inventory:server:drop` | `slot, amount?` | Slot, quantity, drop capacity |
| `rsg-inventory:server:stashAction` | `actionId` | Action registered on the stash the player has open |
| `rsg-inventory:server:syncDrops` | none | Resets what the client knows about drops |

Client events sent by the server: `rsg-inventory:client:open`, `refresh`, `close`, `checkWeapon`, `ItemBox`, `giveAnim`, `addDrop`, `removeDrop`.

Callback (rsg-core) used by the Give list:

```lua
-- client
RSGCore.Functions.TriggerCallback('rsg-inventory:server:getNearbyPlayers', function(list)
    -- list = { { id = 12, name = 'John Marston', distance = 1.4 }, ... } closest first,
    -- only players with a loaded character inside Config.GiveDistance, at most Config.GiveMaxPlayers
end)
```

## 18. Using the inventory (player guide)

| Input | Action |
|---|---|
| Drag | Move / swap / merge. The amount box sets the quantity (`0` or empty = whole stack) |
| Shift + drag | Move half a stack |
| Ctrl + click | Quick move to the other panel |
| Drag onto **Use** / **Give** | Use the item, or open the Give player picker with the amount box pre-filled |
| Double click | Use the item |
| Right-click | Menu: Use, Give, Drop, **Trash**, Move to / Take, Buy / Sell, Copy serial |
| Search box / Sort button | Filter a panel by name; merge stacks and order a panel by category (hotbar slots stay put) |

- **Give:** pick the recipient from the list (name, server id, distance), enter the quantity, confirm. If they walk away or leave, the choice is cancelled.
- **Trash:** choose a quantity, then confirm the warning ("This will permanently delete the item"). Enter never confirms; the item is gone for good and is logged.

---

Support the Project : https://rexshack.tebex.store/
