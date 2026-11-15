RegisterNetEvent(PAM.Events.FreezeTarget, function(state)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, state == true)
end)

RegisterNetEvent(PAM.Events.HealTarget, function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent(PAM.Events.TeleportTarget, function(targetServerId)
    local player = GetPlayerFromServerId(targetServerId)
    if player == -1 then return end
    local targetPed = GetPlayerPed(player)
    if not DoesEntityExist(targetPed) then return end
    local coords = GetEntityCoords(targetPed)
    SetEntityCoords(PlayerPedId(), coords.x + 1.0, coords.y, coords.z, false, false, false, false)
end)

RegisterNetEvent(PAM.Events.BringTarget, function(adminServerId)
    local player = GetPlayerFromServerId(adminServerId)
    if player == -1 then return end
    local targetPed = GetPlayerPed(player)
    if not DoesEntityExist(targetPed) then return end
    local coords = GetEntityCoords(targetPed)
    SetEntityCoords(PlayerPedId(), coords.x + 1.0, coords.y, coords.z, false, false, false, false)
end)

RegisterNetEvent(PAM.Events.SetWeather, function(weather)
    if type(weather) ~= 'string' then return end
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypeOvertimePersist(weather, 10.0)
    Wait(10000)
    SetWeatherTypePersist(weather)
    SetWeatherTypeNowPersist(weather)
end)

RegisterNetEvent(PAM.Events.SetTime, function(hour, minute)
    NetworkOverrideClockTime(hour, minute, 0)
end)
