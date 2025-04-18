CreateThread(function()
    local scenarioHash = GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH")
    local conditionalHash = GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH")

    local dropPromptGroup = GetRandomIntInRange(0, 0xffffff)
    local dropGroupTitle = CreateVarString(10, 'LITERAL_STRING', 'Loot bag')
    local dropBagPromptTitle = CreateVarString(10, 'LITERAL_STRING', 'Drop bag')
   
    local dropBagPrompt = UiPromptRegisterBegin()
    PromptSetControlAction(dropBagPrompt, RSGCore.Shared.Keybinds['G'])
    PromptSetText(dropBagPrompt, dropBagPromptTitle)
    PromptSetEnabled(dropBagPrompt, true)
    PromptSetVisible(dropBagPrompt, true)
    PromptSetHoldMode(dropBagPrompt, true)
    PromptSetGroup(dropBagPrompt, dropPromptGroup)
    PromptRegisterEnd(dropBagPrompt)

    while true do
        if LocalPlayer.state.holdingDrop then
            PromptSetActiveGroupThisFrame(dropPromptGroup, dropGroupTitle)

            if PromptHasHoldModeCompleted(dropBagPrompt) then
                ClearPedTasksImmediately(cache.ped)
                TaskStartScenarioInPlaceHash(cache.ped, scenarioHash, 0, 1, conditionalHash, -1.0, 0)
                Wait(1000)

                local bagObject = LocalPlayer.state.dropBagObject
                DetachEntity(bagObject, true, true)
                local coords = GetEntityCoords(cache.ped)
                local forward = GetEntityForwardVector(cache.ped)
                local x, y, z = table.unpack(coords + forward * 0.57)
                SetEntityCoords(bagObject, x, y, z - 0.9, false, false, false, false)
                SetEntityRotation(bagObject, 0.0, 0.0, 0.0, 2)
                PlaceObjectOnGroundProperly(bagObject)
                FreezeEntityPosition(bagObject, true)
                
                TriggerServerEvent('rsg-inventory:server:updateDrop', LocalPlayer.state.heldDrop, coords)
                LocalPlayer.state.holdingDrop = false
                LocalPlayer.state.dropBagObject = nil
                LocalPlayer.state.heldDrop = nil
            end
            Wait(0)
        else
            Wait(1000)
        end
    end
end)