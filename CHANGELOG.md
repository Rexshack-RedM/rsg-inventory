# Changelog

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
