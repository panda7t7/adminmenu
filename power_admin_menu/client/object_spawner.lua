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
local placementOptions = {}
local placementBaseCoords = nil
local placementModelName = nil
local placementGizmoMode = 'move'
local lastAxisUiUpdate = 0

local function setPlacementCursor(visible)
    placementCursorVisible = visible == true
    if placingObject then
        if placementCursorVisible then
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(false)
        else
            -- Release NUI focus completely so mouse-look and normal movement return.
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
        end
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
        -- Start with the pointer enabled. Hiding it releases NUI focus for gameplay.
        placementCursorVisible = true
        placementGizmoMode = 'move'
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
    local options = placementOptions or {}
    local modelName = placementModelName
    placingObject = false
    if previewObject ~= 0 and DoesEntityExist(previewObject) then
        SetEntityAsMissionEntity(previewObject, true, true)
        DeleteEntity(previewObject)
    end
    previewObject, previewModel, placementCoords, surfaceCoords = 0, 0, nil, nil
    setPlacementUi(false)
    if options.editId then
        local netId = tonumber(options.editNetId) or 0
        local entity = netId ~= 0 and NetworkGetEntityFromNetworkId(netId) or 0
        local deadline = GetGameTimer() + 2500
        while entity ~= 0 and DoesEntityExist(entity) and not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
            NetworkRequestControlOfEntity(entity)
            Wait(25)
        end
        if entity == 0 or not DoesEntityExist(entity) or not NetworkHasControlOfEntity(entity) then
            objectNotify('Could not take network control of this prop. Move closer and try again.', true)
        else
            SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z, false, false, false)
            SetEntityRotation(entity, rotation.x, rotation.y, rotation.z, 2, true)
            FreezeEntityPosition(entity, true)
            TriggerServerEvent('pam:server:managedPropEdit', options.editId, {x=coords.x,y=coords.y,z=coords.z}, {x=rotation.x,y=rotation.y,z=rotation.z}, netId)
        end
        SetModelAsNoLongerNeeded(model)
        placementOptions, placementBaseCoords, placementModelName = {}, nil, nil
        return
    end

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
    if netId and netId ~= 0 then TriggerServerEvent('pam:server:managedPropRegister', netId, modelName, options.persistence or 'temporary', options.spawnToken) end
    placementOptions, placementBaseCoords, placementModelName = {}, nil, nil
    objectNotify(('Object placed successfully%s'):format(netId and netId ~= 0 and (' (Net ID: ' .. netId .. ')') or ''))
end

