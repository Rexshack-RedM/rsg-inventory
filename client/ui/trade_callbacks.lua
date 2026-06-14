RegisterNUICallback('AddTradeItem', function(data, cb)
    if not data or not data.item or not data.amount or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    TriggerServerEvent('rsg-inventory:server:addTradeItem', data.tradeId, data.item, data.amount)
    cb('ok')
end)

RegisterNUICallback('RemoveTradeItem', function(data, cb)
    if not data or not data.tradeId or not data.tradeSlot or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    TriggerServerEvent('rsg-inventory:server:removeTradeItem', data.tradeId, data.tradeSlot)
    cb('ok')
end)

RegisterNUICallback('ConfirmTrade', function(data, cb)
    if not data or not data.tradeId or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    TriggerServerEvent('rsg-inventory:server:confirmTrade', data.tradeId)
    cb('ok')
end)

RegisterNUICallback('CancelTrade', function(data, cb)
    if not data or not data.tradeId or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    TriggerServerEvent('rsg-inventory:server:cancelTrade', data.tradeId)
    cb('ok')
end)

RegisterNUICallback('InitiateTrade', function(data, cb)
    if not data or not data.targetId or not data.token or not ValidateInventoryCbToken(data.token) then
        cb('ok')
        return
    end
    TriggerServerEvent('rsg-inventory:server:initiateTrade', data.targetId)
    cb('ok')
end)
