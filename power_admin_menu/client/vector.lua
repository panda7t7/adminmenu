local vectorOpen = false
local selectedFormat = 1
local laserMode = false
local currentTarget = 0
local lastTargetHandle = -1
local lastTargetUpdate = 0
local pendingDeleteHandle = 0
local pendingDeleteNetId = 0
local cachedTargetModel = 0
local cachedTargetMin = nil
local cachedTargetMax = nil

local LASER_DISTANCE = 1000.0
local BOX_COLOR = { r = 0, g = 255, b = 0, a = 220 }
local BEAM_COLOR = { r = 245, g = 250, b = 255, a = 210 }

local function round(value)
    return math.floor((value * 1000.0) + 0.5) / 1000.0
end

local function rotationToDirection(rotation)
    local rz = math.rad(rotation.z)
    local rx = math.rad(rotation.x)
    local cosX = math.abs(math.cos(rx))
    return {
        x = -math.sin(rz) * cosX,
        y = math.cos(rz) * cosX,
        z = math.sin(rx)
    }
end

-- Use the camera that is actually rendering. This also supports scripted cameras
-- (for example, noclip/admin camera modes) instead of always aiming from gameplay cam.
local function getActiveCamera()
    if IsGameplayCamRendering() then
        return GetGameplayCamCoord(), GetGameplayCamRot(2)
    end

    local renderingCam = GetRenderingCam()
    if renderingCam and renderingCam > 0 then
        return GetCamCoord(renderingCam), GetCamRot(renderingCam, 2)
    end

    return GetGameplayCamCoord(), GetGameplayCamRot(2)
end

-- Match the stable qb-adminmenu pattern: start a fresh ray and immediately read
-- its result. Never retain/poll an old shape-test handle across frames.
local function raycastFromCamera(distance)
    local cameraCoords, cameraRotation = getActiveCamera()
    local direction = rotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoords.x + direction.x * distance,
        y = cameraCoords.y + direction.y * distance,
        z = cameraCoords.z + direction.z * distance
    }

    local rayHandle = StartShapeTestRay(
        cameraCoords.x, cameraCoords.y, cameraCoords.z,
        destination.x, destination.y, destination.z,
        -1, PlayerPedId(), 0
    )

    local rayStatus, didHit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    local resultCoords = destination
    local hitEntity = 0

    if rayStatus == 2 and endCoords then
        resultCoords = endCoords
        if (didHit == true or didHit == 1)
            and type(entityHit) == 'number'
            and entityHit ~= 0
            and DoesEntityExist(entityHit) then
            -- Use the same entity-class gates as the proven qb-adminmenu free-aim
            -- scanner before any model/entity inspection. A world hit is not an entity.
            if IsEntityAPed(entityHit) or IsEntityAVehicle(entityHit) or IsEntityAnObject(entityHit) then
                hitEntity = entityHit
            end
        end
    end

    return cameraCoords, resultCoords, hitEntity
end

local function drawEntityBoundingBox(entity, color)
    if not entity or entity == 0 or entity ~= currentTarget or not DoesEntityExist(entity) then return end
    if not cachedTargetMin or not cachedTargetMax then return end

    local minimum, maximum = cachedTargetMin, cachedTargetMax
    local right, forward, up, position = GetEntityMatrix(entity)
    if not right or not forward or not up or not position then return end

    -- Transform all eight model-space corners through the entity matrix.
    -- This avoids ground-Z lookups and works for rotated/raised props and vehicles.
    local function worldPoint(x, y, z)
        return {
            x = position.x + right.x * x + forward.x * y + up.x * z,
            y = position.y + right.y * x + forward.y * y + up.y * z,
            z = position.z + right.z * x + forward.z * y + up.z * z
        }
    end

    local corners = {
        worldPoint(minimum.x, minimum.y, minimum.z), -- 1
        worldPoint(maximum.x, minimum.y, minimum.z), -- 2
        worldPoint(maximum.x, maximum.y, minimum.z), -- 3
        worldPoint(minimum.x, maximum.y, minimum.z), -- 4
        worldPoint(minimum.x, minimum.y, maximum.z), -- 5
        worldPoint(maximum.x, minimum.y, maximum.z), -- 6
        worldPoint(maximum.x, maximum.y, maximum.z), -- 7
        worldPoint(minimum.x, maximum.y, maximum.z)  -- 8
    }

    local edges = {
        { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 },
        { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 },
        { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 }
    }

    for i = 1, #edges do
        local a = corners[edges[i][1]]
        local b = corners[edges[i][2]]
        DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, color.r, color.g, color.b, color.a)
    end
end

