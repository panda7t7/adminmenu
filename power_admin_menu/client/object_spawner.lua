local placingObject = false
local previewObject = 0
local previewModel = 0
local placementCoords = nil
local surfaceCoords = nil
local placementRotation = vector3(0.0, 0.0, 0.0)
local placementOffset = vector3(0.0, 0.0, 0.0)
local placementStep = 0.10
local placementRotationStep = 5.0
local placementDistance = 6.0
local modelMin = vector3(0.0, 0.0, 0.0)
local lastUiUpdate = 0
local placementCursorVisible = true

local function setPlacementCursor(visible)
    placementCursorVisible = visible == true
    if placingObject then
        -- Keep keyboard focus in NUI either way; only pointer visibility changes.
        SetNuiFocus(true, placementCursorVisible)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'PAM_OBJECT_PLACEMENT_CURSOR', visible = placementCursorVisible })
    end
end

local function objectNotify(message, isError)
    TriggerEvent('chat:addMessage', {
        color = isError and { 255, 90, 90 } or { 100, 220, 170 },
        args = { 'POWER ADMIN', message }
    })
end

local function rotationToDirection(rotation)
    local rz, rx = math.rad(rotation.z), math.rad(rotation.x)
    local cosX = math.abs(math.cos(rx))
    return vector3(-math.sin(rz) * cosX, math.cos(rz) * cosX, math.sin(rx))
end

local function getPlacementPoint(distance)
    local camRot, camPos = GetGameplayCamRot(2), GetGameplayCamCoord()
    local direction = rotationToDirection(camRot)
    local destination = camPos + direction * distance
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z,
        destination.x, destination.y, destination.z, 511, PlayerPedId(), 7)
    local status, hit, endCoords = GetShapeTestResult(ray)
    if status == 2 and hit == true then return endCoords end
    return destination
end

local function setPlacementUi(visible, modelName)
    SendNUIMessage({ type = 'PAM_OBJECT_PLACEMENT', visible = visible, model = modelName or '' })
    if visible then
        -- Start with the pointer enabled. Left Ctrl toggles pointer visibility
        -- without releasing NUI keyboard focus or allowing game-camera input.
        placementCursorVisible = true
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'PAM_OBJECT_PLACEMENT_CURSOR', visible = true })
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end

local function stopPlacement(deletePreview)
    local oldModel = previewModel
    placingObject = false
    if deletePreview and previewObject ~= 0 and DoesEntityExist(previewObject) then
        SetEntityAsMissionEntity(previewObject, true, true)
        DeleteEntity(previewObject)
    end
    previewObject, previewModel, placementCoords, surfaceCoords = 0, 0, nil, nil
    placementOffset = vector3(0.0, 0.0, 0.0)
    setPlacementUi(false)
    if oldModel ~= 0 then SetModelAsNoLongerNeeded(oldModel) end
end

local function sendPlacementState(force)
    local now = GetGameTimer()
    if not force and now - lastUiUpdate < 120 then return end
    lastUiUpdate = now
    if not placementCoords then return end
    SendNUIMessage({
        type = 'PAM_OBJECT_PLACEMENT_STATE',
        coords = { x = placementCoords.x, y = placementCoords.y, z = placementCoords.z },
        rotation = { x = placementRotation.x, y = placementRotation.y, z = placementRotation.z },
        step = placementStep,
        rotationStep = placementRotationStep
    })
end

local function finishPlacement()
    if not placementCoords or previewModel == 0 then return end
    local coords, model = placementCoords, previewModel
    local rotation = placementRotation
    placingObject = false
    if previewObject ~= 0 and DoesEntityExist(previewObject) then
        SetEntityAsMissionEntity(previewObject, true, true)
        DeleteEntity(previewObject)
    end
    previewObject, previewModel, placementCoords, surfaceCoords = 0, 0, nil, nil
    setPlacementUi(false)

    local object = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, true, true, false)
    if object == 0 or not DoesEntityExist(object) or GetEntityType(object) ~= 3 then
        if object ~= 0 and DoesEntityExist(object) then DeleteEntity(object) end
        objectNotify('Object creation failed. The selected model may not be an object.', true)
        SetModelAsNoLongerNeeded(model)
        return
    end

    SetEntityRotation(object, rotation.x, rotation.y, rotation.z, 2, true)
    SetEntityAsMissionEntity(object, true, true)
    SetEntityCollision(object, true, true)
    SetEntityAlpha(object, 255, false)
    FreezeEntityPosition(object, true)
    NetworkRegisterEntityAsNetworked(object)
    local netId = NetworkGetNetworkIdFromEntity(object)
    if netId and netId ~= 0 then
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
    end
    SetModelAsNoLongerNeeded(model)
    objectNotify(('Object placed successfully%s'):format(netId and netId ~= 0 and (' (Net ID: ' .. netId .. ')') or ''))
end

