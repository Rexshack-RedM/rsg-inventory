-- Toggle the hotbar UI with given items
local RSGCore = exports['rsg-core']:GetCoreObject()
-- @param items: table of items to display on the hotbar
RegisterNetEvent('rsg-inventory:client:hotbar', function(items)
    local token = exports['rsg-core']:GenerateCSRFToken() -- CSRF token for NUI security
    local invToken = GenerateInventoryCbToken()
    LocalPlayer.state.hotbarShown = not LocalPlayer.state.hotbarShown -- toggle state
    SendNUIMessage({
        action = 'toggleHotbar',
        open = LocalPlayer.state.hotbarShown,
        items = items,
        token = token,
        invToken = invToken,
    })
end)

-- Close the inventory UI
RegisterNetEvent('rsg-inventory:client:closeInv', function()

    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'close',
        invToken = invToken,
    })
end)

-- Update the player's inventory UI with current items
RegisterNetEvent('rsg-inventory:client:updateInventory', function()

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    local playerData = RSGCore.Functions.GetPlayerData() -- fetch current player data
    SendNUIMessage({
        action = 'update',
        inventory = playerData.items,
        cash = playerData.money.cash,
        token = token,
        invToken = invToken,
    })
end)

-- Show an item box notification for adding/removing items
-- @param itemData: table with item info
-- @param type: string, type of update ('add', 'remove', 'info', etc.)
-- @param amount: number of items affected
RegisterNetEvent('rsg-inventory:client:ItemBox', function(itemData, type, amount)

    local function sendItemBox()
        local invToken = GenerateInventoryCbToken()
        SendNUIMessage({
            action = 'itemBox',
            item = itemData,
            type = type,
            amount = amount,
            labels = buildLabels(),
            invToken = invToken,
        })

        -- Update server hotbar if items were added or removed
        if type == 'remove' or type == 'add' then
            TriggerServerEvent('rsg-inventory:server:updateHotbar')
        end
    end

    -- Throttle item box display to avoid spamming
    local lastItemBoxCall = LocalPlayer.state.lastItemBoxCall or 0
    local currentTime = GetGameTimer()
    local timeElapsed = currentTime - lastItemBoxCall

    if timeElapsed >= 1000 then
        sendItemBox()
        lastItemBoxCall = currentTime
    else
        local delay = 1000 - timeElapsed
        lib.timer(delay, function()
            sendItemBox()
        end, true)
        lastItemBoxCall = currentTime + delay
    end

    LocalPlayer.state.lastItemBoxCall = lastItemBoxCall
end)

-- Update hotbar UI with new items
-- @param items: table of items to display
RegisterNetEvent('rsg-inventory:client:updateHotbar', function(items)

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'updateHotbar',
        items = items,
        token = token,
        invToken = invToken,
    })
end)

local function L(k, d) return locale(k) or d end

function buildLabels()
    return {
        title   = L('ui.title', 'RSG Inventory'),
        close   = L('ui.close', 'Close'),
        close_aria = L('ui.close_aria', 'Close inventory'),
        use     = L('ui.use', 'Use'),
        give    = L('ui.give', 'Give'),
        single  = L('ui.single', 'Single'),
        half    = L('ui.half', 'Half'),
        all     = L('ui.all', 'All'),
        split   = L('ui.split', 'Split'),
        amount  = L('ui.amount', 'Amount'),
        amount_placeholder = L('ui.amount_placeholder', 'amount'),
        drop    = L('ui.drop', 'Drop'),
        copy_serial = L('ui.copy_serial', 'Copy Serial'),
        sell    = L('ui.sell', 'Sell'),
        satchel = L('ui.satchel', 'Satchel'),
        weight  = L('ui.weight', 'Weight'),
        id      = L('ui.id', 'ID'),
        cash    = L('ui.cash', 'Cash'),
        received = L('ui.received', 'Received'),
        used     = L('ui.used', 'Used'),
        removed  = L('ui.removed', 'Removed'),
        trade    = L('ui.trade', 'Trade'),
        your_offer = L('ui.your_offer', 'Your Offer'),
        their_offer = L('ui.their_offer', 'Their Offer'),
        accept   = L('ui.accept', 'Accept'),
        waiting  = L('ui.waiting', 'Waiting for other player...'),
        cancel   = L('ui.cancel', 'Cancel'),
        accepted = L('ui.accepted', 'Accepted'),
        no_items_offered = L('ui.no_items_offered', 'No items offered')
    }
end

-- Open the inventory UI with specified items and optional extra context
-- @param items: table of inventory items
-- @param other: optional table with extra info (trunk, stash, etc.)
RegisterNetEvent('rsg-inventory:client:openInventory', function(items, other)
    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    local Player = RSGCore.Functions.GetPlayerData()
    local config = require 'shared.config'
    local function L(k, d) return locale(k) or d end
    local labels = buildLabels()
    SetNuiFocus(true, true) -- focus mouse and keyboard on NUI

    SendNUIMessage({
        action    = 'open',
        inventory = items,
        slots     = Player.slots,
        maxweight = Player.weight,
        playerId  = Player.source or Player.id or Player.citizenid,
        playerName = (Player.charinfo and Player.charinfo.firstname)
            and (Player.charinfo.firstname .. ' ' .. Player.charinfo.lastname)
            or Player.source,
        other     = other,
        token     = token,
        invToken  = invToken,
        closeKey  = config.Keybinds.Close,
        cash      = Player.money.cash,
        labels    = labels
    })
end)