PAMClient = PAMClient or {}
PAMClient.Spectating = false
PAMClient.SpectateTarget = nil
local restore = nil
local spectateStartedAt = 0

local function stopSpectate()
    if not PAMClient.Spectating and not restore then return end
    NetworkSetInSpectatorMode(false, 0)
    local ped = PlayerPedId()
    if restore then
        SetEntityCoords(ped, restore.x, restore.y, restore.z, false, false, false, false)
        SetEntityHeading(ped, restore.heading or 0.0)
        SetEntityVisible(ped, restore.visible ~= false, false)
        SetEntityCollision(ped, restore.collision ~= false, true)
        FreezeEntityPosition(ped, restore.frozen == true)
    end
    SetEntityInvincible(ped, restore and restore.invincible == true or false)
    ClearFocus()
    restore = nil
    PAMClient.Spectating = false
    PAMClient.SpectateTarget = nil
    SendNUIMessage({ type = 'PAM_SPECTATE_STATE', active = false })
end

RegisterNetEvent(PAM.Events.SpectateStart, function(targetServerId, targetCoords)
    if PAMClient.Spectating then stopSpectate() end
    local targetId = tonumber(targetServerId)
    if not targetId or type(targetCoords) ~= 'table' or type(targetCoords.x) ~= 'number' or type(targetCoords.y) ~= 'number' or type(targetCoords.z) ~= 'number' then
        TriggerServerEvent(PAM.Events.ActionRequest, { action = 'player.spectate.stop', requestId = ('spectate-stop-%s-%s'):format(GetGameTimer(), math.random(100000, 999999)) })
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    restore = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped), visible = IsEntityVisible(ped), collision = true, frozen = IsEntityPositionFrozen(ped), invincible = GetPlayerInvincible(PlayerId()) }
    SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z + 2.0, false, false, false, false)
    RequestCollisionAtCoord(targetCoords.x, targetCoords.y, targetCoords.z)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    if PAMClient.Open then
        PAMClient.Open = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ type = 'PAM_VISIBILITY', visible = false })
    end
    local deadline = GetGameTimer() + 6000
    local targetPed = 0
    repeat
        local player = GetPlayerFromServerId(targetId)
        if player ~= -1 then
            targetPed = GetPlayerPed(player)
            if targetPed ~= 0 and DoesEntityExist(targetPed) then break end
        end
        Wait(100)
    until GetGameTimer() >= deadline
    if targetPed == 0 or not DoesEntityExist(targetPed) then
        stopSpectate()
        TriggerServerEvent(PAM.Events.ActionRequest, { action = 'player.spectate.stop', requestId = ('spectate-stop-%s-%s'):format(GetGameTimer(), math.random(100000, 999999)) })
        SendNUIMessage({ type = 'PAM_ACTION_RESULT', payload = { success = false, message = 'Unable to stream the target. Check routing bucket or network scope.' } })
        return
    end
    NetworkSetInSpectatorMode(true, targetPed)
    PAMClient.Spectating = true
    spectateStartedAt = GetGameTimer()
    PAMClient.SpectateTarget = targetId
    SendNUIMessage({ type = 'PAM_SPECTATE_STATE', active = true, target = targetId })
end)

RegisterNetEvent(PAM.Events.SpectateStop, stopSpectate)
RegisterCommand('pamspectatestop', function() stopSpectate(); TriggerServerEvent(PAM.Events.ActionRequest, { action = 'player.spectate.stop', requestId = ('spectate-stop-%s-%s'):format(GetGameTimer(), math.random(100000, 999999)) }) end, false)
CreateThread(function()
    local lastCheck = 0
    while true do
        if PAMClient.Spectating then
            if IsControlJustReleased(0, 177) then
                TriggerServerEvent(PAM.Events.ActionRequest, { action = 'player.spectate.stop', requestId = ('spectate-stop-%s-%s'):format(GetGameTimer(), math.random(100000, 999999)) })
                stopSpectate()
            end
            local now = GetGameTimer()
            if now - lastCheck >= 1000 then
                lastCheck = now
                local player = GetPlayerFromServerId(PAMClient.SpectateTarget or -1)
                if player == -1 or not DoesEntityExist(GetPlayerPed(player)) or (now - spectateStartedAt) > (Config.PlayerIntelligence.SpectateRestoreTimeoutMs or 300000) then
                    stopSpectate()
                    TriggerServerEvent(PAM.Events.ActionRequest, { action = 'player.spectate.stop', requestId = ('spectate-stop-%s-%s'):format(GetGameTimer(), math.random(100000, 999999)) })
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stopSpectate() end
end)
