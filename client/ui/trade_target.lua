CreateThread(function()
    if GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'rsg_inventory_trade',
            label = locale('ui.trade'),
            icon = 'fas fa-handshake',
            distance = 2.5,
            onSelect = function(data)
                if not IsPedAPlayer(data.entity) then return end
                local serverId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                if serverId and serverId > 0 then
                    TriggerServerEvent('rsg-inventory:server:initiateTrade', serverId)
                end
            end,
        },
    })
end)
