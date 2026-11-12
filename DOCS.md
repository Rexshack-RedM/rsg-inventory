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
| `drop-<time>-<n>` | `drop` | memory only, expires after `Config.Drop.Lifetime` |
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
| `OpenPlayerInventory(src, targetId)` | Search another player (within give distance) |
| `CloseInventory(src)` | |

### Other
| Export | Notes |
|---|---|
| `RegisterStash(id, opts)` / `SaveStash(id)` | See [Stashes](#5-stashes) |
| `CreateDrop(coords, items?)` | Returns drop id |
| `UseItem(itemName, src, item)` | Trigger a usable item callback |

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
| Shop stock (persistent) | Every `ShopRestockMinutes`, on resource stop, on txAdmin shutdown |
| Drops | Never (memory only) |

Housekeeping runs every minute: saves idle dirty stashes, unloads stashes idle for `UnloadAfter` minutes, removes drops older than `Drop.Lifetime`.

> Developer note: rsg-core returns a copy of the player on each `GetPlayer`. Inside the inventory a player container is fetched once and committed once per operation — if you modify items yourself, use the exports rather than editing `PlayerData.items`.

## 11. Security model

- All moves, gives, drops, uses, buys and sells are validated on the server.
- A player can only touch their own inventory and the one container the server opened for them.
- Distance checks: other players (`GiveDistance`), drops (`Drop.OpenDistance`), shops with coords (10 m).
- Dead, last stand and handcuffed players can't open, use, give or drop.
- Cooldowns on use (`UseCooldown`), give (1 s), drop (0.5 s) and shop actions.
- Amounts are integer-checked and clamped; shop buys limited to 1000 per action.
- Stashes can only be opened by server exports.
- Stash action buttons: the server only accepts an action id registered on the stash the player has open (1 s cooldown) and passes it on as a local server event; the click carries no other client data.
- Actions are logged to `rsg-log` (`playerinventory`).

**Your responsibility:** check job / ownership / distance in your own script *before* calling `OpenStash`, `OpenShop` or `OpenPlayerInventory`.

## 12. Database

Created automatically on start (also in `install.sql`):

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

Player items use the existing `players.inventory` column.

## 13. Server owner guide

- **Adding items:** define them in rsg-core shared items (with `category` for filtering) and add the PNG to `html/images/`.
- **Bigger player inventory:** set slots/weight in rsg-core; the config values are only fallbacks.
- **Change keys:** edit `Config.Keys` with RedM control hashes.
- **Disable coin exchange:** `Config.CoinConversion = false`.
- **Translating:** edit or add files in `locales/`; set the language with `setr rsg:locale "de"`.
- **Wiping a stash:** `DELETE FROM inventories WHERE identifier = 'house_12';` while it isn't loaded, or use `ClearStash('house_12')` in-game.
- **Debugging rejected moves:** set `Config.Debug = true` and watch the server console.

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

---

Support: https://buymeacoffee.com/rexshack
