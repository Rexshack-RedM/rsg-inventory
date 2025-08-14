CreateThread(function()
    local scenarioHash     = GetHashKey("RANSACK_FALLBACK_PICKUP_CROUCH")
    local conditionalHash  = GetHashKey("RANSACK_PICKUP_H_0m0_FALLBACK_CROUCH")
    local dropPromptGroup  = GetRandomIntInRange(0, 0xffffff)
    local dropGroupTitle   = CreateVarString(10, 'LITERAL_STRING', 'Loot bag')
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
        local waitTime = 500
        if LocalPlayer.state.holdingDrop then
            waitTime = 0
            PromptSetActiveGroupThisFrame(dropPromptGroup, dropGroupTitle)

            if PromptHasHoldModeCompleted(dropBagPrompt) then
                local bagObject = LocalPlayer.state.dropBagObject
                if DoesEntityExist(bagObject) then
                    ClearPedTasksImmediately(cache.ped)
                    TaskStartScenarioInPlaceHash(cache.ped, scenarioHash, 0, 1, conditionalHash, -1.0, 0)
                    Wait(1000)                   
                    DetachEntity(bagObject, true, true)

                    local coords   = GetEntityCoords(cache.ped)
                    local forward  = GetEntityForwardVector(cache.ped)
                    local x = coords.x + (forward.x * 0.57)
                    local y = coords.y + (forward.y * 0.57)
                    local z = coords.z - 0.90
                    local dropCoords = vector3(x, y, z)

                    SetEntityCoords(bagObject, x, y, z, false, false, false, false)
                    SetEntityRotation(bagObject, 0.0, 0.0, 0.0, 2)
                    PlaceObjectOnGroundProperly(bagObject)
                    FreezeEntityPosition(bagObject, true)

                    local ok, msg = lib.callback.await('rsg-inventory:updateDrop', false, LocalPlayer.state.heldDrop, dropCoords)
                    if not ok then
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

                LocalPlayer.state.holdingDrop  = false
                LocalPlayer.state.dropBagObject = nil
                LocalPlayer.state.heldDrop      = nil
            end
        end
        Wait(waitTime)
    end
end)