Config = {}

Config.ItemBox       = true     -- show the item image box when items are added / removed / used
Config.ItemBoxPosition = 'right' -- 'top', 'bottom', 'top-left', 'top-right', 'bottom-left', 'bottom-right', 'left', 'right'
Config.Notifications = true     -- rsg-core notifications for rejected actions (too heavy, no money, too far...)
Config.ItemNotifications = false -- also show an rsg-core toast for every item added / removed / used
Config.Debug          = false    -- print why moves / shop purchases are rejected to the server console
Config.AutoDatabase   = true     -- create the database tables on start; set false to import install.sql manually

Config.ImagePath      = 'nui://rsg-inventory/html/images/' -- item images folder

-- Player defaults (fallbacks if rsg-core PlayerData has no slots/weight)
Config.PlayerSlots    = 25
Config.PlayerMaxWeight = 35000
Config.HotbarSlots    = 5        -- first N slots are the hotbar

-- Keybinds
-- Rebindable keys: registered with rsg-core RegisterKey (RegisterKeyMapping). The names below are only the
-- defaults; players change them in the game's key settings. Requires rsg-core 3.5.0 or newer.
Config.UseKeyMapping = true
Config.MappedKeys = {
    Open   = 'I',                          -- open the inventory
    Hotbar = 'Z',                          -- show hotbar
    Slots  = { '1', '2', '3', '4', '5' },  -- use hotbar slot 1-5
}
-- A key mapping does not stop the game's own action on that key (satchel menu on I, weapon select on 1-5).
-- true = keep blocking those native controls (uses a small per-frame loop). false = no loop at all.
Config.BlockNativeControls = true

-- Fallback: RedM control hashes, polled every frame. Used when Config.UseKeyMapping = false,
-- and for blocking the native actions above (when Config.BlockNativeControls is true).
Config.Keys = {
    Open   = 0xC1989F95, -- I
    Hotbar = 0x26E9DC00, -- Z (show hotbar)
    Slots  = { 0xE6F612E4, 0x1CE6D9EB, 0x4F49CC4C, 0x8F9F9E58, 0xAB62E997 }, -- 1-5
}
Config.UseCooldown    = 500      -- ms between item uses
Config.MoveCooldown   = 100      -- ms between inventory moves (every move between a player and a stash writes to the database)
Config.LogItems       = true     -- send every AddItem / RemoveItem to rsg-log; false = only moves, gives, drops and trashes are logged

-- While inventory is open, block game controls but allow push-to-talk.
-- Uses SetNuiFocusKeepInput + DisableAllControlActions, then re-enables only these.
-- Keymapped voice (e.g. pma-voice RegisterKeyMapping) also works with KeepInput.
-- Add extra control hashes here if your voice resource uses a control instead of a keybind.
Config.AllowPushToTalkWhileOpen = true
Config.PushToTalkControls = {
    0x4BC9DABB, -- INPUT_PUSH_TO_TALK (common)
}

-- Stashes
Config.Stash = {
    DefaultSlots     = 50,
    DefaultMaxWeight = 1000000,
    MaxSlots         = 300,      -- upper clamp for any stash
    MaxWeight        = 10000000,
    SaveInterval     = 5,        -- minutes idle before a changed stash is saved
    UnloadAfter      = 30,       -- minutes idle before a stash is dropped from memory
    History          = true,     -- log who put / took what in every stash (table inventory_stash_log)
    HistoryDays      = 14,       -- days of stash history to keep
}

-- Ground drops
Config.Drop = {
    Slots        = 30,
    MaxWeight    = 1000000,
    Prop         = `p_bag01x`,
    OpenDistance = 2.0,          -- distance to see a drop when opening inventory
    RenderDistance = 50.0,       -- prop spawn distance
    Lifetime     = 15,           -- minutes before an untouched drop is removed
    SyncDistance = 120.0,        -- drops are only sent to players this close (keep above RenderDistance)
    SyncInterval = 3,            -- seconds between nearby-drop updates
    MergeDistance = 1.5,         -- dropping next to an existing pile adds to it instead of making a new prop (0 = always a new pile)
    Persist      = true,         -- drops (and any cash in them) survive a restart: saved to inventory_drops, timer restarts on load. false = memory only
}

-- Extra carrying capacity granted by other resources (satchels, horses, wagons...) through
-- exports['rsg-inventory']:AddCapacityBonus. These caps apply to every single bonus.
Config.Capacity = {
    MaxBonusSlots  = 50,
    MaxBonusWeight = 100000,
}

-- Item decay: items listed here lose `rate` quality points every Interval minutes (info.quality, 100 = fresh).
-- New items start at quality 100. The quality bar, shop sell price and minQuality already use it.
-- Only online players and loaded stashes decay; weapons are never touched.
Config.Decay = {
    Enabled    = false,
    Interval   = 10,             -- minutes between decay ticks
    Stashes    = true,           -- also decay items inside loaded stashes
    Items      = {
        -- bread    = { rate = 2 },                   -- by item name
        -- raw_meat = { rate = 5, remove = true },    -- remove = delete the item once quality hits 0
    },
    Categories = {
        -- food = { rate = 1 },                       -- by rsg-core item category
    },
}

-- Carry limits (applied on top of weight and slots). Each rule: Items = { name = n }, Categories = { category = n }.
-- A `maxStack` / `maxCarry` field on the rsg-core shared item is used when no rule matches.
Config.ItemLimits = {
    MaxStack = {       -- most of one item in a single slot (extra goes to the next slot). Weapons / unique items never stack
        Default    = nil,        -- e.g. 100 = every stackable item caps at 100 per slot
        Items      = {},         -- bread = 20,
        Categories = {},         -- ammo_pistol = 50,
    },
    MaxCarry = {       -- most of one item a player can hold in total (shops, give and pick-up respect it)
        Default    = nil,
        Items      = {},         -- dynamite = 5,
        Categories = {},
    },
}

Config.ShopDistance   = 10.0    -- how far from a shop's coords a player can still buy / sell

Config.GiveDistance   = 3.0     -- players within this distance appear in the Give list (and the server re-checks it)
Config.GiveMaxPlayers = 12      -- most players shown in the Give list (closest first)

-- Trash: right-click > Trash permanently deletes items after a confirmation
Config.Trash = {
    Enabled = true,
}

-- Every 100 cents in an inventory is automatically exchanged for 1 dollar.
-- Set to false to disable. Pairs must match the money items in rsg-core.
Config.CoinConversion = {
    { cent = 'cent',       dollar = 'dollar' },
    { cent = 'blood_cent', dollar = 'blood_dollar' },
}

-- Category filter: items use the `category` field from rsg-core shared items.
-- Optional display names; any category not listed is shown prettified (ammo_pistol -> Ammo Pistol).
Config.CategoryLabels = {
    -- ammo_pistol = 'Pistol Ammo',
}

-- Shops (created by other resources via exports['rsg-inventory']:CreateShop)
Config.ShopRestockMinutes = 60 -- restock shops (and save persistent stock) every N minutes
