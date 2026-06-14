local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterNetEvent('rsg-inventory:client:tradeRequest', function(initiatorId, initiatorName)
    lib.registerContext({
        id = 'trade_request',
        title = 'Trade Request',
        options = {
            {
                title = 'Accept trade from ' .. initiatorName,
                onSelect = function()
                    TriggerServerEvent('rsg-inventory:server:acceptTradeRequest', initiatorId)
                end
            },
            {
                title = 'Decline trade from ' .. initiatorName,
                onSelect = function()
                    TriggerServerEvent('rsg-inventory:server:declineTradeRequest', initiatorId)
                end
            }
        }
    })
    lib.showContext('trade_request')
end)

RegisterNetEvent('rsg-inventory:client:tradeRequestCancelled', function()

    lib.hideContext()
end)

RegisterNetEvent('rsg-inventory:client:openTrade', function(tradeId, partnerId, partnerName, items, partnerData)

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    local Player = RSGCore.Functions.GetPlayerData()
    local config = require 'shared.config'

    if not IsNuiFocused() then
        SetNuiFocus(true, true)
    end

    local myId = Player.source or Player.id or Player.citizenid

    SendNUIMessage({
        action = 'openTrade',
        tradeId = tradeId,
        partnerId = partnerId,
        partnerName = partnerName,
        inventory = items or Player.items,
        slots = Player.slots,
        maxweight = Player.weight,
        playerId = myId,
        playerName = (Player.charinfo and Player.charinfo.firstname)
            and (Player.charinfo.firstname .. ' ' .. Player.charinfo.lastname)
            or myId,
        cash = Player.money and Player.money.cash or 0,
        labels = buildLabels(),
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('rsg-inventory:client:updateTrade', function(tradeData)

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'updateTrade',
        tradeData = tradeData,
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('rsg-inventory:client:cancelTrade', function()

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'cancelTrade',
        token = token,
        invToken = invToken,
    })
end)

RegisterNetEvent('rsg-inventory:client:completeTrade', function()

    local token = exports['rsg-core']:GenerateCSRFToken()
    local invToken = GenerateInventoryCbToken()
    SendNUIMessage({
        action = 'completeTrade',
        token = token,
        invToken = invToken,
    })
end)
