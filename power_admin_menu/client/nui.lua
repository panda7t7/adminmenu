RegisterNUICallback('action', function(data, cb)
    if type(data) ~= 'table' or type(data.action) ~= 'string' then
        cb({ success = false, message = 'Invalid request.' })
        return
    end
    data.requestId = ('%s-%s'):format(GetGameTimer(), math.random(100000, 999999))
    TriggerServerEvent(PAM.Events.ActionRequest, data)
    cb({ success = true, requestId = data.requestId })
end)

RegisterNUICallback('refresh', function(_, cb)
    TriggerServerEvent(PAM.Events.ActionRequest, {
        action = 'players.refresh',
        requestId = ('refresh-%s-%s'):format(GetGameTimer(), math.random(100000, 999999))
    })
    cb({ success = true })
end)


RegisterNUICallback('catalog', function(data, cb)
    local kind = type(data)=='table' and data.kind or nil
    if kind~='vehicles' and kind~='items' and kind~='jobs' then cb({success=false}); return end
    TriggerServerEvent('pam:server:catalog',kind)
    cb({success=true})
end)

RegisterNUICallback('vector', function(_, cb)
    TriggerServerEvent('pam:server:vectorRequest')
    cb({ success = true })
end)

RegisterNUICallback('laserToggle', function(_, cb)
    TriggerEvent('pam:client:laserToggle')
    cb({ success = true })
end)

RegisterNUICallback('spawnObject', function(data, cb)
    local model = type(data) == 'table' and data.model or nil
    TriggerServerEvent('pam:server:spawnObjectRequest', model)
    cb({ success = true })
end)

RegisterNUICallback('objectPlacementControl', function(data, cb)
    if type(data) ~= 'table' or type(data.control) ~= 'string' then
        cb({ success = false })
        return
    end
    TriggerEvent('pam:client:objectPlacementControl', data.control, data.value)
    cb({ success = true })
end)

RegisterNUICallback('managedPropsList', function(_, cb) TriggerServerEvent('pam:server:managedPropsList'); cb({ success = true }) end)
RegisterNUICallback('managedPropDelete', function(data, cb) TriggerServerEvent('pam:server:managedPropDelete', type(data) == 'table' and data.id or nil); cb({ success = true }) end)
