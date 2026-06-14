CreateThread(function()
    Wait(5000)

    local ok = pcall(function()
        return exports.ox_target.addGlobalPlayer
    end)
    if not ok then return end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'trade',
            label = 'Trade',
            icon = 'fas fa-handshake',
            onSelect = function(data)
                local entity = data.entity
                if IsPedAPlayer(entity) then
                    local playerIndex = NetworkGetPlayerIndexFromPed(entity)
                    local serverId = GetPlayerServerId(playerIndex)
                    if serverId then
                        TriggerServerEvent('rsg-inventory:server:initiateTrade', serverId)
                    end
                end
            end,
        },
    }, 2.5)
end)