RegisterNetEvent('pam:client:objectPlacementControl', function(control, value)
    if not placingObject then return end
    local step = placementStep
    if control == 'toggleCursor' then
        setPlacementCursor(not placementCursorVisible)
        return
    elseif control == 'dragAxis' then
        if type(value) ~= 'table' then return end
        local axis = value.axis
        local steps = tonumber(value.steps)
        local mode = value.mode == 'rotate' and 'rotate' or 'move'
        if (axis ~= 'x' and axis ~= 'y' and axis ~= 'z') or not steps then return end
        steps = math.max(-100, math.min(100, steps))
        if mode == 'move' then
            local delta = placementStep * steps
            if axis == 'x' then placementOffset = placementOffset + vector3(delta, 0.0, 0.0)
            elseif axis == 'y' then placementOffset = placementOffset + vector3(0.0, delta, 0.0)
            else placementOffset = placementOffset + vector3(0.0, 0.0, delta) end
        else
            local delta = placementRotationStep * steps
            if axis == 'x' then placementRotation = vector3(placementRotation.x + delta, placementRotation.y, placementRotation.z)
            elseif axis == 'y' then placementRotation = vector3(placementRotation.x, placementRotation.y + delta, placementRotation.z)
            else placementRotation = vector3(placementRotation.x, placementRotation.y, placementRotation.z + delta) end
        end
        sendPlacementState(true)
        return
    elseif control == 'gizmoMode' then
        placementGizmoMode = value == 'rotate' and 'rotate' or 'move'
        SendNUIMessage({ type = 'PAM_GIZMO_MODE', mode = placementGizmoMode })
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

RegisterNetEvent('pam:client:startObjectPlacement', function(modelName, options)
    if placingObject then stopPlacement(true) end
    options = type(options) == 'table' and options or {}
    placementOptions = options
    placementModelName = modelName
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
    local initial = options.coords and vector3(tonumber(options.coords.x) or playerCoords.x, tonumber(options.coords.y) or playerCoords.y, tonumber(options.coords.z) or playerCoords.z) or (playerCoords + forward * placementDistance)
    if options.rotation then placementRotation = vector3(tonumber(options.rotation.x) or 0.0, tonumber(options.rotation.y) or 0.0, tonumber(options.rotation.z) or placementRotation.z) end
    placementBaseCoords = options.editId and initial or nil
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
            if placementCursorVisible then
                -- NUI owns pointer and keyboard while visible; suppress game input.
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
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
            else
                -- No NUI focus: let the player walk and freely rotate the camera.
                DisableControlAction(0, 36, true)
                DisableControlAction(0, 191, true)
                DisableControlAction(0, 177, true)
                DisableControlAction(0, 200, true)
                if IsDisabledControlJustPressed(0, 36) then setPlacementCursor(true) end
                if IsDisabledControlJustPressed(0, 191) then finishPlacement() end
                if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                    stopPlacement(true)
                    objectNotify('Object placement cancelled.')
                end
            end

            if placementBaseCoords then
                placementCoords = placementBaseCoords + placementOffset
            else
                local hitPoint = getPlacementPoint(placementDistance)
                surfaceCoords = vector3(hitPoint.x, hitPoint.y, hitPoint.z - modelMin.z + 0.015)
                placementCoords = surfaceCoords + placementOffset
            end
            SetEntityCoordsNoOffset(previewObject, placementCoords.x, placementCoords.y, placementCoords.z, false, false, false)
            SetEntityRotation(previewObject, placementRotation.x, placementRotation.y, placementRotation.z, 2, true)
                        -- Draw world-space axes and publish screen positions for mouse dragging.
            local axisEnds = {
                x = vector3(placementCoords.x + 0.85, placementCoords.y, placementCoords.z),
                y = vector3(placementCoords.x, placementCoords.y + 0.85, placementCoords.z),
                z = vector3(placementCoords.x, placementCoords.y, placementCoords.z + 0.85)
            }
            DrawLine(placementCoords.x, placementCoords.y, placementCoords.z, axisEnds.x.x, axisEnds.x.y, axisEnds.x.z, 255, 85, 85, 230)
            DrawLine(placementCoords.x, placementCoords.y, placementCoords.z, axisEnds.y.x, axisEnds.y.y, axisEnds.y.z, 85, 230, 135, 230)
            DrawLine(placementCoords.x, placementCoords.y, placementCoords.z, axisEnds.z.x, axisEnds.z.y, axisEnds.z.z, 90, 155, 255, 230)
            DrawMarker(28, placementCoords.x, placementCoords.y, placementCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.055, 0.055, 0.055, 245, 245, 255, 220, false, false, 2, false, nil, nil, false)
            if placementCursorVisible and GetGameTimer() - lastAxisUiUpdate > 40 then
                lastAxisUiUpdate = GetGameTimer()
                local axes = {}
                for axis, endpoint in pairs(axisEnds) do
                    local ok1, x1, y1 = GetScreenCoordFromWorldCoord(placementCoords.x, placementCoords.y, placementCoords.z)
                    local ok2, x2, y2 = GetScreenCoordFromWorldCoord(endpoint.x, endpoint.y, endpoint.z)
                    if ok1 and ok2 then axes[axis] = { x1=x1, y1=y1, x2=x2, y2=y2 } end
                end
                SendNUIMessage({ type='PAM_GIZMO_AXES', axes=axes, mode=placementGizmoMode })
            end
            sendPlacementState(false)

            if placementCursorVisible and (IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200)) then
                stopPlacement(true)
                objectNotify('Object placement cancelled.')
            end
        end
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and placingObject then stopPlacement(true); placementOptions, placementBaseCoords, placementModelName = {}, nil, nil end
end)

RegisterNetEvent('pam:client:editManagedProp', function(row)
    if type(row) ~= 'table' or type(row.model) ~= 'string' then return end
    SendNUIMessage({ type = 'PAM_VISIBILITY', visible = false })
    TriggerEvent('pam:client:startObjectPlacement', row.model, { editId=row.id, editNetId=row.netId, coords=row.coords, rotation=row.rotation })
end)

RegisterNetEvent('pam:client:managedPropsList', function(rows)
    SendNUIMessage({ type='PAM_MANAGED_PROPS', payload=rows or {} })
end)

RegisterNetEvent('pam:client:managedObjectNotice', function(message, success)
    objectNotify(message, not success)
end)

AddStateBagChangeHandler('pamManagedPropTransform', nil, function(bagName, _, value)
    if type(value) ~= 'table' or type(value.rotation) ~= 'table' then return end
    CreateThread(function()
        local deadline = GetGameTimer() + 15000
        local entity = 0
        while GetGameTimer() < deadline do
            entity = GetEntityFromStateBagName(bagName)
            if entity ~= 0 and DoesEntityExist(entity) and NetworkGetEntityOwner(entity) == PlayerId() then break end
            Wait(100)
        end
        if entity == 0 or not DoesEntityExist(entity) or NetworkGetEntityOwner(entity) ~= PlayerId() then return end
        local rotation = value.rotation
        SetEntityRotation(entity, tonumber(rotation.x) or 0.0, tonumber(rotation.y) or 0.0, tonumber(rotation.z) or 0.0, 2, true)
        FreezeEntityPosition(entity, true)
    end)
end)