local function clearTarget(force)
    currentTarget = 0
    cachedTargetModel, cachedTargetMin, cachedTargetMax = 0, nil, nil
    if force or lastTargetHandle ~= 0 then
        SendNUIMessage({ type = 'PAM_LASER_UPDATE', active = laserMode, target = nil })
        lastTargetHandle = 0
        lastTargetUpdate = GetGameTimer()
    end
end

local function sendTarget(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        clearTarget(false)
        return
    end

    -- Do not trust a shape-test entity handle until the engine classifies it.
    -- This specifically prevents GetEntityModel(0)/invalid-world-hit calls.
    local entityType
    if IsEntityAPed(entity) then
        entityType = 1
    elseif IsEntityAVehicle(entity) then
        entityType = 2
    elseif IsEntityAnObject(entity) then
        entityType = 3
    else
        clearTarget(false)
        return
    end

    local now = GetGameTimer()
    if currentTarget ~= entity then
        cachedTargetModel = GetEntityModel(entity)
        if not cachedTargetModel or cachedTargetModel == 0 then
            clearTarget(false)
            return
        end
        cachedTargetMin, cachedTargetMax = GetModelDimensions(cachedTargetModel)
        currentTarget = entity
        lastTargetHandle = -1
    end
    if lastTargetHandle == entity and (now - lastTargetUpdate) < 100 then return true end

    local coords = GetEntityCoords(entity)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local dx, dy, dz = coords.x - playerCoords.x, coords.y - playerCoords.y, coords.z - playerCoords.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    local model = cachedTargetModel
    local heading = GetEntityHeading(entity)
    local isNetworked = NetworkGetEntityIsNetworked(entity)
    local netId = isNetworked and NetworkGetNetworkIdFromEntity(entity) or 0

    local health, maxHealth, details = '—', '—', 'World object'
    if entityType == 1 then
        health = GetEntityHealth(entity)
        maxHealth = GetPedMaxHealth(entity)
        details = ('Armour %s'):format(GetPedArmour(entity))
    elseif entityType == 2 then
        health, maxHealth = GetEntityHealth(entity), 1000
        details = ('Speed %.1f | Engine %.0f | Body %.0f'):format(
            GetEntitySpeed(entity) * 3.6,
            GetVehicleEngineHealth(entity),
            GetVehicleBodyHealth(entity)
        )
    end

    local typeName = entityType == 1 and 'Ped' or (entityType == 2 and 'Vehicle' or 'Object')
    SendNUIMessage({
        type = 'PAM_LASER_UPDATE',
        active = true,
        target = {
            type = typeName,
            model = tostring(model),
            entity = entity,
            netId = netId,
            health = health,
            maxHealth = maxHealth,
            x = round(coords.x),
            y = round(coords.y),
            z = round(coords.z),
            heading = round(heading),
            distance = round(distance),
            details = details
        }
    })

    lastTargetHandle = entity
    lastTargetUpdate = now
    return true
end

local function toggleLaser()
    laserMode = not laserMode
    currentTarget = 0
    lastTargetHandle = -1
    pendingDeleteHandle = 0
    pendingDeleteNetId = 0
    SendNUIMessage({ type = 'PAM_LASER_MODE', active = laserMode })
    if not laserMode then clearTarget(true) end
end

RegisterNetEvent('pam:client:vectorToggle', function()
    if PAMClient and PAMClient.Open then
        PAMClient.Open = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'PAM_VISIBILITY', visible = false })
    end

    vectorOpen = not vectorOpen
    selectedFormat = 1
    laserMode = false
    currentTarget = 0
    pendingDeleteHandle = 0
    pendingDeleteNetId = 0
    cachedTargetModel, cachedTargetMin, cachedTargetMax = 0, nil, nil
    lastTargetHandle = -1
    SetNuiFocus(vectorOpen, false)
    SetNuiFocusKeepInput(vectorOpen)
    SendNUIMessage({ type = 'PAM_VECTOR_VISIBILITY', visible = vectorOpen, selected = selectedFormat })
    SendNUIMessage({ type = 'PAM_LASER_MODE', active = false })
    SendNUIMessage({ type = 'PAM_LASER_UPDATE', active = false, target = nil })
end)

RegisterCommand('vector', function()
    TriggerServerEvent('pam:server:vectorRequest')
end, false)

