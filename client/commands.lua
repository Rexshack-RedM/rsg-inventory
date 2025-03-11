RegisterCommand('openInv', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if IsNuiFocused() or IsPauseMenuActive() then return end
    if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
        ExecuteCommand('inventory')
    end
end, false)

RegisterCommand('toggleHotbar', function()
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] then
        ExecuteCommand('hotbar')
    end
end, false)

for i = 1, 5 do
    RegisterCommand('slot_' .. i, function()
        Inventory.UseHotbarItem(i)
    end, false)
end