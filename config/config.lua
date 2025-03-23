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

    ShopsRestockCycle = "0 * * * *", -- every hour (https://crontab.guru/)

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