RegisterNetEvent('pam:client:objectPlacementControl', function(control, value)
    if not placingObject then return end
    local step = placementStep
    if control == 'toggleCursor' then
        setPlacementCursor(not placementCursorVisible)
        return
    elseif control == 'step' then
        local requested = tonumber(value)
        if requested == 0.01 or requested == 0.05 or requested == 0.10 or requested == 0.25 or requested == 1.0 then
            placementStep = requested
        end
    elseif control == 'rotationStep' then
        local requested = tonumber(value)
        if requested == 1 or requested == 5 or requested == 15 or requested == 45 then placementRotationStep = requested end
    elseif control == 'place' then
        finishPlacement()
        return
    elseif control == 'cancel' then
        stopPlacement(true)
        objectNotify('Object placement cancelled.')
        return
    elseif control == 'moveX' then placementOffset = placementOffset + vector3(step * (tonumber(value) or 0), 0.0, 0.0)
    elseif control == 'moveY' then placementOffset = placementOffset + vector3(0.0, step * (tonumber(value) or 0), 0.0)
    elseif control == 'moveZ' then placementOffset = placementOffset + vector3(0.0, 0.0, step * (tonumber(value) or 0))
    elseif control == 'rotX' then placementRotation = vector3(placementRotation.x + placementRotationStep * (tonumber(value) or 0), placementRotation.y, placementRotation.z)
    elseif control == 'rotY' then placementRotation = vector3(placementRotation.x, placementRotation.y + placementRotationStep * (tonumber(value) or 0), placementRotation.z)
    elseif control == 'rotZ' then placementRotation = vector3(placementRotation.x, placementRotation.y, placementRotation.z + placementRotationStep * (tonumber(value) or 0))
    elseif control == 'resetOffset' then placementOffset = vector3(0.0, 0.0, 0.0)
    elseif control == 'resetRotation' then placementRotation = vector3(0.0, 0.0, placementRotation.z)
    else return end
    sendPlacementState(true)
end)

RegisterNetEvent('pam:client:startObjectPlacement', function(modelName)
    if placingObject then stopPlacement(true) end
    if type(modelName) ~= 'string' or modelName == '' then return end
    local hash = joaat(modelName)
    -- IsModelAnObject is not a FiveM client native. Validate the model generically,
    -- then validate the preview entity type after creation instead.
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        objectNotify(('Invalid model: %s'):format(modelName), true)
        return
    end

    RequestModel(hash)
    local deadline = GetGameTimer() + 15000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(25) end
    if not HasModelLoaded(hash) then
        objectNotify(('Could not load model: %s'):format(modelName), true)
        SetModelAsNoLongerNeeded(hash)
        return
    end

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    placementRotation = vector3(0.0, 0.0, GetEntityHeading(ped))
    placementOffset = vector3(0.0, 0.0, 0.0)
    placementStep = 0.10
    placementRotationStep = 5.0
    placementDistance = 6.0
    local initial = playerCoords + forward * placementDistance
    previewObject = CreateObjectNoOffset(hash, initial.x, initial.y, initial.z, false, false, false)
    if previewObject == 0 or not DoesEntityExist(previewObject) or GetEntityType(previewObject) ~= 3 then
        if previewObject ~= 0 and DoesEntityExist(previewObject) then DeleteEntity(previewObject) end
        previewObject = 0
        objectNotify(('Model is not a placeable object: %s'):format(modelName), true)
        SetModelAsNoLongerNeeded(hash)
        return
    end

    previewModel = hash
    local minDim = GetModelDimensions(hash)
    modelMin = minDim or vector3(0.0, 0.0, 0.0)
    placingObject = true
    SetEntityAlpha(previewObject, 155, false)
    SetEntityCollision(previewObject, false, false)
    FreezeEntityPosition(previewObject, true)
    setPlacementUi(true, modelName)
    objectNotify(('Placing %s — use the on-screen gizmo controls, Enter to place, Backspace to cancel.'):format(modelName))

    CreateThread(function()
        while placingObject do
            Wait(0)
            DisablePlayerFiring(PlayerId(), true)
            -- Explicitly suppress camera look axes during placement as a safety net.
            DisableControlAction(0, 1, true) -- LookLeftRight
            DisableControlAction(0, 2, true) -- LookUpDown
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 200, true)
            DisableControlAction(0, 177, true)
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 172, true)
            DisableControlAction(0, 173, true)
            DisableControlAction(0, 174, true)
            DisableControlAction(0, 175, true)
            DisableControlAction(0, 14, true)
            DisableControlAction(0, 15, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)

            -- Keyboard input is handled by the focused NUI placement panel.
            if IsDisabledControlJustPressed(0, 14) then placementDistance = math.max(1.0, placementDistance - 0.5) end
            if IsDisabledControlJustPressed(0, 15) then placementDistance = math.min(20.0, placementDistance + 0.5) end

            local hitPoint = getPlacementPoint(placementDistance)
            surfaceCoords = vector3(hitPoint.x, hitPoint.y, hitPoint.z - modelMin.z + 0.015)
            placementCoords = surfaceCoords + placementOffset
            SetEntityCoordsNoOffset(previewObject, placementCoords.x, placementCoords.y, placementCoords.z, false, false, false)
            SetEntityRotation(previewObject, placementRotation.x, placementRotation.y, placementRotation.z, 2, true)
            -- World-space XYZ gizmo axes around the preview pivot.
            DrawLine(placementCoords.x, placementCoords.y, placementCoords.z, placementCoords.x + 0.85, placementCoords.y, placementCoords.z, 255, 85, 85, 230)
            DrawLine(placementCoords.x, placementCoords.y, placementCoords.z, placementCoords.x, placementCoords.y + 0.85, placementCoords.z, 85, 230, 135, 230)
            DrawLine(placementCoords.x, placementCoords.y, placementCoords.z, placementCoords.x, placementCoords.y, placementCoords.z + 0.85, 90, 155, 255, 230)
            DrawMarker(28, placementCoords.x, placementCoords.y, placementCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.055, 0.055, 0.055, 245, 245, 255, 220, false, false, 2, false, nil, nil, false)
            sendPlacementState(false)

            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                stopPlacement(true)
                objectNotify('Object placement cancelled.')
            end
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and placingObject then stopPlacement(true) end
end)
