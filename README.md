# rsg-inventory (rewrite)

Slot/weight inventory for RSG-Core with hotbar, persistent stashes, ground drops, shops and a legacy-compatible API.

## Install
1. Start order: `oxmysql`, `ox_lib`, `rsg-core`, then `rsg-inventory`.
2. Item images go in `html/images/` (same PNGs as the original rsg-inventory).
3. The `inventories` and `shop_stock` tables are created automatically if missing (see `install.sql`).

Player items stay in `players.inventory` and stashes in `inventories`, so existing data loads as-is.

## Controls
| Input | Action |
|---|---|
| `I` | Open / close |
| `Z` | Show hotbar |
| `1`–`5` | Use hotbar slot |
| Drag | Move / swap / merge (amount box, `0` = whole stack) |
| Shift-drag | Move half a stack |
| Ctrl-click | Quick move to the other panel |
| Right-click | Options menu: Use, Give, Drop, Move to / Take, Split, Buy / Sell, Copy serial (each with One / Half / All / Amount…) |
| Double-click | Use |
| Drag onto **Use** / **Give** | Use, or give to the nearest player |

Opening near a drop shows it; otherwise the right panel is the ground and dropping items there creates a bag.
Category chips above each grid filter it by the item's `category` (from rsg-core shared items); they only appear when an inventory holds more than one category. Rename categories with `Config.CategoryLabels`.
Every 100 cents (and blood cents) in an inventory is automatically exchanged for 1 dollar (`Config.CoinConversion`).
Stacks only merge when their metadata (`info`) matches, so different qualities or serials stay separate.

## Saving & crash safety
Player items are saved by rsg-core (on logout / every `UpdateInterval`). In addition, whenever a player moves items into or out of a stash or another player, their inventory is written to the database at the same moment the stash is saved (on close or disconnect). Gives save both players immediately. A server crash therefore can't leave an item saved in two places or in none.

## Server exports
`target` = player server id (number) or stash/drop id (string).

| Export | Returns |
|---|---|
| `AddItem(target, name, amount?, info?, slot?, reason?)` | `ok, err` (`too_heavy` / `no_space` / `invalid_item`) |
| `RemoveItem(target, name, amount?, slot?, reason?)` | `ok` |
| `HasItem(target, 'name' \| {'a','b'} \| {a = 2}, amount?)` | `bool` |
| `GetItemCount(target, name \| {names})` | `number` |
| `CanCarry(target, name, amount?)` | `ok, err` |
| `GetItemBySlot(target, slot)` / `GetItemByName(target, name)` | item |
| `SetItemInfo(target, slot, info)` | `ok` |
| `GetInventory(target)` | player items, or the stash table |
| `ClearInventory(target, keep?)` | `ok` |
| `RegisterStash(id, {label, slots, maxWeight})` / `SaveStash(id)` | |
| `OpenStash(src, id, opts?)` | `ok` |
| `OpenInventory(src, id?, {label, maxweight, slots}?)` | `ok` |
| `OpenPlayerInventory(src, targetId)` | `ok` (search another player) |
| `CloseInventory(src)` | |
| `CreateDrop(coords, items?)` | drop id |
| `UseItem(itemName, src, item)` | |

AddItem also accepts the legacy order `(target, name, amount, slot, info, reason)`.

## Shops
```lua
exports['rsg-inventory']:CreateShop({
    name = 'general', label = 'General Store', coords = vector3(...), -- coords optional
    persistentStock = true, currency = 'cash',
    items = {
        { name = 'bread', price = 0.5, amount = 50, restock = 10, buyPrice = 0.2, maxStock = 100 },
    },
})
exports['rsg-inventory']:OpenShop(source, 'general')
```
Also `RestockShop(name, percent?)` and `DoesShopExist(name)`. Drag from the shop to buy (amount box, default 1); drag onto the shop to sell items it has a `buyPrice` for.

## Legacy compatibility (`server/compat.lua`)
`CanAddItem`, `OpenInventoryById`, `GetItemsByName`, `GetSlots`, `GetFreeWeight`, `SetInventory`, `SetItemData`, `GetItemWeight`, `CreateInventory`, `DeleteInventory`, `ClearStash`, `ForceDropItem`, plus `Player.Functions.AddItem / RemoveItem / GetItemBySlot / GetItemByName / GetItemsByName / ClearInventory / SetInventory`.

rsg-core bridge: `LoadInventory`, `SaveInventory`, `GetTotalWeight`, `GetSlotsByItem`, `GetFirstSlotByItem`.

## Client exports
`HasItem(items, amount?)`, `GetItemCount(name)`, `CloseInventory()`, `IsOpen()`.

Stashes can only be opened from the server (`OpenStash` / `OpenInventory`); there is no client event for it, so players can't open arbitrary stashes.

## Events
- Client: `rsg-inventory:client:ItemBox (item, 'add'|'remove'|'use', amount)` — shown as an ox_lib notification (no NUI popups).

## Commands
`/giveitem [id] [item] [amount]`, `/clearinv [id]` (group.admin).

## Config highlights (`shared/config.lua`)
Player fallbacks, keybinds, use cooldown, stash limits (`MaxSlots`, `MaxWeight`, `SaveInterval`, `UnloadAfter`), drop settings, give distance and shop restock cron.
