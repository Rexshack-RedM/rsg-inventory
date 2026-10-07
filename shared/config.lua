Config = {}

Config.ItemBox       = true     -- show the item image box when items are added / removed / used
Config.ItemBoxPosition = 'right' -- 'top', 'bottom', 'top-left', 'top-right', 'bottom-left', 'bottom-right', 'left', 'right'
Config.Notifications = false    -- set true to show ox_lib notifications from the inventory
Config.Debug          = false    -- print why moves / shop purchases are rejected to the server console

Config.ImagePath      = 'nui://rsg-inventory/html/images/' -- item images folder

-- Player defaults (fallbacks if rsg-core PlayerData has no slots/weight)
Config.PlayerSlots    = 25
Config.PlayerMaxWeight = 35000
Config.HotbarSlots    = 5        -- first N slots are the hotbar

-- Keybinds (RedM control hashes)
Config.Keys = {
    Open   = 0xC1989F95, -- I
    Hotbar = 0x26E9DC00, -- Z (show hotbar)
    Slots  = { 0xE6F612E4, 0x1CE6D9EB, 0x4F49CC4C, 0x8F9F9E58, 0xAB62E997 }, -- 1-5
}
Config.UseCooldown    = 500      -- ms between item uses

-- Stashes
Config.Stash = {
    DefaultSlots     = 50,
    DefaultMaxWeight = 1000000,
    MaxSlots         = 300,      -- clamp for stashes opened from client requests
    MaxWeight        = 10000000,
    SaveInterval     = 5,        -- minutes idle before a changed stash is saved
    UnloadAfter      = 30,       -- minutes idle before a stash is dropped from memory
}

-- Ground drops
Config.Drop = {
    Slots        = 30,
    MaxWeight    = 1000000,
    Prop         = `p_bag01x`,
    OpenDistance = 2.0,          -- distance to see a drop when opening inventory
    RenderDistance = 50.0,       -- prop spawn distance
    Lifetime     = 15,           -- minutes before an untouched drop is removed
}

Config.GiveDistance   = 3.0

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
Config.ShopRestockCycle = '0 * * * *' -- cron: restock every hour
