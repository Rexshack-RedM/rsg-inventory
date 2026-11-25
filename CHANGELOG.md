# Changelog

## 3.5.1

### Fixed
- Admin stash browser search no longer reports "Nothing found" when typing quickly (list throttle 150 ms).
- The open key no longer closes the inventory while the amount, give or trash window is open.

### Docs
- DOCS.md: client events table, key-mapping command names and a client example.

## 3.5.0

### Added
- **Stack and carry limits:** `Config.ItemLimits.MaxStack` (most per slot; the rest goes to the next slot, sorting and moving respect it) and `MaxCarry` (most a player can hold; buying, giving, moving and Take all respect it). New notification `carry_limit`.
- **Locked stashes:** `OpenStash` / `RegisterStash` accept `access = { citizenids, jobs = { name = minGrade }, gangs = { name = minGrade }, ace }` and `owner = citizenid`. `OpenStash` returns `false, 'no_access'` and the player is told.
- **Durability:** new exports `AdjustQuality`, `DamageItem` and `RepairItem` change one item's `info.quality` (a stack is split first); optional removal at 0.
- **Take all** button for stashes and ground piles (`rsg-inventory:server:takeAll`, checked and logged like a normal move).
- **Equipped marker** for the weapon in the ped's hands (inventory and hotbar).
- **Shop pays** line in the item tooltip while a shop is open (buy price scaled by quality); quality shows as a percentage.
- **Admin stash browser** `/stashes`: search every stash, read its history, open it (admin only, logged).
- `Config.ShopDistance` (was a hardcoded 10 m).

### Changed
- The open key now toggles the inventory through the key mapping, so a **rebound key closes it too**. The NUI no longer hardcodes `I`; it only closes on Esc / Tab, plus the default key when the mapping cannot fire (`Config.AllowPushToTalkWhileOpen = false` or `UseKeyMapping = false`). Typing in a text box never triggers it.
- Removing a capacity bonus now also puts **overweight** items on the ground (it only handled lost slots before).
- `Config.Drop.Persist` now defaults to `true`, so dropped items and cash survive a restart.
- Shop stock is saved with one multi-row query per 100 items instead of one query each.
- 10 new locale keys in all 11 languages.

## 3.4.1

### Fixed
- **Numeric-string targets:** `AddItem('12', ...)` and the other exports no longer create a stash called `"12"` (items were silently saved into it). A numeric string is now the player with that id.
- **Shops:** calling `CreateShop` again for a persistent shop no longer resets its stock to the boot-time snapshot; live stock is kept, and saved stock refreshes the cache.
- **HasItem:** `{ item = <non-number> }` requirements no longer throw.
- **CreateDrop:** coordinates passed as a plain table are converted (a table used to break the drop sync loop for everyone); invalid coordinates return `nil`.
- `rsg-inventory:server:syncDrops` has a 2 s cooldown (a client could force a full resend in a loop).

### Changed
- Dropping next to an existing pile adds to it instead of creating another prop (`Config.Drop.MergeDistance`, default `1.5`). A full pile falls back to a new one.
- Move cooldown is now `Config.MoveCooldown` (default `100` ms, was `50`) to cut database writes from spam-clicking.
- New `Config.LogItems` (default `true`) to silence the per-call AddItem / RemoveItem log entries.
- Weapon serials are written to `player_weapons` once per session instead of on every use; `FirstSlotByItem` no longer builds and sorts a table.

## 3.4.0

### Added
- **Rebindable keys:** open (`I`), hotbar (`Z`) and slots (`1`-`5`) are registered with rsg-core `RegisterKey`, so players can rebind them in the game's key settings. New `Config.UseKeyMapping`, `Config.MappedKeys` and `Config.BlockNativeControls`; new locale keys `key_open`, `key_hotbar`, `key_slot` in all 11 languages.

### Changed
- Requires rsg-core 3.5.0 or newer. With `Config.UseKeyMapping = false` the old control-hash polling still works.
- The per-frame loop now only blocks the native satchel menu and weapon quick-select (a key mapping does not stop those). Set `Config.BlockNativeControls = false` to remove it.

## 3.3.0

### Added
- **Give with a player picker:** Give lists the players within `Config.GiveDistance` (character name, server ID, distance), then asks for the quantity and a confirmation. The list refreshes while open, and the choice is cancelled if the player leaves range or disconnects. New `Config.GiveMaxPlayers`.
- **Trash:** right-click > Trash permanently deletes items after a warning and confirmation. New `Config.Trash.Enabled`.
- **Search box and Sort button** on every panel (Sort merges stacks and orders by category; the hotbar keeps its order).
- **Capacity bonuses:** `AddCapacityBonus`, `RemoveCapacityBonus`, `GetCapacityBonus` for satchels, horses and wagons. Overflow moves to free slots or onto the ground.
- **Nearby drop sync:** drops are only sent to players within `Config.Drop.SyncDistance`. Optional drop persistence across restarts (`Config.Drop.Persist`).
- **Stash history:** who put or took what, `GetStashHistory` export and `/stashlog`.
- **Admin viewer:** `/viewinv [id]`.
- **Item decay:** optional quality loss over time with removal at 0 (`Config.Decay`, off by default).
- **Automatic database setup** (`Config.AutoDatabase`); `install.sql` kept for manual install.
- Stash action buttons for scripts, and new locale strings in all 10 languages.

### Changed
- Give, Trash, drop, move and sell refuse an invalid quantity instead of widening it to the whole stack.
- Give validates the recipient, distance, item name and quantity on the server, with a 1 s cooldown.
- Drop sync builds the drop list once per tick instead of once per player.
- ox_lib is no longer required; locales load through rsg-core.
- `DeleteInventory` now also deletes the stash row from the database.
- Re-registering a shop updates its coordinates and currency; `OpenShop` returns the real result.

### Fixed
- Move cooldown and incapacitated checks (dead, last stand, handcuffed players can no longer move items).
- Empty ground piles created by rejected moves.
- Several smaller issues found in the audit (unused client code, loop variable errors, stale shop stock handling).

### Documentation
- `README.md` and `DOCS.md` rewritten: configuration reference, commands, events and callbacks, security model, examples.

### Documentation
- `DOCS.md`: added a generated technical reference (dependencies, database, configuration, exports, callbacks, events, commands, items, locales) with code examples, read straight from the source.

