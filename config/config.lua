Config = {
    UseTarget = GetConvar('UseTarget', 'false') == 'true',

    MaxWeight = 120000,
    MaxSlots = 40,

    StashSize = {
        maxweight = 2000000,
        slots = 100
    },

    DropSize = {
        maxweight = 1000000,
        slots = 50
    },

    Keybinds = {
        Open = 0xC1989F95, -- 'I', to change closing, navigate to 'html/app.js' and change additionalCloseKey setting (https://www.toptal.com/developers/keycode)
        Hotbar = 0x26E9DC00, -- 'Z',
    },

    HotbarSpamProtectionTimeout = 500, -- in miliseconds
    HotbarSpamProtectionNotify = false, -- should player recieve notification when spamming hotbar

    CleanupDropTime = 15,    -- in minutes
    CleanupDropInterval = 1, -- in minutes

    ItemDropObject = `p_bag01x`,
    ItemDropObjectBone = "SKEL_R_Finger00",
    ItemDropObjectOffset = {
        vector3(0.380000, -0.04000, -0.0300000),
        vector3(-5.000000, -95.000000, -90.000),
    },

    ShopsStockEnabled = true, -- enable of tracking shops item stock
    ShopsStockPersistent = true, -- should item stock persist or reset after restart
    ShopsEnableBuyback = true, -- enable shops buying items for fraction of selling price
    ShopsBuybackPriceMultiplier = 0.1, -- fraction of buyback price (1 = full price, 0.1 = 10% of selling price)
    ShopsEnableBuybackStockLimit = true, -- shops won't buyback item if default stock amount is reached
    ShopsMinimumSellQuality = 50, -- shops won't buyback item if item quality drops to this value (set -1 to disable)

    VendingObjects = {
        `s_inv_whiskey02x`,
        `p_whiskeycrate01x`,
        `p_bal_whiskeycrate01`,
        `p_whiskeybarrel01x`,
    },

    VendingItems = {
        { name = 'water', price = 0.1, amount = 50 },
        { name = 'bread', price = 0.1, amount = 50 },
    },
}
