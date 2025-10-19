local RSGCore = exports['rsg-core']:GetCoreObject()
--- Thread to handle player dropping a loot bag using a prompt.
--- This continuously checks if the player is holding a bag and handles placing it on the ground.
CreateThread(function()
    ---@type number Scenario hash for the crouch pickup animation
    local scenarioHash       = GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH")
    ---@type number Conditional animation hash
    local conditionalHash    = GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH")
    ---@type number Prompt group identifier
    local dropPromptGroup    = GetRandomIntInRange(0, 0xffffff)
    ---@type string Title for active prompt group
    local dropGroupTitle     = CreateVarString(10, 'LITERAL_STRING', locale('info.loot_bag') or 'Loot bag')
    ---@type string Text shown on the hold prompt
    local dropBagPromptTitle = CreateVarString(10, 'LITERAL_STRING', locale('info.drop_bag') or 'Drop bag')

    --- Register a UI prompt for dropping the bag
    ---@type number prompt handle
    local dropBagPrompt = UiPromptRegisterBegin()
    PromptSetControlAction(dropBagPrompt, RSGCore.Shared.Keybinds['G']) --- Keybind G to drop bag
    PromptSetText(dropBagPrompt, dropBagPromptTitle)
    PromptSetEnabled(dropBagPrompt, true)
    PromptSetVisible(dropBagPrompt, true)
    PromptSetHoldMode(dropBagPrompt, true) --- Requires hold
    PromptSetGroup(dropBagPrompt, dropPromptGroup)
    PromptRegisterEnd(dropBagPrompt)

    --- Main loop
    while true do
        if LocalPlayer.state.holdingDrop then
            --- Activate the prompt group each frame
            PromptSetActiveGroupThisFrame(dropPromptGroup, dropGroupTitle)

            --- Check if the player completed the hold prompt
            if PromptHasHoldModeCompleted(dropBagPrompt) then
                local bagObject = LocalPlayer.state.dropBagObject
                if DoesEntityExist(bagObject) then
                    --- Clear any current tasks and play pickup animation
                    ClearPedTasksImmediately(cache.ped)
                    TaskStartScenarioInPlaceHash(cache.ped, scenarioHash, 0, true, conditionalHash, -1.0, false)
                    Wait(1000)

                    --- Detach bag from player and compute drop coordinates
                    DetachEntity(bagObject, true, true)
                    local coords  = GetEntityCoords(cache.ped)
                    local forward = GetEntityForwardVector(cache.ped)
                    local dropCoords = vector3(
                        coords.x + (forward.x * 0.57),
                        coords.y + (forward.y * 0.57),
                        coords.z - 0.90
                    )

                    --- Place bag in the world
                    SetEntityCoords(bagObject, dropCoords.x, dropCoords.y, dropCoords.z, false, false, false, false)
                    SetEntityRotation(bagObject, 0.0, 0.0, 0.0, 2)
                    PlaceObjectOnGroundProperly(bagObject)
                    FreezeEntityPosition(bagObject, true)

                    --- Update the server with the new drop location
                    local success = lib.callback.await('rsg-inventory:updateDrop', false, LocalPlayer.state.heldDrop, dropCoords)
                    if not success then
                        lib.notify({
                            title       = locale('error.Error'),
                            description = locale('error.bagcannotplace'),
                            type        = 'error',
                            duration    = 4000
                        })
                    else
                        lib.notify({
                            description = locale('error.bagplace'),
                            type        = 'success',
                            duration    = 3000
                        })
                    end
                end

                --- Reset local player drop state
                LocalPlayer.state.holdingDrop   = false
                LocalPlayer.state.dropBagObject = nil
                LocalPlayer.state.heldDrop      = nil
            end
            Wait(0) --- Check every frame while holding bag
        else
            Wait(500) --- Check less often if not holding bag
        end
    end
end)