local function deleteEntityLocally(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false, 'Target entity no longer exists.'
    end

    if NetworkGetEntityIsNetworked(entity) then
        local timeout = GetGameTimer() + 1200
        NetworkRequestControlOfEntity(entity)
        while not NetworkHasControlOfEntity(entity) and GetGameTimer() < timeout do
            Wait(0)
            NetworkRequestControlOfEntity(entity)
        end
        if not NetworkHasControlOfEntity(entity) then
            return false, 'Could not gain network control of this entity.'
        end
    end

    -- The scanner continues while control is requested; never delete a different
    -- object if the admin moved the laser during that wait.
    if entity ~= currentTarget or not DoesEntityExist(entity) then
        return false, 'Target changed before deletion. Aim again and retry.'
    end

    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
    if DoesEntityExist(entity) then
        return false, 'The game did not allow this entity to be deleted.'
    end
    return true, 'Entity deleted.'
end

RegisterNetEvent('pam:client:laserDeleteLocal', function(entity)
    entity = tonumber(entity) or 0
    if entity == 0 or entity ~= pendingDeleteHandle or entity ~= currentTarget then
        TriggerEvent('pam:client:laserDeleteResult', false, 'Target changed before the delete request completed. Aim again and retry.')
        return
    end

    local success, message = deleteEntityLocally(entity)
    if success then clearTarget(true) end
    TriggerEvent('pam:client:laserDeleteResult', success, message)
    pendingDeleteHandle = 0
end)

RegisterNetEvent('pam:client:laserDeleteNetwork', function(netId)
    netId = tonumber(netId) or 0
    if netId <= 0 or netId ~= pendingDeleteNetId then
        TriggerEvent('pam:client:laserDeleteResult', false, 'Target changed before the delete request completed. Aim again and retry.')
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) or entity ~= currentTarget then
        TriggerEvent('pam:client:laserDeleteResult', false, 'Target entity is no longer available. Aim again and retry.')
        return
    end

    local success, message = deleteEntityLocally(entity)
    if success then clearTarget(true) end
    TriggerEvent('pam:client:laserDeleteResult', success, message)
    pendingDeleteNetId = 0
end)

RegisterNetEvent('pam:client:laserDeleteResult', function(success, message)
    SendNUIMessage({ type = 'PAM_LASER_DELETE_RESULT', success = success == true, message = message or '' })
end)

CreateThread(function()
    while true do
        if not vectorOpen then
            Wait(300)
        else
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local heading = GetEntityHeading(playerPed)
            SendNUIMessage({
                type = 'PAM_VECTOR_UPDATE',
                coords = { x = round(coords.x), y = round(coords.y), z = round(coords.z), heading = round(heading) },
                selected = selectedFormat
            })

            if laserMode then
                local cameraCoords, hitCoords, targetEntity = raycastFromCamera(LASER_DISTANCE)
                local beamColor = BEAM_COLOR

                if targetEntity ~= 0 and DoesEntityExist(targetEntity) and sendTarget(targetEntity) then
                    beamColor = BOX_COLOR
                    drawEntityBoundingBox(targetEntity, BOX_COLOR)
                else
                    clearTarget(false)
                end

                -- Draw every frame, including when the ray hits only the road/sky.
                DrawLine(
                    cameraCoords.x, cameraCoords.y, cameraCoords.z,
                    hitCoords.x, hitCoords.y, hitCoords.z,
                    beamColor.r, beamColor.g, beamColor.b, beamColor.a
                )

                DisableControlAction(0, 24, true)  -- attack
                DisableControlAction(0, 25, true)  -- aim
                DisableControlAction(0, 257, true) -- attack 2
                DisableControlAction(0, 200, true) -- pause menu
            else
                clearTarget(false)
            end

            for _, control in ipairs({ 172, 173, 174, 175, 191, 200 }) do
                DisableControlAction(0, control, true)
            end
            Wait(0)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        vectorOpen, laserMode, currentTarget = false, false, 0
        pendingDeleteHandle, pendingDeleteNetId = 0, 0
        cachedTargetModel, cachedTargetMin, cachedTargetMax = 0, nil, nil
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'PAM_VECTOR_VISIBILITY', visible = false })
    end
end)

RegisterNUICallback('vectorClose', function(_, cb)
    vectorOpen, laserMode, currentTarget = false, false, 0
    pendingDeleteHandle, pendingDeleteNetId = 0, 0
    cachedTargetModel, cachedTargetMin, cachedTargetMax = 0, nil, nil
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'PAM_VECTOR_VISIBILITY', visible = false })
    cb({ success = true })
end)

RegisterNUICallback('laserDelete', function(_, cb)
    if currentTarget == 0 or not DoesEntityExist(currentTarget) then
        cb({ success = false, message = 'No entity targeted.' })
        return
    end

    local target = currentTarget
    local netId = NetworkGetEntityIsNetworked(target) and NetworkGetNetworkIdFromEntity(target) or 0
    pendingDeleteHandle = target
    pendingDeleteNetId = netId
    TriggerServerEvent('pam:server:laserDelete', netId, target)
    cb({ success = true })
end)

RegisterNetEvent('pam:client:laserToggle', function()
    if vectorOpen then toggleLaser() end
end)
