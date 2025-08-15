return {
    -- Whether to use targeting system (e.g., for interaction)
    UseTarget = GetConvar('UseTarget', 'false') == 'true',

    -- Maximum weight and slot capacity for player inventory
    MaxWeight = 120000,
    MaxSlots = 40,

    -- Configuration for stash storage (e.g., chests, safes)
    StashSize = {
        maxweight = 2000000, -- Maximum weight capacity
        slots = 100          -- Number of item slots
    },

    -- Configuration for dropped items on the ground
    DropSize = {
        maxweight = 1000000, -- Max weight for dropped items
        slots = 50           -- Number of slots for dropped items
    },

    -- Key bindings for inventory actions
    Keybinds = {
        Open = 0xC1989F95,   -- Key to open inventory ('I')
        Hotbar = 0x26E9DC00, -- Key to open hotbar ('Z')
    },

    -- Anti-spam settings for hotbar usage
    HotbarSpamProtectionTimeout = 500,     -- Timeout in milliseconds
    HotbarSpamProtectionNotify = false,    -- Whether to notify player on spam

    -- Cleanup settings for dropped items
    CleanupDropTime = 15,     -- Time in minutes before item is cleaned up
    CleanupDropInterval = 1,  -- Interval in minutes to check for cleanup

    -- Object model and bone used for dropped item visuals
    ItemDropObject = `p_bag01x`,                  -- Object to represent dropped item
    ItemDropObjectBone = "SKEL_R_Finger00",       -- Bone to attach object to
    ItemDropObjectOffset = {
        vector3(0.380000, -0.04000, -0.0300000),  -- Position offset
        vector3(-5.000000, -95.000000, -90.000),  -- Rotation offset
    },

    -- Cron expression for shop restocking (every hour)
    ShopsRestockCycle = "0 * * * *",

    -- List of objects that act as vending machines
    VendingObjects = {
        `s_inv_whiskey02x`,
        `p_whiskeycrate01x`,
        `p_bal_whiskeycrate01`,
        `p_whiskeybarrel01x`,
    },

    -- Items available in vending machines
    VendingItems = {
        { name = 'water', price = 0.1, amount = 50 },
        { name = 'bread', price = 0.1, amount = 50 },
    },

    -- Method of giving items (e.g., to nearby players)
    GiveItemType = "nearby",

    -- Command names used in the resource
    CommandNames = {
        GiveItem      = 'giveitem',     -- Give item to player
        RandomItems   = 'randomitems',  -- Give random items
        ClearInv      = 'clearinv',     -- Clear inventory
        CloseInv      = 'closeinv',     -- Close inventory UI
        Hotbar        = 'hotbar',       -- Open hotbar
        Inventory     = 'inventory',    -- Open inventory
        openInv       = 'openinv',      -- Alternate command to open inventory
    }
}